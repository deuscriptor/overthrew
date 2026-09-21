// Regenerate the variant's item definitions and shop from the original FFA files.
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8');
const write = (name, value) => fs.writeFileSync(path.join(root, name), value);
const items = read('scripts/npc/items/orbs.txt');
const blocks = ['common', 'rare', 'epic'].map(rarity => {
  const original = `item_${rarity}_orb_ffa`;
  const match = items.match(new RegExp(`"${original}"\\s*\\{[^}]*\\}`));
  if (!match) throw new Error(`Missing ${original}`);
  return '\t' + match[0].replace(original, `${original}_epic_only`)
    .replace(/"AbilityTextureName"\s+"[^"]+"/, '"AbilityTextureName"\t\t\t"orb_epic"')
    .replace(/"Effect"\s+"[^"]+"/, '"Effect"\t\t\t\t\t\t"particles/purple_item.vpcf"');
});
write('scripts/npc/items/orbs_epic_only.txt', '"DOTAAbilities"\r\n{\r\n' + blocks.join('\r\n\r\n') + '\r\n}\r\n');
const shop = read('scripts/shops/ot3_necropolis_ffa_shops.txt')
  .replace(/item_(common|rare|epic)_orb_ffa/g, '$&_epic_only');
for (const map of ['ot3_ffa_epic', 'ot3_ffa_epic_draft'])
  write(`scripts/shops/${map}_shops.txt`, shop);
write('scripts/shops/ot3_ffa_draft_shops.txt', read('scripts/shops/ot3_necropolis_ffa_shops.txt'));
console.log('Generated epic-only items and shop; retained original FFA prices.');
