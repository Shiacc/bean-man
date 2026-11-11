#!/usr/bin/env bash
# 查 CI 状态与失败 annotation（公开仓库，不需要 token）。
#
# 用法：
#   bash Scripts/ci_status.sh            # 最近一次 run 的步骤状态 + HEAD 的 annotation
#   bash Scripts/ci_status.sh <sha>      # 指定 commit 的 check-run annotation
#
# 为什么需要它：作业日志（/actions/jobs/<id>/logs）要 admin 权限，读不到；
# 公开仓库的 check-run annotation 可以匿名读，而 ios-build.yml 的失败步骤会把
# 每条 *.swift:行:列: error: 发成 annotation（单测断言失败也是这个格式）。
#
# 换仓库：OWNER_REPO=owner/name bash Scripts/ci_status.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

OWNER_REPO=${OWNER_REPO:-Shiacc/bean-man}
API="https://api.github.com/repos/$OWNER_REPO"
SHA=${1:-$(git rev-parse HEAD)}

echo "== 最近一次 run =="
curl -s -m 25 "$API/actions/runs?per_page=1" -o /tmp/bm_runs.json
python3 - "$API" <<'PY'
import json, sys, urllib.request

api = sys.argv[1]
runs = json.load(open('/tmp/bm_runs.json')).get('workflow_runs', [])
if not runs:
    print('没有 run'); raise SystemExit
r = runs[0]
print(r['id'], '|', r['name'], '|', r['head_sha'][:7], '|', r['status'], r['conclusion'])

hdr = {'Accept': 'application/vnd.github+json', 'User-Agent': 'ci-status'}
try:
    jobs = json.load(urllib.request.urlopen(
        urllib.request.Request(f"{api}/actions/runs/{r['id']}/jobs", headers=hdr), timeout=25))
except Exception as e:
    print('读不到 jobs：', e); raise SystemExit

for j in jobs.get('jobs', []):
    print('JOB', j['name'], '|', j['status'], j['conclusion'])
    for s in j.get('steps', []):
        print('   -', s['number'], s['name'], '|', s['status'], s['conclusion'])
PY

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
    if not c.get('annotations_url'):
        continue
    for a in get(c['annotations_url']):
        found = True
        msg = (a.get('message') or '').replace('\n', ' | ')
        print(f"  [{a.get('annotation_level')}] {a.get('path')}:{a.get('start_line')} :: {msg[:300]}")
if not found:
    print('没有 annotation（要么全绿，要么失败原因不是 *.swift:行:列: error: 格式）')
PY