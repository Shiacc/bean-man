// dump_proto.mjs — 逐屏打印原型连线（reactions）与页面 flow 起点，用于诊断「链接不起来」。
// 用法：node dump_proto.mjs
import { boot } from './figma_lib.mjs';

const PAGE = '52:5892';
const { call, finish } = await boot();

await call('navigate_to_page', { pageId: PAGE });

const found = await call('search_nodes', { type: 'FRAME' });
const all = found.nodes || found.results || [];
const frames = all
  .filter((n) => n.type === 'FRAME')
  .map((n) => ({ id: n.id, name: n.name, x: Math.round(n.x), y: Math.round(n.y), w: Math.round(n.width || 0), h: Math.round(n.height || 0) }))
  .filter((n) => (n.w === 390 && n.h === 844) || (n.w === 844 && n.h === 390))
  .sort((a, b) => a.y - b.y || a.x - b.x);

const byId = new Map(frames.map((f) => [f.id, f.name]));
console.log('screens:', frames.length);

const page = await call('get_node', { nodeId: PAGE });
const flowPoints = JSON.stringify(page).match(/"flowStartingPoints":\s*(\[[^\]]*\])/);
console.log('flowStartingPoints:', flowPoints ? flowPoints[1] : '(none in node payload)');

for (const f of frames) {
  const node = await call('get_node', { nodeId: f.id });
  const raw = JSON.stringify(node);
  const reactions = raw.match(/"reactions":\s*(\[[\s\S]*?\])\s*,\s*"(?:transition|annotation)/);
  let info = 'no reactions';
  if (raw.includes('"reactions"')) {
    const ids = [...raw.matchAll(/"destinationId":\s*"([^"]+)"/g)].map((m) => m[1]);
    const trig = [...raw.matchAll(/"type":\s*"(ON_CLICK|ON_DRAG|ON_HOVER|ON_PRESS|AFTER_TIMEOUT|MOUSE_UP|MOUSE_DOWN)"/g)].map((m) => m[1]);
    info = `${trig.join(',')} -> ${ids.map((id) => `${id}${byId.has(id) ? '(' + byId.get(id) + ')' : '(MISSING!)'}`).join(' | ')}`;
  }
  console.log(`${f.name.padEnd(34)} ${f.id.padEnd(10)} ${info}`);
}

await finish();