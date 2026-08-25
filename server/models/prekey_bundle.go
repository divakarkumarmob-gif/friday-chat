package models

// SignedPreKey represents the rotated public key signed with the user's Identity Key
type SignedPreKey struct {
	KeyID     int    `json:"keyId"`
	PublicKey string `json:"publicKey"`
	Signature string `json:"signature"`
	Timestamp int64  `json:"timestamp"`
}

// OneTimePreKey represents a single-use public key for X3DH session initiation
type OneTimePreKey struct {
	KeyID     int    `json:"keyId"`
	PublicKey string `json:"publicKey"`
}

// PreKeyBundle represents the public cryptographic bundle published by a user
type PreKeyBundle struct {
	UserID         string          `json:"userId"`
	RegistrationID int             `json:"registrationId"`
	IdentityKey    string          `json:"identityKey"`
	SignedPreKey   SignedPreKey    `json:"signedPreKey"`
	OneTimePreKeys []OneTimePreKey `json:"oneTimePreKeys,omitempty"`
}
