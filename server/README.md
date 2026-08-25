# Friday Chat - Dual-Database Go Chat Backend & WebRTC Signaling

A high-throughput, horizontally scalable chat and voice/video calling backend combining:
1. **Server-Side Firebase Cloud Messaging (FCM HTTP v1)**: Automated high-priority push notifications dispatched to offline users when messages or WebRTC calls arrive.
2. **FCM Push Device Token Management**: `/api/v1/user/device-token` for multi-device push notification delivery.
3. **End-to-End Encryption (E2EE)**: RESTful `/api/v1/users/{id}/key-bundle` endpoint for Signal Protocol PreKey bundle exchanges.
4. **WebRTC Signaling**: Low-latency SDP offer/answer & ICE candidate exchange for P2P calling.
5. **PostgreSQL**: Relational storage for User Auth, Profiles, Contacts, E2EE Keys, and Device Tokens.
6. **Apache Cassandra**: Distributed time-series storage for Chat Room Message History (`gocql`).
7. **Gorilla WebSocket**: High-performance, lock-free real-time message exchange and presence management.

---

## 🔔 Server-Side FCM Push Notification Engine

When a sender sends a message (or initiates a WebRTC call) to an offline/disconnected recipient, the server automatically:
1. Detects that the recipient is not in the active WebSocket session pool.
2. Looks up all registered FCM Device Tokens for that user in PostgreSQL (`user_device_tokens`).
3. Dispatches a high-priority FCM push notification via the **Firebase HTTP v1 API** to wake up the recipient's phone and trigger a heads-up alert.

### FCM Configuration
Set your Firebase project credentials via command-line flags or environment variables:
```bash
go run . -fcm-project "<YOUR_FIREBASE_PROJECT_ID>" -fcm-token "<YOUR_OAUTH2_ACCESS_TOKEN>"
# or
export FCM_PROJECT_ID="friday-chat-app"
export FCM_ACCESS_TOKEN="ya29.c.b0..."
go run .
```

---

## 📲 FCM Device Token Management API

### 1. Register / Update FCM Device Token
**Endpoint**: `POST /api/v1/user/device-token`
```json
{
  "userId": "user_alice",
  "token": "fcm_token_c89x1-89a...",
  "deviceType": "android"
}
```

### 2. Remove FCM Device Token (Logout)
**Endpoint**: `DELETE /api/v1/user/device-token`
```json
{
  "token": "fcm_token_c89x1-89a..."
}
```

---

## 🔒 End-to-End Encryption (E2EE) Public Key API

### 1. Upload User's Public Key Bundle
**Endpoint**: `POST /api/v1/users/{id}/key-bundle`

### 2. Fetch User B's Public Key Bundle (Session Initiation)
**Endpoint**: `GET /api/v1/users/{id}/key-bundle`
- Atomically retrieves User B's Identity Public Key, active Signed PreKey, and consumes/pops 1 One-Time PreKey.

---

## 🚀 Quickstart Guide

### 1. Start PostgreSQL & Cassandra via Docker
```bash
cd server
docker compose up -d
```

### 2. Initialize Cassandra Schema
```bash
docker exec -i friday_chat_cassandra cqlsh < scripts/schema.cql
```

### 3. Run the Go Server
```bash
go mod tidy
go run .
```

---

## 📡 API Routes Summary

| Method | Route | Description |
| :--- | :--- | :--- |
| `POST` | `/api/v1/user/device-token` | Register/Update user's FCM device token |
| `DELETE` | `/api/v1/user/device-token` | Remove FCM device token on logout |
| `GET` | `/api/v1/user/device-token?userId=...` | List active device tokens for user |
| `GET` | `/api/v1/users/{id}/key-bundle` | Fetch User B's Public Key Bundle (consumes 1 OTPK) |
| `POST` | `/api/v1/users/{id}/key-bundle` | Upload User's Public Key Bundle |
| `POST` | `/api/auth/register` | Register user in PostgreSQL |
| `POST` | `/api/auth/login` | Authenticate user |
| `GET` | `/api/contacts?userId=...` | Retrieve contacts list |
| `POST` | `/api/contacts` | Add contact relationship |
| `GET` | `/api/messages?roomId=...` | Fetch chat history from Cassandra |
| `GET` | `/ws?userId=...&userName=...` | WebSocket for chat & WebRTC signaling |
| `GET` | `/health` | Server health check |
