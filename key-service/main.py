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
KEY_PATTERN = re.compile(r"^ZV-[A-Za-z0-9_-]{32}\$")
DURATION_PATTERN = re.compile(
    r"(\d+)\s*(months?|mo|minutes?|m|hours?|h|days?|d|weeks?|w)",
    re.IGNORECASE,
)
DEFAULT_KEY_LIFETIME = timedelta(days=30)
MAX_KEY_LIFETIME = timedelta(days=30)
RATE_LIMIT = 60
RATE_WINDOW_SECONDS = 60
MAX_BODY_BYTES = 2048

# --- IP / executor logging ------------------------------------------------
GEOIP_ENABLED = os.environ.get("GEOIP_ENABLED", "1") != "0"
GEOIP_URL = (
    "http://ip-api.com/json/{ip}"
    "?fields=status,country,countryCode,regionName,city,isp,org,as"
)
GEOIP_TIMEOUT = 2.5
GEOIP_CACHE_SECONDS = 3600
GEOIP_FAILURE_CACHE_SECONDS = 60
MAX_IP_HISTORY = 10
MAX_EXECUTOR_HISTORY = 10
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