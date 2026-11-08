// wire_proto.mjs — 重建 beanman-ios 的原型：5 条 Flow + 每屏默认跳转 + TabBar 四个 tab 可点。
//
// 为什么要重建：之前的连线只写在屏幕根节点上、而且没有 Flow，Figma 放映时列表是空的，
// 看起来就是「点不动 / 连不起来」。本脚本做三件事：
//   1) update_flows：写 5 条命名 Flow（第一条是默认，放映从这里开始）；
//   2) 每屏根节点挂 ON_CLICK → 该屏在叙事里的下一屏；
//   3) 每屏的 DS/TabBar 实例里，四个 tab（图标 + 文字）各挂 ON_CLICK → 对应一级页。
//
// 用法：node wire_proto.mjs
import { boot } from './figma_lib.mjs';

const PAGE = '52:5892';
const { call, finish } = await boot();

/** 屏幕名 → id（按名字查，避免 id 写死） */
const SCREENS = {
  'T-01-01': '84:6226', 'T-01-02': '85:6299',
  'T-02-01': '85:6370', 'T-02-02': '85:6399', 'T-02-03': '85:6441',
  'T-02-04': '122:10722', 'T-02-05': '122:10762', 'T-02-06': '142:13598',
  'T-03-01': '122:10835', 'T-03-02': '122:10872',
  'T-04-01': '123:11373', 'T-04-02': '123:11164', 'T-04-03': '123:12884',
  'T-04-04': '123:12923', 'T-04-05': '123:11188', 'T-04-06': '142:13582',
  'T-05-01': '123:11399', 'T-05-02': '123:11265', 'T-05-03': '123:11444', 'T-05-04': '123:11343',
  'T-06-01': '123:12251', 'T-06-02': '123:12293', 'T-06-03': '123:12349',
  'T-07-01': '123:12373', 'T-07-02': '123:12405',
  'T-08-01': '123:12454', 'T-08-02': '123:12493',
  'T-09-01': '123:12514', 'T-09-02': '123:12554', 'T-09-03': '123:12582', 'T-09-04': '123:12613',
  'T-10-01': '123:12643',
  'T-11-01': '123:12687', 'T-11-02': '123:12739',
  'T-12-01': '123:12782', 'T-12-02': '123:12801', 'T-12-03': '123:12827', 'T-12-04': '123:12848',
  'T-13-01': '123:13379', 'T-13-02': '123:13424',
  'T-14-01': '123:13454',
};

/** 每条 Flow 的起点 + 顺序 */
const FLOWS = [
  { nodeId: SCREENS['T-12-01'], name: '00 首次引导 → 今日' },
  { nodeId: SCREENS['T-02-01'], name: '01 学习卡（正面 · 背面 · 完成）' },
  { nodeId: SCREENS['T-04-01'], name: '02 弹幕复习（深浅 × 竖横）' },
  { nodeId: SCREENS['T-02-04'], name: '03 手势与拼写错词' },
  { nodeId: SCREENS['T-03-01'], name: '04 单词本卡片流' },
];

/** 每屏点一下去哪（叙事顺序） */
const NEXT = {
  'T-12-01': 'T-12-02', 'T-12-02': 'T-12-03', 'T-12-03': 'T-12-04', 'T-12-04': 'T-01-01',
  'T-01-01': 'T-02-01',
  'T-02-01': 'T-02-02', 'T-02-02': 'T-02-03', 'T-02-03': 'T-01-02',
  'T-01-02': 'T-05-01', 'T-05-01': 'T-05-03', 'T-05-03': 'T-05-04', 'T-05-04': 'T-06-01',
  'T-06-01': 'T-06-02', 'T-06-02': 'T-07-01', 'T-06-03': 'T-07-01',
  'T-07-01': 'T-07-02', 'T-07-02': 'T-08-01',
  'T-08-01': 'T-08-02', 'T-08-02': 'T-09-01',
  'T-09-01': 'T-09-02', 'T-09-02': 'T-09-03', 'T-09-03': 'T-09-04', 'T-09-04': 'T-10-01',
  'T-10-01': 'T-11-01', 'T-11-01': 'T-11-02', 'T-11-02': 'T-13-01',
  'T-13-01': 'T-13-02', 'T-13-02': 'T-14-01', 'T-14-01': 'T-01-01',
  // 独立子流程
  'T-02-04': 'T-02-05', 'T-02-05': 'T-02-06', 'T-02-06': 'T-02-02',
  'T-04-01': 'T-04-02', 'T-04-02': 'T-04-03', 'T-04-03': 'T-04-04',
  'T-04-04': 'T-04-05', 'T-04-05': 'T-04-06', 'T-04-06': 'T-04-01',
  'T-03-01': 'T-03-02', 'T-03-02': 'T-03-01',
};

/** tab 名 → 一级页 */
const TAB_TARGETS = {
  'ic-flame': 'T-01-01', '今日': 'T-01-01',
  'ic-book': 'T-06-01', '词库': 'T-06-01',
  'ic-chart': 'T-10-01', '统计': 'T-10-01',
  'ic-gear': 'T-11-01', '设置': 'T-11-01',
};

const click = (dest) => [
  {
    trigger: { type: 'ON_CLICK' },
    actions: [{ type: 'NODE', destinationId: dest, navigation: 'NAVIGATE', transition: null }],
  },
];

async function reactionsOf(nodeId) {
  const res = await call('get_reactions', { nodeId });
  return res.reactions || [];
}

async function setReactions(nodeId, reactions) {
  await call('set_reactions', { nodeId, reactions });
}

await call('navigate_to_page', { pageId: PAGE });

// 1) 屏幕根节点
let ok = 0;
const problems = [];
for (const [code, id] of Object.entries(SCREENS)) {
  const dest = SCREENS[NEXT[code]];
  if (!dest) { problems.push(`${code} 没有 NEXT`); continue; }
  const keep = (await reactionsOf(id)).filter((r) => r.trigger?.type === 'ON_DRAG');
  try {
    await setReactions(id, [...click(dest), ...keep]);
    ok += 1;
  } catch (e) {
    problems.push(`${code}: ${e.message}`);
  }
}
console.log(`screen root reactions: ${ok}/${Object.keys(SCREENS).length}`);

// 2) TabBar 四个 tab
let tabs = 0;
for (const [code, id] of Object.entries(SCREENS)) {
  const node = await call('get_node', { nodeId: id });
  const root = node.node ?? node;
  const bar = (root.children ?? []).find((c) => String(c.name).startsWith('DS/TabBar'));
  if (!bar) { problems.push(`${code}: 没找到 DS/TabBar`); continue; }
  const inst = await call('get_node', { nodeId: bar.id });
  const instRoot = inst.node ?? inst;
  for (const child of instRoot.children ?? []) {
    const dest = SCREENS[TAB_TARGETS[String(child.name)]];
    if (!dest) continue;
    try {
      await setReactions(child.id, click(dest));
      tabs += 1;
    } catch (e) {
      problems.push(`${code}/${child.name}: ${e.message}`);
    }
  }
}
console.log(`tab hotspots wired: ${tabs}`);

// 3) Flow
const flows = await call('update_flows', {
  pageId: PAGE,
  flows: FLOWS,
  order: FLOWS.map((f) => f.nodeId),
});
console.log('flows:', JSON.stringify(flows).slice(0, 600));

// 4) 读回校验
let linked = 0;
for (const [code, id] of Object.entries(SCREENS)) {
  const rs = await reactionsOf(id);
  if (rs.some((r) => r.trigger?.type === 'ON_CLICK')) linked += 1;
}
console.log(`readback: ${linked}/${Object.keys(SCREENS).length} 屏有根节点点击`);
if (problems.length) console.log('problems:\n  ' + problems.join('\n  '));

await finish();