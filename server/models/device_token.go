package models

import "time"

// DeviceToken represents an FCM device registration token associated with a user
type DeviceToken struct {
	Token      string    `json:"token"`
	UserID     string    `json:"userId"`
	DeviceType string    `json:"deviceType"`
	CreatedAt  time.Time `json:"createdAt"`
	UpdatedAt  time.Time `json:"updatedAt"`
}

// DeviceTokenRequest payload for uploading/updating an FCM token
type DeviceTokenRequest struct {
	UserID     string `json:"userId"`
	Token      string `json:"token"`
	DeviceType string `json:"deviceType,omitempty"` // "android", "ios", "web"
}

// DeviceTokenDeleteRequest payload for removing an FCM token on logout
type DeviceTokenDeleteRequest struct {
	Token string `json:"token"`
}
