# SyncLedger Family Sync Server

A lightweight local server that relays **encrypted** data between family devices on your home Wi-Fi. The server **never** sees your financial data — it only stores and forwards encrypted blobs.

## Quick Start

### Option A: Docker (Recommended)

```bash
cd server
docker compose up -d
```

Server runs at `http://<your-pc-ip>:8742`

### Option B: Node.js Directly

```bash
cd server
npm install
npm start
```

### Find Your PC's IP Address

**Windows:**
```
ipconfig
```
Look for "IPv4 Address" under your Wi-Fi adapter (e.g., `192.168.1.100`)

**Mac/Linux:**
```
ifconfig | grep inet
```

### Pairing Devices

1. On Phone A: Go to Family tab → Setup Pairing → Create Group → "Generate QR Code"
2. On Phone B: Go to Family tab → Setup Pairing → Join Group → "Start Scanning"
3. Scan the QR code shown on Phone A

### Syncing

- Press "Sync Now" on the Family tab
- Both phones must be on the same Wi-Fi as the PC running this server

## Security

- All data is encrypted with XChaCha20-Poly1305 on-device before transmission
- The shared encryption key is exchanged during QR pairing and never sent to the server
- The server stores only: group IDs, device IDs, sequence numbers, and ciphertext blobs
- No financial data, SMS content, or personal information is accessible to the server

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/pair/start` | Create family group and get pairing token |
| POST | `/pair/finish` | Join family group with pairing token |
| POST | `/sync/push` | Push encrypted changes from device |
| GET | `/sync/pull` | Pull encrypted changes for device |
| GET | `/health` | Health check |
