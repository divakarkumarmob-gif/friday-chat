package main

import (
	"context"
	"encoding/json"
	"log"
	"time"

	"friday-chat-server/models"
	"friday-chat-server/repository/cassandra"
	"friday-chat-server/repository/postgres"
	"friday-chat-server/services"
)

// Hub maintains the set of active clients and handles message routing,
// persistence, WebRTC signaling, and offline push notifications via Go channels.
type Hub struct {
	// Registered clients indexed by User ID.
	clients map[string]map[*Client]bool

	// Inbound register requests from newly connected clients.
	register chan *Client

	// Inbound unregister requests from disconnecting clients.
	unregister chan *Client

	// Inbound messages to be routed to specific recipients or broadcasted.
	dispatch chan *WSMessage

	// Outbound broadcast messages to all active clients.
	broadcast chan []byte

	// Distributed Cassandra message repository for persistence
	msgRepo *cassandra.MessageRepository

	// PostgreSQL Device repository for querying FCM tokens
	deviceRepo *postgres.DeviceRepository

	// Firebase Cloud Messaging client
	fcmService *services.FCMService
}

// NewHub creates and initializes a new Hub instance.
func NewHub(
	msgRepo *cassandra.MessageRepository,
	deviceRepo *postgres.DeviceRepository,
	fcmService *services.FCMService,
) *Hub {
	return &Hub{
		clients:    make(map[string]map[*Client]bool),
		register:   make(chan *Client),
		unregister: make(chan *Client),
		dispatch:   make(chan *WSMessage),
		broadcast:  make(chan []byte),
		msgRepo:    msgRepo,
		deviceRepo: deviceRepo,
		fcmService: fcmService,
	}
}

// Run executes the central event loop in a dedicated goroutine.
func (h *Hub) Run() {
	for {
		select {
		case client := <-h.register:
			h.handleRegister(client)

		case client := <-h.unregister:
			h.handleUnregister(client)

		case msg := <-h.dispatch:
			h.handleDispatch(msg)

		case data := <-h.broadcast:
			h.handleBroadcast(data)
		}
	}
}

// handleRegister registers a client and initializes its user session map.
func (h *Hub) handleRegister(client *Client) {
	if _, ok := h.clients[client.UserID]; !ok {
		h.clients[client.UserID] = make(map[*Client]bool)
	}
	h.clients[client.UserID][client] = true

	log.Printf("[Hub] User registered: ID=%s Name='%s' (Active devices for user: %d, Total online users: %d)",
		client.UserID, client.UserName, len(h.clients[client.UserID]), len(h.clients))

	welcomeMsg, _ := json.Marshal(WSMessage{
		Type:      TypeSystem,
		Content:   "Connected to Friday Chat Server. Session established.",
		Timestamp: time.Now().UnixMilli(),
	})
	client.send <- welcomeMsg

	// Broadcast presence update (User Online)
	h.broadcastPresence(client.UserID, client.UserName, true)
}

// handleUnregister cleans up disconnected client sessions and channels.
func (h *Hub) handleUnregister(client *Client) {
	if userClients, ok := h.clients[client.UserID]; ok {
		if _, clientExists := userClients[client]; clientExists {
			delete(userClients, client)
			close(client.send)

			log.Printf("[Hub] Device disconnected for User: ID=%s (Remaining devices: %d)",
				client.UserID, len(userClients))

			if len(userClients) == 0 {
				delete(h.clients, client.UserID)
				log.Printf("[Hub] User completely offline: ID=%s (Total online users: %d)",
					client.UserID, len(h.clients))

				h.broadcastPresence(client.UserID, client.UserName, false)
			}
		}
	}
}

// handleDispatch routes incoming messages based on their type.
func (h *Hub) handleDispatch(msg *WSMessage) {
	encoded, err := json.Marshal(msg)
	if err != nil {
		log.Printf("[Hub] Failed to encode message %s: %v", msg.ID, err)
		return
	}

	switch msg.Type {
	// 💬 Chat Messages
	case TypeDirect:
		h.routeDirectMessage(msg, encoded)
		h.persistMessageAsync(msg)

	case TypeTyping:
		h.routeTypingIndicator(msg, encoded)

	case TypeBroadcast:
		h.handleBroadcast(encoded)
		h.persistMessageAsync(msg)

	// 📞 WebRTC Signaling Handlers (Peer-to-Peer Calls)
	case TypeWebRTCOffer, TypeWebRTCAnswer, TypeWebRTCIceCandidate, TypeWebRTCHangup, TypeWebRTCReject:
		h.routeWebRTCSignaling(msg, encoded)

	default:
		log.Printf("[Hub] Unhandled message type: %s from %s", msg.Type, msg.From)
	}
}

// routeDirectMessage sends a message to all active sessions of the destination user.
func (h *Hub) routeDirectMessage(msg *WSMessage, rawData []byte) {
	recipientSessions, online := h.clients[msg.To]

	if online && len(recipientSessions) > 0 {
		for client := range recipientSessions {
			select {
			case client.send <- rawData:
			default:
				close(client.send)
				delete(recipientSessions, client)
			}
		}
		log.Printf("[Hub:Direct] Routed msg ID=%s from %s -> %s (Delivered)", msg.ID, msg.From, msg.To)

		// Send delivery ACK back to sender
		if senderSessions, senderOnline := h.clients[msg.From]; senderOnline {
			ackMsg, _ := json.Marshal(NewAckMessage(msg.ID, msg.To))
			for senderClient := range senderSessions {
				select {
				case senderClient.send <- ackMsg:
				default:
				}
			}
		}
	} else {
		log.Printf("[Hub:Direct] User %s is offline. Message ID=%s saved & dispatching FCM push...", msg.To, msg.ID)

		// 1. Send push notification to offline recipient's registered devices via FCM
		h.sendOfflinePushNotification(msg)

		// 2. Notify sender that recipient is offline
		if senderSessions, senderOnline := h.clients[msg.From]; senderOnline {
			offlineAlert, _ := json.Marshal(WSMessage{
				Type:      TypeSystem,
				ID:        msg.ID,
				To:        msg.From,
				Content:   "Recipient is currently offline. Push notification delivered.",
				Timestamp: msg.Timestamp,
			})
			for senderClient := range senderSessions {
				select {
				case senderClient.send <- offlineAlert:
				default:
				}
			}
		}
	}
}

// sendOfflinePushNotification queries PostgreSQL for recipient's FCM tokens and dispatches an FCM push
func (h *Hub) sendOfflinePushNotification(msg *WSMessage) {
	if h.deviceRepo == nil || h.fcmService == nil {
		return
	}

	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		tokens, err := h.deviceRepo.GetTokensByUserID(ctx, msg.To)
		if err != nil || len(tokens) == 0 {
			log.Printf("[FCM:Skip] No active device tokens found for offline user %s", msg.To)
			return
		}

		tokenStrings := make([]string, 0, len(tokens))
		for _, t := range tokens {
			tokenStrings = append(tokenStrings, t.Token)
		}

		title := "New Message"
		if msg.From != "" {
			title = "Message from " + msg.From
		}

		body := "🔒 Encrypted Message"
		if msg.Content != "" && msg.Content != "🔒 Encrypted message" {
			body = msg.Content
		}

		data := map[string]string{
			"conversationId": msg.From,
			"senderId":       msg.From,
			"senderName":     msg.From,
			"messageId":      msg.ID,
			"type":           string(msg.Type),
			"timestamp":      time.Now().Format(time.RFC3339),
		}

		h.fcmService.SendMulticastPush(ctx, tokenStrings, title, body, data)
	}()
}

// routeWebRTCSignaling securely forwards WebRTC SDP offers/answers and ICE candidates between peers
func (h *Hub) routeWebRTCSignaling(msg *WSMessage, rawData []byte) {
	if msg.To == "" {
		log.Printf("[Hub:WebRTC] Missing target recipient 'to' for signaling event %s from %s", msg.Type, msg.From)
		return
	}

	recipientSessions, online := h.clients[msg.To]

	if online && len(recipientSessions) > 0 {
		for client := range recipientSessions {
			select {
			case client.send <- rawData:
			default:
				close(client.send)
				delete(recipientSessions, client)
			}
		}
		log.Printf("[Hub:WebRTC] Forwarded %s signaling: %s -> %s", msg.Type, msg.From, msg.To)
	} else {
		log.Printf("[Hub:WebRTC] Recipient %s is offline for %s", msg.To, msg.Type)

		if msg.Type == TypeWebRTCOffer {
			// Trigger high-priority call push notification to wake up recipient device
			h.sendOfflineCallPushNotification(msg)

			// Notify caller that recipient is currently offline
			if callerSessions, callerOnline := h.clients[msg.From]; callerOnline {
				rejectMsg, _ := json.Marshal(NewCallRejectMessage(msg.From, "User is currently offline (Call notification sent)"))
				for callerClient := range callerSessions {
					select {
					case callerClient.send <- rejectMsg:
					default:
					}
				}
			}
		}
	}
}

// sendOfflineCallPushNotification delivers an urgent incoming call push notification
func (h *Hub) sendOfflineCallPushNotification(msg *WSMessage) {
	if h.deviceRepo == nil || h.fcmService == nil {
		return
	}

	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		tokens, err := h.deviceRepo.GetTokensByUserID(ctx, msg.To)
		if err != nil || len(tokens) == 0 {
			return
		}

		tokenStrings := make([]string, 0, len(tokens))
		for _, t := range tokens {
			tokenStrings = append(tokenStrings, t.Token)
		}

		callType := "Voice"
		if msg.Content == "video" {
			callType = "Video"
		}

		title := "Incoming " + callType + " Call"
		body := msg.From + " is calling you..."

		data := map[string]string{
			"conversationId": msg.From,
			"callerId":       msg.From,
			"callerName":     msg.From,
			"type":           "incoming_call",
			"callType":       callType,
		}

		h.fcmService.SendMulticastPush(ctx, tokenStrings, title, body, data)
	}()
}

// routeTypingIndicator forwards typing signals to the recipient without ACK.
func (h *Hub) routeTypingIndicator(msg *WSMessage, rawData []byte) {
	if recipientSessions, online := h.clients[msg.To]; online {
		for client := range recipientSessions {
			select {
			case client.send <- rawData:
			default:
			}
		}
	}
}

// handleBroadcast sends data to all connected clients across all users.
func (h *Hub) handleBroadcast(data []byte) {
	for _, userClients := range h.clients {
		for client := range userClients {
			select {
			case client.send <- data:
			default:
				close(client.send)
				delete(userClients, client)
			}
		}
	}
}

// broadcastPresence broadcasts user online/offline status changes to all connected peers.
func (h *Hub) broadcastPresence(userID, userName string, isOnline bool) {
	status := "offline"
	if isOnline {
		status = "online"
	}

	presencePayload, _ := json.Marshal(map[string]interface{}{
		"userId":   userID,
		"userName": userName,
		"status":   status,
	})

	presenceMsg, _ := json.Marshal(WSMessage{
		Type:      TypePresence,
		From:      userID,
		Content:   status,
		Payload:   presencePayload,
		Timestamp: time.Now().UnixMilli(),
	})

	go func() {
		h.broadcast <- presenceMsg
	}()
}

// persistMessageAsync saves the message to Apache Cassandra asynchronously
func (h *Hub) persistMessageAsync(msg *WSMessage) {
	if h.msgRepo == nil {
		return
	}

	go func() {
		roomID := msg.To
		if msg.Type == TypeDirect {
			if msg.From < msg.To {
				roomID = msg.From + ":" + msg.To
			} else {
				roomID = msg.To + ":" + msg.From
			}
		}

		entity := &models.RoomMessage{
			RoomID:      roomID,
			SenderID:    msg.From,
			SenderName:  msg.From,
			Content:     msg.Content,
			MessageType: string(msg.Type),
			CreatedAt:   time.UnixMilli(msg.Timestamp).UTC(),
		}

		ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		defer cancel()

		if err := h.msgRepo.SaveMessage(ctx, entity); err != nil {
			log.Printf("[Cassandra Persist Error] Msg ID=%s: %v", msg.ID, err)
		} else {
			log.Printf("[Cassandra Persist Success] Room=%s Msg ID=%s saved", roomID, msg.ID)
		}
	}()
}
