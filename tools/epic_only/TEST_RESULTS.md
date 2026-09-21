# Validation — 2026-09-21

Passed automated checks:

- Eleven regression cases execute production Lua with mocked Dota services: map
  inheritance, original-map behavior, FFA upgrade overrides, physical captures,
  direct rewards, source-specific lucky trinkets, time/kill counters, shop
  filtering/accounting, gifts, and reroll spending/exhaustion. Epic Only permits
  all 30 rerolls at one each; ordinary maps retain costs of 1/2/4. Pending
  selection messages also carry the correct map-specific price.
- Actual shop definitions retain the source prices and rules, with epic artwork.
- All 21 rebuilt Panorama scripts pass syntax, block bounds, CRC and unchanged
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
