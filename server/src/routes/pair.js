const express = require('express');
const { v4: uuidv4 } = require('uuid');

module.exports = function (db) {
  const router = express.Router();

  // POST /pair/start
  // Body: { groupId, deviceId }
  // Returns: { pairingToken }
  router.post('/start', (req, res) => {
    try {
      const { groupId, deviceId } = req.body;
      if (!groupId || !deviceId) {
        return res.status(400).json({ error: 'groupId and deviceId required' });
      }

      // Create group if not exists
      const existingGroup = db.prepare('SELECT id FROM groups WHERE id = ?').get(groupId);
      if (!existingGroup) {
        db.prepare('INSERT INTO groups (id, created_at) VALUES (?, ?)').run(
          groupId,
          Date.now()
        );
      }

      // Register creator device
      const existingDevice = db.prepare('SELECT id FROM devices WHERE id = ?').get(deviceId);
      if (!existingDevice) {
        db.prepare('INSERT INTO devices (id, group_id, registered_at) VALUES (?, ?, ?)').run(
          deviceId,
          groupId,
          Date.now()
        );
      }

      // Generate pairing token
      const pairingToken = uuidv4();
      db.prepare(
        'INSERT INTO pairing_tokens (token, group_id, creator_device_id, created_at) VALUES (?, ?, ?, ?)'
      ).run(pairingToken, groupId, deviceId, Date.now());

      res.json({ pairingToken });
    } catch (err) {
      console.error('Pair start error:', err);
      res.status(500).json({ error: 'Internal server error' });
    }
  });

  // POST /pair/finish
  // Body: { groupId, deviceId, pairingToken }
  router.post('/finish', (req, res) => {
    try {
      const { groupId, deviceId, pairingToken } = req.body;
      if (!groupId || !deviceId || !pairingToken) {
        return res.status(400).json({ error: 'Missing required fields' });
      }

      // Validate token
      const token = db.prepare(
        'SELECT * FROM pairing_tokens WHERE token = ? AND group_id = ? AND used = 0'
      ).get(pairingToken, groupId);

      if (!token) {
        return res.status(403).json({ error: 'Invalid or already used pairing token' });
      }

      // Mark token as used
      db.prepare('UPDATE pairing_tokens SET used = 1 WHERE token = ?').run(pairingToken);

      // Register the joining device
      const existingDevice = db.prepare('SELECT id FROM devices WHERE id = ?').get(deviceId);
      if (!existingDevice) {
        db.prepare('INSERT INTO devices (id, group_id, registered_at) VALUES (?, ?, ?)').run(
          deviceId,
          groupId,
          Date.now()
        );
      }

      res.json({ success: true, groupId });
    } catch (err) {
      console.error('Pair finish error:', err);
      res.status(500).json({ error: 'Internal server error' });
    }
  });

  return router;
};
