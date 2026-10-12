const assert = require('node:assert/strict');
const { mkdtempSync, rmSync } = require('node:fs');
const { tmpdir } = require('node:os');
const { join } = require('node:path');
const test = require('node:test');
const { createKeyStore } = require('../key-store');

test('issued keys validate, persist, rotate, and revoke', (context) => {
	const directory = mkdtempSync(join(tmpdir(), 'zachv4-keys-'));
	context.after(() => rmSync(directory, { recursive: true, force: true }));
	const path = join(directory, 'keys.json');
	const discordId = '123456789012345678';
	const store = createKeyStore(path);

	const firstKey = store.issue(discordId);
	assert.match(firstKey, /^ZV-[A-Za-z0-9_-]{32}$/);
	assert.equal(store.validate(firstKey), true);
	assert.equal(createKeyStore(path).validate(firstKey), true);

	const secondKey = store.issue(discordId);
	assert.notEqual(firstKey, secondKey);
	assert.equal(store.validate(firstKey), false);
	assert.equal(store.validate(secondKey), true);
	assert.equal(store.revoke(discordId), true);
	assert.equal(store.validate(secondKey), false);
	assert.equal(store.revoke(discordId), false);
});

test('invalid keys and Discord IDs are rejected', () => {
	const directory = mkdtempSync(join(tmpdir(), 'zachv4-keys-'));
	try {
		const store = createKeyStore(join(directory, 'keys.json'));
		assert.equal(store.validate('not-a-key'), false);
		assert.throws(() => store.issue('not-a-discord-id'), TypeError);
	} finally {
		rmSync(directory, { recursive: true, force: true });
	}
});
