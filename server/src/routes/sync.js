const express = require('express');

module.exports = function (db) {
  const router = express.Router();

  // POST /sync/push
  // Body: { groupId, deviceId, changes: [{ seq, entityType, entityId, opType, payloadCiphertext, payloadNonce, payloadMac, createdAtMs }] }
  router.post('/push', (req, res) => {
    try {
      const { groupId, deviceId, changes } = req.body;
      if (!groupId || !deviceId || !Array.isArray(changes)) {
        return res.status(400).json({ error: 'Missing required fields' });
      }

      // Verify device belongs to group
      const device = db.prepare(
        'SELECT id FROM devices WHERE id = ? AND group_id = ?'
      ).get(deviceId, groupId);
      if (!device) {
        return res.status(403).json({ error: 'Device not registered in group' });
      }

      const insertStmt = db.prepare(`
        INSERT OR IGNORE INTO changes
          (group_id, device_id, seq, created_at_ms, entity_type, entity_id, op_type,
           payload_ciphertext, payload_nonce, payload_mac)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `);

      const insertMany = db.transaction((items) => {
        for (const c of items) {
          insertStmt.run(
            groupId,
            deviceId,
            c.seq,
            c.createdAtMs || Date.now(),
            c.entityType,
            c.entityId,
            c.opType,
            c.payloadCiphertext || null,
            c.payloadNonce || null,
            c.payloadMac || null
          );
        }
      });

      insertMany(changes);
      res.json({ accepted: changes.length });
    } catch (err) {
      console.error('Push error:', err);
      res.status(500).json({ error: 'Internal server error' });
    }
  });

  // GET /sync/pull?groupId=&deviceId=&sinceSeq=
  // Returns changes from OTHER devices in the group
  router.get('/pull', (req, res) => {
    try {
      const { groupId, deviceId, sinceSeq } = req.query;
      if (!groupId || !deviceId) {
        return res.status(400).json({ error: 'groupId and deviceId required' });
      }

      const seq = parseInt(sinceSeq) || 0;

      // Verify device belongs to group
      const device = db.prepare(
        'SELECT id FROM devices WHERE id = ? AND group_id = ?'
      ).get(deviceId, groupId);
      if (!device) {
        return res.status(403).json({ error: 'Device not registered in group' });
      }

      // Get changes from OTHER devices in this group, after sinceSeq
      const changes = db.prepare(`
        SELECT id, device_id, seq, created_at_ms, entity_type, entity_id, op_type,
               payload_ciphertext, payload_nonce, payload_mac
        FROM changes
        WHERE group_id = ? AND device_id != ? AND id > ?
        ORDER BY id ASC
        LIMIT 500
      `).all(groupId, deviceId, seq);

      const result = changes.map(c => ({
        id: c.id,
        deviceId: c.device_id,
        seq: c.seq,
        createdAtMs: c.created_at_ms,
        entityType: c.entity_type,
        entityId: c.entity_id,
        opType: c.op_type,
        payloadCiphertext: c.payload_ciphertext,
        payloadNonce: c.payload_nonce,
        payloadMac: c.payload_mac,
      }));

      res.json({ changes: result });
    } catch (err) {
      console.error('Pull error:', err);
      res.status(500).json({ error: 'Internal server error' });
    }
  });

  return router;
};
