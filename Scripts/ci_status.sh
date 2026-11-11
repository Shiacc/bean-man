#!/usr/bin/env bash
# 查 CI 状态与失败详情（公开仓库，不需要 token）。
#
# 用法：
#   bash Scripts/ci_status.sh            # 最近一次 run 的步骤 + 失败详情
#   bash Scripts/ci_status.sh <sha>      # 指定 commit 的 check-run annotation
#
# 三条匿名可见的通道（日志本体 /actions/jobs/<id>/logs 要 admin 权限，读不到）：
#   1. check-run annotation（workflow 里的 ::error::）；
#   2. **run 页面的 HTML**——失败步骤的日志片段会被嵌进页面，`*.swift:行:列: error` 能直接 grep 到；
#   3. 同页面里的 Fatal error / Test runner crashed。
# 换仓库：OWNER_REPO=owner/name bash Scripts/ci_status.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

OWNER_REPO=${OWNER_REPO:-Shiacc/bean-man}
API="https://api.github.com/repos/$OWNER_REPO"
SHA=${1:-$(git rev-parse HEAD)}

echo "== 最近一次 run =="
curl -s -m 25 "$API/actions/runs?per_page=1" -o /tmp/bm_runs.json
RUN_ID=$(python3 - "$API" <<'PY'
import json, sys, urllib.request

api = sys.argv[1]
runs = json.load(open('/tmp/bm_runs.json')).get('workflow_runs', [])
if not runs:
    print(''); raise SystemExit
r = runs[0]
print(r['id'], '|', r['name'], '|', r['head_sha'][:7], '|', r['status'], r['conclusion'],
      file=sys.stderr)
print(r['id'])

hdr = {'Accept': 'application/vnd.github+json', 'User-Agent': 'ci-status'}
try:
    jobs = json.load(urllib.request.urlopen(
        urllib.request.Request(f"{api}/actions/runs/{r['id']}/jobs", headers=hdr), timeout=25))
except Exception as e:
    print('读不到 jobs：', e, file=sys.stderr); raise SystemExit

for j in jobs.get('jobs', []):
    print('JOB', j['name'], '|', j['status'], j['conclusion'], file=sys.stderr)
    for s in j.get('steps', []):
        print('   -', s['number'], s['name'], '|', s['status'], s['conclusion'], file=sys.stderr)
PY
)

echo
echo "== $SHA 的 annotation =="
python3 - "$API" "$SHA" <<'PY'
import json, sys, urllib.request

api, sha = sys.argv[1], sys.argv[2]
hdr = {'Accept': 'application/vnd.github+json', 'User-Agent': 'ci-status'}


def get(url):
    return json.load(urllib.request.urlopen(urllib.request.Request(url, headers=hdr), timeout=25))


try:
    checks = get(f"{api}/commits/{sha}/check-runs")
except Exception as e:
    print('读不到 check-runs：', e); raise SystemExit

print('check-runs:', checks.get('total_count'), checks.get('message', ''))
found = False
for c in checks.get('check_runs', []):
    print('-', c['name'], c['status'], c['conclusion'])
    url = c.get('annotations_url') or f"{api}/check-runs/{c['id']}/annotations"
    try:
        items = get(url)
    except Exception:
        continue
    for a in items:
        found = True
        msg = (a.get('message') or '').replace('\n', ' | ')
        print(f"  [{a.get('annotation_level')}] {a.get('path')}:{a.get('start_line')} :: {msg[:300]}")
if not found:
    print('没有 annotation（workflow 里的 ::error:: 有时不落到这里，看下面的 run 页面）')
PY

if [ -n "${RUN_ID:-}" ]; then
  echo
  echo "== run 页面里的错误（匿名可见） =="
  curl -s -m 30 "https://github.com/$OWNER_REPO/actions/runs/$RUN_ID" -o /tmp/bm_run.html
  ERRORS=$(grep -o -E "[A-Za-z0-9_/.-]+\.swift:[0-9]+:[0-9]+: error[^\"<>]{0,220}" /tmp/bm_run.html | head -20)
  CRASHES=$(grep -o -E "(Fatal error|Test runner crashed|XCTAssert[A-Za-z]* failed)[^\"<>]{0,220}" /tmp/bm_run.html | head -10)
  if [ -n "$ERRORS" ]; then
    printf '%s\n' "$ERRORS"
  fi
  if [ -n "$CRASHES" ]; then
    printf '%s\n' "$CRASHES"
  fi
  if [ -z "$ERRORS" ] && [ -z "$CRASHES" ]; then
    echo "（页面里没找到 .swift 错误行；可能全绿，或失败原因不在日志片段里）"
  fi
fi