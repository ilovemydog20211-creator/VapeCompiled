import asyncio
import hashlib
import ipaddress
import json
import os
import re
import secrets
import threading
import time
import urllib.error
import urllib.request
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

# --- IP logging -------------------------------------------------------------
GEOIP_ENABLED = os.environ.get("GEOIP_ENABLED", "1") != "0"
GEOIP_URL = (
    "http://ip-api.com/json/{ip}"
    "?fields=status,country,countryCode,regionName,city,isp,org,as"
)
GEOIP_TIMEOUT = 2.5
GEOIP_CACHE_SECONDS = 3600
GEOIP_FAILURE_CACHE_SECONDS = 60
MAX_IP_HISTORY = 10
TRUST_PROXY_HEADERS = os.environ.get("TRUST_PROXY_HEADERS", "1") != "0"


_geo_cache = {}
_geo_lock = threading.Lock()


def normalise_ip(value):
    if not isinstance(value, str):
        return None
    candidate = value.strip()
    if not candidate:
        return None
    if candidate.startswith("[") and "]" in candidate:
        candidate = candidate[1:candidate.index("]")]
    try:
        return str(ipaddress.ip_address(candidate))
    except ValueError:
        return None


def resolve_client_ip(handler):
    if TRUST_PROXY_HEADERS:
        forwarded = handler.headers.get("X-Forwarded-For")
        if forwarded:
            for candidate in forwarded.split(","):
                parsed = normalise_ip(candidate)
                if parsed:
                    return parsed
        real_ip = normalise_ip(handler.headers.get("X-Real-IP") or "")
        if real_ip:
            return real_ip
    return normalise_ip(handler.client_address[0]) or handler.client_address[0]


def lookup_ip(ip):
    """Best-effort geo/ISP lookup. Never raises, returns None on failure."""
    if not ip or not GEOIP_ENABLED:
        return None
    try:
        parsed = ipaddress.ip_address(ip)
    except ValueError:
        return None
    if not parsed.is_global:
        return {"label": "private / local network", "isp": None}

    now = time.monotonic()
    with _geo_lock:
        cached = _geo_cache.get(ip)
        if cached and now - cached[0] < cached[2]:
            return cached[1]

    result = None
    try:
        with urllib.request.urlopen(
            GEOIP_URL.format(ip=ip), timeout=GEOIP_TIMEOUT
        ) as response:
            data = json.loads(response.read().decode("utf-8", "replace"))
        if isinstance(data, dict) and data.get("status") == "success":
            place = ", ".join(
                part
                for part in (
                    data.get("city"),
                    data.get("regionName"),
                    data.get("country"),
                )
                if part
            )
            result = {
                "label": place or "unknown",
                "isp": data.get("isp") or data.get("org") or data.get("as"),
            }
    except (urllib.error.URLError, OSError, ValueError) as error:
        print(f"GeoIP lookup for {ip} failed: {error}")

    with _geo_lock:
        _geo_cache[ip] = (
            now,
            result,
            GEOIP_CACHE_SECONDS if result else GEOIP_FAILURE_CACHE_SECONDS,
        )
        if len(_geo_cache) > 5000:
            for stale_ip, entry in list(_geo_cache.items()):
                if now - entry[0] >= entry[2]:
                    _geo_cache.pop(stale_ip, None)
    return result


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

    def get_record(self, discord_id):
        with self.lock:
            record = self.users.get(str(discord_id))
            return dict(record) if record is not None else None

    def note_ip(self, discord_id, client_ip, max_history=MAX_IP_HISTORY):
        """Record a seen IP. Only writes to disk when the IP set changes."""
        if not client_ip:
            return None
        discord_id = str(discord_id)
        now = datetime.now(timezone.utc).isoformat()
        with self.lock:
            record = self.users.get(discord_id)
            if record is None:
                return None

            history = list(record.get("ipHistory") or [])
            first_ip = record.get("firstIp") or client_ip
            is_new = client_ip not in history
            if is_new:
                history.append(client_ip)
                history = history[-max_history:]

            if is_new:
                updated_record = dict(record)
                updated_record["firstIp"] = first_ip
                updated_record["lastIp"] = client_ip
                updated_record["lastSeenAt"] = now
                updated_record["ipHistory"] = history
                updated_users = dict(self.users)
                updated_users[discord_id] = updated_record
                self._save(updated_users)
                self.users = updated_users
            else:
                record["lastSeenAt"] = now

            return {
                "first_ip": first_ip,
                "last_ip": client_ip,
                "new_ip": is_new,
                "history": history,
            }


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
            client_ip = resolve_client_ip(self)
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
                ip_info = (
                    key_store.note_ip(owner_id, client_ip) if owner_id else None
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
                        client_ip,
                        ip_info,
                    )
            self._send_json(
                200,
                {
                    "valid": result == "valid",
                    "reason": result,
                    "ip": client_ip,
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

    async def log_key_event(event, notify_user_id=None, **details):
        guild = bot.get_guild(int(DISCORD_GUILD_ID))
        if guild is None:
            raise RuntimeError("Configured Discord server is not available")
        channel = discord.utils.get(guild.text_channels, name="key-usage-logs")
        titles = {
            "key_validated": ("Key validated", discord.Color.green()),
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
            "first_ip": "First seen IP",
        }
        affected_records = details.pop("affected_records", [])
        ip_info = details.pop("ip_info", None)
        client_ip = details.get("client_ip")
        for name, value in details.items():
            if value is None:
                continue
            if name in {"actor_id", "target_id", "discord_id"}:
                value = f"<@{value}>"
            elif name == "roblox_user_id":
                value = (
                    f"[View Roblox profile](https://www.roblox.com/users/"
                    f"{value}/profile) (`{value}`)"
                )
            elif name in {"client_ip", "first_ip"}:
                value = f"`{value}`"
            elif name == "expires_at":
                try:
                    value = f"<t:{int(parse_timestamp(value).timestamp())}:F>"
                except (TypeError, ValueError):
                    value = str(value)
            embed.add_field(
                name=field_labels.get(name, name.replace("_", " ").title()),
                value=str(value),
                inline=name not in {"roblox_user_id"},
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
        if client_ip:
            geo = await asyncio.to_thread(lookup_ip, client_ip)
            if geo:
                location = geo["label"]
                if geo.get("isp"):
                    location += f"\n{geo['isp']}"
                embed.add_field(name="Approx. location", value=location, inline=True)
            if ip_info and ip_info.get("first_ip") != client_ip:
                embed.add_field(
                    name="First seen IP",
                    value=f"`{ip_info['first_ip']}`",
                    inline=True,
                )
            if ip_info and ip_info.get("new_ip") and len(ip_info["history"]) > 1:
                embed.add_field(name="Note", value="New IP for this key", inline=True)
        embed.set_footer(text="VapeCompiled Key Audit")
        if channel is None:
            print(f"Key audit event (no #key-usage-logs channel): {event} {details}")
            return
        try:
            await channel.send(
                content=f"<@{notify_user_id}>" if notify_user_id else None,
                embed=embed,
                allowed_mentions=discord.AllowedMentions(
                    users=[discord.Object(id=int(notify_user_id))]
                    if notify_user_id
                    else [],
                ),
            )
        except discord.HTTPException as error:
            print(f"Could not write key audit event: {error}")

    def queue_key_validation_log(
        owner_id, roblox_user_id, result, expires_at, client_ip, ip_info
    ):
        future = asyncio.run_coroutine_threadsafe(
            log_key_event(
                "key_validated",
                discord_id=owner_id,
                roblox_user_id=roblox_user_id,
                result=result,
                expires_at=expires_at,
                client_ip=client_ip,
                ip_info=ip_info,
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
                "`.ip [@user]` — show recorded IPs for a key (admins: any user)\n"
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

        ip_match = re.fullmatch(r"[.,]ip(?:\s+<@!?(\d+)>)?", command)
        if ip_match:
            target_id = ip_match.group(1) or str(message.author.id)
            if target_id != str(message.author.id) and not is_server_admin(message):
                await message.reply("Only admins can look up another user's IPs.")
                return
            record = key_store.get_record(target_id)
            if record is None:
                await message.reply("That user has no key record.")
                return

            embed = discord.Embed(
                title="Key IP record",
                color=discord.Color.blurple(),
                timestamp=datetime.now(timezone.utc),
            )
            embed.add_field(name="Discord user", value=f"<@{target_id}>", inline=True)
            if record.get("robloxUserId"):
                embed.add_field(
                    name="Roblox account",
                    value=(
                        f"[Profile](https://www.roblox.com/users/"
                        f"{record['robloxUserId']}/profile) "
                        f"(`{record['robloxUserId']}`)"
                    ),
                    inline=True,
                )
            embed.add_field(
                name="First seen IP",
                value=f"`{record.get('firstIp') or 'unknown'}`",
                inline=True,
            )
            embed.add_field(
                name="Last seen IP",
                value=f"`{record.get('lastIp') or 'unknown'}`",
                inline=True,
            )
            if record.get("lastSeenAt"):
                embed.add_field(
                    name="Last seen",
                    value=f"<t:{int(parse_timestamp(record['lastSeenAt']).timestamp())}:R>",
                    inline=True,
                )
            if record.get("expiresAt"):
                embed.add_field(
                    name="Expires",
                    value=f"<t:{int(parse_timestamp(record['expiresAt']).timestamp())}:F>",
                    inline=True,
                )
            history = record.get("ipHistory") or []
            if len(history) > 1:
                embed.add_field(
                    name=f"IP history ({len(history)})",
                    value="\n".join(f"`{item}`" for item in history),
                    inline=False,
                )
            last_ip = record.get("lastIp")
            if last_ip:
                geo = await asyncio.to_thread(lookup_ip, last_ip)
                if geo:
                    embed.add_field(
                        name="Approx. location",
                        value=geo["label"],
                        inline=True,
                    )
            embed.set_footer(text="VapeCompiled Key Audit")
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