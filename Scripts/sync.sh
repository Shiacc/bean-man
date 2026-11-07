#!/usr/bin/env bash
# 一条命令完成「拉 →（有改动就提交）→ 推」。
#
#   ./Scripts/sync.sh                     # 自动提交信息：chore: 同步 2026-11-07 21:40
#   ./Scripts/sync.sh "feat: 今日页"       # 指定提交信息
#
# WSL 与 macOS 都能直接跑；Windows 上用 Scripts/sync.ps1 包一层。
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

if ! git remote get-url origin >/dev/null 2>&1; then
  echo "✗ 还没有 origin 远程仓库，先执行："
  echo "  git remote add origin git@gitee.com:zhuge-x/beanman.git"
  exit 1
fi

msg="${1:-}"

echo "→ 拉取（rebase，自动暂存本地改动）"
git pull --rebase --autostash

if [[ -n "$(git status --porcelain)" ]]; then
  if [[ -z "$msg" ]]; then
    msg="chore: 同步 $(date '+%Y-%m-%d %H:%M')"
  fi
  echo "→ 提交：$msg"
  git add -A
  git commit -m "$msg"
else
  echo "→ 没有本地改动"
fi

echo "→ 推送"
git push

echo
git status -sb