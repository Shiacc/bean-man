// figma_audit.mjs — 检查 beanman-ios 页的网格排布、屏编号与原型连线。
// 用法：复制 figma_lib.mjs + 本文件到 WSL ~/，cd ~ && node figma_audit.mjs。
// 依赖：本机装了 npx、Figma 桌面端打开着 app-design 文件。
// audit_ui.mjs — 检查 beanman-ios 页的网格排布与原型连线
import { boot, W, H, COL, ROW, X0, Y0 } from './figma_lib.mjs';

const PAGE = '52:5892';
const { call, finish } = await boot();

async function main() {
  await call('navigate_to_page', { pageId: PAGE });
  const found = await call('search_nodes', { type: 'FRAME' });
  const all = found.nodes || found.results || [];
  const frames = all
    .filter((n) => n.type === 'FRAME' || n.type === 'COMPONENT')
    .map((n) => ({
      id: n.id, name: n.name, x: Math.round(n.x), y: Math.round(n.y),
      w: Math.round(n.width || 0), h: Math.round(n.height || 0),
    }))
    .filter((n) => (n.w === 390 && n.h === 844) || (n.w === 844 && n.h === 390));

  console.log(`screens: ${frames.length}`);

  const rows = new Map();
  const problems = [];
  for (const f of frames) {
    const c = (f.x - X0) / COL;
    const r = (f.y - Y0) / ROW;
    const text = f.name.replace(/^T-(\d{2})-(\d{2})\s*·?\s*/, '');
    if (!Number.isInteger(c) || !Number.isInteger(r) || c < 0 || r < 0) {
      problems.push(`网格不对 ${f.name} @ (${f.x},${f.y}) → c=${(c).toFixed(2)} r=${(r).toFixed(2)}`);
    }
    if (!/^T-\d{2}-\d{2}/.test(f.name)) problems.push(`命名不合规 ${f.name}`);
    if (!rows.has(r)) rows.set(r, []);
    rows.get(r).push({ ...f, c, r, text });
  }

  // 行内列序检查
  for (const [r, list] of [...rows.entries()].sort((a, b) => a[0] - b[0])) {
    list.sort((a, b) => a.c - b.c);
    const cols = list.map((x) => x.c);
    const dup = cols.filter((v, i) => cols.indexOf(v) !== i);
    if (dup.length) problems.push(`r${r} 列重复: ${dup.join(',')}`);
    if (cols.some((v, i) => i > 0 && v !== cols[i - 1] + 1)) {
      problems.push(`r${r} 列不连续: ${cols.join(',')}`);
    }
    console.log(`r${String(r).padStart(2)} | ${list.map((x) => `c${x.c} ${x.name.split(' ')[0]}`).join(' | ')}`);
  }

  // 重叠检查
  for (let i = 0; i < frames.length; i++) {
    for (let j = i + 1; j < frames.length; j++) {
      const a = frames[i], b = frames[j];
      if (a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h) {
        problems.push(`重叠: ${a.name} × ${b.name}`);
      }
    }
  }

  // 原型连线
  let withReactions = 0;
  const reactionRows = [];
  for (const f of frames) {
    let r = null;
    try { r = await call('get_reactions', { nodeId: f.id }); } catch { r = null; }
    const list = r?.reactions || r?.nodes?.[0]?.reactions || [];
    if (list.length) {
      withReactions++;
      reactionRows.push(`${f.name.split(' ')[0]} → ${list.map((x) => `${x.trigger?.type || '?'}→${(x.actions||[]).map(a=>a.destinationId||a.type).join('/')}`).join(', ')}`);
    }
  }
  console.log(`\n有原型的屏: ${withReactions}/${frames.length}`);
  reactionRows.forEach((s) => console.log('  ' + s));

  console.log('\n问题:');
  if (!problems.length) console.log('  无');
  problems.forEach((p) => console.log('  - ' + p));

  finish();
}

main().catch((e) => { console.error('ERR', e.message); finish(); process.exit(1); });