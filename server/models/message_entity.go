package models

import (
	"time"

	"github.com/gocql/gocql"
)

// RoomMessage represents a distributed time-series chat message stored in Cassandra
type RoomMessage struct {
	RoomID      string          `json:"roomId"`
	Bucket      string          `json:"bucket"`
	MessageID   gocql.UUID      `json:"messageId"`
	SenderID    string          `json:"senderId"`
	SenderName  string          `json:"senderName"`
	Content     string          `json:"content"`
	MessageType string          `json:"messageType"`
	CreatedAt   time.Time       `json:"createdAt"`
}

// FormatBucket calculates the monthly partitioning bucket for Cassandra time-series storage
func FormatBucket(t time.Time) string {
	return t.UTC().Format("2006-01")
}
