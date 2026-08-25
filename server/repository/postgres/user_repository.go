package postgres

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"

	"friday-chat-server/models"
	"golang.org/x/crypto/bcrypt"
)

var (
	ErrUserNotFound      = errors.New("user not found")
	ErrInvalidPassword   = errors.New("invalid credentials")
	ErrUserAlreadyExists = errors.New("user with this username or phone already exists")
)

// UserRepository handles user entity persistence in PostgreSQL
type UserRepository struct {
	db *sql.DB
}

func NewUserRepository(db *sql.DB) *UserRepository {
	return &UserRepository{db: db}
}

// CreateUser registers a new user profile and stores their salted bcrypt password hash
func (r *UserRepository) CreateUser(ctx context.Context, req *models.RegisterRequest, userID string) (*models.User, error) {
	// Hash password with bcrypt
	hashedBytes, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, fmt.Errorf("failed to hash password: %w", err)
	}

	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	now := time.Now().UTC()
	user := &models.User{
		ID:          userID,
		PhoneNumber: req.PhoneNumber,
		Username:    req.Username,
		DisplayName: req.DisplayName,
		AvatarURL:   req.AvatarURL,
		StatusBio:   req.StatusBio,
		CreatedAt:   now,
		UpdatedAt:   now,
	}
	if user.StatusBio == "" {
		user.StatusBio = "Hey there! I am using Friday Chat."
	}

	// 1. Insert into users table
	userQuery := `
		INSERT INTO users (id, phone_number, username, display_name, avatar_url, status_bio, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
	`
	_, err = tx.ExecContext(ctx, userQuery,
		user.ID, user.PhoneNumber, user.Username, user.DisplayName, user.AvatarURL, user.StatusBio, user.CreatedAt, user.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to insert user: %w", err)
	}

	// 2. Insert into auth_credentials table
	authQuery := `
		INSERT INTO auth_credentials (user_id, password_hash, last_login_at)
		VALUES ($1, $2, $3)
	`
	_, err = tx.ExecContext(ctx, authQuery, user.ID, string(hashedBytes), now)
	if err != nil {
		return nil, fmt.Errorf("failed to insert auth credentials: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return nil, err
	}

	return user, nil
}

// GetUserByID retrieves a user profile by unique user ID
func (r *UserRepository) GetUserByID(ctx context.Context, id string) (*models.User, error) {
	query := `
		SELECT id, phone_number, username, display_name, avatar_url, status_bio, created_at, updated_at
		FROM users
		WHERE id = $1
	`
	row := r.db.QueryRowContext(ctx, query, id)

	var u models.User
	var avatar, bio sql.NullString

	err := row.Scan(&u.ID, &u.PhoneNumber, &u.Username, &u.DisplayName, &avatar, &bio, &u.CreatedAt, &u.UpdatedAt)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrUserNotFound
		}
		return nil, err
	}

	u.AvatarURL = avatar.String
	u.StatusBio = bio.String
	return &u, nil
}

// Authenticate verifies username and password, returning the User profile upon success
func (r *UserRepository) Authenticate(ctx context.Context, username, password string) (*models.User, error) {
	query := `
		SELECT u.id, u.phone_number, u.username, u.display_name, u.avatar_url, u.status_bio, u.created_at, u.updated_at, a.password_hash
		FROM users u
		JOIN auth_credentials a ON u.id = a.user_id
		WHERE u.username = $1
	`
	row := r.db.QueryRowContext(ctx, query, username)

	var u models.User
	var avatar, bio sql.NullString
	var passwordHash string

	err := row.Scan(&u.ID, &u.PhoneNumber, &u.Username, &u.DisplayName, &avatar, &bio, &u.CreatedAt, &u.UpdatedAt, &passwordHash)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrInvalidPassword
		}
		return nil, err
	}

	// Compare bcrypt hash
	if err := bcrypt.CompareHashAndPassword([]byte(passwordHash), []byte(password)); err != nil {
		return nil, ErrInvalidPassword
	}

	u.AvatarURL = avatar.String
	u.StatusBio = bio.String

	// Update last login timestamp in background
	go func(userID string) {
		_, _ = r.db.Exec(`UPDATE auth_credentials SET last_login_at = $1 WHERE user_id = $2`, time.Now().UTC(), userID)
	}(u.ID)

	return &u, nil
}
