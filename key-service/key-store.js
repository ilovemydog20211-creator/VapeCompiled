const { createHash, randomBytes } = require('node:crypto');
const { mkdirSync, readFileSync, renameSync, writeFileSync } = require('node:fs');
const { dirname } = require('node:path');

const KEY_PATTERN = /^ZV-[A-Za-z0-9_-]{32}$/;
const HASH_PATTERN = /^[a-f0-9]{64}$/;
const DISCORD_ID_PATTERN = /^\d{17,20}$/;

function hashKey(key) {
	return createHash('sha256').update(key, 'utf8').digest('hex');
}

function createKeyStore(filePath) {
	mkdirSync(dirname(filePath), { recursive: true });

	const users = new Map();
	const hashes = new Set();

	try {
		const data = JSON.parse(readFileSync(filePath, 'utf8'));
		if (data.version !== 1 || !Array.isArray(data.keys)) {
			throw new Error('Key store has an unsupported format');
		}

		for (const entry of data.keys) {
			if (
				!entry ||
				!DISCORD_ID_PATTERN.test(entry.discordId) ||
				!HASH_PATTERN.test(entry.keyHash) ||
				hashes.has(entry.keyHash)
			) {
				throw new Error('Key store contains an invalid key record');
			}
			users.set(entry.discordId, entry);
			hashes.add(entry.keyHash);
		}
	} catch (error) {
		if (error.code !== 'ENOENT') {
			throw error;
		}
	}

	function save(records) {
		const temporaryPath = `${filePath}.${process.pid}.tmp`;
		const contents = JSON.stringify({
			version: 1,
			keys: Array.from(records.values())
		}, null, 2);
		writeFileSync(temporaryPath, contents, { mode: 0o600 });
		renameSync(temporaryPath, filePath);
	}

	return {
		issue(discordId) {
			if (!DISCORD_ID_PATTERN.test(discordId)) {
				throw new TypeError('A valid Discord user ID is required');
			}

			const key = `ZV-${randomBytes(24).toString('base64url')}`;
			const record = {
				discordId,
				keyHash: hashKey(key),
				issuedAt: new Date().toISOString()
			};
			const nextUsers = new Map(users);
			nextUsers.set(discordId, record);
			save(nextUsers);

			const previous = users.get(discordId);
			if (previous) hashes.delete(previous.keyHash);
			users.set(discordId, record);
			hashes.add(record.keyHash);
			return key;
		},

		validate(key) {
			return typeof key === 'string' &&
				KEY_PATTERN.test(key) &&
				hashes.has(hashKey(key));
		},

		revoke(discordId) {
			const record = users.get(discordId);
			if (!record) return false;
			const nextUsers = new Map(users);
			nextUsers.delete(discordId);
			save(nextUsers);
			users.delete(discordId);
			hashes.delete(record.keyHash);
			return true;
		}
	};
}

module.exports = { createKeyStore };
