"""Protocol checks without downloading Torch or any translation model."""
from __future__ import annotations

import http.client
import importlib.util
import json
import pathlib
import threading
import unittest
from http.server import ThreadingHTTPServer

HERE = pathlib.Path(__file__).resolve().parent.parent
SERVER = HERE / "server" / "translate-live" / "app.py"
SPEC = importlib.util.spec_from_file_location("sarah_live_marian", SERVER)
assert SPEC and SPEC.loader
app = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(app)


class TestLocalInterpreterProtocol(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.original = app.translate_he_fr
        cls.original_fr_he = app.translate_fr_he
        app.translate_he_fr = lambda sentence: "Bonjour" if sentence else ""
        app.translate_fr_he = lambda sentence: "שלום" if sentence else ""
        cls.httpd = ThreadingHTTPServer(("127.0.0.1", 0), app.API)
        cls.port = cls.httpd.server_address[1]
        cls.thread = threading.Thread(target=cls.httpd.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.httpd.shutdown()
        cls.httpd.server_close()
        cls.thread.join(timeout=3)
        app.translate_he_fr = cls.original
        app.translate_fr_he = cls.original_fr_he

    def request(self, path, payload, method="POST"):
        client = http.client.HTTPConnection("127.0.0.1", self.port, timeout=3)
        headers = {"Content-Type": "application/json"}
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        client.request(method, path, body=data, headers=headers)
        result = client.getresponse()
        status = result.status
        body = json.loads(result.read().decode("utf-8"))
        client.close()
        return status, body

    def test_hebrew_to_french_contract(self):
        code, data = self.request("/translate", {
            "q": "שלום", "source": "he", "target": "fr", "format": "text"
        })
        self.assertEqual(code, 200)
        self.assertEqual(data["translatedText"], "Bonjour")

    def test_french_to_hebrew_contract(self):
        code, data = self.request("/translate", {
            "q": "Bonjour", "source": "fr", "target": "he", "format": "text"
        })
        self.assertEqual(code, 200)
        self.assertEqual(data["translatedText"], "שלום")

    def test_wrong_direction_not_faked(self):
        code, data = self.request("/translate", {
            "q": "hello", "source": "en", "target": "fr"
        })
        self.assertEqual(code, 422)
        self.assertIn("error", data)

    def test_empty_text_not_translated(self):
        code, _ = self.request("/translate", {
            "q": "", "source": "he", "target": "fr"
        })
        self.assertEqual(code, 400)

    def test_too_long_rejected(self):
        code, _ = self.request("/translate", {
            "q": "שלום" * 200, "source": "he", "target": "fr"
        })
        self.assertEqual(code, 413)

    def test_health_endpoint(self):
        client = http.client.HTTPConnection("127.0.0.1", self.port, timeout=3)
        client.request("GET", "/health")
        response = client.getresponse()
        data = json.loads(response.read().decode("utf-8"))
        self.assertEqual(response.status, 200)
        self.assertEqual(data["directions"], [["he", "fr"], ["fr", "he"]])
        client.close()


if __name__ == "__main__":
    unittest.main()
