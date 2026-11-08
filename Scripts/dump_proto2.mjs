// dump_proto2.mjs — 用 get_reactions（而不是 get_node）读真实原型连线
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
let linked = 0;

for (const f of frames) {
  const res = await call('get_reactions', { nodeId: f.id });
  const reactions = res.reactions || [];
  if (reactions.length > 0) linked += 1;
  const desc = reactions
    .map((r) => {
      const trig = r.trigger?.type ?? '?';
      const act = (r.actions || [])
        .map((a) => {
          const dest = a.destinationId ?? '';
          const name = byId.get(dest) ?? (dest ? 'MISSING' : '');
          return `${a.type}${dest ? '->' + name : ''}${a.navigation ? '/' + a.navigation : ''}`;
        })
        .join(',');
      return `${trig}:${act}`;
    })
    .join(' ; ');
  console.log(`${f.name.padEnd(34)} ${f.id.padEnd(10)} ${reactions.length ? desc : '—'}`);
}

console.log(`\nlinked screens: ${linked}/${frames.length}`);
await finish();