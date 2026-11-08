// fix_links.mjs — 修正小豆链（05-01→05-02→05-03→05-04→06-01），并抽查 TabBar 子节点是否真的挂上了
import { boot } from './figma_lib.mjs';

const { call, finish } = await boot();
await call('navigate_to_page', { pageId: '52:5892' });

const click = (dest) => [
  { trigger: { type: 'ON_CLICK' }, actions: [{ type: 'NODE', destinationId: dest, navigation: 'NAVIGATE', transition: null }] },
];

const FIX = [
  ['123:11399', '123:11265'], // 05-01 今日·小豆推荐 → 05-02 学习卡·推荐词
  ['123:11265', '123:11444'], // 05-02 → 05-03 洞察面板
  ['123:11444', '123:11343'], // 05-03 → 05-04 推荐来源
  ['123:11343', '123:12251'], // 05-04 → 06-01 词库列表
];

for (const [from, to] of FIX) {
  const keep = ((await call('get_reactions', { nodeId: from })).reactions || []).filter(
    (r) => r.trigger?.type === 'ON_DRAG',
  );
  await call('set_reactions', { nodeId: from, reactions: [...click(to), ...keep] });
  console.log('ok', from, '->', to);
}

// 抽查：今日页的 TabBar 四个 tab
const node = await call('get_node', { nodeId: '84:6226' });
const root = node.node ?? node;
const bar = (root.children ?? []).find((c) => String(c.name).startsWith('DS/TabBar'));
const inst = await call('get_node', { nodeId: bar.id });
for (const child of (inst.node ?? inst).children ?? []) {
  const rs = (await call('get_reactions', { nodeId: child.id })).reactions || [];
  const dest = rs[0]?.actions?.[0]?.destinationId;
  if (dest || String(child.name).startsWith('ic-') || ['今日', '词库', '统计', '设置'].includes(String(child.name))) {
    console.log(`  tab node ${String(child.name).padEnd(10)} -> ${dest ?? '(无)'}`);
  }
}

await finish();