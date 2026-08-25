package postgres

import (
	"context"
	"database/sql"
	"fmt"

	"friday-chat-server/models"
)

// DeviceRepository manages FCM device registration tokens in PostgreSQL
type DeviceRepository struct {
	db *sql.DB
}

func NewDeviceRepository(db *sql.DB) *DeviceRepository {
	return &DeviceRepository{db: db}
}

// UpsertDeviceToken registers or reassigns an FCM device token to a User ID
func (r *DeviceRepository) UpsertDeviceToken(ctx context.Context, userID, token, deviceType string) error {
	if deviceType == "" {
		deviceType = "android"
	}

	query := `
		INSERT INTO user_device_tokens (token, user_id, device_type, updated_at)
		VALUES ($1, $2, $3, CURRENT_TIMESTAMP)
		ON CONFLICT (token) DO UPDATE SET
			user_id = EXCLUDED.user_id,
			device_type = EXCLUDED.device_type,
			updated_at = CURRENT_TIMESTAMP
	`

	_, err := r.db.ExecContext(ctx, query, token, userID, deviceType)
	if err != nil {
		return fmt.Errorf("failed to upsert FCM device token: %w", err)
	}
	return nil
}

// RemoveDeviceToken deletes a device token upon user logout
func (r *DeviceRepository) RemoveDeviceToken(ctx context.Context, token string) error {
	query := `DELETE FROM user_device_tokens WHERE token = $1`
	_, err := r.db.ExecContext(ctx, query, token)
	if err != nil {
		return fmt.Errorf("failed to delete FCM device token: %w", err)
	}
	return nil
}

// GetTokensByUserID retrieves all active FCM device tokens registered to a user
func (r *DeviceRepository) GetTokensByUserID(ctx context.Context, userID string) ([]*models.DeviceToken, error) {
	query := `
		SELECT token, user_id, device_type, created_at, updated_at
		FROM user_device_tokens
		WHERE user_id = $1
		ORDER BY updated_at DESC
	`
	rows, err := r.db.QueryContext(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var tokens []*models.DeviceToken
	for rows.Next() {
		var dt models.DeviceToken
		if err := rows.Scan(&dt.Token, &dt.UserID, &dt.DeviceType, &dt.CreatedAt, &dt.UpdatedAt); err != nil {
			return nil, err
		}
		tokens = append(tokens, &dt)
	}
	return tokens, nil
}
