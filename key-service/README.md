# zachv4 key service

`main.py` runs the Discord `.key` bot and HTTP validation API. The Discord server ID is set to
`1558998367512559636`, and `.key` requires role ID `1559000140675813417` unless the member
is the server owner. Use `.key` or `,key` to request a key. Each eligible user has one active
key; requesting another rotates it. A Discord administrator can revoke a key with
`.key revoke @user` or `,key revoke @user`, revoke every key with `.revoke all`, or revoke an
individual key with `.revoke @user`. An administrator can create a private usage-log channel
with `.logs`; successful validations are logged with the Discord account that was issued the
key. Logs do not identify or verify the Roblox account using the key.

## Bot-Hosting setup

1. Upload `main.py` and `requirements.txt` to the server. Set the startup file to `main.py`.
2. Add `DISCORD_BOT_TOKEN` in the host's private environment-variable settings. Use a newly
   reset token and do not put it in source code or chat.
3. Enable **Message Content Intent** in the Discord Developer Portal. Give the bot permission
   to read and reply to server messages, send DMs, manage channels (for `.logs`), and view/send
   in the private log channel. Assign the required role to users who should be able to generate
   keys.
4. The app listens on `PORT`, then `SERVER_PORT`, then `8787`. Configure the host's assigned
   port as `PORT` if it does not provide either variable automatically. Set `KEY_STORE_PATH`
   to a file on persistent storage if the host's working directory is not persistent.
5. Send `.key` in the configured Discord server. The bot DMs the generated key.

The HTTP API accepts `POST /validate` with JSON `{ "key": "..." }`. The Lua script also needs
`shared.VapeKeyApiUrl` set to the public HTTPS base URL before it starts. The Python listener
itself is plain HTTP; use a TLS/HTTPS proxy or a host-provided HTTPS endpoint in front of the
assigned port. A raw IP and port do not provide HTTPS by themselves.

Keys are stored as SHA-256 hashes in `KEY_STORE_PATH` (default `./data/keys.json`). Back up
this file on persistent storage. The client-side gate can be modified by users who control
the client, so it is not tamper-proof DRM.
