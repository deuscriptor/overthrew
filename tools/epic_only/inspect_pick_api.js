const fs = require('node:fs');
const text = fs.readFileSync('C:/Program Files (x86)/Steam/steamapps/common/dota 2 beta/game/dota/bin/win64/server.dll').toString('latin1');
const strings = text.match(/[\x20-\x7e]{6,}/g);
console.log(strings.filter(s => /^(Set|Get|Add|Is|Enable|Allow).*?(Hero.*(Pick|Select|Avail)|SingleDraft|Drafting|CustomGame.*(Hero|Pick))/.test(s)).join('\n'));
console.log(strings.filter(s => /hero_picker|single_draft|SingleDraft/.test(s)).join('\n'));
