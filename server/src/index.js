const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const { initDb } = require('./db');
const pairRoutes = require('./routes/pair');
const syncRoutes = require('./routes/sync');

const PORT = process.env.PORT || 8742;

const app = express();
app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '10mb' }));

const db = initDb();

app.use('/pair', pairRoutes(db));
app.use('/sync', syncRoutes(db));

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', version: '1.0.0' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`SyncLedger server running on port ${PORT}`);
  console.log(`Access from LAN: http://<your-pc-ip>:${PORT}`);
});
