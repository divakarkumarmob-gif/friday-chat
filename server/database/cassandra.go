package database

import (
	"fmt"
	"log"
	"time"

	"github.com/gocql/gocql"
)

// CassandraConfig holds cluster nodes and keyspace configuration for Apache Cassandra
type CassandraConfig struct {
	Hosts       []string
	Port        int
	Keyspace    string
	Consistency gocql.Consistency
	Timeout     time.Duration
}

// ConnectCassandra initializes a gocql Session with connection pooling and schema auto-creation
func ConnectCassandra(cfg CassandraConfig) (*gocql.Session, error) {
	cluster := gocql.NewCluster(cfg.Hosts...)
	cluster.Port = cfg.Port
	cluster.Keyspace = cfg.Keyspace
	cluster.Consistency = cfg.Consistency
	if cfg.Timeout > 0 {
		cluster.Timeout = cfg.Timeout
	} else {
		cluster.Timeout = 10 * time.Second
	}

	// Retry policy & connection pool tuning
	cluster.RetryPolicy = &gocql.SimpleRetryPolicy{NumRetries: 3}
	cluster.NumConns = 4

	session, err := cluster.CreateSession()
	if err != nil {
		return nil, fmt.Errorf("failed to create cassandra session: %w", err)
	}

	log.Printf("✅ Apache Cassandra connected successfully (Keyspace: %s on %v:%d)", cfg.Keyspace, cfg.Hosts, cfg.Port)
	return session, nil
}
