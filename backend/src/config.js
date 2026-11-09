import fs from 'node:fs';

/**
 * Builds the `ssl` option for the pg Pool from environment variables.
 *
 *   DB_SSL=true                 -> encrypt the connection (required by Amazon RDS,
 *                                  whose PostgreSQL 16 parameter group sets
 *                                  rds.force_ssl=1)
 *   DB_SSL_CA=/certs/rds-ca.pem -> also verify the server certificate against
 *                                  this CA bundle (prevents MITM)
 *
 * Locally (docker compose) DB_SSL is unset, so plain TCP is used inside the
 * private Docker bridge network.
 */
export function buildSslConfig(env = process.env) {
  if (String(env.DB_SSL || '').toLowerCase() !== 'true') {
    return false;
  }
  if (env.DB_SSL_CA) {
    return {
      rejectUnauthorized: true,
      ca: fs.readFileSync(env.DB_SSL_CA, 'utf8'),
    };
  }
  // Encrypted but unverified — only as a fallback when no CA bundle is mounted.
  return { rejectUnauthorized: false };
}
