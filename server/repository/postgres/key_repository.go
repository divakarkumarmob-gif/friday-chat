package postgres

import (
	"context"
	"database/sql"
	"errors"
	"fmt"

	"friday-chat-server/models"
)

var ErrPreKeyBundleNotFound = errors.New("public key bundle not found for user")

// KeyRepository handles Signal Protocol E2EE public keys in PostgreSQL
type KeyRepository struct {
	db *sql.DB
}

func NewKeyRepository(db *sql.DB) *KeyRepository {
	return &KeyRepository{db: db}
}

// SaveKeyBundle saves or updates a user's Public Identity Key, Signed PreKey, and One-Time PreKeys
func (r *KeyRepository) SaveKeyBundle(ctx context.Context, userID string, bundle *models.PreKeyBundle) error {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	// 1. Upsert Identity Key
	identityQuery := `
		INSERT INTO e2ee_identity_keys (user_id, registration_id, public_identity_key, updated_at)
		VALUES ($1, $2, $3, CURRENT_TIMESTAMP)
		ON CONFLICT (user_id) DO UPDATE SET
			registration_id = EXCLUDED.registration_id,
			public_identity_key = EXCLUDED.public_identity_key,
			updated_at = CURRENT_TIMESTAMP
	`
	_, err = tx.ExecContext(ctx, identityQuery, userID, bundle.RegistrationID, bundle.IdentityKey)
	if err != nil {
		return fmt.Errorf("failed to upsert identity key: %w", err)
	}

	// 2. Upsert Signed PreKey
	signedQuery := `
		INSERT INTO e2ee_signed_prekeys (user_id, key_id, public_key, signature, timestamp)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (user_id, key_id) DO UPDATE SET
			public_key = EXCLUDED.public_key,
			signature = EXCLUDED.signature,
			timestamp = EXCLUDED.timestamp
	`
	_, err = tx.ExecContext(ctx, signedQuery,
		userID,
		bundle.SignedPreKey.KeyID,
		bundle.SignedPreKey.PublicKey,
		bundle.SignedPreKey.Signature,
		bundle.SignedPreKey.Timestamp,
	)
	if err != nil {
		return fmt.Errorf("failed to upsert signed prekey: %w", err)
	}

	// 3. Insert One-Time PreKeys
	if len(bundle.OneTimePreKeys) > 0 {
		stmt, err := tx.PrepareContext(ctx, `
			INSERT INTO e2ee_one_time_prekeys (user_id, key_id, public_key)
			VALUES ($1, $2, $3)
			ON CONFLICT (user_id, key_id) DO UPDATE SET public_key = EXCLUDED.public_key
		`)
		if err != nil {
			return err
		}
		defer stmt.Close()

		for _, otpk := range bundle.OneTimePreKeys {
			if _, err := stmt.ExecContext(ctx, userID, otpk.KeyID, otpk.PublicKey); err != nil {
				return fmt.Errorf("failed to insert one-time prekey %d: %w", otpk.KeyID, err)
			}
		}
	}

	return tx.Commit()
}

// FetchKeyBundle retrieves a user's Public Key Bundle and consumes one One-Time PreKey
func (r *KeyRepository) FetchKeyBundle(ctx context.Context, targetUserID string) (*models.PreKeyBundle, error) {
	// 1. Fetch Identity Key
	var registrationID int
	var identityKey string
	err := r.db.QueryRowContext(ctx, `
		SELECT registration_id, public_identity_key 
		FROM e2ee_identity_keys 
		WHERE user_id = $1
	`, targetUserID).Scan(&registrationID, &identityKey)

	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrPreKeyBundleNotFound
		}
		return nil, fmt.Errorf("error fetching identity key: %w", err)
	}

	// 2. Fetch Active Signed PreKey (latest)
	var signedPreKey models.SignedPreKey
	err = r.db.QueryRowContext(ctx, `
		SELECT key_id, public_key, signature, timestamp 
		FROM e2ee_signed_prekeys 
		WHERE user_id = $1 
		ORDER BY key_id DESC LIMIT 1
	`, targetUserID).Scan(
		&signedPreKey.KeyID,
		&signedPreKey.PublicKey,
		&signedPreKey.Signature,
		&signedPreKey.Timestamp,
	)
	if err != nil {
		return nil, fmt.Errorf("error fetching signed prekey: %w", err)
	}

	bundle := &models.PreKeyBundle{
		UserID:         targetUserID,
		RegistrationID: registrationID,
		IdentityKey:    identityKey,
		SignedPreKey:   signedPreKey,
		OneTimePreKeys: []models.OneTimePreKey{},
	}

	// 3. Atomically consume 1 One-Time PreKey (OTPK) if available
	otpkRow := r.db.QueryRowContext(ctx, `
		DELETE FROM e2ee_one_time_prekeys 
		WHERE ctid IN (
			SELECT ctid FROM e2ee_one_time_prekeys WHERE user_id = $1 LIMIT 1
		)
		RETURNING key_id, public_key
	`, targetUserID)

	var otpk models.OneTimePreKey
	if err := otpkRow.Scan(&otpk.KeyID, &otpk.PublicKey); err == nil {
		bundle.OneTimePreKeys = append(bundle.OneTimePreKeys, otpk)
	}

	return bundle, nil
}
