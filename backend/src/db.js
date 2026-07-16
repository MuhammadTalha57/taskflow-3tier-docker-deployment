import pg from 'pg';

const { Pool } = pg;

// All credentials come from environment variables — nothing hardcoded.
// docker-compose injects these from the .env file.
const pool = new Pool({
  host: process.env.DB_HOST || 'db',
  port: Number(process.env.DB_PORT) || 5432,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

pool.on('error', (err) => {
  // Catches errors on idle clients (e.g. DB restarts) so the process
  // doesn't crash from an unhandled 'error' event.
  console.error('[db] Unexpected error on idle client', err);
});

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/**
 * Connects to Postgres with exponential backoff so the backend container
 * can start before the database is fully ready (Postgres itself can take
 * a few seconds to accept connections even after its container is "up").
 * This is a belt-and-braces safety net on top of the Compose healthcheck
 * + depends_on: condition: service_healthy.
 */
export async function connectWithRetry({
  retries = 10,
  initialDelayMs = 1000,
  maxDelayMs = 15000,
} = {}) {
  let attempt = 0;
  let delay = initialDelayMs;

  while (attempt < retries) {
    try {
      const client = await pool.connect();
      client.release();
      console.log(`[db] Connected to Postgres (attempt ${attempt + 1})`);
      return;
    } catch (err) {
      attempt += 1;
      console.warn(
        `[db] Connection attempt ${attempt}/${retries} failed: ${err.message}`
      );
      if (attempt >= retries) {
        throw new Error(
          `[db] Could not connect to Postgres after ${retries} attempts`
        );
      }
      await sleep(delay);
      delay = Math.min(delay * 2, maxDelayMs); // exponential backoff, capped
    }
  }
}

/**
 * Idempotent schema bootstrap. Safe to run on every startup.
 * For a larger project you'd swap this for a real migration tool
 * (node-pg-migrate, Flyway, etc.) — kept simple here on purpose.
 */
export async function ensureSchema() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS tasks (
      id SERIAL PRIMARY KEY,
      title TEXT NOT NULL,
      done BOOLEAN NOT NULL DEFAULT FALSE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `);
  console.log('[db] Schema verified/created');
}

/**
 * Cheap liveness check used by /health — a single fast query that proves
 * the pool can actually reach and query the database, not just that the
 * process is running.
 */
export async function checkDbHealth() {
  await pool.query('SELECT 1');
}

export default pool;
