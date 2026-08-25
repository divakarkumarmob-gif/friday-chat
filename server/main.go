package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"

	"friday-chat-server/config"
	"friday-chat-server/database"
	"friday-chat-server/models"
	"friday-chat-server/repository/cassandra"
	"friday-chat-server/repository/postgres"
	"friday-chat-server/services"

	"github.com/gocql/gocql"
	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

func serveWs(hub *Hub, w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query()
	userID := query.Get("userId")
	userName := query.Get("userName")

	if userID == "" {
		http.Error(w, "Missing required query parameter: 'userId'", http.StatusBadRequest)
		return
	}
	if userName == "" {
		userName = fmt.Sprintf("User_%s", userID)
	}

	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("[WebSocket Upgrade Error] User %s: %v", userID, err)
		return
	}

	client := NewClient(hub, conn, userID, userName)
	hub.register <- client

	go client.writePump()
	go client.readPump()
}

func main() {
	// 1. Load runtime configuration from .env and environment variables
	cfg := config.Load()

	// 2. Initialize PostgreSQL Connection & Repositories
	var userRepo *postgres.UserRepository
	var contactRepo *postgres.ContactRepository
	var keyRepo *postgres.KeyRepository
	var deviceRepo *postgres.DeviceRepository

	pgDBConn, err := database.ConnectPostgresURL(cfg.PostgresURL)
	if err != nil {
		log.Printf("⚠️ PostgreSQL not available (%v). Running with in-memory fallback.", err)
	} else {
		defer pgDBConn.Close()
		userRepo = postgres.NewUserRepository(pgDBConn)
		contactRepo = postgres.NewContactRepository(pgDBConn)
		keyRepo = postgres.NewKeyRepository(pgDBConn)
		deviceRepo = postgres.NewDeviceRepository(pgDBConn)
	}

	// 3. Initialize Apache Cassandra Connection & Message Repository
	var msgRepo *cassandra.MessageRepository

	casSession, err := database.ConnectCassandra(database.CassandraConfig{
		Hosts:       []string{cfg.CassandraHost},
		Port:        cfg.CassandraPort,
		Keyspace:    cfg.CassandraKeyspace,
		Consistency: gocql.Quorum,
		Timeout:     5 * time.Second,
	})
	if err != nil {
		log.Printf("⚠️ Cassandra not available (%v). Running without distributed persistence.", err)
	} else {
		defer casSession.Close()
		msgRepo = cassandra.NewMessageRepository(casSession)
	}

	// 4. Initialize Firebase Cloud Messaging Service
	fcmService := services.NewFCMService(services.FCMConfig{
		ProjectID:   cfg.FCMProjectID,
		AccessToken: cfg.FCMServerKey,
	})

	// 5. Initialize WebSocket Hub
	hub := NewHub(msgRepo, deviceRepo, fcmService)
	go hub.Run()

	mux := http.NewServeMux()

	// --- WebSocket Handler ---
	mux.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		serveWs(hub, w, r)
	})

	// --- REST API: User Authentication & Profiles (PostgreSQL) ---
	mux.HandleFunc("/api/auth/register", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}
		if userRepo == nil {
			http.Error(w, "PostgreSQL database not connected", http.StatusServiceUnavailable)
			return
		}

		var req models.RegisterRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "Invalid JSON payload", http.StatusBadRequest)
			return
		}

		userID := fmt.Sprintf("u_%d", time.Now().UnixNano())
		user, err := userRepo.CreateUser(r.Context(), &req, userID)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(models.AuthResponse{
			User:  user,
			Token: "mock_jwt_token_" + user.ID,
		})
	})

	mux.HandleFunc("/api/auth/login", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}
		if userRepo == nil {
			http.Error(w, "PostgreSQL database not connected", http.StatusServiceUnavailable)
			return
		}

		var req models.LoginRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "Invalid JSON payload", http.StatusBadRequest)
			return
		}

		user, err := userRepo.Authenticate(r.Context(), req.Username, req.Password)
		if err != nil {
			http.Error(w, "Invalid username or password", http.StatusUnauthorized)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(models.AuthResponse{
			User:  user,
			Token: "mock_jwt_token_" + user.ID,
		})
	})

	// --- REST API: FCM Device Token Management ---
	mux.HandleFunc("/api/v1/user/device-token", func(w http.ResponseWriter, r *http.Request) {
		if deviceRepo == nil {
			http.Error(w, "PostgreSQL Device repository not connected", http.StatusServiceUnavailable)
			return
		}

		switch r.Method {
		case http.MethodPost:
			var req models.DeviceTokenRequest
			if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
				http.Error(w, "Invalid JSON payload", http.StatusBadRequest)
				return
			}
			if req.UserID == "" || req.Token == "" {
				http.Error(w, "Missing 'userId' or 'token'", http.StatusBadRequest)
				return
			}

			if err := deviceRepo.UpsertDeviceToken(r.Context(), req.UserID, req.Token, req.DeviceType); err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}

			w.WriteHeader(http.StatusOK)
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(map[string]string{
				"status":  "token updated",
				"userId":  req.UserID,
				"message": "FCM device token registered successfully",
			})

		case http.MethodDelete:
			var req models.DeviceTokenDeleteRequest
			if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
				http.Error(w, "Invalid JSON payload", http.StatusBadRequest)
				return
			}
			if req.Token == "" {
				http.Error(w, "Missing 'token' to delete", http.StatusBadRequest)
				return
			}

			if err := deviceRepo.RemoveDeviceToken(r.Context(), req.Token); err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}

			w.WriteHeader(http.StatusOK)
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(map[string]string{
				"status":  "token removed",
				"message": "FCM device token deleted successfully",
			})

		case http.MethodGet:
			userID := r.URL.Query().Get("userId")
			if userID == "" {
				http.Error(w, "Missing 'userId' query parameter", http.StatusBadRequest)
				return
			}

			tokens, err := deviceRepo.GetTokensByUserID(r.Context(), userID)
			if err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(tokens)

		default:
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		}
	})

	// --- REST API: End-to-End Encryption (E2EE) Key Bundles ---
	mux.HandleFunc("/api/v1/users/", func(w http.ResponseWriter, r *http.Request) {
		if keyRepo == nil {
			http.Error(w, "PostgreSQL Key repository not connected", http.StatusServiceUnavailable)
			return
		}

		path := strings.TrimPrefix(r.URL.Path, "/api/v1/users/")
		parts := strings.Split(path, "/")

		if len(parts) != 2 || parts[1] != "key-bundle" {
			http.NotFound(w, r)
			return
		}

		targetUserID := parts[0]
		if targetUserID == "" {
			http.Error(w, "Invalid user ID in URL path", http.StatusBadRequest)
			return
		}

		switch r.Method {
		case http.MethodGet:
			bundle, err := keyRepo.FetchKeyBundle(r.Context(), targetUserID)
			if err != nil {
				http.Error(w, err.Error(), http.StatusNotFound)
				return
			}
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(bundle)

		case http.MethodPost, http.MethodPut:
			var bundle models.PreKeyBundle
			if err := json.NewDecoder(r.Body).Decode(&bundle); err != nil {
				http.Error(w, "Invalid PreKey bundle JSON payload", http.StatusBadRequest)
				return
			}
			bundle.UserID = targetUserID

			if err := keyRepo.SaveKeyBundle(r.Context(), targetUserID, &bundle); err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
			w.WriteHeader(http.StatusCreated)
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(map[string]string{
				"status":  "success",
				"userId":  targetUserID,
				"message": "PreKey bundle registered successfully",
			})

		default:
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		}
	})

	// --- REST API: Contacts (PostgreSQL) ---
	mux.HandleFunc("/api/contacts", func(w http.ResponseWriter, r *http.Request) {
		if contactRepo == nil {
			http.Error(w, "PostgreSQL database not connected", http.StatusServiceUnavailable)
			return
		}

		switch r.Method {
		case http.MethodGet:
			userID := r.URL.Query().Get("userId")
			if userID == "" {
				http.Error(w, "Missing 'userId' query param", http.StatusBadRequest)
				return
			}
			contacts, err := contactRepo.GetContactsByUserID(r.Context(), userID)
			if err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(contacts)

		case http.MethodPost:
			var req struct {
				UserID        string `json:"userId"`
				ContactUserID string `json:"contactUserId"`
				Nickname      string `json:"nickname"`
			}
			if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
				http.Error(w, "Invalid payload", http.StatusBadRequest)
				return
			}
			if err := contactRepo.AddContact(r.Context(), req.UserID, req.ContactUserID, req.Nickname); err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
			w.WriteHeader(http.StatusCreated)
			json.NewEncoder(w).Encode(map[string]string{"status": "contact added"})

		default:
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		}
	})

	// --- REST API: Message History (Apache Cassandra) ---
	mux.HandleFunc("/api/messages", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}
		if msgRepo == nil {
			http.Error(w, "Cassandra database not connected", http.StatusServiceUnavailable)
			return
		}

		query := r.URL.Query()
		roomID := query.Get("roomId")
		if roomID == "" {
			http.Error(w, "Missing 'roomId' query param", http.StatusBadRequest)
			return
		}

		bucket := query.Get("bucket")
		limit, _ := strconv.Atoi(query.Get("limit"))
		if limit <= 0 {
			limit = 50
		}

		var beforeID *gocql.UUID
		if beforeStr := query.Get("before"); beforeStr != "" {
			if parsedUUID, err := gocql.ParseUUID(beforeStr); err == nil {
				beforeID = &parsedUUID
			}
		}

		messages, err := msgRepo.GetMessagesByRoom(r.Context(), roomID, bucket, limit, beforeID)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(messages)
	})

	// --- Health & Stats ---
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"status":       "healthy",
			"postgres":     userRepo != nil,
			"cassandra":    msgRepo != nil,
			"e2eeKeys":     keyRepo != nil,
			"deviceTokens": deviceRepo != nil,
			"fcmPush":      fcmService != nil,
			"time":         time.Now().UTC().Format(time.RFC3339),
		})
	})

	mux.HandleFunc("/stats", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"activeUsers": len(hub.clients),
			"timestamp":   time.Now().UnixMilli(),
		})
	})

	serverAddr := ":" + cfg.Port
	server := &http.Server{
		Addr:         serverAddr,
		Handler:      mux,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	stopChan := make(chan os.Signal, 1)
	signal.Notify(stopChan, os.Interrupt, syscall.SIGTERM)

	go func() {
		log.Printf("==========================================================")
		log.Printf("🚀 Friday Chat Server (PostgreSQL + Cassandra + E2EE + FCM)")
		log.Printf("📡 WebSocket URL: ws://localhost:%s/ws?userId=<ID>&userName=<NAME>", cfg.Port)
		log.Printf("📲 FCM Token API: http://localhost:%s/api/v1/user/device-token", cfg.Port)
		log.Printf("🔑 E2EE Key API : http://localhost:%s/api/v1/users/{id}/key-bundle", cfg.Port)
		log.Printf("🔔 Push Engine  : Firebase HTTP v1 (Project: %s)", cfg.FCMProjectID)
		log.Printf("❤️ Health check : http://localhost:%s/health", cfg.Port)
		log.Printf("==========================================================")
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server error: %v", err)
		}
	}()

	<-stopChan
	log.Println("\n[Shutdown] Shutting down server gracefully...")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.Printf("[Shutdown Error] %v", err)
	}

	log.Println("[Shutdown] Server stopped.")
}
