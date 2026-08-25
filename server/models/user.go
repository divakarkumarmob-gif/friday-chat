package models

import "time"

// User represents a relational user profile in PostgreSQL
type User struct {
	ID          string    `json:"id"`
	PhoneNumber string    `json:"phoneNumber"`
	Username    string    `json:"username"`
	DisplayName string    `json:"displayName"`
	AvatarURL   string    `json:"avatarUrl,omitempty"`
	StatusBio   string    `json:"statusBio,omitempty"`
	CreatedAt   time.Time `json:"createdAt"`
	UpdatedAt   time.Time `json:"updatedAt"`
}

// Contact represents an entry in a user's address book
type Contact struct {
	UserID        string    `json:"userId"`
	ContactUserID string    `json:"contactUserId"`
	Nickname      string    `json:"nickname,omitempty"`
	Profile       *User     `json:"profile,omitempty"`
	CreatedAt     time.Time `json:"createdAt"`
}

// RegisterRequest payload for user onboarding
type RegisterRequest struct {
	PhoneNumber string `json:"phoneNumber"`
	Username    string `json:"username"`
	DisplayName string `json:"displayName"`
	Password    string `json:"password"`
	AvatarURL   string `json:"avatarUrl,omitempty"`
	StatusBio   string `json:"statusBio,omitempty"`
}

// LoginRequest payload for authentication
type LoginRequest struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

// AuthResponse payload returned upon successful login/registration
type AuthResponse struct {
	User  *User  `json:"user"`
	Token string `json:"token"`
}
