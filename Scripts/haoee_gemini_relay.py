"""haoee Gemini 中转小服务（给 dsh-image-gen 的 Google 原生接口用）

为什么需要它：插件调用 Google 原生接口时只发 `x-goog-api-key` 头，
而 haoee 的网关只认 `Authorization: Bearer <key>`（实测 x-goog-api-key → 401 apiKey 无效）。
这个小服务监听本机，把插件的请求原样转发给 haoee，只做两件事：
  1. 把 x-goog-api-key 换成 Authorization: Bearer
  2. 给 GET /v1beta/models 返回一份合成清单（haoee 自己对 /v1beta/models 返回 400）

用法：
    python haoee_gemini_relay.py            # 前台跑，Ctrl+C 退出
    python haoee_gemini_relay.py --port 8791 --log relay.log

插件里填：
    Provider      Google（Gemini）
    Endpoint      http://127.0.0.1:8791/v1beta
    原生 API      开（googleNative）
    模型          gemini-3.1-flash-image-preview
    API Key       haoee（随便填，relay 会替换成 .env 里的 HAOEE_API_KEY）
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

UPSTREAM = "https://maas.haoee.com"
ENV_PATH = os.path.expanduser(r"~\.dsh\.env")
MODEL = "gemini-3.1-flash-image-preview"


def load_key() -> str:
    for line in open(ENV_PATH, encoding="utf-8"):
        if line.startswith("HAOEE_API_KEY="):
            return line.split("=", 1)[1].strip()
    path = os.environ.get("HAOEE_ENV_FILE")
    if path and os.path.exists(path):
        for line in open(path, encoding="utf-8"):
            if line.startswith("HAOEE_API_KEY="):
                return line.split("=", 1)[1].strip()
    raise SystemExit("HAOEE_API_KEY not found (looked in ~/.dsh/.env)")


KEY = load_key()
LOG = None


def log(msg: str) -> None:
    line = msg.rstrip()
    print(line, flush=True)
    if LOG:
        LOG.write(line + "\n")
        LOG.flush()


def models_payload() -> dict:
    """合成一份 Google 风格的模型清单，够插件「测试连接 / 拉取模型」用。"""
    return {
        "models": [
            {
                "name": f"models/{MODEL}",
                "displayName": "Gemini 3.1 Flash Image (haoee)",
                "description": "haoee MaaS 转发的 Gemini 图像生成模型",
                "supportedGenerationMethods": ["generateContent"],
            },
            {
                "name": "models/gemini-3.1-flash-image",
                "displayName": "Gemini 3.1 Flash Image",
                "supportedGenerationMethods": ["generateContent"],
            },
        ]
    }


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def _send(self, code: int, payload: bytes, ctype: str = "application/json") -> None:
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self) -> None:  # noqa: N802
        if self.path.startswith("/v1beta/models"):
            body = json.dumps(models_payload()).encode()
            log(f"GET {self.path} -> 200 (synthetic {len(body)}B)")
            self._send(200, body)
            return
        log(f"GET {self.path} -> 404")
        self._send(404, json.dumps({"error": {"message": "not found"}}).encode())

    def do_POST(self) -> None:  # noqa: N802
        length = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(length) if length else b""

        url = UPSTREAM + self.path
        headers = {"Content-Type": "application/json", "Authorization": "Bearer " + KEY}
        req = urllib.request.Request(url, data=raw, headers=headers, method="POST")
        try:
            with urllib.request.urlopen(req, timeout=600) as resp:
                body = resp.read()
                ctype = resp.headers.get("Content-Type", "application/json")
                log(f"POST {self.path} -> {resp.status} {len(body)}B")
                self._send(resp.status, body, ctype)
        except urllib.error.HTTPError as e:
            body = e.read()
            log(f"POST {self.path} -> {e.code} {body[:160].decode('utf-8', 'replace')}")
            self._send(e.code, body, e.headers.get("Content-Type", "application/json"))
        except Exception as e:  # noqa: BLE001
            msg = json.dumps({"error": {"message": f"relay failed: {e}"}}).encode()
            log(f"POST {self.path} -> 502 {e}")
            self._send(502, msg)

    def log_message(self, fmt: str, *args) -> None:  # 静音默认日志
        return


def main() -> None:
    global LOG
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8791)
    ap.add_argument("--log", default="")
    args = ap.parse_args()

    if args.log:
        LOG = open(args.log, "a", encoding="utf-8")

    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    log(f"haoee gemini relay listening on http://127.0.0.1:{args.port}/v1beta  (model={MODEL})")
    log(f"key loaded: {KEY[:4]}...{KEY[-4:]}  ({len(KEY)} chars)")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        log("bye")


if __name__ == "__main__":
    sys.exit(main())