import hashlib
import json
import os
import re
import secrets
import threading
import time
import asyncio
from collections import deque
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Optional

import discord
from discord import app_commands


DISCORD_GUILD_ID = "1558998367512559636"
ADMIN_ROLE_ID = "1559000140675813417"
PORT = int(os.environ.get("PORT") or os.environ.get("SERVER_PORT") or "8787")
KEY_STORE_PATH = Path(os.environ.get("KEY_STORE_PATH", "./data/keys.json"))
MODERATION_STORE_PATH = Path(
    os.environ.get("MODERATION_STORE_PATH", "./data/moderation.json")
)
KEY_PATTERN = re.compile(r"^ZV-[A-Za-z0-9_-]{32}$")
LINK_PATTERN = re.compile(
    r"(?<![@\w])(?:https?://)?(?:www\.)?"
    r"(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}"
    r"(?::\d{1,5})?(?:[/?#][^\s]*)?|"
    r"discord(?:app)?\.com/invite/[a-z0-9-]+|discord\.gg/[a-z0-9-]+",
    re.IGNORECASE,
)
RATE_LIMIT = 60
RATE_WINDOW_SECONDS = 60
MAX_BODY_BYTES = 1024


class ModerationSettings:
    DEFAULTS = {
        "anti_raid": {
            "enabled": False,
            "threshold": 5,
            "window_seconds": 10,
            "punishment": "timeout",
        },
        "anti_link": {
            "enabled": False,
            "punishment": "delete",
        },
    }

    def __init__(self, path):
        self.path = path
        self.lock = threading.Lock()
        self.settings = {
            name: values.copy() for name, values in self.DEFAULTS.items()
        }
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self._load()

    def _load(self):
        try:
            data = json.loads(self.path.read_text(encoding="utf-8"))
        except FileNotFoundError:
            return

        if (
            not isinstance(data, dict)
            or data.get("version") != 1
            or not isinstance(data.get("settings"), dict)
        ):
            raise ValueError("Moderation settings have an unsupported format")

        for name, values in data["settings"].items():
            if name not in self.DEFAULTS or not isinstance(values, dict):
                raise ValueError("Moderation settings contain an invalid section")
            merged = self.settings[name].copy()
            merged.update(values)
            if name == "anti_raid":
                if (
                    not isinstance(merged["enabled"], bool)
                    or isinstance(merged["threshold"], bool)
                    or not isinstance(merged["threshold"], int)
                    or not 2 <= merged["threshold"] <= 100
                    or isinstance(merged["window_seconds"], bool)
                    or not isinstance(merged["window_seconds"], int)
                    or not 1 <= merged["window_seconds"] <= 300
                    or merged["punishment"] not in {"warn", "timeout", "kick", "ban"}
                ):
                    raise ValueError("Moderation settings contain invalid anti-raid values")
            elif (
                not isinstance(merged["enabled"], bool)
                or merged["punishment"] not in {
                    "delete", "warn", "timeout", "kick", "ban"
                }
            ):
                raise ValueError("Moderation settings contain invalid anti-link values")
            self.settings[name] = merged

    def get(self, section):
        with self.lock:
            return self.settings[section].copy()

    def update(self, section, values):
        with self.lock:
            updated = self.settings[section].copy()
            updated.update(values)
            all_settings = {
                name: config.copy() for name, config in self.settings.items()
            }
            all_settings[section] = updated
            temporary_path = self.path.with_name(
                f"{self.path.name}.{os.getpid()}.tmp"
            )
            try:
                with temporary_path.open("w", encoding="utf-8") as file:
                    json.dump(
                        {"version": 1, "settings": all_settings},
                        file,
                        indent=2,
                    )
                    file.flush()
                    os.fsync(file.fileno())
                os.chmod(temporary_path, 0o600)
                os.replace(temporary_path, self.path)
            finally:
                temporary_path.unlink(missing_ok=True)
            self.settings = all_settings


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
            self.users[record["discordId"]] = record

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

    def issue(self, discord_id):
        discord_id = str(discord_id)
        with self.lock:
            key = "ZV-" + secrets.token_urlsafe(24)
            record = {
                "discordId": discord_id,
                "keyHash": hashlib.sha256(key.encode("utf-8")).hexdigest(),
                "issuedAt": datetime.now(timezone.utc).isoformat(),
            }
            updated_users = dict(self.users)
            updated_users[discord_id] = record
            self._save(updated_users)
            self.users = updated_users
            return key

    def validate_for_roblox_user(self, key, roblox_user_id):
        if not isinstance(key, str) or not KEY_PATTERN.fullmatch(key):
            return None, "invalid"
        if (
            isinstance(roblox_user_id, bool)
            or not isinstance(roblox_user_id, int)
            or roblox_user_id <= 0
        ):
            return None, "invalid_user"

        key_hash = hashlib.sha256(key.encode("utf-8")).hexdigest()
        with self.lock:
            for discord_id, record in self.users.items():
                if record["keyHash"] != key_hash:
                    continue

                roblox_id = str(roblox_user_id)
                bound_id = record.get("robloxUserId")
                if bound_id is not None and bound_id != roblox_id:
                    return None, "account_mismatch"

                if bound_id is None:
                    updated_users = dict(self.users)
                    updated_record = dict(record)
                    updated_record["robloxUserId"] = roblox_id
                    updated_users[discord_id] = updated_record
                    self._save(updated_users)
                    self.users = updated_users

                return discord_id, "valid"
        return None, "invalid"

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


def make_api_handler(key_store, on_valid_key=None):
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
                owner_id, result = key_store.validate_for_roblox_user(
                    payload["key"],
                    payload["robloxUserId"],
                )
            except OSError as error:
                print(f"Could not save Roblox key binding: {error}")
                self._send_json(500, {"error": "Could not save key binding"})
                return

            if owner_id is not None and on_valid_key:
                on_valid_key(owner_id)
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
    moderation_settings = ModerationSettings(MODERATION_STORE_PATH)
    intents = discord.Intents.default()
    intents.message_content = True
    intents.members = True
    bot = discord.Client(intents=intents)
    command_tree = app_commands.CommandTree(bot)
    configured_guild = discord.Object(id=int(DISCORD_GUILD_ID))
    recent_joins = deque()
    raid_punished_users = set()

    def is_member_admin(member, guild):
        return (
            guild.owner_id == member.id
            or member.guild_permissions.administrator
            or any(str(role.id) == ADMIN_ROLE_ID for role in member.roles)
        )

    def is_server_admin(message):
        return is_member_admin(message.author, message.guild)

    def is_interaction_admin(interaction):
        return (
            interaction.guild is not None
            and is_member_admin(interaction.user, interaction.guild)
        )

    async def apply_punishment(member, punishment, reason):
        try:
            if punishment == "warn":
                await member.send(f"Warning from {member.guild.name}: {reason}")
            elif punishment == "timeout":
                await member.timeout(timedelta(minutes=10), reason=reason)
            elif punishment == "kick":
                await member.kick(reason=reason)
            elif punishment == "ban":
                await member.guild.ban(
                    member,
                    reason=reason,
                    delete_message_seconds=0,
                )
            else:
                raise ValueError(f"Unsupported moderation punishment: {punishment}")
        except discord.HTTPException as error:
            print(
                f"Could not apply {punishment} to {member} ({member.id}): {error}"
            )

    @command_tree.command(
        name="antiraid",
        description="Configure protection against rapid member joins",
        guild=configured_guild,
    )
    @app_commands.describe(
        enabled="Turn anti-raid protection on or off",
        threshold="Number of joins that triggers protection (2-100)",
        window_seconds="Time window for counting joins (1-300 seconds)",
        punishment="Action to take when a raid is detected",
    )
    @app_commands.choices(
        punishment=[
            app_commands.Choice(name="Warn by DM", value="warn"),
            app_commands.Choice(name="Timeout for 10 minutes", value="timeout"),
            app_commands.Choice(name="Kick", value="kick"),
            app_commands.Choice(name="Ban", value="ban"),
        ]
    )
    async def antiraid(
        interaction: discord.Interaction,
        enabled: Optional[bool] = None,
        threshold: Optional[app_commands.Range[int, 2, 100]] = None,
        window_seconds: Optional[app_commands.Range[int, 1, 300]] = None,
        punishment: Optional[app_commands.Choice[str]] = None,
    ):
        if not is_interaction_admin(interaction):
            await interaction.response.send_message(
                "Only server admins can configure moderation.",
                ephemeral=True,
            )
            return

        changes = {}
        if enabled is not None:
            changes["enabled"] = enabled
        if threshold is not None:
            changes["threshold"] = threshold
        if window_seconds is not None:
            changes["window_seconds"] = window_seconds
        if punishment is not None:
            changes["punishment"] = punishment.value
        if changes:
            try:
                moderation_settings.update("anti_raid", changes)
            except OSError as error:
                print(f"Could not save anti-raid settings: {error}")
                await interaction.response.send_message(
                    "Could not save anti-raid settings. Check the bot's data directory.",
                    ephemeral=True,
                )
                return

        config = moderation_settings.get("anti_raid")
        state = "enabled" if config["enabled"] else "disabled"
        await interaction.response.send_message(
            f"Anti-raid is **{state}**. It triggers at "
            f"**{config['threshold']} joins / {config['window_seconds']} seconds** "
            f"and uses **{config['punishment']}**.",
            ephemeral=True,
        )

    @command_tree.command(
        name="antilink",
        description="Configure protection against links in server messages",
        guild=configured_guild,
    )
    @app_commands.describe(
        enabled="Turn anti-link protection on or off",
        punishment="Action to take when a non-admin posts a link",
    )
    @app_commands.choices(
        punishment=[
            app_commands.Choice(name="Delete message only", value="delete"),
            app_commands.Choice(name="Warn by DM", value="warn"),
            app_commands.Choice(name="Timeout for 10 minutes", value="timeout"),
            app_commands.Choice(name="Kick", value="kick"),
            app_commands.Choice(name="Ban", value="ban"),
        ]
    )
    async def antilink(
        interaction: discord.Interaction,
        enabled: Optional[bool] = None,
        punishment: Optional[app_commands.Choice[str]] = None,
    ):
        if not is_interaction_admin(interaction):
            await interaction.response.send_message(
                "Only server admins can configure moderation.",
                ephemeral=True,
            )
            return

        changes = {}
        if enabled is not None:
            changes["enabled"] = enabled
        if punishment is not None:
            changes["punishment"] = punishment.value
        if changes:
            try:
                moderation_settings.update("anti_link", changes)
            except OSError as error:
                print(f"Could not save anti-link settings: {error}")
                await interaction.response.send_message(
                    "Could not save anti-link settings. Check the bot's data directory.",
                    ephemeral=True,
                )
                return

        config = moderation_settings.get("anti_link")
        state = "enabled" if config["enabled"] else "disabled"
        await interaction.response.send_message(
            f"Anti-link is **{state}** and uses **{config['punishment']}** "
            "for links. Link messages are always deleted.",
            ephemeral=True,
        )

    async def log_key_use(discord_id):
        guild = bot.get_guild(int(DISCORD_GUILD_ID))
        if guild is None:
            raise RuntimeError("Configured Discord server is not available")
        channel = discord.utils.get(guild.text_channels, name="key-usage-logs")
        if channel is None:
            return
        await channel.send(f"Valid key used by Discord account <@{discord_id}>.")

    def queue_key_use_log(discord_id):
        future = asyncio.run_coroutine_threadsafe(
            log_key_use(discord_id),
            bot.loop,
        )

        def report_log_error(completed):
            error = completed.exception()
            if error:
                print(f"Could not log key use: {error}")

        future.add_done_callback(report_log_error)

    @bot.event
    async def on_message(message):
        if message.author.bot or message.guild is None:
            return
        if str(message.guild.id) != DISCORD_GUILD_ID:
            return

        link_config = moderation_settings.get("anti_link")
        if (
            link_config["enabled"]
            and not is_server_admin(message)
            and LINK_PATTERN.search(message.content)
        ):
            reason = "Posting links is not allowed while anti-link protection is enabled."
            try:
                await message.delete(reason="Anti-link protection")
            except discord.HTTPException as error:
                print(
                    f"Could not delete link message from {message.author} "
                    f"({message.author.id}): {error}"
                )
            if link_config["punishment"] != "delete":
                await apply_punishment(
                    message.author,
                    link_config["punishment"],
                    reason,
                )
            return

        command = message.content.strip().lower()
        if command in {".key", ",key"}:
            if not is_server_admin(message):
                await message.reply("You need the required admin role to use `.key`.")
                return

            key = key_store.issue(message.author.id)
            try:
                await message.author.send(
                    f"Your zachv4 access key is:\n`{key}`\n\n"
                    "Keep this key private. Running `.key` again replaces your old key."
                )
                await message.reply("I sent your key in a DM. Keep it private.")
            except discord.Forbidden:
                await message.reply(
                    "I couldn't DM you. Enable DMs from server members, "
                    "then run `.key` again for a fresh key."
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
            if channel is None:
                channel = await message.guild.create_text_channel(
                    "key-usage-logs",
                    overwrites=private_permissions,
                    reason=f"Key usage logs requested by {message.author}",
                )
            else:
                await channel.set_permissions(
                    message.guild.default_role,
                    view_channel=False,
                    reason="Restrict access to key usage logs",
                )
                await channel.set_permissions(
                    bot_member,
                    private_permissions[bot_member],
                    reason="Allow bot to write key usage logs",
                )
            await message.reply(f"Key usage logs are enabled in {channel.mention}.")
            return

        revoke_match = re.fullmatch(r"[.,]revoke\s+(all|<@!?(\d+)>)", command)
        if revoke_match:
            if not is_server_admin(message):
                await message.reply("Only server admins can revoke keys.")
                return

            if revoke_match.group(1).lower() == "all":
                count = key_store.revoke_all()
                await message.reply(f"Revoked all {count} active key(s).")
            else:
                revoked = key_store.revoke(revoke_match.group(2))
                await message.reply(
                    "That user's key has been revoked."
                    if revoked else "That user has no active key."
                )
            return

        match = re.fullmatch(r"[.,]key\s+revoke\s+<@!?(\d+)>", command)
        if match:
            if not is_server_admin(message):
                await message.reply("Only server admins can revoke keys.")
                return
            revoked = key_store.revoke(match.group(1))
            await message.reply(
                "That user's key has been revoked."
                if revoked else "That user has no active key."
            )

    @bot.event
    async def on_ready():
        print(f"Bot logged in as {bot.user}")
        print(
            "Prefix commands require Message Content Intent enabled both in this "
            "bot's intents and in the Discord Developer Portal."
        )
        try:
            synced = await command_tree.sync(guild=configured_guild)
            print(f"Synced {len(synced)} moderation slash command(s)")
        except discord.HTTPException as error:
            print(f"Could not sync moderation slash commands: {error}")

    @bot.event
    async def on_member_join(member):
        if str(member.guild.id) != DISCORD_GUILD_ID:
            return
        if is_member_admin(member, member.guild):
            return
        config = moderation_settings.get("anti_raid")
        if not config["enabled"]:
            recent_joins.clear()
            raid_punished_users.clear()
            return

        now = time.monotonic()
        recent_joins.append((now, member))
        while (
            recent_joins
            and now - recent_joins[0][0] > config["window_seconds"]
        ):
            recent_joins.popleft()
        active_user_ids = {joined_member.id for _, joined_member in recent_joins}
        raid_punished_users.intersection_update(active_user_ids)

        if len(recent_joins) >= config["threshold"]:
            for _, joined_member in recent_joins:
                if joined_member.id in raid_punished_users:
                    continue
                raid_punished_users.add(joined_member.id)
                await apply_punishment(
                    joined_member,
                    config["punishment"],
                    "A rapid-join raid was detected in the server.",
                )

    api_server = ThreadingHTTPServer(
        ("0.0.0.0", PORT),
        make_api_handler(key_store, queue_key_use_log),
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
