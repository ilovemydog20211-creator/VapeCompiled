const assert = require('node:assert/strict');
const { mkdtempSync, rmSync } = require('node:fs');
const { tmpdir } = require('node:os');
const { join } = require('node:path');
const test = require('node:test');
const { createKeyStore } = require('../key-store');
const { createValidationServer } = require('../server');

test('validation API accepts active keys and rejects invalid ones', async (context) => {
	const directory = mkdtempSync(join(tmpdir(), 'zachv4-api-'));
	context.after(() => rmSync(directory, { recursive: true, force: true }));
	const store = createKeyStore(join(directory, 'keys.json'));
	const key = store.issue('123456789012345678');
	const server = createValidationServer(store);
	await new Promise((resolve, reject) => {
		server.once('error', reject);
		server.listen(0, '127.0.0.1', resolve);
	});
	context.after(() => new Promise((resolve, reject) => {
		server.close((error) => error ? reject(error) : resolve());
	}));

	const address = server.address();
	const endpoint = `http://127.0.0.1:${address.port}/validate`;
	const validResponse = await fetch(endpoint, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify({ key })
	});
	assert.equal(validResponse.status, 200);
	assert.deepEqual(await validResponse.json(), { valid: true });

	const invalidResponse = await fetch(endpoint, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify({ key: 'invalid' })
	});
	assert.equal(invalidResponse.status, 200);
	assert.deepEqual(await invalidResponse.json(), { valid: false });
});

test('validation API rejects malformed JSON and unsupported routes', async (context) => {
	const directory = mkdtempSync(join(tmpdir(), 'zachv4-api-'));
	context.after(() => rmSync(directory, { recursive: true, force: true }));
	const server = createValidationServer(createKeyStore(join(directory, 'keys.json')));
	await new Promise((resolve, reject) => {
		server.once('error', reject);
		server.listen(0, '127.0.0.1', resolve);
	});
	context.after(() => new Promise((resolve, reject) => {
		server.close((error) => error ? reject(error) : resolve());
	}));

	const endpoint = `http://127.0.0.1:${server.address().port}`;
	const malformedResponse = await fetch(`${endpoint}/validate`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: '{'
	});
	assert.equal(malformedResponse.status, 400);

	const missingRouteResponse = await fetch(`${endpoint}/missing`, { method: 'POST' });
	assert.equal(missingRouteResponse.status, 404);
});
