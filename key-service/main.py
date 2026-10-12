import hashlib
import json
import os
import re
import secrets
import threading
import time
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import discord


DISCORD_GUILD_ID = "1558998367512559636"
PORT = int(os.environ.get("PORT") or os.environ.get("SERVER_PORT") or "8787")
KEY_STORE_PATH = Path(os.environ.get("KEY_STORE_PATH", "./data/keys.json"))
KEY_PATTERN = re.compile(r"^ZV-[A-Za-z0-9_-]{32}$")
RATE_LIMIT = 60
RATE_WINDOW_SECONDS = 60
MAX_BODY_BYTES = 1024


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

    def validate(self, key):
        if not isinstance(key, str) or not KEY_PATTERN.fullmatch(key):
            return False
        key_hash = hashlib.sha256(key.encode("utf-8")).hexdigest()
        with self.lock:
            return any(record["keyHash"] == key_hash for record in self.users.values())

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


def make_api_handler(key_store):
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

            if not isinstance(payload, dict) or not isinstance(payload.get("key"), str):
                self._send_json(400, {"error": "A key is required"})
                return

            self._send_json(200, {"valid": key_store.validate(payload["key"])})

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
    bot = discord.Client(intents=intents)

    @bot.event
    async def on_message(message):
        if message.author.bot or message.guild is None:
            return
        if str(message.guild.id) != DISCORD_GUILD_ID:
            return

        command = message.content.strip()
        if command == ".key":
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

        match = re.fullmatch(r"\.key\s+revoke\s+<@!?(\d+)>", command)
        if match:
            if not message.author.guild_permissions.administrator:
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

    api_server = ThreadingHTTPServer(
        ("0.0.0.0", PORT),
        make_api_handler(key_store),
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
