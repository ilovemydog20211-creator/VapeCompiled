# zachv4 key service

This service runs a Discord `.key` bot and an HTTP API used by the key prompt in `main.lua`.
Each Discord user has one active key. Running `.key` again rotates it; an administrator can
revoke a user's key with `.key revoke @user`. Keys do not expire automatically.

## Setup

1. Use Node.js 20 or newer. Upload the contents of this directory to a Node.js deployment
   (or upload the repository and set the deployment root to `key-service`).
2. Create a Discord application and bot in the Discord Developer Portal. Copy the bot token
   into the host's environment-variable manager as `DISCORD_BOT_TOKEN`. Never commit or share
   the real token.
3. Enable the **Message Content Intent** for the bot. Invite it to your server with permissions
   to read messages, send messages, and send DMs. Set `DISCORD_GUILD_ID` to your server ID in
   the environment-variable manager.
4. Deploy this service on a host with a stable public HTTPS URL and persistent storage. Make
   sure the host exposes the port configured by `PORT`. Set `PORT` to the host's assigned
   port and `KEY_STORE_PATH` to a file on persistent storage.
5. Before loading `main.lua`, configure the executor environment with:

   ```lua
   shared.VapeKeyApiUrl = 'https://your-public-key-service.example'
   ```

   The URL must be the HTTPS base URL only; the script appends `/validate`.
6. Run `npm install` once and set the startup command to `npm start`. Users can request keys
   by sending `.key` in the configured server. The bot sends each key privately by DM.

The API accepts `POST /validate` with JSON `{ "key": "..." }` and responds with
`{ "valid": true }` or `{ "valid": false }`. It has a per-IP request limit of 60 checks per
minute. The API should only be exposed through HTTPS; do not expose the plain HTTP listener
directly to the public internet.

The service stores only SHA-256 hashes of generated keys in `KEY_STORE_PATH` (default
`./data/keys.json`); back up that file on persistent storage. The Discord bot token and the
key store are not needed by the Lua client. Client-side checks can be modified by users who
control the client, so this is a license gate, not tamper-proof DRM.

Run the automated tests with `npm test`.
