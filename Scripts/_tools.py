import json
import pathlib

p = pathlib.Path('/home/test/fig-schemas.json')
d = json.loads(p.read_text(encoding='utf-8'))
tools = d.get('tools') if isinstance(d, dict) else d
names = [t.get('name') for t in (tools or [])]
print(len(names))
print('\n'.join(sorted(names)))