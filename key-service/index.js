const { Client, Events, GatewayIntentBits, PermissionsBitField } = require('discord.js');
const { resolve } = require('node:path');
const { createKeyStore } = require('./key-store');
const { createValidationServer } = require('./server');

const token = process.env.DISCORD_BOT_TOKEN;
if (!token) {
	throw new Error('DISCORD_BOT_TOKEN must be set');
}

const port = Number(process.env.PORT || 8787);
if (!Number.isInteger(port) || port < 1 || port > 65535) {
	throw new Error('PORT must be a valid TCP port');
}

const keyStorePath = resolve(process.env.KEY_STORE_PATH || './data/keys.json');
const allowedGuildId = process.env.DISCORD_GUILD_ID || null;
const keyStore = createKeyStore(keyStorePath);

const client = new Client({
	intents: [
		GatewayIntentBits.Guilds,
		GatewayIntentBits.GuildMessages,
		GatewayIntentBits.MessageContent
	]
});

async function handleMessage(message) {
	if (message.author.bot || !message.guild) return;
	if (allowedGuildId && message.guild.id !== allowedGuildId) return;

	const command = message.content.trim();
	if (command === '.key') {
		const key = keyStore.issue(message.author.id);
		try {
			await message.author.send(`Your zachv4 access key is:\n\`${key}\`\n\nThis key stays active until you generate another one or a server admin revokes it. Keep it private.`);
			await message.reply('I sent your key in a DM. Keep it private.');
		} catch (error) {
			console.error(`Could not deliver a key to Discord user ${message.author.id}:`, error);
			await message.reply('I could not DM you. Enable server-member DMs and run `.key` again; that will generate a fresh key.');
		}
		return;
	}

	const revokeMatch = command.match(/^\.key\s+revoke\s+<@!?(\d+)>$/);
	if (!revokeMatch) return;

	if (!message.member.permissions.has(PermissionsBitField.Flags.Administrator)) {
		await message.reply('Only server admins can revoke keys.');
		return;
	}

	const revoked = keyStore.revoke(revokeMatch[1]);
	await message.reply(revoked ? 'That user’s key has been revoked.' : 'That user has no active key.');
}

client.on(Events.MessageCreate, (message) => {
	void handleMessage(message).catch(async (error) => {
		console.error('Discord key command failed:', error);
		try {
			await message.reply('The key command failed. Please ask an admin to check the key service logs.');
		} catch (replyError) {
			console.error('Could not report the key command failure in Discord:', replyError);
		}
	});
});

client.once(Events.ClientReady, (readyClient) => {
	console.log(`Key bot logged in as ${readyClient.user.tag}`);
});

client.on(Events.Error, (error) => {
	console.error('Discord client error:', error);
});

async function start() {
	await client.login(token);
	const server = createValidationServer(keyStore);
	server.on('error', (error) => {
		console.error('Key validation server error:', error);
		process.exitCode = 1;
		client.destroy();
	});
	server.listen(port, '0.0.0.0', () => {
		console.log(`Key validation API listening on port ${port}`);
	});
}

start().catch((error) => {
	console.error('Key service failed to start:', error);
	process.exitCode = 1;
	client.destroy();
});
