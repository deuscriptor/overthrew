// Run with Node from any directory. Install the pinned optional Lua runner with:
// npm ci --prefix tools/epic_only/runtime --ignore-scripts --no-audit --no-fund
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '../..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8');
const baseOverview = read('resource/overviews/ot3_necropolis_ffa.txt');
const registeredMaps = [...read('addoninfo.txt').matchAll(/"(ot3_ffa_[^"]+)"/g)].map(match => match[1]);
assert.equal(new Set(registeredMaps).size, 3, 'All three renamed variants registered');
for (const map of new Set(registeredMaps)) {
  assert.equal(read(`resource/overviews/${map}.txt`), map + baseOverview.slice('ot3_necropolis_ffa'.length), `${map} minimap terrain and projection`);
}
const overviewMaterial = baseOverview.match(/material\s+(\S+)/)[1];
assert.ok(fs.existsSync(path.join(root, overviewMaterial + '_c')), 'Minimap material exists');
console.log('PASS all registered FFA variants include the original minimap material and coordinate calibration');
const original = read('scripts/npc/items/orbs.txt');
const variant = read('scripts/npc/items/orbs_epic_only.txt');
const shop = read('scripts/shops/ot3_ffa_epic_shops.txt');
assert.equal(read('scripts/shops/ot3_ffa_epic_draft_shops.txt'), shop);
assert.equal(read('scripts/shops/ot3_ffa_draft_shops.txt'), read('scripts/shops/ot3_necropolis_ffa_shops.txt'));

for (const [rarity, price] of [['common', 2000], ['rare', 4000], ['epic', 8000]]) {
  const name = `item_${rarity}_orb_ffa`;
  const block = (text, item) => {
    const match = text.match(new RegExp(`"${item}"\\s*\\{([^}]*)\\}`));
    assert.ok(match, `Missing ${item}`);
    return Object.fromEntries([...match[1].matchAll(/"([^"]+)"\s*"([^"]*)"/g)].map(m => [m[1], m[2]]));
  };
  const base = block(original, name);
  const copy = block(variant, name + '_epic_only');
  assert.equal(Number(copy.ItemCost), price, `${rarity} price`);
  assert.deepEqual(copy, { ...base, AbilityTextureName: 'orb_epic', Effect: 'particles/purple_item.vpcf' });
  assert.ok(shop.includes(`"${name}_epic_only"`), `${rarity} item in variant shop`);
}
assert.match(read('scripts/npc/npc_items_custom.txt'), /#base\s+"items\/orbs_epic_only\.txt"/);
console.log('PASS actual shop definitions retain prices/rules and use epic visuals');

const result = spawnSync(process.execPath, [
  path.join(__dirname, 'runtime/node_modules/fengari-node-cli/src/lua-cli.js'),
  'tools/epic_only/test_orbs.lua',
], { cwd: root, encoding: 'utf8' });
if (result.stdout) process.stdout.write(result.stdout);
if (result.stderr) process.stderr.write(result.stderr);
assert.equal(result.error, undefined, 'Lua process startup');
assert.equal(result.status, 0, 'Lua process exit');
// Fengari versions can print a Lua error without setting a nonzero process exit.
assert.match(result.stdout || '', /\d+ orb regression cases passed\s*$/);
assert.equal((result.stderr || '').trim(), '', 'Lua stderr');
