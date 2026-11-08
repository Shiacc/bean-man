// t_reaction.mjs — 单点验证 set_reactions 是否持久化
import { boot } from './figma_lib.mjs';

const { call, finish } = await boot();
await call('navigate_to_page', { pageId: '52:5892' });

const res = await call('set_reactions', {
  nodeId: '84:6226',
  reactions: [
    {
      trigger: { type: 'ON_CLICK' },
      actions: [{ type: 'NODE', destinationId: '85:6299', navigation: 'NAVIGATE', transition: null }],
    },
  ],
});
console.log('set ->', JSON.stringify(res).slice(0, 400));

const node = await call('get_node', { nodeId: '84:6226' });
const s = JSON.stringify(node);
console.log('has reactions key:', s.includes('"reactions"'));
const m = s.match(/"reactions":\s*(\[[\s\S]{0,500})/);
console.log(m ? m[1] : '(none)');

await finish();