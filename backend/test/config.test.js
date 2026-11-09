import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { buildSslConfig } from '../src/config.js';

test('TLS is disabled when DB_SSL is not set (local docker compose)', () => {
  assert.equal(buildSslConfig({}), false);
  assert.equal(buildSslConfig({ DB_SSL: 'false' }), false);
});

test('TLS without CA bundle encrypts but does not verify', () => {
  assert.deepEqual(buildSslConfig({ DB_SSL: 'true' }), { rejectUnauthorized: false });
});

test('TLS with CA bundle verifies the server certificate (AWS RDS)', () => {
  const caPath = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'ca-')), 'ca.pem');
  fs.writeFileSync(caPath, '-----BEGIN CERTIFICATE-----\nTEST\n-----END CERTIFICATE-----\n');
  const ssl = buildSslConfig({ DB_SSL: 'TRUE', DB_SSL_CA: caPath });
  assert.equal(ssl.rejectUnauthorized, true);
  assert.match(ssl.ca, /BEGIN CERTIFICATE/);
});
