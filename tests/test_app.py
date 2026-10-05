import json
import os
import threading
import unittest
from http.server import ThreadingHTTPServer
from urllib.error import HTTPError
from urllib.request import urlopen
from unittest.mock import patch
from app.server import Handler


class ServiceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.base = f"http://127.0.0.1:{cls.server.server_port}"

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join()

    def test_health(self):
        with urlopen(self.base + "/health", timeout=2) as response:
            self.assertEqual(response.status, 200)
            self.assertEqual(json.load(response), {"status": "ok"})

    def test_version_environment(self):
        with patch.dict(os.environ, APP_VERSION="abc123", APP_ENV="production"):
            with urlopen(self.base + "/version", timeout=2) as response:
                self.assertEqual(json.load(response), {"version": "abc123", "environment": "production"})

    def test_unknown_path(self):
        with self.assertRaises(HTTPError) as error:
            urlopen(self.base + "/missing", timeout=2)
        self.assertEqual(error.exception.code, 404)
        error.exception.close()
