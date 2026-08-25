package database

import (
	"database/sql"
	"fmt"
	"log"
	"time"

	_ "github.com/lib/pq"
)

// PostgresConfig holds credentials and host settings for PostgreSQL connection
type PostgresConfig struct {
	Host     string
	Port     int
	User     string
	Password string
	DBName   string
	SSLMode  string
}

// ConnectPostgres establishes a managed connection pool to PostgreSQL using explicit config
func ConnectPostgres(cfg PostgresConfig) (*sql.DB, error) {
	connStr := fmt.Sprintf(
		"host=%s port=%d user=%s password=%s dbname=%s sslmode=%s",
		cfg.Host, cfg.Port, cfg.User, cfg.Password, cfg.DBName, cfg.SSLMode,
	)
	return initDB(connStr)
}

// ConnectPostgresURL establishes a connection pool using a standard postgres:// URL
func ConnectPostgresURL(url string) (*sql.DB, error) {
	return initDB(url)
}

func initDB(connStr string) (*sql.DB, error) {
	db, err := sql.Open("postgres", connStr)
	if err != nil {
		return nil, fmt.Errorf("failed to open postgres connection: %w", err)
	}

	// Configure connection pool limits
	db.SetMaxOpenConns(50)
	db.SetMaxIdleConns(25)
	db.SetConnMaxLifetime(5 * time.Minute)

	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("failed to ping postgres: %w", err)
	}

	log.Printf("✅ PostgreSQL database connected successfully")
	return db, nil
}
