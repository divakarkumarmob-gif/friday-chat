package services

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"time"
)

// FCMConfig holds Firebase Cloud Messaging project configuration
type FCMConfig struct {
	ProjectID   string
	AccessToken string // OAuth2 token / Server API Key
}

// FCMService handles dispatching push notifications via Firebase HTTP v1 API
type FCMService struct {
	config     FCMConfig
	httpClient *http.Client
}

func NewFCMService(config FCMConfig) *FCMService {
	return &FCMService{
		config: config,
		httpClient: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

// fcmMessage represents the standard Firebase HTTP v1 message structure
type fcmMessage struct {
	Token        string            `json:"token"`
	Notification *fcmNotification  `json:"notification,omitempty"`
	Data         map[string]string `json:"data,omitempty"`
	Android      *fcmAndroid       `json:"android,omitempty"`
	APNS         *fcmAPNS          `json:"apns,omitempty"`
}

type fcmNotification struct {
	Title string `json:"title"`
	Body  string `json:"body"`
}

type fcmAndroid struct {
	Priority     string             `json:"priority"` // "HIGH"
	Notification *fcmAndroidDetails `json:"notification,omitempty"`
}

type fcmAndroidDetails struct {
	ChannelID   string `json:"channel_id"`
	Sound       string `json:"sound"`
	ClickAction string `json:"click_action,omitempty"`
}

type fcmAPNS struct {
	Payload *fcmAPNSPayload `json:"payload,omitempty"`
}

type fcmAPNSPayload struct {
	Aps *fcmAps `json:"aps,omitempty"`
}

type fcmAps struct {
	Sound            string `json:"sound"`
	Badge            int    `json:"badge"`
	ContentAvailable int    `json:"content-available"`
}

type fcmPayloadWrapper struct {
	Message fcmMessage `json:"message"`
}

// SendPushNotification sends a high-priority push notification to a single FCM device token
func (s *FCMService) SendPushNotification(
	ctx context.Context,
	deviceToken string,
	title string,
	body string,
	data map[string]string,
) error {
	if deviceToken == "" {
		return fmt.Errorf("empty device token")
	}

	// Construct FCM HTTP v1 message payload
	msg := fcmMessage{
		Token: deviceToken,
		Notification: &fcmNotification{
			Title: title,
			Body:  body,
		},
		Data: data,
		Android: &fcmAndroid{
			Priority: "HIGH",
			Notification: &fcmAndroidDetails{
				ChannelID:   "friday_chat_messages",
				Sound:       "default",
				ClickAction: "FLUTTER_NOTIFICATION_CLICK",
			},
		},
		APNS: &fcmAPNS{
			Payload: &fcmAPNSPayload{
				Aps: &fcmAps{
					Sound:            "default",
					Badge:            1,
					ContentAvailable: 1,
				},
			},
		},
	}

	wrapper := fcmPayloadWrapper{Message: msg}
	bodyBytes, err := json.Marshal(wrapper)
	if err != nil {
		return fmt.Errorf("failed to marshal FCM payload: %w", err)
	}

	// In development / fallback mode when ProjectID is default
	if s.config.ProjectID == "" || s.config.ProjectID == "demo-project" {
		log.Printf("🔔 [FCM:Simulated] High-Priority Push Dispatched to Token='%s...' Title='%s' Body='%s' Data=%v",
			truncate(deviceToken, 16), title, body, data)
		return nil
	}

	// Production HTTP v1 API endpoint
	url := fmt.Sprintf("https://fcm.googleapis.com/v1/projects/%s/messages:send", s.config.ProjectID)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(bodyBytes))
	if err != nil {
		return fmt.Errorf("failed to create FCM request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	if s.config.AccessToken != "" {
		req.Header.Set("Authorization", "Bearer "+s.config.AccessToken)
	}

	resp, err := s.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("FCM network error: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		respBody, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("FCM server responded with status %d: %s", resp.StatusCode, string(respBody))
	}

	log.Printf("✅ [FCM] Push successfully delivered to token: %s", truncate(deviceToken, 16))
	return nil
}

// SendMulticastPush delivers the push notification across all registered devices of a user
func (s *FCMService) SendMulticastPush(
	ctx context.Context,
	deviceTokens []string,
	title string,
	body string,
	data map[string]string,
) {
	for _, token := range deviceTokens {
		go func(t string) {
			pushCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()
			if err := s.SendPushNotification(pushCtx, t, title, body, data); err != nil {
				log.Printf("⚠️ [FCM Error] Failed sending to token '%s': %v", truncate(t, 16), err)
			}
		}(token)
	}
}

func truncate(s string, length int) string {
	if len(s) <= length {
		return s
	}
	return s[:length] + "..."
}
