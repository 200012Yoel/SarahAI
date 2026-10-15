#!/usr/bin/env python3
"""Sarah / Yoann Translate Live: local Apache-2.0 licensed Marian neural MT.

Supported directions: Hebrew→French and French→Hebrew. Other language
pairs must use other explicitly installed models. No audio leaves the iPhone.
Models are downloaded on first use to the configured HF cache.
"""
from __future__ import annotations

import json
import os
import threading
from functools import lru_cache
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

MAX_REQUEST_BYTES = 5000
MODEL_IDS = {
    ("he", "fr"): os.getenv("SARAH_MT_MODEL_HE_FR", "Helsinki-NLP/opus-tatoeba-he-fr"),
    ("fr", "he"): os.getenv("SARAH_MT_MODEL_FR_HE", "Helsinki-NLP/opus-mt-fr-he"),
}
BIND = os.getenv("SARAH_MT_BIND", "0.0.0.0")
PORT = int(os.getenv("SARAH_MT_PORT", "5000"))
_LOCK = threading.RLock()
_ENGINES = {}


def load_model(source="he", target="fr"):
    pair = (source, target)
    if pair not in MODEL_IDS:
        raise ValueError("Unsupported translation direction")
    with _LOCK:
        if pair in _ENGINES:
            return
        import torch
        from transformers import MarianMTModel, MarianTokenizer

        torch.set_num_threads(max(1, min(int(os.getenv("SARAH_MT_THREADS", "2")), 4)))
        model_id = MODEL_IDS[pair]
        tokenizer = MarianTokenizer.from_pretrained(model_id)
        model = MarianMTModel.from_pretrained(model_id)
        model.eval()
        _ENGINES[pair] = (tokenizer, model)


def _translate(source: str, target: str, message: str) -> str:
    load_model(source, target)
    import torch
    with _LOCK, torch.inference_mode():
        tokenizer, model = _ENGINES[(source, target)]
        batch = tokenizer([message], return_tensors="pt", truncation=True, max_length=192)
        tokens = model.generate(
            **batch, max_new_tokens=192, num_beams=1, do_sample=False
        )
        return str(tokenizer.batch_decode(tokens, skip_special_tokens=True)[0]).strip()


@lru_cache(maxsize=128)
def translate_he_fr(message: str) -> str:
    return _translate("he", "fr", message)


@lru_cache(maxsize=128)
def translate_fr_he(message: str) -> str:
    return _translate("fr", "he", message)


class API(BaseHTTPRequestHandler):
    server_version = "YoannTranslateLive/2.0"

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
                "status": "ready" if ("he", "fr") in _ENGINES else "loading",
                "models": [
                    {"source": src, "target": tgt, "name": name,
                     "loaded": (src, tgt) in _ENGINES}
                    for (src, tgt), name in MODEL_IDS.items()
                ],
                "directions": [["he", "fr"], ["fr", "he"]],
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
            if not isinstance(source, str) or not isinstance(target, str):
                self.reply(422, {"error": "Invalid source or target"})
                return
            if (source, target) not in MODEL_IDS:
                self.reply(422, {"error": "This server supports he-fr and fr-he only."})
                return
            if len(sentence) > 450:
                self.reply(413, {"error": "Short live fragments only (max 450 characters)"})
                return
            if source == "he":
                result = translate_he_fr(sentence.strip())
            else:
                result = translate_fr_he(sentence.strip())
            if not result:
                self.reply(503, {"error": "Neural translator returned empty output"})
                return
            self.reply(200, {
                "translatedText": result, "source": source, "target": target
            })
        except Exception as exc:
            # No raw audio or transcript is logged; avoid leaking user input.
            self.reply(503, {"error": type(exc).__name__})

    def log_message(self, _format, *args):
        return  # No private conversation content in logs.


if __name__ == "__main__":
    print("Yoann Translate Live: preloading Hebrew → French", flush=True)
    load_model("he", "fr")
    server = ThreadingHTTPServer((BIND, PORT), API)
    print(f"Yoann listening at http://{BIND}:{PORT}/health", flush=True)
    server.serve_forever()
