-- Apache Cassandra Schema for Distributed Time-Series Message History

CREATE KEYSPACE IF NOT EXISTS friday_chat 
WITH replication = {
    'class': 'SimpleStrategy', 
    'replication_factor': 1
};

-- Time-series messages table partitioned by room_id and time bucket.
-- Clustered by message_id (timeuuid) in descending order to fetch recent messages first.
CREATE TABLE IF NOT EXISTS friday_chat.messages_by_room (
    room_id text,
    bucket text,                  -- Time bucket, e.g. "2026-08" to keep partitions bounded
    message_id timeuuid,          -- TimeUUID encodes creation timestamp and uniqueness
    sender_id text,
    sender_name text,
    content text,
    message_type text,            -- text, image, audio, document, etc.
    created_at timestamp,
    PRIMARY KEY ((room_id, bucket), message_id)
) WITH CLUSTERING ORDER BY (message_id DESC);

-- Index table to keep track of a user's recent conversations
CREATE TABLE IF NOT EXISTS friday_chat.user_inbox (
    user_id text,
    room_id text,
    last_message_id timeuuid,
    last_sender_id text,
    last_message_content text,
    updated_at timestamp,
    PRIMARY KEY (user_id, updated_at, room_id)
) WITH CLUSTERING ORDER BY (updated_at DESC);
