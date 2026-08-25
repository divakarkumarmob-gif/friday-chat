package config

import (
	"log"
	"os"
	"strconv"

	"github.com/joho/godotenv"
)

// Config holds all runtime environment configuration for the server
type Config struct {
	Port              string
	PostgresURL       string
	CassandraHost     string
	CassandraPort     int
	CassandraKeyspace string
	FCMProjectID      string
	FCMServerKey      string
	JWTSecret         string
}

// Load reads configuration from .env file (if present) and environment variables
func Load() *Config {
	// Attempt to load .env file; if not found, rely on system/container environment variables
	if err := godotenv.Load(".env"); err != nil {
		if err := godotenv.Load(); err != nil {
			log.Println("ℹ️ No .env file found, using system environment variables.")
		}
	}

	casPort, err := strconv.Atoi(getEnv("CASSANDRA_PORT", "9042"))
	if err != nil {
		casPort = 9042
	}

	// Check FCM server key / access token aliases
	fcmKey := getEnv("FCM_SERVER_KEY", "")
	if fcmKey == "" {
		fcmKey = getEnv("FCM_ACCESS_TOKEN", "")
	}

	cfg := &Config{
		Port: getEnv("PORT", "8080"),
		PostgresURL: getEnv(
			"POSTGRES_URL",
			"postgres://chat_user:chat_password@localhost:5432/friday_chat_db?sslmode=disable",
		),
		CassandraHost:     getEnv("CASSANDRA_HOST", "localhost"),
		CassandraPort:     casPort,
		CassandraKeyspace: getEnv("CASSANDRA_KEYSPACE", "friday_chat"),
		FCMProjectID:      getEnv("FCM_PROJECT_ID", "demo-project"),
		FCMServerKey:      fcmKey,
		JWTSecret:         getEnv("JWT_SECRET", "friday_chat_default_jwt_secret_key_change_in_prod"),
	}

	return cfg
}

func getEnv(key, fallback string) string {
	if value, exists := os.LookupEnv(key); exists && value != "" {
		return value
	}
	return fallback
}
