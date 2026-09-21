# Epic-only FFA

`ot3_necropolis_ffa_epic_only` is a separately selectable copy of Necropolis FFA.
The English label is `Ffa Epic Only`; existing UI styles apply their usual casing.
All original orb-producing events grant epic rewards, including passive/kill
meters, hero-pick bonuses, captured drops, overthrow bursts, shops and gifts.
Eight teams, timing, thresholds, source-specific lucky trinket chances and
the 2,000 / 4,000 / 8,000 shop prices are retained. Reward effects, selection
strength/pool use the existing epic rules. Each reroll costs 1 in Epic Only,
so the existing localhost allowance of 30 funds 30 rerolls. Other maps retain
their rarity-dependent 1 / 2 / 4 costs. Source rarity
is retained separately for triggers and placement; it never downgrades a reward.

The original map remains registered. Gameplay and UI inherit its FFA settings
without replacing the new map identity. No public leaderboard entry or new
backend integration is added. Existing private/local lobby fallbacks still apply.

`ot3_necropolis_ffa_epic_only_single_draft` is an additional private-play copy,
displayed as `Ffa Epic Only Single Draft`. It retains all Epic Only rules,
including 30 reroll points at 1 per reroll. Banning is disabled. Each player
receives one Strength, Agility, Intelligence and Universal hero, drawn from
the addon's enabled heroes using the installed game's attributes. No hero
appears in more than one player's offers. Offers persist across reconnects.
The native picker enforces per-player availability; both custom random paths
choose only from that player's four heroes. The smart-random button is hidden
and the supporter pick-delay overlay is bypassed on this variant.

Launch it with:

```text
dota_launch_custom_game overthrew ot3_necropolis_ffa_epic_only_single_draft
```

`ot3_necropolis_ffa_single_draft` / `Ffa Single Draft` provides the same
four-choice, no-ban draft with standard FFA orb rules. Common, rare and epic
rewards, timed epic events, shop items and rarity-dependent reroll costs
(1 / 2 / 4, with the existing 30-point allowance) match the original FFA map.
Both Epic Only variants remain available separately.

```text
dota_launch_custom_game overthrew ot3_necropolis_ffa_single_draft
```

`script_reload_code single_draft_smoke` checks offers and any selected hero.
`script_reload_code single_draft_random_smoke` deliberately chooses a random
hero from player 0's offers; run it only during a disposable Tools-mode draft.
After a hero initializes on standard Single Draft, run
`script_reload_code standard_single_draft_smoke` in a fresh disposable session
to check real shop-item rewards and reroll spending. It grants three item
rewards and spends 7 of the starting 30 reroll points.

Launch from the Dota console using the standard
[addon launch command](https://developer.valvesoftware.com/wiki/Dota_2_Workshop_Tools/Addon_Overview/Playing_Addons):

```text
dota_launch_custom_game overthrew ot3_necropolis_ffa_epic_only
```

In a disposable Tools-mode session, after addon initialization, run
`script_reload_code epic_only_smoke` to check the loaded map identity, FFA settings,
world entities and physical common/rare/epic requests. The check removes its
three temporary capture units. Once a hero is initialized, it also queues three
test rewards through the real selection renderer. It works on the original FFA map as a
regression check. Visually check the minimap, capture effects, shop descriptions,
hero bonus icons, and both time/kill progress bars in the client.

## Automated checks

With Node.js available:

```text
node tools/epic_only/run_tests.js
node tools/epic_only/panorama_resources.js verify
node tools/epic_only/panorama_test.js
```

The Lua test harness executes production code with mocked engine services. Its
pinned development-only runner can be restored with
`npm ci --prefix tools/epic_only/runtime --ignore-scripts --no-audit --no-fund`.
Panorama resources, sources and regeneration are described in
[panorama_README.md](panorama_README.md). Regenerate the variant shop/item files
with `node tools/epic_only/build_shop.js` after editing the original FFA items.

## Map package

Run from PowerShell:

```powershell
& ./tools/epic_only/Build-Map.ps1
& ./tools/epic_only/Build-Map.ps1 -VerifyOnly
& ./tools/epic_only/Build-Map.ps1 -TargetMap ot3_necropolis_ffa_epic_only_single_draft
& ./tools/epic_only/Build-Map.ps1 -TargetMap ot3_necropolis_ffa_epic_only_single_draft -VerifyOnly
& ./tools/epic_only/Build-Map.ps1 -TargetMap ot3_necropolis_ffa_single_draft
& ./tools/epic_only/Build-Map.ps1 -TargetMap ot3_necropolis_ffa_single_draft -VerifyOnly
```

If local PowerShell execution policy disables scripts, use a process-local
invocation (this does not change the machine's policy):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ./tools/epic_only/Build-Map.ps1 -VerifyOnly
```

The builder creates `maps/ot3_necropolis_ffa_epic_only.vpk` from the existing
`maps/ot3_necropolis_ffa.vpk`. The editable Necropolis map source is not present
in this checkout. This is a package alias copy, not a Hammer rebuild.

The output keeps every original internal path and adds a matching path under
the new map name. Geometry, entities, navigation and world data remain unchanged.
The new root `.vmap_c` and three `.vrman_c` manifests register both namespaces,
including the world resource name derived by the engine from the selected map.
These four metadata resources have rebuilt external-reference tables and IDs;
the manifest resource lists also include the new names. Original paths remain
available for the world's existing references. The original package is not edited.
The preview texture is copied under the new map name; the overview reuses the
original overview material and bounds.

The builder accepts only the unsigned, single-file VPK v2 format used by the
source package. It rebuilds the directory, file CRC32 values, chunk MD5 hashes
and package hashes. Verification also compares all original payloads and checks
the four repaired aliases against their deterministic generated metadata.
The builder can update a previous generated copy, but rejects unrelated or
manually edited packages. Engine testing is separate from structural validation.

The generated copy contains 157 original entries and 157 aliases. Valve's
installed `resourceinfo.exe` successfully reads its new `.vmap_c` and world
resource; the world still names the preserved original worldnode paths.

SHA-256 values for the source and repaired generated package:

```text
source: 27C8477F5609286A9BE4453C490687F83B7BCF804D18B778697A0CE21E53B9A2
copy:   907E9809DCE86DD17797DF1179BB7A241E1596582C76D811AC88B07C09306D45
```

After building, launch the addon with `ot3_necropolis_ffa_epic_only` and verify
the map loads, pathing/minimap work, and Lua reports the new map name. Also load
`ot3_necropolis_ffa` separately to verify the existing map still works.
