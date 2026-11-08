// check_pages.mjs — 验证 get_pages 是否列出页面 flows（作为「flow 校验」规则的依据）
import { boot } from './figma_lib.mjs';

const { call, finish } = await boot();
const res = await call('get_pages', {});
const pages = res.pages || res.results || [];
for (const p of pages) {
  const flows = p.flows ? p.flows.map((f) => `${f.name}@${f.nodeId}`).join(' | ') : '(无 flows 字段)';
  console.log(`${String(p.name).padEnd(24)} ${String(p.id).padEnd(10)} ${flows}`);
}
await finish();