// lib2.mjs - BeanMan (豆卡单词) Figma build helpers.
import { spawn } from 'node:child_process';

export const HEX = {
  brand: '#E4703A', brandPressed: '#C2571F', brandTint: '#FFF1E8', brandSoft: '#F8D9C6',
  bg: '#FFFFFF', surface: '#F7F5F1', surfaceAlt: '#EDE9E2', border: '#E6E1D8',
  textPrimary: '#1C1B18', textSecondary: '#6E6962', textTertiary: '#A39D93',
  success: '#2F8F4E', successTint: '#E8F4EC', warning: '#C98A12', warningTint: '#FBF0D9',
  danger: '#D93A2B', dangerTint: '#FBE9E7', overlay: '#1C1B18'
};
export const VARNAME = {
  brand: 'brand', brandPressed: 'brand/pressed', brandTint: 'brand/tint', brandSoft: 'brand/soft',
  bg: 'bg', surface: 'surface', surfaceAlt: 'surface/alt', border: 'border',
  textPrimary: 'text/primary', textSecondary: 'text/secondary', textTertiary: 'text/tertiary',
  success: 'success', successTint: 'success/tint', warning: 'warning', warningTint: 'warning/tint',
  danger: 'danger', dangerTint: 'danger/tint', overlay: 'overlay'
};
export const F = {
  r: { family: 'Noto Sans SC', style: 'Regular' },
  m: { family: 'Noto Sans SC', style: 'Medium' },
  b: { family: 'Noto Sans SC', style: 'Bold' }
};
export const W = 390, H = 844, COL = 454, ROW = 940, X0 = 360, Y0 = 260;
export const colX = c => X0 + c * COL;
export const rowY = r => Y0 + r * ROW;
export const hx = s => { const n = s.replace('#',''); return { r: parseInt(n.slice(0,2),16)/255, g: parseInt(n.slice(2,4),16)/255, b: parseInt(n.slice(4,6),16)/255 }; };
export const strlen = s => { let n = 0; for (const ch of s) n += (ch.charCodeAt(0) > 255 ? 1 : 0.55); return n; };
const sleep = ms => new Promise(r => setTimeout(r, ms));

export const ICONS = {
  back: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none"><path d="M15 4.5L7.5 12l7.5 7.5" stroke="{c}" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  close: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none"><path d="M6 6l12 12M18 6L6 18" stroke="{c}" stroke-width="1.9" stroke-linecap="round"/></svg>',
  chev: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none"><path d="M9.5 5l7 7-7 7" stroke="{c}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  more: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none"><circle cx="5.5" cy="12" r="1.7" fill="{c}"/><circle cx="12" cy="12" r="1.7" fill="{c}"/><circle cx="18.5" cy="12" r="1.7" fill="{c}"/></svg>',
  speaker: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none"><path d="M4.5 9.5h3L12 5.5v13l-4.5-4H4.5v-5z" stroke="{c}" stroke-width="1.7" stroke-linejoin="round"/><path d="M15.5 9a4.2 4.2 0 010 6M18 6.5a7.5 7.5 0 010 11" stroke="{c}" stroke-width="1.7" stroke-linecap="round"/></svg>',
  check: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none"><path d="M5 12.5l4.5 4.5L19 7" stroke="{c}" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  book: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none"><path d="M4.5 5.5h6a3 3 0 013 3v10a2.5 2.5 0 00-2.5-2.5h-6.5v-10.5z" stroke="{c}" stroke-width="1.7" stroke-linejoin="round"/><path d="M19.5 5.5h-6a3 3 0 00-3 3v10a2.5 2.5 0 012.5-2.5h6.5v-10.5z" stroke="{c}" stroke-width="1.7" stroke-linejoin="round"/></svg>',
  chart: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none"><path d="M5 19V11M12 19V5M19 19v-6" stroke="{c}" stroke-width="2" stroke-linecap="round"/></svg>',
  gear: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none"><circle cx="12" cy="12" r="3.2" stroke="{c}" stroke-width="1.7"/><path d="M12 3.5v2.2M12 18.3v2.2M3.5 12h2.2M18.3 12h2.2M6 6l1.6 1.6M16.4 16.4L18 18M18 6l-1.6 1.6M7.6 16.4L6 18" stroke="{c}" stroke-width="1.7" stroke-linecap="round"/></svg>',
  flame: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none"><path d="M12 3.5c3.4 3.2 5.5 5.6 5.5 8.6A5.5 5.5 0 0112 17.6a5.5 5.5 0 01-5.5-5.5c0-3 2.1-5.4 5.5-8.6z" stroke="{c}" stroke-width="1.7" stroke-linejoin="round"/></svg>',
  play: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none"><path d="M8 5.5l10 6.5-10 6.5v-13z" stroke="{c}" stroke-width="1.8" stroke-linejoin="round"/></svg>',
  pen: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none"><path d="M4.5 19.5l1-4.2L15.8 5a2.2 2.2 0 013.2 3.2L8.7 18.5l-4.2 1z" stroke="{c}" stroke-width="1.7" stroke-linejoin="round"/></svg>'
};

export async function boot() {
  const child = spawn('npx', ['-y', '@figwright/mcp@latest'], { stdio: ['pipe', 'pipe', 'pipe'] });
  let buf = ''; const pend = new Map(); let id = 0;
  child.stdout.on('data', d => { buf += d; let i; while ((i = buf.indexOf('\n')) >= 0) { const l = buf.slice(0, i).trim(); buf = buf.slice(i + 1); if (!l) continue; let m; try { m = JSON.parse(l); } catch { continue; } if (m.id !== undefined && pend.has(m.id)) { pend.get(m.id)(m); pend.delete(m.id); } } });
  child.stderr.on('data', () => {});
  const rpc = (method, params, ms = 180000) => { const mid = ++id; return new Promise((res, rej) => { const t = setTimeout(() => { pend.delete(mid); rej(new Error('timeout ' + method)); }, ms); pend.set(mid, m => { clearTimeout(t); res(m); }); child.stdin.write(JSON.stringify({ jsonrpc: '2.0', id: mid, method, params }) + '\n'); }); };
  const raw = async (tool, args = {}) => rpc('tools/call', { name: tool, arguments: args });
  const call = async (tool, args = {}, tries = 3) => {
    let last = null;
    for (let i = 0; i < tries; i++) {
      const r = await raw(tool, args);
      const txt = (r.result?.content || []).map(x => x.text || '').join('');
      let j; try { j = JSON.parse(txt); } catch { j = { raw: txt.slice(0, 400) }; }
      if (j && j.raw && /INTERNAL_ERROR|timed out|timeout|Unable to establish/i.test(j.raw) && i < tries - 1) { await sleep(2500); continue; }
      if (j && j.isError) {
        last = j;
        if (/10 seconds|timed out|timeout|INTERNAL_ERROR|connection/i.test(txt) && i < tries - 1) { await sleep(1500); continue; }
        console.log('CALLFAIL', tool, JSON.stringify(args).slice(0, 100), txt.slice(0, 180));
        return j;
      }
      return j;
    }
    return last;
  };
  await rpc('initialize', { protocolVersion: '2025-06-18', capabilities: {}, clientInfo: { name: 'dsh-beanman', version: '1' } });
  child.stdin.write(JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized' }) + '\n');
  const files = await call('list_files', {});
  const want = process.env.FIGFILE; const list = files.files || [];
  const f = (want && list.find(x => x.fileName === want)) || list[0];
  if (!f) throw new Error('no figma file open');
  await call('use_file', { sessionId: f.sessionId });
  return { call, rpc, raw, child, file: f, finish() { child.kill(); } };
}

// ---- tokens ----
export async function ensureTokens(call, collName = 'BeanMan / Color') {
  const defs = await call('get_variable_defs', {});
  const cols = defs.collections || [];
  let col = cols.find(c => c.name === collName);
  let collId, modeId;
  if (!col) {
    const c = await call('create_variable_collection', { name: collName });
    collId = c.collectionId; modeId = c.defaultModeId;
  } else {
    collId = col.id;
    modeId = col.defaultModeId || (col.modes && col.modes[0] && col.modes[0].modeId);
  }
  const mine = (defs.variables || []).filter(v => v.collectionId === collId);
  const byName = Object.fromEntries(mine.map(v => [v.name, v.id]));
  const vars = {};
  for (const k of Object.keys(VARNAME)) {
    let vid = byName[VARNAME[k]];
    if (!vid) {
      const v = await call('create_variable', { name: VARNAME[k], collectionId: collId, resolvedType: 'COLOR' });
      vid = v.variableId || v.id;
    }
    if (!vid) { console.log('VARFAIL', k); continue; }
    vars[k] = vid;
    await call('set_variable_value', { variableId: vid, modeId, value: hx(HEX[k]) });
  }
  return { vars, byKey: vars, collId, modeId };
}

// ---- api ----
export function mk(call, V) {
  const api = {};
  const bindId = (hexColor) => {
    for (const k of Object.keys(HEX)) if (HEX[k].toUpperCase() === String(hexColor).toUpperCase()) return V[k];
    return null;
  };
  const paint = (c, opacity) => [{ type: 'SOLID', color: hx(c || HEX.bg), opacity: opacity === undefined ? 1 : opacity }];
  api.V = V;
  api.FR = async (p, n, x, y, w, h, o = {}) => {
    const fillArr = o.fill ? paint(o.fill, o.opacity) : [];
    const r = await call('create_frame', { parentId: p, name: n, x, y, width: w, height: h, fills: fillArr, cornerRadius: o.radius || 0, strokes: o.stroke ? [{ type: 'SOLID', color: hx(o.stroke) }] : [], strokeWeight: o.stroke ? (o.sw || 1) : 0, clipsContent: o.clip !== false });
    if (!r.nodeId) return null;
    if (o.fill) { const vid = bindId(o.fill); if (vid) { await call('bind_variable_to_paint', { nodeId: r.nodeId, target: 'fills', index: 0, variableId: vid }); if (o.opacity !== undefined && o.opacity < 1) await call('set_fills', { nodeId: r.nodeId, fills: paint(o.fill, o.opacity) }); } }
    if (o.stroke) { const vid = bindId(o.stroke); if (vid) await call('bind_variable_to_paint', { nodeId: r.nodeId, target: 'strokes', index: 0, variableId: vid }); }
    if (o.shadow) await call('set_effects', { nodeId: r.nodeId, effects: [{ type: 'DROP_SHADOW', color: { r: 0.11, g: 0.1, b: 0.09, a: 0.08 }, offset: { x: 0, y: 6 }, radius: 18, spread: 0, visible: true, blendMode: 'NORMAL' }] });
    return r.nodeId;
  };
  api.RC = async (p, n, x, y, w, h, c, radius = 0, opacity) => {
    const r = await call('create_rectangle', { parentId: p, name: n, x, y, width: w, height: h, cornerRadius: radius, fills: c ? paint(c, opacity) : [] });
    if (r.nodeId && c) { const vid = bindId(c); if (vid) { await call('bind_variable_to_paint', { nodeId: r.nodeId, target: 'fills', index: 0, variableId: vid }); if (opacity !== undefined && opacity < 1) await call('set_fills', { nodeId: r.nodeId, fills: paint(c, opacity) }); } }
    return r.nodeId;
  };
  api.CIRC = async (p, n, x, y, d, c) => {
    const r = await call('create_ellipse', { parentId: p, name: n, x, y, width: d, height: d, fills: c ? paint(c) : [] });
    if (r.nodeId && c) { const vid = bindId(c); if (vid) await call('bind_variable_to_paint', { nodeId: r.nodeId, target: 'fills', index: 0, variableId: vid }); }
    return r.nodeId;
  };
  api.TX = async (p, txt, x, y, size, c, weight = 'r', o = {}) => {
    const font = weight === 'm' ? F.m : weight === 'b' ? F.b : F.r;
    const r = await call('create_text', { characters: txt, parentId: p, x, y, fontName: font, fontSize: size, fills: paint(c || HEX.textPrimary), textAutoResize: 'WIDTH_AND_HEIGHT', lineHeight: o.lh ? { unit: 'PIXELS', value: o.lh } : undefined, textAlignHorizontal: o.align || 'LEFT' });
    if (!r.nodeId) return null;
    if (c) { const vid = bindId(c); if (vid) await call('bind_variable_to_paint', { nodeId: r.nodeId, target: 'fills', index: 0, variableId: vid }); }
    if (o.w) { await call('resize_nodes', { nodeIds: [r.nodeId], width: o.w, height: Math.max(size * 1.4, 18) }); }
    return r.nodeId;
  };
  api.TB = async (p, txt, x, y, w, size, c, weight = 'r', lh) => {
    const font = weight === 'm' ? F.m : weight === 'b' ? F.b : F.r;
    const r = await call('create_text', { characters: txt, parentId: p, x, y, fontName: font, fontSize: size, fills: paint(c || HEX.textPrimary), textAutoResize: 'HEIGHT', lineHeight: lh ? { unit: 'PIXELS', value: lh } : { unit: 'PIXELS', value: Math.round(size * 1.5) } });
    if (!r.nodeId) return null;
    if (c) { const vid = bindId(c); if (vid) await call('bind_variable_to_paint', { nodeId: r.nodeId, target: 'fills', index: 0, variableId: vid }); }
    await call('resize_nodes', { nodeIds: [r.nodeId], width: w, height: 20 });
    return r.nodeId;
  };
  api.ICON = async (p, key, x, y, size, c) => {
    const svg = ICONS[key].replace(/\{c\}/g, c || HEX.textSecondary).replace('width="24" height="24"', 'width="' + size + '" height="' + size + '"');
    const r = await call('import_svg', { svg, name: 'ic-' + key, parentId: p, x, y, width: size, height: size });
    return r.nodeId;
  };
  api.INST = async (p, cid, x, y, name) => { const r = await call('create_instance', { componentId: cid, parentId: p, x, y, name }); return r.nodeId; };
  api.status = async (p) => {
    await api.TX(p, '9:41', 28, 16, 15, HEX.textPrimary, 'm');
    for (const [i, hh] of [[0, 3], [1, 9], [2, 5], [3, 12]]) await api.RC(p, 'bar' + i, 300 + i * 6, 32 - hh / 2, 3, hh, HEX.textPrimary, 1.5);
    const bat = await api.RC(p, 'bat', 352, 23, 22, 12, null, 3.5);
    await call('set_strokes', { nodeId: bat, strokes: [{ type: 'SOLID', color: hx(HEX.textPrimary) }], strokeWeight: 1.2 });
    await api.RC(p, 'batfill', 354, 25, 17, 8, HEX.textPrimary, 2);
    await api.RC(p, 'batnub', 375, 27, 2, 4, HEX.textTertiary, 1);
  };
  api.nav = async (p, title, o = {}) => {
    if (o.left !== 'none') await api.ICON(p, o.left || 'back', 16, 58, 24, HEX.textPrimary);
    if (title) await api.TX(p, title, 52, 60, 17, HEX.textPrimary, 'm');
    if (o.right) await api.TX(p, o.right, W - 20 - strlen(o.right) * 13, 61, 13, HEX.brand, 'm');
    if (o.more) await api.ICON(p, 'more', 350, 58, 24, HEX.textPrimary);
    await api.RC(p, 'navline', 0, 92, W, 0.5, HEX.border);
  };
  api.rowlabel = async (p, r, code, name) => {
    await api.TX(p, 'r' + r, 40, rowY(r) + 2, 11, HEX.brand, 'b');
    await api.TX(p, name, 40, rowY(r) + 18, 12, HEX.textPrimary, 'm');
    await api.TX(p, code, 40, rowY(r) + 36, 10, HEX.textTertiary);
  };
  return api;
}