const http = require('node:http');

const BODY_LIMIT = 1024;
const RATE_LIMIT = 60;
const RATE_WINDOW_MS = 60_000;

function sendJson(response, statusCode, body) {
	response.writeHead(statusCode, {
		'Content-Type': 'application/json; charset=utf-8',
		'Cache-Control': 'no-store',
		'X-Content-Type-Options': 'nosniff'
	});
	response.end(JSON.stringify(body));
}

function createValidationServer(keyStore) {
	const requests = new Map();

	return http.createServer(async (request, response) => {
		if (request.method !== 'POST' || request.url !== '/validate') {
			sendJson(response, 404, { error: 'Not found' });
			return;
		}

		const now = Date.now();
		const address = request.socket.remoteAddress || 'unknown';
		let window = requests.get(address);
		if (!window || now - window.startedAt >= RATE_WINDOW_MS) {
			window = { startedAt: now, count: 0 };
			requests.set(address, window);
		}
		window.count += 1;

		if (requests.size > 10_000) {
			for (const [ip, entry] of requests) {
				if (now - entry.startedAt >= RATE_WINDOW_MS) requests.delete(ip);
			}
		}

		if (window.count > RATE_LIMIT) {
			sendJson(response, 429, { error: 'Too many requests' });
			return;
		}

		let body = '';
		try {
			for await (const chunk of request) {
				body += chunk;
				if (Buffer.byteLength(body, 'utf8') > BODY_LIMIT) {
					sendJson(response, 413, { error: 'Request too large' });
					request.destroy();
					return;
				}
			}

			const payload = JSON.parse(body);
			if (!payload || typeof payload.key !== 'string') {
				sendJson(response, 400, { error: 'A key is required' });
				return;
			}

			sendJson(response, 200, { valid: keyStore.validate(payload.key) });
		} catch (error) {
			if (response.headersSent || response.destroyed) return;
			if (error instanceof SyntaxError) {
				sendJson(response, 400, { error: 'Invalid JSON' });
				return;
			}

			console.error('Key validation request failed:', error);
			sendJson(response, 500, { error: 'Internal server error' });
		}
	});
}

module.exports = { createValidationServer };
