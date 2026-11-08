#!/usr/bin/env python
"""把 GitHub PAT 写进仓库 Secret（默认 ADMIN_TOKEN），供 .github/workflows/repo-visibility.yml 使用。

用法：
    python Scripts/set_repo_secret.py --repo Shiacc/bean-man --token-file C:/Users/me/.dsh/secrets/github-pat.txt
    python Scripts/set_repo_secret.py --generate-pat            # 只打印需要勾选的权限说明

依赖：pynacl（pip install pynacl）
"""

from __future__ import annotations

import argparse
import base64
import json
import pathlib
import sys
import urllib.request

from nacl import public

API = "https://api.github.com"


def call(path: str, token: str, method: str = "GET", body: dict | None = None) -> dict:
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(
        API + path,
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "Content-Type": "application/json",
        },
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        raw = resp.read()
        return json.loads(raw) if raw else {}


def sealed(public_key_b64: str, value: str) -> str:
    box = public.SealedBox(public.PublicKey(base64.b64decode(public_key_b64)))
    return base64.b64encode(box.encrypt(value.encode())).decode()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default="Shiacc/bean-man")
    ap.add_argument("--token-file", default=r"C:\Users\lenovo\.dsh\secrets\github-pat.txt")
    ap.add_argument("--name", default="ADMIN_TOKEN")
    args = ap.parse_args()

    token = pathlib.Path(args.token_file).read_text(encoding="utf-8").strip()
    if not token:
        print("令牌文件是空的", file=sys.stderr)
        return 1

    key = call(f"/repos/{args.repo}/actions/secrets/public-key", token)
    call(
        f"/repos/{args.repo}/actions/secrets/{args.name}",
        token,
        method="PUT",
        body={"encrypted_value": sealed(key["key"], token), "key_id": key["key_id"]},
    )

    names = [s["name"] for s in call(f"/repos/{args.repo}/actions/secrets", token)["secrets"]]
    print("已写入 Secret：", args.name)
    print("当前仓库 Secret：", ", ".join(names))
    return 0


if __name__ == "__main__":
    sys.exit(main())