-- PostgreSQL Schema for Friday Chat Relational Data, Signal E2EE Keys & FCM Device Tokens

-- 1. User Profiles
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(64) PRIMARY KEY,
    phone_number VARCHAR(32) UNIQUE NOT NULL,
    username VARCHAR(64) UNIQUE NOT NULL,
    display_name VARCHAR(128) NOT NULL,
    avatar_url TEXT,
    status_bio VARCHAR(256) DEFAULT 'Available',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Authentication Credentials
CREATE TABLE IF NOT EXISTS auth_credentials (
    user_id VARCHAR(64) PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    password_hash VARCHAR(256) NOT NULL,
    last_login_at TIMESTAMP WITH TIME ZONE
);

-- 3. Contact Lists (Address Book)
CREATE TABLE IF NOT EXISTS contacts (
    user_id VARCHAR(64) REFERENCES users(id) ON DELETE CASCADE,
    contact_user_id VARCHAR(64) REFERENCES users(id) ON DELETE CASCADE,
    nickname VARCHAR(128),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, contact_user_id)
);

-- 4. E2EE: Long-Term Public Identity Keys & Registration ID
CREATE TABLE IF NOT EXISTS e2ee_identity_keys (
    user_id VARCHAR(64) PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    registration_id INT NOT NULL,
    public_identity_key TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 5. E2EE: Signed PreKeys (Periodically rotated)
CREATE TABLE IF NOT EXISTS e2ee_signed_prekeys (
    user_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    key_id INT NOT NULL,
    public_key TEXT NOT NULL,
    signature TEXT NOT NULL,
    timestamp BIGINT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, key_id)
);

-- 6. E2EE: One-Time PreKeys (Consumed upon peer session initiation)
CREATE TABLE IF NOT EXISTS e2ee_one_time_prekeys (
    user_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    key_id INT NOT NULL,
    public_key TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, key_id)
);

-- 7. FCM Device Registration Tokens (Multi-device support per user)
CREATE TABLE IF NOT EXISTS user_device_tokens (
    token TEXT PRIMARY KEY,
    user_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_type VARCHAR(32) DEFAULT 'android',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for high-concurrency queries
CREATE INDEX IF NOT EXISTS idx_contacts_user_id ON contacts(user_id);
CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone_number);
CREATE INDEX IF NOT EXISTS idx_otpk_user_id ON e2ee_one_time_prekeys(user_id);
CREATE INDEX IF NOT EXISTS idx_device_tokens_user_id ON user_device_tokens(user_id);
