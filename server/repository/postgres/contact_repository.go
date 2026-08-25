package postgres

import (
	"context"
	"database/sql"
	"time"

	"friday-chat-server/models"
)

// ContactRepository handles contact list queries in PostgreSQL
type ContactRepository struct {
	db *sql.DB
}

func NewContactRepository(db *sql.DB) *ContactRepository {
	return &ContactRepository{db: db}
}

// AddContact links a contact to a user's address book
func (r *ContactRepository) AddContact(ctx context.Context, userID, contactUserID, nickname string) error {
	query := `
		INSERT INTO contacts (user_id, contact_user_id, nickname, created_at)
		VALUES ($1, $2, $3, $4)
		ON CONFLICT (user_id, contact_user_id) 
		DO UPDATE SET nickname = EXCLUDED.nickname
	`
	_, err := r.db.ExecContext(ctx, query, userID, contactUserID, nickname, time.Now().UTC())
	return err
}

// GetContactsByUserID fetches all contacts for a specific user with their profile details
func (r *ContactRepository) GetContactsByUserID(ctx context.Context, userID string) ([]*models.Contact, error) {
	query := `
		SELECT c.user_id, c.contact_user_id, c.nickname, c.created_at,
		       u.id, u.phone_number, u.username, u.display_name, u.avatar_url, u.status_bio, u.created_at, u.updated_at
		FROM contacts c
		JOIN users u ON c.contact_user_id = u.id
		WHERE c.user_id = $1
		ORDER BY u.display_name ASC
	`
	rows, err := r.db.QueryContext(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var contacts []*models.Contact
	for rows.Next() {
		var c models.Contact
		var nickname sql.NullString
		var u models.User
		var avatar, bio sql.NullString

		err := rows.Scan(
			&c.UserID, &c.ContactUserID, &nickname, &c.CreatedAt,
			&u.ID, &u.PhoneNumber, &u.Username, &u.DisplayName, &avatar, &bio, &u.CreatedAt, &u.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}

		c.Nickname = nickname.String
		u.AvatarURL = avatar.String
		u.StatusBio = bio.String
		c.Profile = &u

		contacts = append(contacts, &c)
	}

	return contacts, nil
}

// RemoveContact deletes a contact relation
func (r *ContactRepository) RemoveContact(ctx context.Context, userID, contactUserID string) error {
	query := `DELETE FROM contacts WHERE user_id = $1 AND contact_user_id = $2`
	_, err := r.db.ExecContext(ctx, query, userID, contactUserID)
	return err
}
