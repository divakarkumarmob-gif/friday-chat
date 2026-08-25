package cassandra

import (
	"context"
	"fmt"
	"time"

	"friday-chat-server/models"
	"github.com/gocql/gocql"
)

// MessageRepository handles distributed time-series chat history persistence in Apache Cassandra
type MessageRepository struct {
	session *gocql.Session
}

func NewMessageRepository(session *gocql.Session) *MessageRepository {
	return &MessageRepository{session: session}
}

// SaveMessage writes a chat message into the time-series table partitioned by room_id and time bucket
func (r *MessageRepository) SaveMessage(ctx context.Context, msg *models.RoomMessage) error {
	if msg.MessageID == (gocql.UUID{}) {
		msg.MessageID = gocql.TimeUUID()
	}
	if msg.CreatedAt.IsZero() {
		msg.CreatedAt = time.Now().UTC()
	}
	if msg.Bucket == "" {
		msg.Bucket = models.FormatBucket(msg.CreatedAt)
	}

	query := `
		INSERT INTO friday_chat.messages_by_room (
			room_id, bucket, message_id, sender_id, sender_name, content, message_type, created_at
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
	`

	err := r.session.Query(query,
		msg.RoomID,
		msg.Bucket,
		msg.MessageID,
		msg.SenderID,
		msg.SenderName,
		msg.Content,
		msg.MessageType,
		msg.CreatedAt,
	).WithContext(ctx).Exec()

	if err != nil {
		return fmt.Errorf("failed to save message to cassandra: %w", err)
	}

	return nil
}

// GetMessagesByRoom retrieves message history for a chat room within a time bucket, ordered by newest first
func (r *MessageRepository) GetMessagesByRoom(
	ctx context.Context,
	roomID string,
	bucket string,
	limit int,
	beforeID *gocql.UUID,
) ([]*models.RoomMessage, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	if bucket == "" {
		bucket = models.FormatBucket(time.Now().UTC())
	}

	var query string
	var iter *gocql.Iter

	if beforeID != nil && *beforeID != (gocql.UUID{}) {
		// Pagination: fetch messages older than beforeID
		query = `
			SELECT room_id, bucket, message_id, sender_id, sender_name, content, message_type, created_at
			FROM friday_chat.messages_by_room
			WHERE room_id = ? AND bucket = ? AND message_id < ?
			ORDER BY message_id DESC
			LIMIT ?
		`
		iter = r.session.Query(query, roomID, bucket, *beforeID, limit).WithContext(ctx).Iter()
	} else {
		// Fetch most recent messages in this bucket
		query = `
			SELECT room_id, bucket, message_id, sender_id, sender_name, content, message_type, created_at
			FROM friday_chat.messages_by_room
			WHERE room_id = ? AND bucket = ?
			ORDER BY message_id DESC
			LIMIT ?
		`
		iter = r.session.Query(query, roomID, bucket, limit).WithContext(ctx).Iter()
	}

	var messages []*models.RoomMessage
	var m models.RoomMessage

	for iter.Scan(
		&m.RoomID,
		&m.Bucket,
		&m.MessageID,
		&m.SenderID,
		&m.SenderName,
		&m.Content,
		&m.MessageType,
		&m.CreatedAt,
	) {
		copied := m
		messages = append(messages, &copied)
	}

	if err := iter.Close(); err != nil {
		return nil, fmt.Errorf("error reading messages from cassandra: %w", err)
	}

	return messages, nil
}
