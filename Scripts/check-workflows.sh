#!/usr/bin/env bash
# 校验两个 workflow 的 YAML 是否可解析，并打印 job 名。
set -u
cd /mnt/d/deepseek-harness/resources/dsh-profiles/beanman-ios || exit 1
python3 - <<'PY'
import yaml
for f in ['.github/workflows/ios-build.yml', '.github/workflows/release-testflight.yml']:
    with open(f, encoding='utf-8') as fh:
        d = yaml.safe_load(fh)
    print(f, '-> jobs:', ','.join((d.get('jobs') or {}).keys()) or '(none)')
print('YAML OK')
PY