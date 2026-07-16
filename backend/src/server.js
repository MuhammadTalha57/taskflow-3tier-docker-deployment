import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import tasksRouter from './routes/tasks.js';
import { connectWithRetry, ensureSchema, checkDbHealth } from './db.js';

const app = express();
const PORT = process.env.PORT || 4000;

app.use(cors());
app.use(express.json());

// Simple request logger — helpful for demoing/debugging in a portfolio context.
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} ${req.method} ${req.path}`);
  next();
});

app.get('/health', async (req, res) => {
  try {
    await checkDbHealth();
    res.status(200).json({ status: 'ok', db: 'connected' });
  } catch (err) {
    res.status(503).json({ status: 'unhealthy', db: 'unreachable', error: err.message });
  }
});

app.use('/api/tasks', tasksRouter);

// 404 fallback
app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// Central error handler
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error('[server] Unhandled error', err);
  res.status(500).json({ error: 'Internal server error' });
});

async function start() {
  try {
    console.log('[server] Waiting for database...');
    await connectWithRetry();
    await ensureSchema();

    const server = app.listen(PORT, () => {
      console.log(`[server] Backend listening on port ${PORT}`);
    });

    // Graceful shutdown for clean container stop/restart behavior.
    const shutdown = (signal) => {
      console.log(`[server] Received ${signal}, shutting down gracefully...`);
      server.close(() => {
        console.log('[server] Closed out remaining connections');
        process.exit(0);
      });
    };
    process.on('SIGTERM', () => shutdown('SIGTERM'));
    process.on('SIGINT', () => shutdown('SIGINT'));
  } catch (err) {
    console.error('[server] Fatal startup error:', err.message);
    process.exit(1);
  }
}

start();
