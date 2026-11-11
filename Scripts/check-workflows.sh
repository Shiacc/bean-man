#!/usr/bin/env bash
# 校验所有 workflow 的 YAML 是否可解析，并打印 job 名。
set -u
# 相对脚本位置定位仓库根：仓库已从 DSH 工作区搬到 D:\repos\beanman-ios
cd "$(dirname "$0")/.." || exit 1
python3 - <<'PY'
import glob
import yaml
for f in sorted(glob.glob('.github/workflows/*.yml')):
    with open(f, encoding='utf-8') as fh:
        d = yaml.safe_load(fh)
    on = d.get('on', d.get(True, {}))
    trig = ','.join(on.keys()) if isinstance(on, dict) else str(on)
    print(f, '-> jobs:', ','.join((d.get('jobs') or {}).keys()) or '(none)', '| trigger:', trig)
    if d.get('jobs') and 'steps' not in next(iter(d['jobs'].values())):
        print('   !! 有 job 没有 steps')
print('YAML OK')
PY