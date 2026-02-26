const Database = require('better-sqlite3');
const path = require('path');

function initDb() {
  const dbPath = path.join(__dirname, '..', 'data', 'sync.db');
  const fs = require('fs');
  fs.mkdirSync(path.dirname(dbPath), { recursive: true });

  const db = new Database(dbPath);
  db.pragma('journal_mode = WAL');

  db.exec(`
    CREATE TABLE IF NOT EXISTS groups (
      id TEXT PRIMARY KEY,
      created_at INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS devices (
      id TEXT PRIMARY KEY,
      group_id TEXT NOT NULL,
      registered_at INTEGER NOT NULL,
      FOREIGN KEY (group_id) REFERENCES groups(id)
    );

    CREATE TABLE IF NOT EXISTS pairing_tokens (
      token TEXT PRIMARY KEY,
      group_id TEXT NOT NULL,
      creator_device_id TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      used INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (group_id) REFERENCES groups(id)
    );

    CREATE TABLE IF NOT EXISTS changes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      group_id TEXT NOT NULL,
      device_id TEXT NOT NULL,
      seq INTEGER NOT NULL,
      created_at_ms INTEGER NOT NULL,
      entity_type TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      op_type TEXT NOT NULL,
      payload_ciphertext TEXT,
      payload_nonce TEXT,
      payload_mac TEXT,
      UNIQUE(group_id, device_id, seq)
    );

    CREATE INDEX IF NOT EXISTS idx_changes_group_seq
      ON changes(group_id, seq);
  `);

  return db;
}

module.exports = { initDb };
