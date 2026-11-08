// clean_flows.mjs — 删除自动生成的 Flow 2..N，只留 5 条命名 Flow 并排好顺序
import { boot } from './figma_lib.mjs';

const PAGE = '52:5892';
const KEEP = ['123:12782', '85:6370', '123:11373', '122:10722', '122:10835'];

const { call, finish } = await boot();
await call('navigate_to_page', { pageId: PAGE });

const before = await call('update_flows', { pageId: PAGE });
const flows = before.flows || [];
console.log('before:', flows.length, flows.map((f) => f.name).join(' | ').slice(0, 200));

const remove = flows.filter((f) => !KEEP.includes(f.nodeId)).map((f) => f.nodeId);
const after = await call('update_flows', { pageId: PAGE, remove, order: KEEP });
console.log('after:', (after.flows || []).length);
for (const f of after.flows || []) console.log(`  ${f.name.padEnd(30)} ${f.nodeId}`);

await finish();