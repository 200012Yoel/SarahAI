#!/usr/bin/env python3
"""Sarah Translate Live: commercial-permissive Helsinki-NLP HE→FR endpoint.

This server uses a real Apache-2.0 licensed Marian neural machine translation
model locally, unlike a toy lookup dictionary. It accepts the LibreTranslate
POST /translate JSON shape already used by Sarah's iPhone app.

The pretrained model is NOT bundled here; on first start its weights are
downloaded from Hugging Face and cached in /models. Review the model license.
"""
from __future__ import annotations

import json
import os
import threading
from functools import lru_cache
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

MAX_REQUEST_BYTES = 5000
MODEL_ID = os.getenv("SARAH_MT_MODEL", "Helsinki-NLP/opus-mt-he-fr")
BIND = os.getenv("SARAH_MT_BIND", "0.0.0.0")
PORT = int(os.getenv("SARAH_MT_PORT", "5000"))
SOURCE = "he"
TARGET = "fr"

_LOCK = threading.Lock()
_ENGINE = None
_TOKENIZER = None


def load_model():
    global _ENGINE, _TOKENIZER
    with _LOCK:
        if _ENGINE is not None:
            return
        import torch
        from transformers import MarianMTModel, MarianTokenizer

        torch.set_num_threads(max(1, min(int(os.getenv("SARAH_MT_THREADS", "2")), 4)))
        _TOKENIZER = MarianTokenizer.from_pretrained(MODEL_ID)
        _ENGINE = MarianMTModel.from_pretrained(MODEL_ID)
        _ENGINE.eval()


@lru_cache(maxsize=128)
def translate_he_fr(message: str) -> str:
    load_model()
    import torch
    with _LOCK, torch.inference_mode():
        batch = _TOKENIZER(
            [message], return_tensors="pt", truncation=True, max_length=192
        )
        tokens = _ENGINE.generate(
            **batch, max_new_tokens=192, num_beams=1, do_sample=False
        )
        return str(_TOKENIZER.batch_decode(tokens, skip_special_tokens=True)[0]).strip()


class API(BaseHTTPRequestHandler):
    server_version = "SarahTranslateLive/1.0"

    def reply(self, code: int, payload: dict):
        encoded = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(encoded)

    def do_GET(self):
        if self.path == "/health":
            self.reply(200, {
                "status": "ready" if _ENGINE is not None else "loading",
                "model": MODEL_ID,
                "directions": [[SOURCE, TARGET]],
                "backend": "Helsinki Marian / Apache-2.0"
            })
        else:
            self.reply(404, {"error": "Not found"})

    def do_POST(self):
        if self.path.rstrip("/") != "/translate":
            self.reply(404, {"error": "Not found"})
            return
        try:
            n = int(self.headers.get("Content-Length", "0"))
            if n <= 0 or n > MAX_REQUEST_BYTES:
                self.reply(413, {"error": "Text request too large"})
                return
            body = json.loads(self.rfile.read(n))
            source = body.get("source")
            target = body.get("target")
            sentence = body.get("q")
            if not isinstance(sentence, str) or not sentence.strip():
                self.reply(400, {"error": "Empty translation"})
                return
            if (source, target) != (SOURCE, TARGET):
                self.reply(422, {
                    "error": "This server supports he -> fr only.",
                    "source": SOURCE, "target": TARGET
                })
                return
            if len(sentence) > 450:
                self.reply(413, {"error": "Short live fragments only (max 450 characters)"})
                return
            result = translate_he_fr(sentence.strip())
            if not result:
                self.reply(503, {"error": "Neural translator returned empty output"})
                return
            self.reply(200, {"translatedText": result, "source": SOURCE, "target": TARGET})
        except Exception as exc:
            # No user audio and no personal transcript in server logs.
            self.reply(503, {"error": type(exc).__name__})

    def log_message(self, _format, *args):
        return  # Do not log private conversations


if __name__ == "__main__":
    print(f"Sarah Translate Live loading {MODEL_ID}, CPU-only, no paid API", flush=True)
    load_model()
    server = ThreadingHTTPServer((BIND, PORT), API)
    print(f"Sarah Translate Live ready at http://{BIND}:{PORT}/health", flush=True)
    server.serve_forever()
