# zachv4 key service

`main.py` runs the Discord key bot and HTTP validation API. The Discord server ID is
`1558998367512559636`; issuing and revoking keys requires the configured admin role
`1559000140675813417`, Discord Administrator, or the server owner.

## Prefix commands

- `.help` (or `,help`) lists the bot commands.
- `.key [@user] [duration]` issues a key by DM. Without a mention it issues a key to
  the command author. The default duration is 30 days.
- `.key revoke @user`, `.revoke @user`, and `.revoke all` revoke keys.
- `.kick @user` revokes that user's key. An already-running script checks every 30
  seconds and kicks its own Roblox client after the service confirms the revocation.
- `.logs` creates or secures the private `#key-usage-logs` channel.

The previous `/antiraid` and `/antilink` moderation slash commands have been removed.

Durations range from one minute to 30 days (one month). Examples include `1m`, `1h`,
`7d`, `1w`, and `1 month`. For example, `.key @user 1 month` issues a key to the
mentioned server member and sends it to their DMs. Issuing another key for the same
Discord user replaces their previous key.

Keys expire at their stored UTC expiry timestamp and are rejected immediately after
that time, including after a service restart. A key becomes permanently bound to the
first Roblox user ID that successfully validates it; attempts from another ID are
rejected. Validation and key lifecycle events include the Discord IDs, Roblox user
ID when provided, result, event time, and expiry in the audit log. The key itself is
never written to the logs.

The `.kick` command cannot kick another player from a Roblox server. It only causes
the client running this script to kick itself after its next successful API check.
Network outages delay that check; an unreachable service does not trigger a kick.

## Bot-Hosting setup

1. Upload `main.py` and `requirements.txt` and set the startup file to `main.py`.
2. Add `DISCORD_BOT_TOKEN` in the host's private environment-variable settings. Keep
   the token out of source code and chat.
3. Enable **Message Content Intent** and **Server Members Intent** in the Discord
   Developer Portal. Invite the bot with the `bot` scope and grant it permission to
   read and reply to server messages, send DMs, manage channels, and view/send in the
   private audit channel. Assign the required role to key administrators.
4. The app listens on `PORT`, then `SERVER_PORT`, then `8787`. Set `KEY_STORE_PATH`
   to a file on persistent storage if the host's working directory is not persistent.
5. Send `.help` in the configured server to see commands.

The HTTP API accepts `POST /validate` with JSON containing both `key` and
`robloxUserId`. The submitted Roblox ID is client-provided, not cryptographically
verified by Roblox; a modified client can spoof it. The Lua script also needs
`shared.VapeKeyApiUrl` set to the public HTTPS base URL before it starts. The Python
listener itself is plain HTTP; use a TLS/HTTPS proxy or a host-provided HTTPS endpoint.

Keys are stored as SHA-256 hashes in `KEY_STORE_PATH` (default `./data/keys.json`).
Legacy records without an expiry are migrated to a 30-day lifetime from their
recorded issue time. Back up this file on persistent storage. The client-side gate
can be modified by users who control the client, so it is not tamper-proof DRM.
