# Validation — 2026-09-21

## Current map names

The variants have been renamed to `ot3_ffa_epic`, `ot3_ffa_epic_draft` and
`ot3_ffa_draft`. Earlier runtime markers below retain the names used when
those tests actually ran. The renamed packages were rebuilt with new internal
resource namespaces, and registration, shops, overview calibration, localization
keys and compiled UI were updated. Shop eligibility now uses the inherited
FFA map name. All Lua/UI regression checks and VPK resource/checksum validation
pass under the new names. The renamed packages have not been relaunched in Dota.

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

## Minimap correction

User screenshots exposed missing minimap terrain and incorrect camera projection
on Epic Only Single Draft. Both Single Draft variants lacked their map-named
`resource/overviews/*.txt` files; the first Epic Only copy already had one.
Added both files with the original FFA material, position and scale, and made
the map builder generate/verify overviews. The regression runner checks every
registered FFA variant's overview and the referenced compiled material.
Prior in-engine smoke checks did not visually inspect the minimap. The fix
requires a map reload; a running user game was not interrupted to test it.
# Hero swaps validation — 2026-09-23

- Automated regression suite passed, including request authentication, recipient
  consent, cross-team eligibility, all pre-match phases, expiration, cancellation,
  disconnects, changed heroes, competing requests, deferred execution, exact
  rarity refunds, and prevention of duplicate refunds on a second swap.
- Panorama tests passed for requesting, accepting, declining, cancelling, busy
  players, spectators, and match-start closure. All 23 script resources rebuilt
  with syntax, DATA, block bounds and CRC verification.
- Disposable local Dota Tools session: real hero entities swapped across teams;
  player teams, gold, items/slots and remaining rerolls stayed with their players.
  Hero facets and selected-hero references remained correct. A spent rare ability
  orb, epic auto-rune orb and rare stat-boost orb were refunded as 2/4/2 choices.
  Old upgrade counts and residual rune/stat buffs were cleared. Reassignment also
  passed with native hero availability restricted to each player's original hero.
- Actual client **Accept** button completed the authenticated swap. The panel was
  visually checked in strategy and preparation. Forcing match start closed the
  server's swap window and published `open = 0` to the UI.
- Runtime markers: `HERO_SWAPS_SMOKE_PASS`, `HERO_SWAPS_UI_PASS`, and
  `HERO_SWAPS_CLOSE_PASS`. Smoke scripts use a synthetic local second player and
  temporarily simulate its connected flag; they do not test online networking.
  Multiplayer testing was skipped as requested.

## Other / Items settings and category pages

- Full Node/Fengari regression suite passed, including new flag defaults,
  validation and locking, independent item toggles, 30/999 reroll allowances,
  unchanged rarity prices, coalesced assembly scans, and ward/detection duration.
- Compiled Panorama resources rebuilt and verified. UI tests check three pages,
  category visibility, preserved controls and the complete Apply payload.
- Local Dota Tools: all category pages visually inspected; the actual controls
  enabled the new options and Apply locked all four values on the server.
- `HOST_SETTINGS_ENGINE_PASS`: 999 rerolls; Observer lifetime about 1080 seconds;
  Sentry lifetime and detection about 1260 seconds (accounting for spawn delay).
- `HOST_ITEMS_ENGINE_PASS` in a fresh game: disabled Rapier/Dagon assemblies on
  heroes and couriers returned all components/recipes with combine locks and no
  gold change; enabled items assembled; Radiance still assembled with its shared
  Sacred Relic component. Shop inspected after removing the native whitelist;
  custom item entries are available again.
- Multiplayer testing remains skipped as requested.

## 2026-09-24: Longer Wards and Kill Goal duration

- Longer Wards now sets both ward lifetimes and Sentry detection to 3600 seconds
  from placement. The enabled option initializes Observer stock to four on each
  FFA team after native shop stock becomes available; it does not refill on respawn.
- Node/Fengari suite passed for option-off and other-map behavior, initialization
  readiness, one-time stock adjustment, both native ward durations and Sentry sight.
- Kill Goals 1, 15, 30, 45, 60 and 90 pass the formula
  `DEFAULT_MATCH_LENGTH * (kill_goal / 30)` with server/HUD agreement.
- Fresh local Tools match: all eight teams reported Observer stock four; Kill Goal
  60 published a 2400-second match limit. Placed Observer/Sentry lifetime and Sentry
  detection measured approximately 3600 seconds, accounting for spawn delay.

## 2026-09-24: waiting indicator and Invincible Wards

- Non-host settings footer: soft white waiting label; automated Panorama check verifies dot cycle `.`, `..`, `...`, `.`, host visibility and hiding after rules lock.
- Invincible Wards: default off, above Longer Wards on Other page; server validates and publishes the flag. Tests cover independent lifetime/protection toggles, other maps, unlocked rules and excluding combat summons.
- Native local engine: `invincible_wards_smoke.lua` placed Observer and Sentry wards with Longer Wards disabled. Both resisted a hero attack and 10,000 pure damage, then expired after shortening their native lifetime modifier. Output: `INVINCIBLE_WARDS_DAMAGE_PASS` and both `INVINCIBLE_WARDS_EXPIRY_PASS` markers.
- Host authorization regression uses two simulated players with first-loader privileges assigned to a different player from the listen-server owner; edits, forged sender IDs and start requests are checked.
- Actual multiplayer load-order testing remains unverified: no second player/client is available. These simulated-player checks are not a multiplayer test.

## 2026-09-24: All Vision and settings order

- Core order: Turbo, Single Draft, Epic-Only, Kill Goal. Other order: Infinite Rerolls, Longer Wards, Invincible Wards, All Vision.
- Invincible Wards now defaults on. All Vision defaults off and configures the native game-mode fog setting when the host applies rules.
- UI build and regression suite passed, including ordering, defaults, validation, lock enforcement and enabled/disabled fog calls.
- Native tools check `all_vision_smoke.lua` passed: all seven opposing FFA teams saw an enemy across the map, then could not see that enemy with `modifier_invisible`. Fog state was restored after the check. Output: `ALL_VISION_PASS distant enemy visible to all opposing teams; invisible enemy hidden`.

## 2026-09-24: free local premium and vanity

- Full regression suite passed, including free-collection checks for local tier 2, zero cost, inventory refresh, reusable consumables, preserving stored account data and preventing backend purchase/equipment/currency writes.
- Native engine: `FREE_COLLECTION_ACCESS_PASS 269 items; premium tier 2; no equipment backend timer` and `FREE_COLLECTION_EQUIP_PASS high_five_bronze`.
- Panorama collection source extracted with preserved container metadata and rebuilt. Purchase tabs/buttons removed, vanity action buttons use equip/use directly, local consumable actions enabled. No multiplayer test performed.

## 2026-09-24: Turbo Madstones and Shard availability

- Core order is Single Draft, Turbo, Epic-Only, Kill Goal.
- Turbo doubles kill Madstones and halves scheduled grant times; craft costs and native tier unlock times remain unchanged. User explicitly chose to preserve native crafting after investigating runtime tier timing.
- Turbo schedules one initial Shard stock addition for each FFA team at half its configured initial stock time (120 / 2 = 60 seconds). Non-Turbo uses the native 120-second unlock.
- `test_turbo_items.lua` covers all five grant times, normal mode unchanged, and the Shard timer/stock addition for all eight teams. Full regression suite and Panorama build passed.
- Native local test verified `IncreaseItemStock` changes Shard stock from 0 to 1 before its normal unlock on all eight FFA teams. No multiplayer test was performed.

## 2026-09-26: default-on options and Other page order

- Defaults changed: Single Draft, Turbo, All Vision, Infinite Rerolls, Divine Rapier
  and Dagon now start enabled in the Host Options menu, joining Longer Wards and
  Invincible Wards. Epic-Only is the only match flag still defaulting off. Defaults
  are declared in `DEFAULT_ON_FLAGS` in `scripts/vscripts/libraries/host_options.lua`.
- New Other page order: All Vision, Infinite Rerolls, Longer Wards, Invincible Wards.
- Verified 2026-09-26 after Node.js v24 was installed: `run_tests.js` (all Lua
  suites incl. host rules), `panorama_test.js`, and `panorama_resources.js
  build`/`verify` (27 scripts + shop-image alias) all pass with the new defaults
  and Other-page order.
- `custom_loading_screen.vjs_c` was first hand-patched in place, then regenerated
  by the official builder; the builder output is byte-identical to the hand patch.
- Non-English localization removed (`resource/addon_russian.txt`, `addon_schinese.txt`);
  only `addon_english.txt` remains. Full offline suite re-run and passing afterward.

## 2026-09-26: Backpack Items

- New Core option **Backpack Items** (below Epic-Only, default off). Engine probes
  in a tools match established the approach: `item:OnEquip()` activates a backpack
  item's native modifiers in place (idempotent, survives swaps, death and respawn,
  cleaned up on removal or drop); the engine rejects backpack casts, while
  `OnSpellStart` plus `UseResources` works for no-target, point, unit-target and
  charge-consuming items, and still respects enemy Linken's Spheres. Toggle
  (Armlet) and channelled items do not work this way and are refused.
- Offline: full `run_tests.js` passes, including the new `test_backpack_items.lua`;
  `panorama_test.js` and `panorama_resources.js build`/`verify` pass.
- Native tools check `backpack_items_smoke.lua`: 19/19 on a freshly launched client,
  covering swap/cooldown rules, unique backpack equip, BKB passive and active from
  the backpack, main-slot/backpack interplay, inert Linken's Sphere and Aeon Disk,
  and a Scythe of Vyse cast from 1400 units (walks in, hexes, starts cooldown).
- Client: a temporary HUD hook fired `Activated` on the native backpack
  `AbilityButton`s: BKB in slot 6 cast from the backpack, and Blink in slot 7 opened
  native targeting. Screenshot check: the settings page fits five Core rows without
  scrolling, and Kill Goal stays right-aligned.
- Not yet checked: physical mouse clicks and drag-and-drop on backpack slots, the
  6-second swap delay in a real match (the delay is not observable through the
  item API), and multiplayer.

## 2026-09-26: Backpack Items without lapses when switching

- Reported: switching items quickly between main slots and the backpack briefly
  dropped their stats and passives. A probe showed `SwapItems` across the boundary
  unequips both items, and the engine re-equips the main slot one only later; the
  reconcile loop then restored backpack items up to 0.1s late.
- Fix: the order filter now performs main/backpack moves itself and re-equips both
  items in the same server step; the reconcile loop runs every server tick for
  other inventory changes. Health and mana keep their percentages (verified at
  full health: 1638 → 758 → 1638 within one step, nothing lost).
- `test_backpack_items.lua` gained a mock matching the engine's unequip behaviour;
  the new move tests fail without the fix and pass with it. Full `run_tests.js`
  passes.
- Native tools check `backpack_items_smoke.lua`: 23/23. A per-tick watcher sampled
  11 server ticks while Heart and Butterfly switched 10 times between main slots
  and the backpack, displacing Ogre Axe and Blade of Alacrity: 0 ticks with a
  missing effect or reduced strength, agility or max health.

## 2026-09-26: Backpack Items swap cooldown for Linken's Sphere / Aeon Disk

- Swapping Linken's Sphere or Aeon Disk between main slots and the backpack, in
  either direction, puts both swapped items on a 6 second cooldown (only the moved
  item when the target slot is empty); longer running cooldowns are kept. Ordinary
  swaps, moves within one area and a disabled option are unaffected.
- `test_backpack_items.lua` covers both items, both directions, empty slots,
  longer cooldowns, ordinary swaps and native moves. Full `run_tests.js` passes.
- Native tools check `backpack_items_smoke.lua`: all checks pass. After real move
  orders, Linken's Sphere, Aeon Disk and both swapped partners had 5–6 s of
  cooldown; an enemy hex was not blocked by the freshly swapped Linken's Sphere,
  and was blocked once the sphere's cooldown was reset (control).

## 2026-09-26: Backpack Items simulated multiplayer, native backpack casts

Player 0 (Sven) plus three bot players (`GameRules:AddBotPlayerWithEntityScript`:
Lina, Axe, Arc Warden) on separate FFA teams, in a local tools session. Script:
`backpack_items_multiplayer_smoke.lua` (`backpack_items_multiplayer_off_smoke.lua`
for the option off).

Bugs found:
- Backpack casts were refused under fountain protection and Puck's Phase Shift,
  while native item casts work there and end the state.
- Backpack casts did not break Shadow Blade invisibility or trigger other cast
  events, because the spell effect ran without a native cast.
- A queued out-of-range backpack cast survived a hero swap.
- `MoveItem` treated swaps the engine refuses (Rapier/Gem into the backpack) as
  done, so a Linken's Sphere swapped against a Gem was put on cooldown. Refused
  swaps are now left to the engine.

Redesign: active backpack items get `SetCanBeUsedOutOfInventory(true)` and the
engine casts them natively (validation, range approach, turning, cast events). The
custom cast pipeline was removed, which fixes the first three bugs. Probes before
the change: native casts from the backpack worked for no-target, unit-target,
point-target and channelled items (Meteor Hammer), broke invisibility and walked
into range; items without the flag, illusions and stash items could not be cast;
Armlet toggled in the backpack without its Unholy Strength effect (so toggles stay
refused); shift-queued backpack casts are dropped by the engine (main slot ones
work).

Results: `run_tests.js` passes. Multiplayer smoke: 64 checks, 0 failures —
per-hero uniqueness, casts between players, same-tick mutual hex, Linken's /
Aeon across players, casts dropped by target invisibility or a third-party kill,
refused Rapier/Gem swaps, hero swap with equipped backpack items (no leftover
effects, uniqueness recomputed), fountain protection, invisibility break, Lotus
Orb reflection, Blink/Clarity/Dagon with all main slots full (0 lapses), Meteor
Hammer channel, Armlet refusal, flag cleared in the stash, Manta illusions unable
to cast, Tempest Double casts. `backpack_items_smoke.lua`: 28 checks, 0 failures.

Option off (`backpack_items_multiplayer_off_smoke.lua`): 15 checks, 0 failures — no
player's backpack items work or can be cast, no cooldown is spent, and the native
backpack swap delay stays.

Real client orders (a temporary Panorama hook, removed afterwards; the rebuilt HUD
script is byte-identical to before): 18 checks, 0 failures. Player 0's client cast
reaches the order filter with issuer 0 and the backpack hex lands; an inactive copy
is refused with the error sent to player 0; orders naming the bot's hero or item
cannot cast or move the bot's backpack items (the engine substitutes the player's
own hero, which does not hold the item); a dispatched click on the own backpack
slot casts BKB; 40 rapid client moves arrived with 0 lapses in 74 ticks. Limits of
the local session: `net_fakelag 150` does not delay the host's own loopback client
(33 ms round trip either way), and `GameUI.SelectUnit` cannot select an enemy hero,
so a click while viewing an enemy portrait was not exercised (the click handler
requires a controllable portrait unit). Physical mouse clicks and real remote
clients remain manual checks.
