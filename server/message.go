package main

import (
	"encoding/json"
	"time"
)

// MessageType defines the category of the payload
type MessageType string

const (
	// Chat message types
	TypeDirect    MessageType = "direct"    // 1-to-1 direct message
	TypeBroadcast MessageType = "broadcast" // Global broadcast
	TypeSystem    MessageType = "system"    // Server alerts, connection events
	TypeAck       MessageType = "ack"       // Message delivery acknowledgement
	TypeTyping    MessageType = "typing"    // Typing indicator
	TypePresence  MessageType = "presence"  // Online / Offline status updates

	// WebRTC Signaling message types
	TypeWebRTCOffer        MessageType = "offer"         // SDP Offer from Caller to Callee
	TypeWebRTCAnswer       MessageType = "answer"        // SDP Answer from Callee to Caller
	TypeWebRTCIceCandidate MessageType = "ice-candidate" // ICE Candidate exchange
	TypeWebRTCHangup       MessageType = "call_hangup"   // Call ended by either peer
	TypeWebRTCReject       MessageType = "call_reject"   // Call declined by Callee
)

// WSMessage represents the standard JSON message frame exchanged over WebSocket
type WSMessage struct {
	Type      MessageType     `json:"type"`                // Type of message
	ID        string          `json:"id,omitempty"`        // Unique message identifier
	From      string          `json:"from,omitempty"`      // Sender User ID
	To        string          `json:"to,omitempty"`        // Receiver User ID
	Content   string          `json:"content,omitempty"`   // Message text or signaling summary
	Payload   json.RawMessage `json:"payload,omitempty"`   // Raw WebRTC SDP/ICE candidate payload
	Timestamp int64           `json:"timestamp"`           // Unix timestamp in milliseconds
}

// NewSystemMessage creates a formatted system alert message
func NewSystemMessage(content string) *WSMessage {
	return &WSMessage{
		Type:      TypeSystem,
		Content:   content,
		Timestamp: time.Now().UnixMilli(),
	}
}

// NewAckMessage creates a delivery confirmation message
func NewAckMessage(messageID, recipientID string) *WSMessage {
	return &WSMessage{
		Type:      TypeAck,
		ID:        messageID,
		To:        recipientID,
		Content:   "delivered",
		Timestamp: time.Now().UnixMilli(),
	}
}

// NewCallRejectMessage creates a call rejection / user unavailable notification
func NewCallRejectMessage(callerID, reason string) *WSMessage {
	return &WSMessage{
		Type:      TypeWebRTCReject,
		To:        callerID,
		Content:   reason,
		Timestamp: time.Now().UnixMilli(),
	}
}
