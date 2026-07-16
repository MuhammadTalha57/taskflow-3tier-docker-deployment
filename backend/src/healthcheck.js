// Used by the Dockerfile HEALTHCHECK instruction.
// Avoids pulling in curl/wget just for a health probe — keeps the image small.
import http from 'node:http';

const options = {
  host: '127.0.0.1',
  port: process.env.PORT || 4000,
  path: '/health',
  timeout: 2000,
};

const req = http.get(options, (res) => {
  process.exit(res.statusCode === 200 ? 0 : 1);
});

req.on('error', () => process.exit(1));
req.on('timeout', () => {
  req.destroy();
  process.exit(1);
});
