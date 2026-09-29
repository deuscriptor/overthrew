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

## 2026-09-26: Local Host owner claim

- Host selection on Local Host no longer uses connection order. The client VM sharing the server process reads the `overthrew_host_claim` convar token and returns it with the `overthrew_claim_host` console command, which the server attributes to the issuing player.
- `test_host_rules.lua`: wrong, unattributed and repeated guesses are rejected. The first-loader native host and the listen-server slot are ignored. The claim survives Init/script reload and a disconnected owner releases the host. The 30-second fallback uses native privileges, and a late owner claim replaces the fallback host. The client half sends nothing without a token or outside setup, and claims on the setup transition or when loaded during setup, without the server-only state constants.
- Engine findings (Tools, listen server): Panorama `Game.GetConvarInt` reads engine convars (`fps_max`, `sv_cheats`) but returns 0 for the Lua-registered convar, even in the host process, so a Panorama claim cannot work. The client Lua VM reads it. `Convars:GetCommandClient()` returns the issuing player's pawn (`:GetController()` gives the player). The client VM lacks `DOTA_GAMERULES_STATE_*` constants.
- Fresh map restart: `host_claim_smoke.lua` printed `HOST_CLAIM_PASS owner 0` with no fallback. The screenshot shows Apply & Start and the Add Bots host option for the owner.
- Real multi-client load order remains untested: no second client is available.

## 2026-09-29: Claim Host replaces automatic host selection

- Field report on the lobby-order build: sometimes every player saw "Waiting for the host" with nobody able to edit, and values edited before everyone had loaded reverted once all players were in.
- No automatic host on configurable FFA. The server publishes `match_rules.ready` once setup has begun and no human player is `NOT_YET_CONNECTED` (latched; after 120 seconds of setup, players still loading are skipped). The loading screen builds the settings only when `ready` or `locked` is set; the normal tips show until then. `HostOptions:claim_host` is accepted only when ready, unlocked, with no current host, from a connected human (sender-checked). The first claim wins. A host who disconnects or abandons before starting frees the role and does not get it back on return. Other maps keep native privileges.
- UI: a gold-lit **Claim host** card (diamond mark, gold uppercase title, detail line, tooltip) in Apply & Start's footprint. One request at a time, retried after 2 seconds if not granted. The waiting card now names the host (`{s:host_name} is choosing the match rules`). RU/UK waiting texts say "host" (official UK client: «Очікування хоста»). New tokens `host_rules_claim`, `_detail`, `_tip` in all three languages.
- `test_host_rules.lua`: closed before setup and while anyone loads; no automatic host; ready latches; forged and bot claims are rejected; the first claim wins; only the host edits; a leaving host frees the role and a returning one does not take it back or reset values; only the host applies; the host is fixed after lock; the 120-second cap opens claims; script reload clears the host; other maps use native privileges. `panorama_test.js`: hidden while `ready` is 0; claim card footprint, glow, hover and single request with retry; the claimer gets Apply & Start; the waiting card names the host; nothing after lock. Smokes that apply rules now claim host 0 first; `host_claim_smoke.lua` replaces `host_owner_smoke.lua`.
- Tools (fresh client): `all players loaded, host can be claimed`. Screenshot: read-only settings with the Claim Host card. A simulated click logged `player 0 claimed host` and showed Apply & Start (and the Add Bots host option). A clicked Epic-Only toggle was stored on the server (`epic_orbs true`, published 1). With player 1 published as host (visual check only), the card read "WAITING FOR THE HOST / Claim Bot is choosing the match rules". Fresh map: `HOST_CLAIM_PASS host 0`, `KGLOCK setup applied`.
- Follow-up: read-only viewers get greyed-out switches (track `saturation 0`, `opacity 0.5`; the host keeps full colour). `panorama_test.js` checks the host, waiting and new-host states. Tools capture with a staged host: waiting players' switches are grey, and after a real claim the same switches are green for the host.
- Not tested: several real clients claiming at once, and a real host leaving mid-setup. Bots stay `NOT_YET_CONNECTED` during setup, so they cannot hold the role.

## 2026-09-28: Local Host lobbies reporting a dedicated server

- Field report (published build of 2026-09-27, a friend's Local Host lobby): a non-owner who loaded first got settings access while others were still loading. Only the native path grants access during loading, and it ran only when `IsDedicatedServer()` was true. So real Local Host lobbies most likely report a dedicated server, unlike `dota_launch_custom_game` in Tools.
- Claim gating now checks for a game client in the server process (client.dll-only convar `dota_camera_distance`; absent from server/engine DLLs). Tools: the server VM sees it (`1200`) with `IsDedicatedServer()` false.
- The fallback countdown now starts once every player has loaded (no `NOT_YET_CONNECTED` player), with a 120-second cap from setup start.
- `test_host_rules.lua`: a server without a local client resolves native immediately. A Local Host lobby reporting dedicated takes the claim path. The fallback waits while a player is loading, fires 30 seconds after the last load, and caps at 120 seconds with a stuck loader.
- Tools map restart: `[Host Options] waiting for the Local Host owner's claim`, then `Local Host owner claimed host: player 0`. `host_claim_smoke.lua`: `HOST_CLAIM_PASS owner 0`.
- Not verified: a real Local Host lobby. Tools cannot create lobbies ("Cannot start matchmaking with -insecure, -dev or -tools"). Whether the lobby server shares the owner's process is untested; if it runs as a separate process, the claim cannot work and native privileges are used immediately (logged as `no game client in the server process`).

## 2026-09-28: settings pages reordered to Core, Items, Other

- `panorama_test.js` checks the tab order and that page 2 is Items, page 3 Other. Full offline suite and Panorama build/verify passed.
- Tools client: tabs read Core, Items, Other. Clicking Items opened Divine Rapier and Dagon.

## 2026-09-28: waiting-for-host status card

- Non-host footer is now a status card in Apply & Start's footprint (42px high, 12px margin): pulsing gold dots, **Waiting for the host** title and a detail line. The old three-line label pushed the Kill Goal row out of view. It also showed `rules....`, because the localized sentence ended with a period before the animated dots.
- Duplicate `host_rules_waiting` tokens removed in all three languages; new `host_rules_waiting_detail`.
- `panorama_test.js`: card height and margin match Apply & Start, two labels with no appended dots, dots light in turn, dots container padded so the lifted dot is not clipped. Full offline suite and Panorama build/verify passed.
- Tools client: a temporary script made nobody the host, as while the owner loads. Screenshots show the card centred under five visible rows and the lit dot round with its glow; before the padding, the lifted dot was clipped flat at the top.

## 2026-09-28 (night): live Local Host lobby findings, lobby order only

- Field report on build 125: a non-owner who loaded first still got host in a friend's Local Host lobby.
- Live solo test (normal client via `steam -applaunch 570 -condebug`, private Local Host lobby of published 125):
  - Only one `dota2.exe` ran. The server logged in-process: `ActivateServerFromLobby - IsLan: YES, IsDedicatedServer: NO`, `Connected to 'loopback:1'`.
  - 125 took the claim path, and the claim arrived at setup start: `Local Host owner claimed host: player 0`. The mechanism works live.
  - At match start the log tears off to `game/dota/console.<match_id>.log`. It begins with a CSODOTALobby dump that includes `leader_id` (the owner's SteamID64), `all_members[n]` with team/slot, `lan: true` and `lan_host_ping_location`. Then `CDOTA_PlayerResource: Initializing from lobby (main), player SteamID ... slot 1 preferred PlayerID 0`: player IDs come from lobby slots. No script API exposes `leader_id`.
- Conclusion: the claim is valid only for a client in the server process. So in the field report the non-owner's PC most likely ran the server: Dota does not always host on the lobby owner's PC. The claim therefore identifies the hosting machine, not the owner, and it overrode lobby order.
- Build 126: host is the lowest-ID human player (lobby order) only. The claim (convar, console command, client VM `libraries/host_claim.lua`, `host_claim_smoke.lua`) is removed. At setup the server logs each player's ID, account ID, name and connection, and each host change.
- `test_host_rules.lua`: the first loader (native privileges, listen-server slot) is ignored. The owner waits while loading, then is host. Bots are skipped. A disconnected owner passes host to the next member and gets it back on return. Edits and Apply are authorized for the owner only, with forged senders rejected. The 120-second cap unblocks a stuck owner, and script reload restores lobby order.
- To verify in a real multi-player lobby: with `-condebug` on the machine that runs the server, compare `CSODOTALobby.leader_id` and the `preferred PlayerID` lines with `[Host Options] host is player N`.
- Searched for a way to read the lobby owner, with none found. The Panorama `Game` API has no lobby/leader accessor, and no script method mentions a lobby leader. Custom UI is sandboxed: the HUD root is `DotaHud` and the loading screen root is `DotaLoadingScreen`. Neither reaches the dashboard's custom-lobby panel (no `LobbyLeader` class panels, no dashboard IDs). The setup log also records each player's native `PlayerHasCustomGameHostPrivileges` value (Tools: `native host true` for the single player), so one multi-player game can show whether native privileges follow `leader_id`.

## 2026-09-28 (later): lobby-order host and ID-carrying claim

- Field report on build 124 (`overthrew_clean_124`, published 00:25): in a friend's Local Host lobby, a non-owner who loaded first still got host. No server log was captured. Likely causes: the lobby server runs outside the owner's process, so the claim is skipped and native privileges apply; or the owner's console command was attributed to server slot 0, the first client to connect.
- Server Lua file writes (`InitLogFile`, `AppendToLogFile`) are deprecated stubs, so a cross-process file handshake is not possible.
- Native privileges removed. Fallback and no-client host is the lowest-ID human player (the lobby's first member; IDs are assigned from the lobby before loading). Nobody is host while that player is loading; disconnected, abandoned or failed players are skipped; after 120 seconds of setup, still-loading players are skipped.
- The claim now carries the claimant's player ID (client VM `GetLocalPlayerID()`); command attribution is ignored. The failure cap is 20 wrong tokens in total and only disables claims.
- `test_host_rules.lua`: native privileges (held by the first loader) are ignored. Lobby order waits for a loading owner, skips bots and disconnected or abandoned players, and ends the wait at the cap. The claim follows the named ID, not the command client, and rejects invalid, bot or unknown IDs. The client sends `<token> <id>` only once its ID is known.
- Tools map (fresh client): `waiting for the Local Host owner's claim`, `player 0 … connection 2`, `Local Host owner claimed host: player 0`. `host_claim_smoke.lua`: `HOST_CLAIM_PASS owner 0 lobby leader 0`.
- Unverified: that player ID 0 is the lobby creator in a real lobby (check that the owner appears first in the loading-screen player list), and which path a real Local Host lobby takes (the owner's `-condebug` log shows it).

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

## 2026-09-27: Russian localization restored

- `resource/addon_russian.txt` reinstated (byte-identical to its state before the
  2026-09-26 removal); `addon_schinese.txt` stays removed. Dota loads it by client
  language; no registration is needed.
- Brought up to date: added the 20 tokens introduced since (Backpack Items label,
  errors and tooltip, all `host_rules_*_tip` tooltips, `host_rules_time_limit`,
  `kill_voting_description_no_token`, four Local Host notices), translated the
  host-option labels that had been copied in English, and aligned Hero Swaps
  wording with the file's orb term («осколки»).
- `run_tests.js` now asserts `addon_english.txt` and `addon_russian.txt` define the
  same token set (3362 tokens). Full offline suite passes. Not checked in game
  with a Russian client.

## 2026-09-27: Ukrainian localization added

- New `resource/addon_ukrainian.txt`, generated in the same key order and layout
  as `addon_english.txt`. All 3,362 tokens are present; 245 values stay as in English
  (placeholders, map/mode/cosmetic/item titles kept English as in the official client).
- Style and terminology follow the official Dota 2 Ukrainian client, taken from the
  game's own `resource/localization/*_ukrainian.txt` (inside `game/dota/pak01_dir.vpk`).
  About 420 values reuse official text verbatim (same English source string, or the
  hero_demo sample addon's Ukrainian file); the rest were translated with official
  hero, ability, item and creep names.
- Validated with a script: every English placeholder, `%var%`, `{s:..}`, tag, `\n`
  and escape is kept; no unescaped quotes.
- `run_tests.js` parity check now covers English, Russian and Ukrainian (3362 tokens
  each). Full offline suite passes. Not checked in game with a Ukrainian client.

## 2026-09-27: Player tips

- Offline: `test_tips.lua` (new, in `run_tests.js`) runs the production `tips.lua`,
  `custom_chat.lua`, `toasts.lua` and `end_game_stats.lua`. It checks the toast/chat
  payloads, the tally, the 3-per-game cap (still enforced after the cooldown), the
  30 s cooldown per tipper, ignored self/invalid tips and that no HTTP requests are
  made. `panorama_test.js` adds scoreboard Tip-button blocking (cooldown; the cap
  survives the cooldown, which the previous client code got wrong) and the
  end-screen badge (only when tipped, before the MVP crown, localized tooltip).
  Panorama rebuild/verify: 28 scripts. Full offline suite passes (3364 tokens in
  each language).
- Dota Tools (`tips_smoke.lua`, player 0 plus Pudge/Techies bot players on separate
  FFA teams): all seven checks `ok`, including zero HTTP requests. Screenshots with
  a Ukrainian client showed the top-right toast (Techies → «дякує» → coin 5 →
  Sven) and the chat line «Tip Bot 2 дарує <name> 5 Слави!». The end screen showed
  the Glory badge with the correct counts (Pudge 2, Sven 5, Techies 1), after the
  hero name and left of the MVP crown.
- Not checked: clicking the scoreboard Tip button and hovering over the tooltip (no simulated mouse
  input), English/Russian clients, real multiplayer.

## 2026-09-27: Tip toast and chat line polish

- `toasts.js` is now editable in `panorama_sources`; the original container is backed up
  in `panorama_backups`. Tip toast: player-colour strips under the portraits, a plain-text
  name when there's no Steam ID, a gold frame and second chime for the tipped player,
  a coin pop, and at most three tip toasts on screen.
  Fixed an existing bug: each toast's expiry passed the newest toast id instead of its
  own.
- Chat line: 19 px Glory coin icon; names use the new `PLAYER_COLOR_READABLE`
  action.
- Offline: `panorama_test.js` adds tests for the readable chat colours and the tip
  toast, including the expiry-id fix. `test_tips.lua` checks the new colour action.
  29 Panorama scripts rebuilt and verified. The full suite passes.
- Not checked in the client: the user will check it in-game. Inline styles
  set from JS (`borderBottom`, `boxShadow`, the `preTransformScale2d`
  transition) and the chat `<img>` size still need a visual check.

## 2026-09-27: Compiled tip toast style, amount 50

- `toasts.css` was recovered from the compiled `toasts.vcss_c`, whose original is backed up.
  Recompiling it unchanged with `resourcecompiler.exe` gave byte-identical CSS. Using
  `file://{images}` URLs gives empty `s2r://` paths, so the sources keep `s2r://` URLs.
  The compiler accepted a bogus property; it does not validate property names.
- Restyle, tip rules only: compact dark gradient card with a gold top hairline, flush
  112×63 portraits, names underneath, 6 px stacking gap. `TipArrive` glint,
  `TipCoinPop` and `TipLocalArrive` pulse are CSS keyframes. The tipped-you frame is now
  the `TipToLocalPlayer` class and bot names use the `TipPlayerName` class; the inline
  styles are gone. Amount changed to 50 (`TIPS_CURRENCY_PER_TIP`).
- `panorama_resources.js build`/`verify` now compile and check `.css` sources. There are
  29 scripts and 1 style; the full offline suite passes.
- Dota Tools, fresh session: `tips_smoke.lua` finished with DONE. A screenshot showed two
  stacked cards: the tip to player 0 with the gold frame, and the bot-to-bot tip without it.
  Both showed 50, and chat read «… 50 Слави!». The client log had no CSS or texture
  errors for the toast. The sub-second glint and coin pop could not be caught by
  `jpeg_screenshot`, so they need a human look.

## 2026-09-27: Early "+1 kill goal" menu hidden

- `EarlyConsumables:SendEarlyConsumablesState` returns early when
  `GameLoop:HasFixedKillGoal()`, so the menu, which only appears on that state event,
  never shows. `PlayerVoteAdditionalGoal` ignores votes there, because a vote still
  extended the host's time limit. Other maps are unchanged.
- Offline: new `test_early_consumables.lua` (in `run_tests.js`) covers both cases. The full
  suite passes.
- Dota Tools: on a fresh FFA match, a screenshot at 0:04 match time, inside the
  20-second window, showed no menu.
- GG Token: `WebInventory:ItemConsumeEvent` refuses `bp_gg_token` while the kill goal is
  host-fixed, before consuming it, and shows the new
  `dota_hud_error_gg_token_fixed_kill_goal` error (EN/RU/UK). `test_free_collection.lua`
  covers refusal and other maps.
- Dota Tools: `kill_goal_lock_smoke.lua` printed `KGLOCK PASS goal 40, time limit 1600`. No
  menu state was sent, and the vote and token left the goal and time unchanged. A screenshot showed
  the Ukrainian error «Мету вбивств задав хост, її не можна змінити» and no menu at 0:02.

## 2026-09-27: Fountain smoke with All Vision

- With All Vision on, the fountain aura's effect modifier makes units on their own fountain
  invisible, immune to true sight and hidden from the enemy minimap. The owning team sees
  a smoke particle. The All Vision tooltip is updated in EN/RU/UK.
- Offline: new `test_fountain_smoke.lua` (in `run_tests.js`). The full suite passes.
- Dota Tools (`fountain_smoke_smoke.lua`, player 0 plus an enemy bot): all 10 checks `ok`:
  - both heroes smoked on their own fountains, and neither side can see the other's;
  - a Sentry Ward with true sight placed 150 units from the smoked bot did not reveal it;
  - Sven visible to the enemy after leaving and smoked again after returning.

  Screenshots: Sven translucent on his fountain; the enemy fountain centred on the bot's
  position appears empty. Bot players added mid-game spawn at the map centre, so the
  smoke moves the bot to its fountain first.

## 2026-09-27: Hero swap menu restyle and pre-game stun fix

- Bug: after a pre-game swap, `modifier_pregame_stunned` stayed on the hero but still
  counted as coming from the old team. On the new team's fountain, the aura's debuff
  immunity suppressed it, so the hero could walk until it left the fountain.
  `swap_pregame_stun_smoke.lua` reproduced this: `IsStunned` false on the fountain and true
  outside it. `HeroSwaps:Assign` now re-creates the stun after the team change with its
  remaining time. After the fix, the smoke shows both swapped heroes stunned on their new
  fountains, with the same remaining time, and outside them. `test_hero_swaps.lua` covers
  the re-creation.
- Menu restyle in `utils.js`: host-settings palette, toast-style player cards, green/red/neutral
  buttons; IDs and behaviour unchanged. `panorama_test.js` checks button looks, the colour
  strip and the incoming-request accent. The full suite passes.
- Dota Tools, Ukrainian client, with simulated clicks: `hero_swaps_look_smoke.lua` gave
  incoming, sent and plain rows. The first build squeezed names under the long Ukrainian
  button labels, so the panel was widened to 420 px with single-line names; re-checked.
  Hover brightened the row. A real click on Accept swapped the heroes (player 0 became Lina)
  and showed the gold status line.
- Toggle polish, measured from 1600x900 client screenshots with a pixel script:
  - The request count now fills a 19 px gold circle (16 screen px) and is centred with
    text-align plus 2 px top padding. Digit ink boxes for 1/2/3 are centred vertically and
    within 0.5 px horizontally; before, the count was about 1 px left, and a 15 px circle
    could only get within 0.5 px. Margins on a centred child did not move it at this scale.
  - The title is centred inside its own label: Panorama sized it ~5 px wider than the
    uppercase text it draws, which left 11 px of space before the text and 16 px after.
    Now 14 px and 13 px. The gap before the badge sits on the title only while the badge
    shows. The user confirmed the result in the client.

## 2026-09-27: Settings pager restyle

- `InitMatchRules` regroups the loading screen's `#LS_Tips_Left`, `#LS_Tips_Bullets` and
  `#LS_Tips_Right` into `MatchRulesPager` under the panel and restyles them inline; no
  compiled XML or CSS changes. `panorama_test.js` covers:
  - the grouping, removed frame art, dimmed and disabled end arrows, and gold-pill current page;
  - arrow glow until hover, and unvisited-page bullet glow;
  - bullet clicks, and the icon ignoring the mouse.
- Dota Tools (fresh client, loading screen, simulated mouse):
  - The right arrow glowed and the unvisited bullets glowed with the tabs; hovering gave the gold border.
  - Clicking switched to Other: the left arrow glowed, the right one settled, the first bullet greyed.
  - First click attempt found the chevron image (now centred in a 30 px button) taking the
    mouse events; `hittest = false` on the icon fixed hover and click.
  - A temporary `SetHint` stack log showed that the setup code does not open other pages
    (the grey tabs in one screenshot came from interaction). It was removed afterwards.
