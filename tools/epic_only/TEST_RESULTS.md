# Validation — 2026-09-21

Passed automated checks:

- Eleven regression cases execute production Lua with mocked Dota services: map
  inheritance, original-map behavior, FFA upgrade overrides, physical captures,
  direct rewards, source-specific lucky trinkets, time/kill counters, shop
  filtering/accounting, gifts, and reroll spending/exhaustion. Epic Only permits
  all 30 rerolls at one each; ordinary maps retain costs of 1/2/4. Pending
  selection messages also carry the correct map-specific price.
- Actual shop definitions retain the source prices and rules, with epic artwork.
- All 23 rebuilt Panorama scripts pass syntax, block bounds, CRC and unchanged
  non-DATA checks. Mocked panel tests cover independent time/kill counters,
  effective reward presentation and original-map behavior. Reroll panel tests
  exercise server-supplied pricing, balances 0/1/2/3/4/30, duplicate clicks,
  and the Epic Only tooltip.
- The repaired VPK passes resource CRC32 and package/chunk MD5 verification.
  Its original resource payloads are unchanged; four new-name metadata entries
  register the copied map namespace. Valve `resourceinfo` reads the repaired
  map root and manifest, including the new world resource ID.

Passed in Dota Tools mode (before the reroll pricing adjustment; that adjustment
was checked with the automated Lua and Panorama tests above):

- Original `ot3_necropolis_ffa` loaded and initialized. Three physical spawn
  requests produced common, rare and epic particles/modifiers respectively.
- `ot3_necropolis_ffa_epic_only` loaded with the correct map identity, world
  entities and physics. Server and client addon initialization completed.
- Eight FFA teams and paired drops were confirmed. All three requested source
  rarities produced epic particles and capture modifiers, retaining source data.
- With Pugna initialized, three reward requests passed through the real upgrade
  selection code and all queued epic rewards.

Runtime markers:

```text
EPIC_ONLY_SMOKE PASS map=ot3_necropolis_ffa paired_drops=true sources=3
EPIC_ONLY_SMOKE PASS map=ot3_necropolis_ffa_epic_only paired_drops=true sources=3
EPIC_ONLY_REWARDS PASS map=ot3_necropolis_ffa_epic_only hero=npc_dota_hero_pugna
```

The original addon also logs existing localization/asset warnings and a
`B_LOCAL_LOBBY` reference error from the unchanged loadout-promo collection
configuration. These occur on the original map as well. No errors in the new
map-family or orb-progress code were observed. This was a local smoke test,
not a full eight-player balance or visual review.

## Epic Only Single Draft

Automated checks additionally execute the production Single Draft module with
eight player slots and a spectator. They verify one enabled hero per attribute,
32 distinct offers, stable offers on reconnect, engine availability registration,
zero bans, both custom random routes, locked picks, spectators, and the end of
the pick phase. The copy inherits FFA rules, epic rewards and 1-point rerolls;
its shop definition is identical to Epic Only's. Panorama identity tests include
both variants. The new VPK passes the same 157-original/157-alias resource and
package checksum checks.

In Dota Tools mode, the new map loaded and reached gameplay. The native picker
rejected unoffered Axe and accepted offered Crystal Maiden. Four offers matched
the installed game's four attributes. The physical-orb and real upgrade-selection
smoke checks passed with Crystal Maiden. In a second draft, the smart-random
server path selected offered Morphling and advanced to strategy time.

```text
SINGLE_DRAFT_SMOKE PASS players=1 state=4
SINGLE_DRAFT_RANDOM PASS hero=npc_dota_hero_morphling
EPIC_ONLY_SMOKE PASS map=ot3_necropolis_ffa_epic_only_single_draft paired_drops=true sources=3
EPIC_ONLY_REWARDS PASS map=ot3_necropolis_ffa_epic_only_single_draft hero=npc_dota_hero_crystal_maiden
```

The eight-player allocation was tested with mocks; the in-engine checks used
one local player. Existing addon asset/localization and loadout-promo warnings
remain as described above.

## Standard-orb Single Draft

Added `ot3_necropolis_ffa_single_draft` alongside both Epic Only variants.
The draft allocation suite now runs against both Single Draft maps. Standard
Single Draft also passes the production Lua checks for common/rare/epic
queue rewards and physical orb visuals, rejects Epic Only shop items, and
retains reroll prices 1/2/4. Its shop file matches the original FFA shop exactly.
Panorama checks confirm FFA layout inheritance with Single Draft enabled and
Epic Only disabled. All 23 compiled scripts and the new map's 157 original
entries plus 157 aliases pass resource/checksum validation.

In a local Dota Tools session on 2026-09-21, this map loaded, skipped banning,
and offered Largo, Spectre, Shadow Demon and Sand King: one hero per current
attribute. The native picker rejected unoffered Axe. The random-pick path
selected offered Largo, and the map reached gameplay.

Physical requests produced common, rare and epic particles/modifiers. Real
upgrade queues retained all three rarities. Creating the three normal shop
items and adding them to the hero exercised the inventory filter: their
rewards retained the corresponding rarity and prices were 2000/4000/8000.
Real upgrade rerolls consumed 1/2/4 points from the fresh 30-point allowance,
with synchronized balances 29/27/23 and new selections of the same rarity.

```text
SINGLE_DRAFT_RANDOM PASS hero=npc_dota_hero_largo
SINGLE_DRAFT_SMOKE PASS players=1 state=10
EPIC_ONLY_SMOKE PASS map=ot3_necropolis_ffa_single_draft paired_drops=true sources=3
EPIC_ONLY_REWARDS PASS map=ot3_necropolis_ffa_single_draft hero=npc_dota_hero_largo
STANDARD_SD_ITEM PASS rarity=1 price=2000
STANDARD_SD_ITEM PASS rarity=2 price=4000
STANDARD_SD_ITEM PASS rarity=4 price=8000
STANDARD_SD_REROLL PASS rarity=1 remaining=29
STANDARD_SD_REROLL PASS rarity=2 remaining=27
STANDARD_SD_REROLL PASS rarity=4 remaining=23
STANDARD_SD_SMOKE PASS map=ot3_necropolis_ffa_single_draft items=normal rerolls=1/2/4
```

This was a one-player local smoke test, not an eight-player playtest. Existing
addon asset/localization warnings remain. A test-harness shop-enumeration
assertion was corrected because Lua LoadKeyValues loses repeated shop `item`
keys; the final check exercises actual items and inventory filtering instead.
