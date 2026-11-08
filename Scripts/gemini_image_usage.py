"""量一次 Gemini 图像生成的真实 token 用量（经 relay，避免鉴权差异）。

用法：
    python Scripts/gemini_image_usage.py
输出：usageMetadata、响应头里可能出现的计费字段、图片字节数。
"""
from __future__ import annotations

import json
import sys
import urllib.request

RELAY = "http://127.0.0.1:8791/v1beta/models/gemini-3.1-flash-image-preview:generateContent"

PROMPT = (
    "A macOS app icon for an app named 'BeanMan': a cream-coloured bean with a "
    "friendly cat face, warm orange background #E4703A, flat sticker style, "
    "thick dark outline, no text, centered squircle icon."
)


def main() -> int:
    body = json.dumps(
        {
            "contents": [{"parts": [{"text": PROMPT}]}],
            "generationConfig": {"imageConfig": {"aspectRatio": "1:1", "imageSize": "1K"}},
            "responseModalities": ["IMAGE"],
        }
    ).encode("utf-8")

    req = urllib.request.Request(
        RELAY,
        data=body,
        headers={"Content-Type": "application/json", "x-goog-api-key": "haoee"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=180) as resp:
        raw = resp.read()
        headers = dict(resp.headers)

    payload = json.loads(raw.decode("utf-8"))
    usage = payload.get("usageMetadata") or payload.get("usage") or {}
    print("usage:", json.dumps(usage, ensure_ascii=False, indent=2))

    interesting = {k: v for k, v in headers.items() if any(t in k.lower() for t in ("cost", "quota", "usage", "token", "request-id"))}
    print("headers:", json.dumps(interesting, ensure_ascii=False, indent=2))

    data = payload.get("candidates", [{}])[0].get("content", {}).get("parts", [])
    for part in data:
        inline = part.get("inlineData") or part.get("inline_data")
        if inline:
            import base64

            print("image bytes:", len(base64.b64decode(inline["data"])))
            break
    return 0


if __name__ == "__main__":
    sys.exit(main())