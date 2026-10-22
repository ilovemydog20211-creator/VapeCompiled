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
ALERT_USER_ID = os.environ.get("ALERT_USER_ID", "1545619172023607447").strip() or None
TRUST_PROXY = os.environ.get("TRUST_PROXY", "1").lower() not in {"0", "false", "no"}
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
MAX_BODY_BYTES = 4096
IP_HEADERS = ("CF-Connecting-IP", "X-Forwarded-For", "X-Real-IP", "True-Client-IP")


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


def clean_text(value, limit):
    """Coerce a client-supplied field into a short, safe string or None."""
    if value is None:
        return None
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        value = str(value)
    if not isinstance(value, str):
        return None
    value = value.replace("\n", " ").replace("\r", " ").strip()
    value = re.sub(r"\s{2,}", " ", value)
    if not value:
        return None
    return value[:limit]


def client_ip_of(handler):
    if TRUST_PROXY:
        for header in IP_HEADERS:
            raw = handler.headers.get(header)
            if raw:
                candidate = raw.split(",")[0].strip()
                if candidate:
                    return candidate[:64]
    return handler.client_address[0]


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

    def validate_for_roblox_user(self, key, roblox_user_id, metadata=None):
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

                changes = {}
                if bound_id is None:
                    changes["robloxUserId"] = roblox_id
                if metadata:
                    for name, value in metadata.items():
                        if value:
                            changes[name] = value

                if changes:
                    updated_users = dict(self.users)
                    updated_record = dict(record)
                    updated_record.update(changes)
                    updated_users[discord_id] = updated_record
                    self._save(updated_users)
                    self.users = updated_users

                return discord_id, "valid", record["expiresAt"]
        return None, "invalid", None

    def get(self, discord_id):
        with self.lock:
            record = self.users.get(str(discord_id))
            return dict(record) if record is not None else None

    def revoke(self, discord_id):
        return self.revoke_with_details(discord_id) is not None

    def revoke_with_details(self, discord_id):
        discord_id = str(discord_id)
        with self.lock:
            record = self.users.get(discord_id)
            if record is None:
                return None
            updated_users = dict(self.users)
            del updated_users[discord_id]
            self._save(updated_users)
            self.users = updated_users
            return dict(record)

    def revoke_all(self):
        return len(self.revoke_all_with_details())

    def revoke_all_with_details(self):
        with self.lock:
            records = [dict(record) for record in self.users.values()]
            if records:
                self._save({})
                self.users = {}
            return records


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
            client_ip = client_ip_of(self)
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

            heartbeat = payload.get("heartbeat") is True
            metadata = {
                "lastIp": client_ip,
                "lastExecutor": clean_text(payload.get("executor"), 60),
                "lastExecutorVersion": clean_text(payload.get("executorVersion"), 40),
                "lastFingerprint": clean_text(payload.get("fingerprint"), 80),
                "lastPlaceId": clean_text(payload.get("placeId"), 24),
                "lastJobId": clean_text(payload.get("jobId"), 60),
                "lastGameName": clean_text(payload.get("gameName"), 80),
                "lastSeenAt": datetime.now(timezone.utc).isoformat(),
            }

            try:
                owner_id, result, expires_at = key_store.validate_for_roblox_user(
                    payload["key"],
                    payload["robloxUserId"],
                    None if heartbeat else metadata,
                )
            except OSError as error:
                print(f"Could not save Roblox key binding: {error}")
                self._send_json(500, {"error": "Could not save key binding"})
                return

            if on_key_validation and (result != "valid" or not heartbeat):
                details = dict(metadata)
                details["client_ip"] = client_ip
                details["user_agent"] = clean_text(
                    self.headers.get("User-Agent"), 120
                )
                details["heartbeat"] = heartbeat
                on_key_validation(
                    owner_id,
                    payload["robloxUserId"],
                    result,
                    expires_at,
                    details,
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
    if ALERT_USER_ID and not ALERT_USER_ID.isdigit():
        print(f"ALERT_USER_ID {ALERT_USER_ID!r} is not a numeric Discord ID")

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

    async def log_key_event(event, notify_user_id=None, alert=False, **details):
        guild = bot.get_guild(int(DISCORD_GUILD_ID))
        if guild is None:
            raise RuntimeError("Configured Discord server is not available")
        channel = discord.utils.get(guild.text_channels, name="key-usage-logs")
        titles = {
            "script_executed": ("Script executed", discord.Color.green()),
            "key_validated": ("Key check rejected", discord.Color.orange()),
            "key_issued": ("Key issued", discord.Color.blurple()),
            "key_delivery_failed": ("Key delivery failed", discord.Color.orange()),
            "key_revoked": ("Key revoked", discord.Color.red()),
            "key_revoke_not_found": ("Key revocation failed", discord.Color.orange()),
            "key_kick_requested": ("Access revoked", discord.Color.red()),
            "key_kick_not_found": ("Access revocation failed", discord.Color.orange()),
            "all_keys_deleted": ("All keys deleted", discord.Color.dark_red()),
            "keys_revoked": ("Keys revoked", discord.Color.dark_red()),
        }
        title, color = titles.get(
            event,
            ("Key service event", discord.Color.light_grey()),
        )
        embed = discord.Embed(
            title=title,
            color=color,
            timestamp=datetime.now(timezone.utc),
        )
        field_labels = {
            "actor_id": "Action by",
            "target_id": "Discord user",
            "discord_id": "Key owner",
            "roblox_user_id": "Roblox account",
            "result": "Result",
            "expires_at": "Expires (UTC)",
            "duration": "Duration",
            "count": "Keys affected",
            "client_ip": "Client IP",
            "user_agent": "User agent",
            "executor": "Executor",
            "executor_version": "Executor version",
            "fingerprint": "Fingerprint",
            "game_name": "Game",
            "place_id": "Place ID",
            "job_id": "Job ID",
            "heartbeat": "Heartbeat",
        }
        affected_records = details.pop("affected_records", [])
        for name, value in details.items():
            if value is None or value is False:
                continue
            if name in {"actor_id", "target_id", "discord_id"}:
                value = f"<@{value}>"
            elif name == "roblox_user_id":
                value = (
                    f"[View Roblox profile](https://www.roblox.com/users/"
                    f"{value}/profile) (`{value}`)"
                )
            elif name == "expires_at":
                try:
                    value = f"<t:{int(parse_timestamp(value).timestamp())}:F>"
                except (TypeError, ValueError):
                    value = str(value)
            elif name == "client_ip":
                value = f"[`{value}`](https://ipinfo.io/{value})"
            elif name == "place_id":
                value = f"[`{value}`](https://www.roblox.com/games/{value})"
            elif name in {"executor", "executor_version", "fingerprint"}:
                value = f"`{value}`"
            embed.add_field(
                name=field_labels.get(name, name.replace("_", " ").title()),
                value=str(value),
                inline=name not in {"roblox_user_id", "user_agent", "fingerprint"},
            )
        for record in affected_records[:20]:
            roblox_user_id = record.get("robloxUserId")
            affected = f"<@{record['discordId']}>"
            if roblox_user_id:
                affected += (
                    f"\n[Roblox profile](https://www.roblox.com/users/"
                    f"{roblox_user_id}/profile)"
                )
            embed.add_field(name="Deleted key", value=affected, inline=True)
        if len(affected_records) > 20:
            embed.add_field(
                name="Additional keys",
                value=f"{len(affected_records) - 20} more affected",
                inline=True,
            )
        embed.set_footer(text="VapeCompiled Key Audit")

        mentions = []
        if notify_user_id:
            mentions.append(str(notify_user_id))
        if alert and ALERT_USER_ID and ALERT_USER_ID not in mentions:
            mentions.append(ALERT_USER_ID)

        if channel is None:
            print(f"Key audit event (no #key-usage-logs channel): {event} {details}")
            return
        try:
            await channel.send(
                content=" ".join(f"<@{m}>" for m in mentions) or None,
                embed=embed,
                allowed_mentions=discord.AllowedMentions(
                    users=[discord.Object(id=int(m)) for m in mentions],
                ),
            )
        except discord.HTTPException as error:
            print(f"Could not write key audit event: {error}")

    def queue_key_validation_log(owner_id, roblox_user_id, result, expires_at, details):
        event = "script_executed" if result == "valid" else "key_validated"
        future = asyncio.run_coroutine_threadsafe(
            log_key_event(
                event,
                discord_id=owner_id,
                roblox_user_id=roblox_user_id,
                result=result,
                expires_at=expires_at,
                client_ip=details.get("client_ip"),
                user_agent=details.get("user_agent"),
                executor=details.get("lastExecutor"),
                executor_version=details.get("lastExecutorVersion"),
                fingerprint=details.get("lastFingerprint"),
                game_name=details.get("lastGameName"),
                place_id=details.get("lastPlaceId"),
                job_id=details.get("lastJobId"),
                notify_user_id=owner_id if result != "valid" else None,
                alert=True,
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
                "`.delete all` — delete all active keys\n"
                "`.kick @user` — revoke their key and kick a running client\n"
                "`.keyinfo @user` — show the last IP, executor and fingerprint\n"
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

        keyinfo_match = re.fullmatch(r"[.,]keyinfo\s+<@!?(\d+)>", command)
        if keyinfo_match:
            if not is_server_admin(message):
                await message.reply("Only server admins can use `.keyinfo`.")
                return
            target_id = keyinfo_match.group(1)
            record = key_store.get(target_id)
            if record is None:
                await message.reply("That user has no active key.")
                return
            embed = discord.Embed(
                title="Key record",
                color=discord.Color.blurple(),
                timestamp=datetime.now(timezone.utc),
            )
            embed.add_field(name="Key owner", value=f"<@{target_id}>")
            try:
                issued = int(parse_timestamp(record["issuedAt"]).timestamp())
                expires = int(parse_timestamp(record["expiresAt"]).timestamp())
                embed.add_field(name="Issued (UTC)", value=f"<t:{issued}:F>")
                embed.add_field(name="Expires (UTC)", value=f"<t:{expires}:F>")
            except (KeyError, TypeError, ValueError):
                pass
            if record.get("robloxUserId"):
                embed.add_field(
                    name="Roblox account",
                    value=(
                        f"[View profile](https://www.roblox.com/users/"
                        f"{record['robloxUserId']}/profile) "
                        f"(`{record['robloxUserId']}`)"
                    ),
                )
            if record.get("lastIp"):
                embed.add_field(
                    name="Last IP",
                    value=f"[`{record['lastIp']}`](https://ipinfo.io/{record['lastIp']})",
                )
            if record.get("lastExecutor"):
                version = record.get("lastExecutorVersion")
                embed.add_field(
                    name="Executor",
                    value=f"`{record['lastExecutor']}`"
                    + (f" `{version}`" if version else ""),
                )
            if record.get("lastFingerprint"):
                embed.add_field(
                    name="Fingerprint",
                    value=f"`{record['lastFingerprint']}`",
                )
            if record.get("lastGameName"):
                embed.add_field(name="Last game", value=record["lastGameName"])
            if record.get("lastSeenAt"):
                try:
                    seen = int(parse_timestamp(record["lastSeenAt"]).timestamp())
                    embed.add_field(name="Last seen (UTC)", value=f"<t:{seen}:R>")
                except (TypeError, ValueError):
                    pass
            await message.reply(embed=embed)
            return

        kick_match = re.fullmatch(r"[.,]kick\s+<@!?(\d+)>", command)
        if kick_match:
            if not is_server_admin(message):
                await message.reply("Only server admins can use `.kick`.")
                return

            target_id = kick_match.group(1)
            record = key_store.revoke_with_details(target_id)
            if record:
                await message.reply(
                    f"<@{target_id}>’s key was revoked. A running script will "
                    "kick its Roblox client on its next key check.",
                    allowed_mentions=discord.AllowedMentions(
                        users=[discord.Object(id=int(target_id))]
                    ),
                )
            else:
                await message.reply("That user has no active key to revoke.")
            await log_key_event(
                "key_kick_requested" if record else "key_kick_not_found",
                actor_id=message.author.id,
                target_id=target_id,
                roblox_user_id=record.get("robloxUserId") if record else None,
                notify_user_id=target_id if record else None,
            )
            return

        delete_all_match = re.fullmatch(r"[.,]delete\s+all", command)
        revoke_match = re.fullmatch(r"[.,]revoke\s+(all|<@!?(\d+)>)", command)
        key_revoke_match = re.fullmatch(
            r"[.,]key\s+revoke\s+<@!?(\d+)>",
            command,
        )
        if delete_all_match or revoke_match or key_revoke_match:
            if not is_server_admin(message):
                await message.reply("Only server admins can revoke keys.")
                return

            if delete_all_match or (
                revoke_match and revoke_match.group(1) == "all"
            ):
                records = key_store.revoke_all_with_details()
                count = len(records)
                await message.reply(f"Deleted all {count} active key(s).")
                await log_key_event(
                    "all_keys_deleted",
                    actor_id=message.author.id,
                    count=count,
                    affected_records=records,
                )
            else:
                target_id = (
                    key_revoke_match.group(1)
                    if key_revoke_match
                    else revoke_match.group(2)
                )
                record = key_store.revoke_with_details(target_id)
                await message.reply(
                    f"<@{target_id}>’s key has been revoked."
                    if record else "That user has no active key.",
                    allowed_mentions=discord.AllowedMentions(
                        users=[discord.Object(id=int(target_id))]
                        if record else [],
                    ),
                )
                await log_key_event(
                    "key_revoked" if record else "key_revoke_not_found",
                    actor_id=message.author.id,
                    target_id=target_id,
                    roblox_user_id=record.get("robloxUserId") if record else None,
                    notify_user_id=target_id if record else None,
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