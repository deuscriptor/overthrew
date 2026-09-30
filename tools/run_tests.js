// Run with Node from any directory. Install the pinned optional Lua runner with:
// npm ci --prefix tools/runtime --ignore-scripts --no-audit --no-fund
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8');
const registeredMaps = [...read('addoninfo.txt').match(/maps\s*=\s*\[([^\]]*)\]/)[1].matchAll(/"([^"]+)"/g)].map(match => match[1]);
assert.deepEqual(registeredMaps, ['ot3_necropolis_ffa'], 'Only the configurable FFA map is registered');
const list = (dir, suffix) => fs.readdirSync(path.join(root, dir)).filter(name => name.endsWith(suffix)).map(name => name.slice(0, name.length - suffix.length));
const mapFiles = [...list('maps', '.vpk'), ...list('resource/overviews', '.txt'), ...list('scripts/shops', '_shops.txt'), ...list('scripts/upgrades/overrides', '')];
assert.deepEqual([...new Set(mapFiles)], registeredMaps, 'Map packages, overviews, shops and upgrade overrides exist only for registered maps');
const overviewMaterial = read('resource/overviews/ot3_necropolis_ffa.txt').match(/material\s+(\S+)/)[1];
assert.ok(fs.existsSync(path.join(root, overviewMaterial + '_c')), 'Minimap material exists');
console.log('PASS only ot3_necropolis_ffa is registered and shipped, with its minimap material');
const localizationKeys = language => new Set([...read(`resource/addon_${language}.txt`).matchAll(/^\s*"([^"]+)"[ \t]*"/gm)].map(match => match[1]));
const englishKeys = localizationKeys('english');
for (const language of ['russian', 'ukrainian']) {
  const keys = localizationKeys(language);
  assert.deepEqual([...englishKeys].filter(key => !keys.has(key)), [], `English tokens missing from addon_${language}.txt`);
  assert.deepEqual([...keys].filter(key => !englishKeys.has(key)), [], `${language} tokens missing from addon_english.txt`);
}
console.log(`PASS addon_english.txt, addon_russian.txt and addon_ukrainian.txt define the same ${englishKeys.size} tokens`);
const orbs = read('scripts/npc/items/orbs.txt');
const shop = read('scripts/shops/ot3_necropolis_ffa_shops.txt');
const orbNames = [...orbs.matchAll(/^\t"(item_[^"]+)"/gm)].map(match => match[1]);
assert.deepEqual(orbNames, ['item_common_orb_ffa', 'item_rare_orb_ffa', 'item_epic_orb_ffa'], 'Only FFA orbs are defined');
for (const [rarity, price] of [['common', 2000], ['rare', 4000], ['epic', 8000]]) {
  const name = `item_${rarity}_orb_ffa`;
  assert.equal(Number(orbs.match(new RegExp(`"${name}"\\s*\\{[^}]*"ItemCost"\\s*"(\\d+)"`))[1]), price, `${rarity} price`);
  assert.ok(shop.includes(`"${name}"`), `${rarity} orb in the FFA shop`);
}
console.log('PASS the FFA shop sells the three FFA orbs at their original prices');

const result = spawnSync(process.execPath, [
  path.join(__dirname, 'runtime/node_modules/fengari-node-cli/src/lua-cli.js'),
  'tools/test_host_rules.lua',
], { cwd: root, encoding: 'utf8' });
if (result.stdout) process.stdout.write(result.stdout);
if (result.stderr) process.stderr.write(result.stderr);
assert.equal(result.error, undefined, 'Lua process startup');
assert.equal(result.status, 0, 'Lua process exit');
// Fengari versions can print a Lua error without setting a nonzero process exit.
assert.match(result.stdout || '', /\d+ orb regression cases passed/);
assert.match(result.stdout || '', /PASS host rules:.*one-time start\s*$/);
assert.equal((result.stderr || '').trim(), '', 'Lua stderr');
require('./panorama_test');
const swaps = spawnSync(process.execPath, [
  path.join(__dirname, 'runtime/node_modules/fengari-node-cli/src/lua-cli.js'),
  'tools/test_hero_swaps.lua',
], { cwd: root, encoding: 'utf8' });
if (swaps.stdout) process.stdout.write(swaps.stdout);
if (swaps.stderr) process.stderr.write(swaps.stderr);
assert.equal(swaps.error, undefined);
assert.equal(swaps.status, 0);
assert.equal((swaps.stderr || '').trim(), '');
assert.match(swaps.stdout, /PASS hero swaps:/);
const hostSettings = spawnSync(process.execPath, [
  path.join(__dirname, 'runtime/node_modules/fengari-node-cli/src/lua-cli.js'),
  'tools/test_host_settings.lua',
], { cwd: root, encoding: 'utf8' });
if (hostSettings.stdout) process.stdout.write(hostSettings.stdout);
if (hostSettings.stderr) process.stderr.write(hostSettings.stderr);
assert.equal(hostSettings.error, undefined);
assert.equal(hostSettings.status, 0);
assert.equal((hostSettings.stderr || '').trim(), '');
assert.match(hostSettings.stdout, /PASS host settings:/);
const freeCollection = spawnSync(process.execPath, [
  path.join(__dirname, 'runtime/node_modules/fengari-node-cli/src/lua-cli.js'),
  'tools/test_free_collection.lua',
], { cwd: root, encoding: 'utf8' });
if (freeCollection.stdout) process.stdout.write(freeCollection.stdout);
if (freeCollection.stderr) process.stderr.write(freeCollection.stderr);
assert.equal(freeCollection.error, undefined);
assert.equal(freeCollection.status, 0);
assert.equal((freeCollection.stderr || '').trim(), '');
assert.match(freeCollection.stdout, /PASS free collection:/);
const turboItems = spawnSync(process.execPath, [
  path.join(__dirname, 'runtime/node_modules/fengari-node-cli/src/lua-cli.js'),
  'tools/test_turbo_items.lua',
], { cwd: root, encoding: 'utf8' });
if (turboItems.stdout) process.stdout.write(turboItems.stdout);
if (turboItems.stderr) process.stderr.write(turboItems.stderr);
assert.equal(turboItems.error, undefined);
assert.equal(turboItems.status, 0);
assert.equal((turboItems.stderr || '').trim(), '');
assert.match(turboItems.stdout, /PASS Turbo items:/);
const backpackItems = spawnSync(process.execPath, [
  path.join(__dirname, 'runtime/node_modules/fengari-node-cli/src/lua-cli.js'),
  'tools/test_backpack_items.lua',
], { cwd: root, encoding: 'utf8' });
if (backpackItems.stdout) process.stdout.write(backpackItems.stdout);
if (backpackItems.stderr) process.stderr.write(backpackItems.stderr);
assert.equal(backpackItems.error, undefined);
assert.equal(backpackItems.status, 0);
assert.equal((backpackItems.stderr || '').trim(), '');
assert.match(backpackItems.stdout, /PASS backpack items:/);
const illusionPerformance = spawnSync(process.execPath, [
  path.join(__dirname, 'runtime/node_modules/fengari-node-cli/src/lua-cli.js'),
  'tools/test_illusion_performance.lua',
], { cwd: root, encoding: 'utf8' });
if (illusionPerformance.stdout) process.stdout.write(illusionPerformance.stdout);
if (illusionPerformance.stderr) process.stderr.write(illusionPerformance.stderr);
assert.equal(illusionPerformance.error, undefined);
assert.equal(illusionPerformance.status, 0);
assert.equal((illusionPerformance.stderr || '').trim(), '');
assert.match(illusionPerformance.stdout, /PASS illusion performance:/);
const tips = spawnSync(process.execPath, [
  path.join(__dirname, 'runtime/node_modules/fengari-node-cli/src/lua-cli.js'),
  'tools/test_tips.lua',
], { cwd: root, encoding: 'utf8' });
if (tips.stdout) process.stdout.write(tips.stdout);
if (tips.stderr) process.stderr.write(tips.stderr);
assert.equal(tips.error, undefined);
assert.equal(tips.status, 0);
assert.equal((tips.stderr || '').trim(), '');
assert.match(tips.stdout, /PASS tips:/);
const earlyConsumables = spawnSync(process.execPath, [
  path.join(__dirname, 'runtime/node_modules/fengari-node-cli/src/lua-cli.js'),
  'tools/test_early_consumables.lua',
], { cwd: root, encoding: 'utf8' });
if (earlyConsumables.stdout) process.stdout.write(earlyConsumables.stdout);
if (earlyConsumables.stderr) process.stderr.write(earlyConsumables.stderr);
assert.equal(earlyConsumables.error, undefined);
assert.equal(earlyConsumables.status, 0);
assert.equal((earlyConsumables.stderr || '').trim(), '');
assert.match(earlyConsumables.stdout, /PASS early consumables:/);
const fountainSmoke = spawnSync(process.execPath, [
  path.join(__dirname, 'runtime/node_modules/fengari-node-cli/src/lua-cli.js'),
  'tools/test_fountain_smoke.lua',
], { cwd: root, encoding: 'utf8' });
if (fountainSmoke.stdout) process.stdout.write(fountainSmoke.stdout);
if (fountainSmoke.stderr) process.stderr.write(fountainSmoke.stderr);
assert.equal(fountainSmoke.error, undefined);
assert.equal(fountainSmoke.status, 0);
assert.equal((fountainSmoke.stderr || '').trim(), '');
assert.match(fountainSmoke.stdout, /PASS fountain smoke:/);
const fountainProtection = spawnSync(process.execPath, [
  path.join(__dirname, 'runtime/node_modules/fengari-node-cli/src/lua-cli.js'),
  'tools/test_fountain_protection.lua',
], { cwd: root, encoding: 'utf8' });
if (fountainProtection.stdout) process.stdout.write(fountainProtection.stdout);
if (fountainProtection.stderr) process.stderr.write(fountainProtection.stderr);
assert.equal(fountainProtection.error, undefined);
assert.equal(fountainProtection.status, 0);
assert.equal((fountainProtection.stderr || '').trim(), '');
assert.match(fountainProtection.stdout, /PASS fountain protection:/);
