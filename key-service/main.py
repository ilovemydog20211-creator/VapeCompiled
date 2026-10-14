import hashlib
import json
import os
import re
import secrets
import threading
import time
import asyncio
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import discord
from discord import app_commands


DISCORD_GUILD_ID = "1558998367512559636"
ADMIN_ROLE_ID = "1559000140675813417"
PORT = int(os.environ.get("PORT") or os.environ.get("SERVER_PORT") or "8787")
KEY_STORE_PATH = Path(os.environ.get("KEY_STORE_PATH", "./data/keys.json"))
KEY_PATTERN = re.compile(r"^ZV-[A-Za-z0-9_-]{32}$")
DURATION_PATTERN = re.compile(
    r"(\d+)\s*(months?|mo|minutes?|m|hours?|h|days?|d|weeks?|w)",
    re.IGNORECASE,
)
DEFAULT_KEY_LIFETIME = timedelta(days=30)
MAX_KEY_LIFETIME = timedelta(days=30)
RATE_LIMIT = 60
RATE_WINDOW_SECONDS = 60
MAX_BODY_BYTES = 1024


def parse_key_lifetime(value):
    if value is None:
        return DEFAULT_KEY_LIFETIME
    match = DURATION_PATTERN.fullmatch(value.strip())
    if match is None:
        raise ValueError("Use a duration such as 1m, 1h, 7d, or 1 month.")

    amount = int(match.group(1))
    unit = match.group(2).lower()
    try:
        if unit.startswith("mo"):
            lifetime = timedelta(days=amount * 30)
        elif unit.startswith("w"):
            lifetime = timedelta(weeks=amount)
        elif unit.startswith("d"):
            lifetime = timedelta(days=amount)
        elif unit.startswith("h"):
            lifetime = timedelta(hours=amount)
        else:
            lifetime = timedelta(minutes=amount)
    except OverflowError as error:
        raise ValueError(
            "Key duration must be between 1 minute and 1 month."
        ) from error

    if lifetime < timedelta(minutes=1) or lifetime > MAX_KEY_LIFETIME:
        raise ValueError("Key duration must be between 1 minute and 1 month.")
    return lifetime


def parse_timestamp(value):
    if not isinstance(value, str):
        raise ValueError("Key store contains an invalid timestamp")
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        raise ValueError("Key store timestamps must include a timezone")
    return parsed.astimezone(timezone.utc)


class KeyStore:
    def __init__(self, path):
        self.path = path
        self.lock = threading.Lock()
        self.users = {}
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self._load()

    def _load(self):
        try:
            data = json.loads(self.path.read_text(encoding="utf-8"))
        except FileNotFoundError:
            return

        if not isinstance(data, dict) or data.get("version") != 1:
            raise ValueError("Key store has an unsupported format")
        records = data.get("keys")
        if not isinstance(records, list):
            raise ValueError("Key store is missing its key list")

        for record in records:
            if (
                not isinstance(record, dict)
                or not isinstance(record.get("discordId"), str)
                or not isinstance(record.get("keyHash"), str)
                or not re.fullmatch(r"[a-f0-9]{64}", record["keyHash"])
                or record["discordId"] in self.users
            ):
                raise ValueError("Key store contains an invalid record")
            issued_at = parse_timestamp(record.get("issuedAt"))
            if "expiresAt" not in record:
                record = dict(record)
                record["expiresAt"] = (
                    issued_at + DEFAULT_KEY_LIFETIME
                ).isoformat()
            else:
                parse_timestamp(record["expiresAt"])
            self.users[record["discordId"]] = record
        if records and any("expiresAt" not in record for record in records):
            self._save(self.users)

    def _save(self, users):
        temporary_path = self.path.with_name(f"{self.path.name}.{os.getpid()}.tmp")
        try:
            with temporary_path.open("w", encoding="utf-8") as file:
                json.dump({"version": 1, "keys": list(users.values())}, file, indent=2)
                file.flush()
                os.fsync(file.fileno())
            os.chmod(temporary_path, 0o600)
            os.replace(temporary_path, self.path)
        finally:
            temporary_path.unlink(missing_ok=True)

    def issue(self, discord_id, lifetime=DEFAULT_KEY_LIFETIME):
        discord_id = str(discord_id)
        if (
            not isinstance(lifetime, timedelta)
            or lifetime < timedelta(minutes=1)
            or lifetime > MAX_KEY_LIFETIME
        ):
            raise ValueError("Key duration must be between 1 minute and 1 month.")
        with self.lock:
            key = "ZV-" + secrets.token_urlsafe(24)
            now = datetime.now(timezone.utc)
            expires_at = now + lifetime
            record = {
                "discordId": discord_id,
                "keyHash": hashlib.sha256(key.encode("utf-8")).hexdigest(),
                "issuedAt": now.isoformat(),
                "expiresAt": expires_at.isoformat(),
            }
            updated_users = dict(self.users)
            updated_users[discord_id] = record
            self._save(updated_users)
            self.users = updated_users
            return key, expires_at.isoformat()

    def validate_for_roblox_user(self, key, roblox_user_id):
        if not isinstance(key, str) or not KEY_PATTERN.fullmatch(key):
            return None, "invalid", None
        if (
            isinstance(roblox_user_id, bool)
            or not isinstance(roblox_user_id, int)
            or roblox_user_id <= 0
        ):
            return None, "invalid_user", None

        key_hash = hashlib.sha256(key.encode("utf-8")).hexdigest()
        with self.lock:
            for discord_id, record in self.users.items():
                if record["keyHash"] != key_hash:
                    continue

                roblox_id = str(roblox_user_id)
                expires_at = parse_timestamp(record["expiresAt"])
                if datetime.now(timezone.utc) >= expires_at:
                    return discord_id, "expired", record["expiresAt"]

                bound_id = record.get("robloxUserId")
                if bound_id is not None and bound_id != roblox_id:
                    return discord_id, "account_mismatch", record["expiresAt"]

                if bound_id is None:
                    updated_users = dict(self.users)
                    updated_record = dict(record)
                    updated_record["robloxUserId"] = roblox_id
                    updated_users[discord_id] = updated_record
                    self._save(updated_users)
                    self.users = updated_users

                return discord_id, "valid", record["expiresAt"]
        return None, "invalid", None

    def revoke(self, discord_id):
        discord_id = str(discord_id)
        with self.lock:
            if discord_id not in self.users:
                return False
            updated_users = dict(self.users)
            del updated_users[discord_id]
            self._save(updated_users)
            self.users = updated_users
            return True

    def revoke_all(self):
        with self.lock:
            count = len(self.users)
            if count:
                self._save({})
                self.users = {}
            return count


def make_api_handler(key_store, on_key_validation=None):
    rate_lock = threading.Lock()
    rate_windows = {}

    class ValidationHandler(BaseHTTPRequestHandler):
        def _send_json(self, status_code, body):
            encoded = json.dumps(body).encode("utf-8")
            self.send_response(status_code)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("Content-Length", str(len(encoded)))
            self.end_headers()
            self.wfile.write(encoded)

        def do_POST(self):
            if self.path != "/validate":
                self._send_json(404, {"error": "Not found"})
                return

            now = time.monotonic()
            client_ip = self.client_address[0]
            with rate_lock:
                window = rate_windows.get(client_ip)
                if window is None or now - window[0] >= RATE_WINDOW_SECONDS:
                    window = [now, 0]
                    rate_windows[client_ip] = window
                window[1] += 1

                if len(rate_windows) > 10000:
                    expired = [
                        ip for ip, item in rate_windows.items()
                        if now - item[0] >= RATE_WINDOW_SECONDS
                    ]
                    for ip in expired:
                        rate_windows.pop(ip, None)

                if window[1] > RATE_LIMIT:
                    self._send_json(429, {"error": "Too many requests"})
                    return

            try:
                content_length = int(self.headers.get("Content-Length", ""))
            except ValueError:
                self._send_json(400, {"error": "Invalid Content-Length"})
                return

            if content_length < 0:
                self._send_json(400, {"error": "Invalid Content-Length"})
                return
            if content_length > MAX_BODY_BYTES:
                self._send_json(413, {"error": "Request too large"})
                self.close_connection = True
                return

            try:
                payload = json.loads(self.rfile.read(content_length))
            except (json.JSONDecodeError, UnicodeDecodeError):
                self._send_json(400, {"error": "Invalid JSON"})
                return

            if (
                not isinstance(payload, dict)
                or not isinstance(payload.get("key"), str)
                or isinstance(payload.get("robloxUserId"), bool)
                or not isinstance(payload.get("robloxUserId"), int)
                or payload["robloxUserId"] <= 0
            ):
                self._send_json(
                    400,
                    {"error": "A key and positive Roblox user ID are required"},
                )
                return

            try:
                owner_id, result, expires_at = key_store.validate_for_roblox_user(
                    payload["key"],
                    payload["robloxUserId"],
                )
            except OSError as error:
                print(f"Could not save Roblox key binding: {error}")
                self._send_json(500, {"error": "Could not save key binding"})
                return

            if on_key_validation:
                heartbeat = payload.get("heartbeat") is True
                if result != "valid" or not heartbeat:
                    on_key_validation(
                        owner_id,
                        payload["robloxUserId"],
                        result,
                        expires_at,
                    )
            self._send_json(
                200,
                {
                    "valid": result == "valid",
                    "reason": result,
                },
            )

        def log_message(self, format_string, *args):
            return

    return ValidationHandler


def main():
    token = os.environ.get("DISCORD_BOT_TOKEN")
    if not token:
        raise RuntimeError(
            "Add DISCORD_BOT_TOKEN in Bot-Hosting's environment variables"
        )
    if not 1 <= PORT <= 65535:
        raise RuntimeError("PORT must be a valid TCP port")

    key_store = KeyStore(KEY_STORE_PATH)
    intents = discord.Intents.default()
    intents.message_content = True
    intents.members = True
    bot = discord.Client(intents=intents)
    command_tree = app_commands.CommandTree(bot)
    configured_guild = discord.Object(id=int(DISCORD_GUILD_ID))

    def is_member_admin(member, guild):
        return (
            guild.owner_id == member.id
            or member.guild_permissions.administrator
            or any(str(role.id) == ADMIN_ROLE_ID for role in member.roles)
        )

    def is_server_admin(message):
        return is_member_admin(message.author, message.guild)

    async def log_key_event(event, **details):
        guild = bot.get_guild(int(DISCORD_GUILD_ID))
        if guild is None:
            raise RuntimeError("Configured Discord server is not available")
        channel = discord.utils.get(guild.text_channels, name="key-usage-logs")
        timestamp = datetime.now(timezone.utc).isoformat(timespec="seconds")
        fields = [f"event={event}", f"timestamp={timestamp}"]
        fields.extend(
            f"{name}={value}"
            for name, value in details.items()
            if value is not None
        )
        entry = "`" + " | ".join(fields) + "`"
        if channel is None:
            print(f"Key audit event (no #key-usage-logs channel): {entry}")
            return
        try:
            await channel.send(
                entry,
                allowed_mentions=discord.AllowedMentions.none(),
            )
        except discord.HTTPException as error:
            print(f"Could not write key audit event: {error}")

    def queue_key_validation_log(owner_id, roblox_user_id, result, expires_at):
        future = asyncio.run_coroutine_threadsafe(
            log_key_event(
                "key_validated",
                discord_id=owner_id,
                roblox_user_id=roblox_user_id,
                result=result,
                expires_at=expires_at,
            ),
            bot.loop,
        )

        def report_log_error(completed):
            error = completed.exception()
            if error:
                print(f"Could not log key validation: {error}")

        future.add_done_callback(report_log_error)

    @bot.event
    async def on_message(message):
        if message.author.bot or message.guild is None:
            return
        if str(message.guild.id) != DISCORD_GUILD_ID:
            return

        command = message.content.strip().lower()
        if command in {".help", ",help"}:
            await message.reply(
                "**Key bot commands**\n"
                "`.help` — show this list\n"
                "`.key [@user] [duration]` — issue a key by DM "
                "(default: 30 days; 1 minute to 1 month)\n"
                "`.key revoke @user` — revoke one user's key\n"
                "`.revoke @user` or `.revoke all` — revoke keys\n"
                "`.kick @user` — revoke their key and kick a running client\n"
                "`.logs` — create or secure the private key audit channel\n\n"
                "Durations: `1m`, `1h`, `7d`, `1w`, or `1 month`.\n"
                "Key issuance and revocation require the configured admin role "
                "or Discord Administrator."
            )
            return

        if command in {".logs", ",logs"}:
            if not is_server_admin(message):
                await message.reply("Only server admins can create the key log channel.")
                return
            channel = discord.utils.get(
                message.guild.text_channels,
                name="key-usage-logs",
            )
            bot_member = message.guild.me
            if bot_member is None:
                raise RuntimeError("Bot member is not available in the configured server")
            admin_role = message.guild.get_role(int(ADMIN_ROLE_ID))
            private_permissions = {
                message.guild.default_role: discord.PermissionOverwrite(
                    view_channel=False,
                ),
                bot_member: discord.PermissionOverwrite(
                    view_channel=True,
                    send_messages=True,
                    read_message_history=True,
                ),
            }
            if admin_role is not None:
                private_permissions[admin_role] = discord.PermissionOverwrite(
                    view_channel=True,
                    send_messages=True,
                    read_message_history=True,
                )
            if channel is None:
                channel = await message.guild.create_text_channel(
                    "key-usage-logs",
                    overwrites=private_permissions,
                    reason=f"Key usage logs requested by {message.author}",
                )
            else:
                for target, permissions in private_permissions.items():
                    await channel.set_permissions(
                        target,
                        overwrite=permissions,
                        reason="Secure the key usage log channel",
                    )
            await message.reply(f"Key usage logs are enabled in {channel.mention}.")
            return

        kick_match = re.fullmatch(r"[.,]kick\s+<@!?(\d+)>", command)
        if kick_match:
            if not is_server_admin(message):
                await message.reply("Only server admins can use `.kick`.")
                return

            target_id = kick_match.group(1)
            revoked = key_store.revoke(target_id)
            if revoked:
                await message.reply(
                    "That user's key was revoked. A running script will kick "
                    "its Roblox client on its next key check."
                )
            else:
                await message.reply("That user has no active key to revoke.")
            await log_key_event(
                "key_kick_requested" if revoked else "key_kick_not_found",
                actor_id=message.author.id,
                target_id=target_id,
            )
            return

        revoke_match = re.fullmatch(r"[.,]revoke\s+(all|<@!?(\d+)>)", command)
        key_revoke_match = re.fullmatch(
            r"[.,]key\s+revoke\s+<@!?(\d+)>",
            command,
        )
        if revoke_match or key_revoke_match:
            if not is_server_admin(message):
                await message.reply("Only server admins can revoke keys.")
                return

            if revoke_match and revoke_match.group(1) == "all":
                count = key_store.revoke_all()
                await message.reply(f"Revoked all {count} key(s).")
                await log_key_event(
                    "keys_revoked",
                    actor_id=message.author.id,
                    count=count,
                )
            else:
                target_id = (
                    key_revoke_match.group(1)
                    if key_revoke_match
                    else revoke_match.group(2)
                )
                revoked = key_store.revoke(target_id)
                await message.reply(
                    "That user's key has been revoked."
                    if revoked else "That user has no active key."
                )
                await log_key_event(
                    "key_revoked" if revoked else "key_revoke_not_found",
                    actor_id=message.author.id,
                    target_id=target_id,
                )
            return

        key_match = re.fullmatch(
            r"[.,]key(?:\s+(<@!?\d+>))?(?:\s+(.+))?",
            command,
        )
        if key_match is None:
            return
        if not is_server_admin(message):
            await message.reply("You need the required admin role to use `.key`.")
            return

        try:
            lifetime = parse_key_lifetime(key_match.group(2))
        except ValueError as error:
            await message.reply(str(error))
            return

        target_id = (
            re.search(r"\d+", key_match.group(1)).group()
            if key_match.group(1)
            else str(message.author.id)
        )
        target = message.guild.get_member(int(target_id))
        if target is None:
            try:
                target = await message.guild.fetch_member(int(target_id))
            except discord.NotFound:
                await message.reply("That user is not a member of this server.")
                return
            except discord.HTTPException as error:
                print(f"Could not look up key recipient {target_id}: {error}")
                await message.reply("I could not look up that server member.")
                return

        try:
            key, expires_at = key_store.issue(target.id, lifetime)
        except OSError as error:
            print(f"Could not save an issued key for {target.id}: {error}")
            await message.reply("Could not save the key. Check the key service logs.")
            return

        try:
            await target.send(
                f"Your zachv4 access key is:\n`{key}`\n\n"
                f"This key expires at {expires_at} (UTC) and is locked to the "
                "first Roblox account that successfully uses it. Keep it private."
            )
        except discord.Forbidden:
            await message.reply(
                f"I couldn't DM {target.mention}. Enable DMs and ask an admin "
                "to issue a new key."
            )
            await log_key_event(
                "key_delivery_failed",
                actor_id=message.author.id,
                target_id=target.id,
                expires_at=expires_at,
            )
            return
        except discord.HTTPException as error:
            print(f"Could not DM a key to Discord user {target.id}: {error}")
            await message.reply("I could not deliver the key. Check the key service logs.")
            await log_key_event(
                "key_delivery_failed",
                actor_id=message.author.id,
                target_id=target.id,
                expires_at=expires_at,
            )
            return

        await message.reply(f"I sent a key to {target.mention} by DM.")
        await log_key_event(
            "key_issued",
            actor_id=message.author.id,
            target_id=target.id,
            duration=key_match.group(2) or "30d",
            expires_at=expires_at,
        )


    @bot.event
    async def on_ready():
        print(f"Bot logged in as {bot.user}")
        print(
            "Prefix commands require Message Content Intent enabled both in this "
            "bot's intents and in the Discord Developer Portal."
        )
        command_tree.clear_commands(guild=configured_guild)
        try:
            await command_tree.sync(guild=configured_guild)
        except discord.HTTPException as error:
            print(f"Could not remove retired moderation slash commands: {error}")

    api_server = ThreadingHTTPServer(
        ("0.0.0.0", PORT),
        make_api_handler(key_store, queue_key_validation_log),
    )
    api_server.daemon_threads = True
    api_thread = threading.Thread(
        target=api_server.serve_forever,
        name="key-validation-api",
        daemon=True,
    )
    api_thread.start()
    print(f"Key validation API listening on port {PORT}")

    try:
        bot.run(token)
    finally:
        api_server.shutdown()
        api_server.server_close()


if __name__ == "__main__":
    main()
