// dump_tabbar.mjs — 打印 TableBar 实例的子节点，确定四个 tab 的节点 id
import { boot } from './figma_lib.mjs';

const { call, finish } = await boot();
await call('navigate_to_page', { pageId: '52:5892' });

const screen = await call('get_node', { nodeId: '84:6226' });
const n = screen.node ?? screen;
const tab = (n.children ?? []).find((c) => c.name === 'DS/TabBar');
console.log('instance', tab?.id, tab?.type, tab?.width, tab?.height);
const inst = await call('get_node', { nodeId: tab.id });
const root = inst.node ?? inst;
for (const c of root.children ?? []) {
  const label = c.characters ? ` "${c.characters}"` : '';
  console.log(`  ${String(c.type).padEnd(10)} ${String(c.name).padEnd(20)} ${c.id} ${Math.round(c.x)},${Math.round(c.y)}${label}`);
}
await finish();