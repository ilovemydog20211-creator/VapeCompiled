import json
import tempfile
import threading
import unittest
from datetime import datetime, timedelta, timezone
from http.server import ThreadingHTTPServer
from pathlib import Path
from urllib.request import Request, urlopen

from main import KeyStore, make_api_handler, parse_key_lifetime


class KeyStoreTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.path = Path(self.directory.name) / "keys.json"
        self.store = KeyStore(self.path)

    def tearDown(self):
        self.directory.cleanup()

    def test_keys_bind_to_first_roblox_account(self):
        key, expires_at = self.store.issue("123456789012345678")

        self.assertEqual(
            self.store.validate_for_roblox_user(key, 12345),
            ("123456789012345678", "valid", expires_at),
        )
        self.assertEqual(
            self.store.validate_for_roblox_user(key, 54321),
            ("123456789012345678", "account_mismatch", expires_at),
        )
        self.assertEqual(
            KeyStore(self.path).validate_for_roblox_user(key, 12345),
            ("123456789012345678", "valid", expires_at),
        )
        self.assertEqual(
            self.store.validate_for_roblox_user("not-a-key", 12345),
            (None, "invalid", None),
        )

    def test_revoked_key_fails_the_next_client_validation(self):
        key, _ = self.store.issue("123456789012345678")
        self.assertEqual(
            self.store.validate_for_roblox_user(key, 12345)[1],
            "valid",
        )

        record = self.store.revoke_with_details("123456789012345678")
        self.assertEqual(record["robloxUserId"], "12345")
        self.assertEqual(
            self.store.validate_for_roblox_user(key, 12345),
            (None, "invalid", None),
        )

    def test_bulk_revoke_returns_records_for_audit_logging(self):
        self.store.issue("123456789012345678")
        self.store.issue("223456789012345678")

        records = self.store.revoke_all_with_details()

        self.assertEqual(
            {record["discordId"] for record in records},
            {"123456789012345678", "223456789012345678"},
        )
        self.assertEqual(self.store.revoke_all(), 0)

    def test_expired_keys_are_rejected_without_binding(self):
        key, _ = self.store.issue("123456789012345678")
        records = json.loads(self.path.read_text(encoding="utf-8"))
        records["keys"][0]["expiresAt"] = (
            datetime.now(timezone.utc) - timedelta(seconds=1)
        ).isoformat()
        self.path.write_text(json.dumps(records), encoding="utf-8")
        self.store = KeyStore(self.path)

        owner_id, result, _ = self.store.validate_for_roblox_user(key, 12345)
        self.assertEqual((owner_id, result), ("123456789012345678", "expired"))
        self.assertNotIn("robloxUserId", self.store.users["123456789012345678"])

    def test_validation_api_reports_expired_keys(self):
        key, _ = self.store.issue("123456789012345678")
        records = json.loads(self.path.read_text(encoding="utf-8"))
        records["keys"][0]["expiresAt"] = (
            datetime.now(timezone.utc) - timedelta(seconds=1)
        ).isoformat()
        self.path.write_text(json.dumps(records), encoding="utf-8")
        self.store = KeyStore(self.path)

        server = ThreadingHTTPServer(
            ("127.0.0.1", 0),
            make_api_handler(self.store),
        )
        server_thread = threading.Thread(target=server.serve_forever, daemon=True)
        server_thread.start()
        try:
            request = Request(
                f"http://127.0.0.1:{server.server_port}/validate",
                data=json.dumps(
                    {"key": key, "robloxUserId": 12345}
                ).encode("utf-8"),
                headers={"Content-Type": "application/json"},
                method="POST",
            )
            with urlopen(request) as response:
                self.assertEqual(
                    json.loads(response.read()),
                    {"valid": False, "reason": "expired"},
                )
        finally:
            server.shutdown()
            server.server_close()
            server_thread.join()

    def test_lifetimes_accept_supported_range_and_reject_out_of_range(self):
        self.assertEqual(parse_key_lifetime("1m"), timedelta(minutes=1))
        self.assertEqual(parse_key_lifetime("1 month"), timedelta(days=30))
        self.assertEqual(parse_key_lifetime(None), timedelta(days=30))
        for value in ("0m", "31d", "1s", "invalid", "999999999999999999d"):
            with self.subTest(value=value), self.assertRaises(ValueError):
                parse_key_lifetime(value)


if __name__ == "__main__":
    unittest.main()
