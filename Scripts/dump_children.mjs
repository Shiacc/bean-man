// dump_children.mjs — 打印若干屏的直接子节点（name/type/坐标），用于确定可挂交互的热点
import { boot } from './figma_lib.mjs';

const { call, finish } = await boot();
await call('navigate_to_page', { pageId: '52:5892' });

const targets = process.argv.slice(2);
const ids = targets.length
  ? targets
  : ['84:6226', '85:6370', '123:11373', '123:12251', '123:12514', '123:13379'];

for (const id of ids) {
  const node = await call('get_node', { nodeId: id });
  const n = node.node ?? node;
  console.log(`\n=== ${n.name} (${n.id})`);
  for (const c of n.children ?? []) {
    const label = c.characters ? ` "${String(c.characters).replace(/\n/g, ' / ').slice(0, 24)}"` : '';
    console.log(`  ${String(c.type).padEnd(10)} ${String(c.name).padEnd(26)} ${Math.round(c.x)},${Math.round(c.y)} ${Math.round(c.width)}x${Math.round(c.height)}${label}`);
  }
}

await finish();