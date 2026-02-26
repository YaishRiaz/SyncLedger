# SyncLedger

Privacy-first personal finance & Sri Lankan CSE stock tracker via SMS parsing, with optional Family Sync over your home network.

## Features

- **SMS Parsing**: Automatically parses HNB, NDB, and CDS-Alerts SMS messages
- **Offline-First**: All data stored locally on your phone (SQLite via Drift)
- **Transfer Matching**: Automatically links NDB outward transfers with HNB CEFT credits
- **Stock Tracking**: Tracks CSE stock activity from CDS-Alerts (buys, sells, deposits, withdrawals)
- **Family Sync**: Optional E2EE sync between family devices over local Wi-Fi
- **Analytics**: Monthly cashflow, category breakdown, top merchants, stock activity
- **Privacy**: Raw SMS text is never stored (unless Debug Mode is enabled)

## Architecture

```
lib/
  core/           - Constants, theme, extensions, logger
  data/
    db/           - Drift database schema & queries
    sms/          - Flutter SMS plugin interface
    sync/         - E2EE crypto, sync client, sync service
  domain/
    models/       - Data models & enums
    parsers/      - HNB, NDB, CDS SMS parsers
    services/     - Transfer matcher, auto-tagger, investment service
  presentation/
    providers/    - Riverpod state management
    screens/      - UI screens (onboarding, dashboard, transactions, stocks, analytics, family, settings)
    widgets/      - Reusable widgets

android/          - Native Kotlin SMS plugin (BroadcastReceiver + ContentResolver)
server/           - Node.js sync relay server (Docker-ready)
test/             - Unit tests for parsers, matcher, tagger
```

## How to Run

### Prerequisites

1. **Flutter SDK** (3.16+): https://docs.flutter.dev/get-started/install
2. **Android Studio** with Android SDK 23+
3. **A physical Android phone** (SMS reading doesn't work on emulators)
4. **USB cable** for connecting phone to PC

### Step 1: Set Up Flutter

```bash
# Clone or copy the project
cd SyncLedger

# Get dependencies
flutter pub get

# Generate Drift database code
dart run build_runner build --delete-conflicting-outputs
```-

### Step 2: Connect Your Phone

1. On your Android phone: Settings → Developer Options → Enable **USB Debugging**
   - (If Developer Options is hidden: Settings → About Phone → tap **Build Number** 7 times)
2. Connect phone via USB
3. Verify connection:
   ```bash
   flutter devices
   ```

### Step 3: Run the App

```bash
flutter run
```

### Step 4: Grant SMS Permissions

- On first launch, go through the onboarding screens
- On the Dashboard, tap **Import SMS** — the app will request SMS permissions
- Grant both READ_SMS and RECEIVE_SMS
- The app will scan your inbox for HNB, NDB, and CDS-Alerts messages

### Step 5: Start the Family Sync Server (Optional)

On your PC (must be on the same Wi-Fi as your phones):

```bash
cd server

# Option A: Docker (recommended)
docker compose up -d

# Option B: Node.js directly
npm install
npm start
```

Find your PC's local IP:
- **Windows**: `ipconfig` → look for "IPv4 Address" (e.g., `192.168.1.100`)
- **Mac/Linux**: `ifconfig | grep inet`

### Step 6: Pair Devices

1. **Phone A** (first device):
   - Go to Family tab → "Setup Pairing" → "Create Group" → "Generate QR Code"
2. **Phone B** (second device):
   - Go to Family tab → "Setup Pairing" → "Join Group" → "Start Scanning"
   - Scan the QR code from Phone A
3. Both phones should show "Connected to family group"

### Step 7: Sync

- On either phone: Family tab → "Sync Now"
- Both phones must be on the same Wi-Fi as the PC running the server

## SMS Formats Supported

### HNB (Hatton National Bank)
- CEFT credit: `HNB LKR X,XXX.XX credited to Ac No:... Reason:CEFT-...`
- Card/online debit: `HNB SMS ALERT:INTERNET, Account:..., Location:..., Amount:...`
- Fees: `A Transaction for LKR XX.XX has been debit ed ... Remarks:...`
- Reversals: `HNB TRANSACTION REVERSAL ... Amount:XXX.XX LKR`

### NDB (National Development Bank)
- Debit: `LKR X,XXX.XX debited from AC ... as CEFTS Outward Transfer`
- Fee: `LKR XX.XX debited ... as CEFTS Transfer Charges`
- POS: `LKR XXX.XX debited ... as POS TXN ... at MERCHANT`
- Credit: `LKR X,XXX.XX credited to AC ... as Mobile Banking TXN`

### CDS-Alerts (Colombo Stock Exchange)
- Trades: `CDS-Alerts DD-MMM-YY PURCHASES SYMBOL QTY SALES SYMBOL QTY`
- Deposits: `CDS-Alerts DD-MMM-YY DEPOSITS SYMBOL QTY`
- Withdrawals: `CDS-Alerts DD-MMM-YY WITHDRAWALS SYMBOL QTY`

## Running Tests

```bash
flutter test
```

## Security Design

- **On-device encryption**: Raw SMS stored only in Debug Mode; otherwise only parsed fields + hash
- **Family Sync E2EE**: XChaCha20-Poly1305 authenticated encryption
- **Shared key**: Derived during QR pairing, never transmitted to server
- **Server sees only**: Group IDs, device IDs, sequence numbers, and ciphertext blobs
- **No cloud**: All sync happens over local Wi-Fi only

## License

Private / All rights reserved.
