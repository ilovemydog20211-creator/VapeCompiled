# zachv4 key service

`main.py` runs the Discord `.key` bot and HTTP validation API. The Discord server ID is set to
`1558998367512559636`, and `.key` requires role ID `1559000140675813417` unless the member
is the server owner. Use `.key` or `,key` to request a key. Each eligible user has one active
key; requesting another rotates it. A Discord administrator can revoke a key with
`.key revoke @user` or `,key revoke @user`, revoke every key with `.revoke all`, or revoke an
individual key with `.revoke @user`. An administrator can create a private usage-log channel
with `.logs`; successful validations are logged with the Discord account that was issued the
key. Logs do not identify or verify the Roblox account using the key.

## Moderation commands

The bot registers the guild-scoped `/antiraid` and `/antilink` slash commands. Only the server
owner, a Discord administrator, or a member with the configured admin role can change these
settings. Both protections are disabled by default, and settings are saved in
`MODERATION_STORE_PATH` (default `./data/moderation.json`).

- `/antiraid` shows the current settings. Optional settings let you enable/disable protection,
  choose a join threshold (2-100) and time window (1-300 seconds), and pick `warn`, `timeout`,
  `kick`, or `ban`. When the threshold is reached, the selected action is applied once to all
  non-admin members who joined during that window. Further joins are included if the threshold
  remains reached. Timeouts last 10 minutes.
- `/antilink` shows the current settings. Choose whether to enable it and pick `delete`, `warn`,
  `timeout`, `kick`, or `ban`. Link messages are deleted when possible; the selected action is
  then applied (except `delete`, which only removes the message). Server admins are exempt.

The bot needs the `applications.commands` invite scope for slash commands. Enable the
**Server Members Intent** in the Discord Developer Portal and in the bot for anti-raid join
detection. Grant **Manage Messages** for link deletion, and grant **Moderate Members**,
**Kick Members**, and/or **Ban Members** if those punishments will be selected. The bot's role
must be above members it needs to timeout, kick, or ban.

## Bot-Hosting setup

1. Upload `main.py` and `requirements.txt` to the server. Set the startup file to `main.py`.
2. Add `DISCORD_BOT_TOKEN` in the host's private environment-variable settings. Use a newly
   reset token and do not put it in source code or chat.
3. Enable **Message Content Intent** and **Server Members Intent** in the Discord Developer
   Portal. Invite the bot with the `bot` and `applications.commands` scopes. Give it permission
   to read and reply to server messages, send DMs, manage channels (for `.logs`), and view/send
   in the private log channel. For moderation, also grant the permissions listed above. Assign
   the required role to users who should be able to generate keys.
4. The app listens on `PORT`, then `SERVER_PORT`, then `8787`. Configure the host's assigned
   port as `PORT` if it does not provide either variable automatically. Set `KEY_STORE_PATH`
   and `MODERATION_STORE_PATH` to files on persistent storage if the host's working directory
   is not persistent.
5. Send `/antiraid` or `/antilink` in the configured Discord server to configure protection,
   or send `.key` to request a key. The bot DMs the generated key.

The HTTP API accepts `POST /validate` with JSON containing both `key` and `robloxUserId`.
On first successful use, the service permanently binds that key to the submitted Roblox
user ID; subsequent checks from a different ID are rejected. This is a client-submitted ID,
not cryptographic Roblox account verification, so a modified client can spoof it.
The Lua script also needs
`shared.VapeKeyApiUrl` set to the public HTTPS base URL before it starts. The Python listener
itself is plain HTTP; use a TLS/HTTPS proxy or a host-provided HTTPS endpoint in front of the
assigned port. A raw IP and port do not provide HTTPS by themselves.

Keys are stored as SHA-256 hashes in `KEY_STORE_PATH` (default `./data/keys.json`). Back up
this file on persistent storage. The client-side gate can be modified by users who control
the client, so it is not tamper-proof DRM.
