# CLAUDE.md

Guidance for Claude Code and human contributors working in this repository.
Development-only: never part of the Workshop package (see [Release and publishing](#release-and-publishing)).

## Project

`overthrew` is a Dota 2 custom game addon, a fork of Overthrow 3.0 (see `README.md` and `LICENSE`).
It adds a host-configurable free-for-all mode on `ot3_necropolis_ffa`.

- **Map:** `ot3_necropolis_ffa` is the only registered map and the `DefaultMap` in `addoninfo.txt` (8 players,
  min 1). The other Overthrow maps (Duo, Quintet, Octet, `ot3_demo`) and the earlier `ot3_ffa_*` variants were
  removed; `run_tests.js` fails if a map package, overview, shop or upgrade override exists for an unregistered
  map. The Hero Demo tooling (`game/demo`, the `ot3_demo` Panorama panel) still loads in Tools mode.
- **No map sources:** the map ships as a compiled VPK only; there is no Hammer source.
- **Spec:** `tools/README.md` is the authoritative feature specification. Keep it and `README.md` current (see
  [Documentation](#documentation)).

## Repository layout

| Path | Contents |
| --- | --- |
| `addoninfo.txt` | Map registration, default map, player limits |
| `scripts/vscripts/` | Game Lua. Entry points: `addon_game_mode.lua` (server) and `addon_game_mode_client.lua` (client) |
| `scripts/vscripts/*_smoke.lua` | In-game smoke tests, run by hand in Workshop Tools (they ship in the package) |
| `scripts/npc/`, `scripts/shops/`, `scripts/upgrades/` | KeyValues data: heroes, items, abilities, shops, orb upgrades |
| `resource/addon_{english,russian,ukrainian}.txt` | Localization |
| `panorama/` | **Compiled** UI resources (`.vjs_c`, `.vcss_c`, `.vxml_c`). Never edit these by hand |
| `tools/panorama_sources/` | Editable Panorama JS (and `toasts.css`), compiled into `panorama/` |
| `tools/panorama_backups/` | Original compiled resources that the builds start from |
| `tools/test_*.lua`, `tools/*.js` | Offline test suite and helper scripts |
| `tools/runtime/` | npm dependencies of the offline Lua runner (Fengari) |
| `tools/*.md` | Feature spec, Panorama notes, test log, publishing check, investigations |
| `.github/` | CI workflows and Dependabot |

## Commands

Run everything from the addon root. Requires Node.js 24. In Git Bash, if `node` isn't on the PATH, run
`export PATH="/c/Program Files/nodejs:$PATH"` first.

```sh
npm ci --prefix tools/runtime --ignore-scripts --no-audit --no-fund   # once, or when runner deps are missing
node tools/run_tests.js                  # full offline suite: Lua tests on Fengari, localization parity, Panorama tests
node tools/panorama_test.js              # Panorama logic only (already included in run_tests.js)
node tools/panorama_resources.js build   # after editing tools/panorama_sources/: rebuild panorama/*_c
node tools/panorama_resources.js verify  # compiled resources match their sources (CI runs this)
luacheck scripts/vscripts                # luacheck 1.2.0 (CI downloads the release binary)
node tools/vconsole.js 'script_reload_code host_rules_smoke'   # send console commands to a running Dota client
```

Before opening a PR, `luacheck`, `run_tests.js` and `panorama_resources.js verify` must pass, because CI runs the same three.

## Architecture

### Host settings

On `ot3_necropolis_ffa` the pre-game panel shows the host settings menu instead of guides/videos:

1. The menu stays hidden until every player has loaded (or a 120s wait expires).
2. The first player to press **Claim host** becomes the host. There is no automatic host. A host who leaves
   before starting frees the role.
3. **Apply & Start** sends `HostOptions:apply_rules`, locks the options (`HostOptions.locked`) and starts hero pick.

State lives in `scripts/vscripts/libraries/host_options.lua`: `MATCH_FLAGS`, `DEFAULT_ON_FLAGS`, and events
`HostOptions:apply_rules`, `HostOptions:set_option_state` and `HostOptions:claim_host`. It is published through the
`game_options` net table under the keys `host_options` and `match_rules`. `ApplyRules` rejects a payload
unless every flag is present and is 0/1/true/false.

| Option (flag) | Default | Menu tab | Effect | Consumer |
| --- | --- | --- | --- | --- |
| Single Draft (`single_draft`) | on | Core | Single Draft hero pick | `core_declarations.lua`, `game/single_draft.lua` |
| Turbo (`turbo`) | on | Core | 2x earned gold/XP and kill Madstones; Shard at 1:00 | `core_declarations.lua`, `game/turbo_rewards.lua` |
| Epic-Only orbs (`epic_orbs`) | off | Core | Every orb upgrade is epic; each reroll costs 1 | `core_declarations.lua` (`IsEpicOnlyMap`, `IsFlatRerollMap`) |
| Backpack Items (`backpack_items`) | off | Core | Backpack items stay active (see spec) | `game/backpack_items.lua`, `filters/order.lua` |
| Kill Goal (`kill_goal`, number) | 50 | Core | Match time = 1200s × goal / 30 | `host_options.lua` → `GameLoop` |
| Divine Rapier (`divine_rapier`) | on | Items | Off = item disabled/disassembled | `game/host_items.lua` |
| Dagon (`dagon`) | on | Items | Off = item disabled/disassembled | `game/host_items.lua` |
| All Vision (`all_vision`) | on | Other | No fog; units on their own fountain are hidden from enemies | `host_options.lua`, `modifier_fountain_rejuvenation_lua.lua` |
| Infinite Rerolls (`infinite_rerolls`) | on | Other | 999 rerolls | `game/upgrades/rerolls.lua` |
| Longer Wards (`longer_wards`) | on | Other | 60-min Observer/Sentry lifetime; 4 Observers in stock | `game/host_items.lua` |
| Invincible Wards (`invincible_wards`) | on | Other | Placed wards immune to attacks and damage | `game/host_items.lua` |

Always-on FFA features, each documented in `tools/README.md`:

- Cross-team hero swaps (`game/hero_swaps.lua`).
- Fountain protection: on the own fountain and for 1.5s after leaving it, disarmed, no damage or enemy debuffs
  dealt, untargetable by enemies and no damage taken until an attempt to harm while lingering; no orb captures; dark
  look of the native AFK fountain invulnerability
  (`game/fountain_protection.lua`, `Filters:FountainDamageFilter`, `Filters:FountainModifierFilter`).
- Free local premium and collection. Backend writes are blocked, Misc-slot gameplay boosts are not granted,
  and the Collection shows only the Cosmetics tab.
- Scoreboard player tips (`libraries/webapi/tips.lua`). They are local only: a toast, a chat line and an
  end-screen tally, limited to 3 per match with a 30s cooldown. No currency moves.
- A host-fixed kill goal: the original "+1 kill goal" vote is suppressed server-side, and GG Tokens are refused.

### Recipe: adding a boolean host option

Update these five places together:

1. **`host_options.lua`:** add the name to `MATCH_FLAGS`. Add it to `DEFAULT_ON_FLAGS` only if it should start on.
2. **Panorama:** in `tools/panorama_sources/panorama/layout/custom_game/custom_loading_screen/custom_loading_screen.js`,
   add it to a category (`core`, `items` or `other`) in the `categories` array. Array order is on-screen order. Then run
   `panorama_resources.js build`.
3. **Localization:** add `host_rules_<name>` (label) and `host_rules_<name>_tip` (tooltip) to all three `addon_*.txt`
   files. Category headings are `host_rules_category_<id>`.
4. **Consumer:** read the flag with `HostOptions:GetOption("<name>")` where the effect applies, guarded by
   `HostOptions.locked` when it must not act before Apply & Start.
5. **Tests:** update the defaults and apply payloads in `tools/test_host_rules.lua` and the category order in
   `tools/panorama_test.js`. Also add the flag to every `ApplyRules({...})` call in `scripts/vscripts/*_smoke.lua`.

Then add the option to the table above, to `tools/README.md` and to `README.md` (see [Documentation](#documentation)).

## Conventions

### Panorama

- The runtime loads only compiled resources. Edit JS in `tools/panorama_sources/`, then `build`, then `verify`.
  Commit both the source and the rebuilt `_c` file.
- XML containers are never modified. The only CSS with an editable source is `toasts/toasts.css`.
  Styles compile through Valve's `game/bin/win64/resourcecompiler.exe` via the untracked
  `content/dota_addons/overthrew/` folder, so building CSS needs Windows with Workshop Tools installed.
- Image URLs in CSS sources must stay `s2r://…_png.vtex`. No PNG sources exist, and `file://{images}`
  compiles to empty paths.
- The compiler does not validate property names, so check the client log (`-condebug`) after a style change.
- Server-to-client events go through `ProtectedCustomEvents`. Payloads arrive under `event_data`; subscribe with
  `GameEvents.NewProtectedFrame(panel).SubscribeProtected(...)`.

### Localization

- Every token change goes into **all three** files with real translations. `run_tests.js` fails if the token sets
  differ. English is the fallback for other client languages.
- **Russian:** keep item, hero and game-mode names in English, as the Russian Dota client does.
- **Ukrainian:** follow the official Dota 2 Ukrainian client (`resource/localization/*_ukrainian.txt` inside
  `game/dota/pak01_dir.vpk`). That means «ви» address, the ’ apostrophe, official hero/ability names in prose,
  item titles in English, and an «Англійською: …» line on ability descriptions.

### Lua

- New engine API globals go into the `engine` list in `.luacheckrc`. The repo's own globals and the
  `table`/`string`/`math` extensions are collected automatically.
- There is one map, so code doesn't branch on the map name. Per-map data stays keyed by `GetMapName()`
  (`TEAMS_LAYOUTS`, MVP rewards, neutral drop times, `scripts/upgrades/overrides/<map>/`).
- Modifiers on heroes are copied to every illusion, and the engine visits each Lua modifier of every hero unit on
  every attack and damage instance (see "Illusions and performance" in `tools/README.md`). Keep them few, and never
  declare a global `MODIFIER_EVENT_*` in them: register the handler with `UnitEvents` (`libraries/unit_events.lua`)
  and route the event through `modifier_event_proxy`. A modifier kept through death returns
  `self:GetParent():IsIllusionGoneOnDeath()` from `RemoveOnDeath` (server side). Measure with `illusion_perf_smoke`.
- Illusions carry their generic upgrades in one modifier, `modifier_illusion_generic_upgrades`. A new generic upgrade
  goes into `IllusionGenericUpgrades.HOSTED` (`game/upgrades/illusion_generic_upgrades.lua`) if it follows the rules
  listed there; a new property it needs goes into `IllusionGenericUpgrades.PROPERTIES`. `test_illusion_performance.lua`
  checks both.

### Documentation

Bring the READMEs up to date as part of every significant change, in the same PR, before calling the work done:

- **`README.md`** (public overview): what the game offers and how to get it. Update it when user-visible features,
  host options, defaults, maps or the release/installation flow change.
- **`tools/README.md`** (feature spec): exact behavior, limits and design decisions. Update it with every behavior
  change, and keep test and tooling notes current.
- **`CLAUDE.md`** (this file): update it when commands, layout, conventions, CI or the host-option recipe change.

A change is significant when it adds, removes or renames a feature or option, changes a default or visible behavior,
or changes how the project is built, tested or released. Refactors, internal fixes and test-only changes don't need
README edits. If nothing needs updating, say so in the PR description.

### Git and pull requests

- Branch from `main` with a short kebab-case topic name (e.g. `backpack-items`), then open a PR into `main`.
- PRs are squash-merged with Title Case titles, e.g. `Add Luacheck to Build (#15)`. The `Build` check is required.
- Record test runs (offline and in-game) in `tools/TEST_RESULTS.md`.

## In-game testing (Dota 2 Workshop Tools)

Launching Dota or sending console commands acts on the developer's machine. Claude should ask first unless the
developer has granted standing permission.

- **Launch:** start Dota with `-tools` (add `-condebug` to capture logs), choose addon `overthrew`, then run
  `dota_launch_custom_game overthrew ot3_necropolis_ffa` in the console.
- **Smoke scripts:** run with `script_reload_code <name>` (e.g. `host_rules_smoke`, `backpack_items_smoke`,
  `hero_swaps_smoke`; see `scripts/vscripts/*_smoke.lua`). They print `..._PASS` markers or assert. Many mutate
  state, so use a fresh session for each.
- **VConsole:** `tools/vconsole.js` talks to port 29000 (`--port`, `--wait-ms`, `--listen-ms`). Its output can include
  backlog, so send `echo <unique marker>` first and read only what follows. The backlog is short, so long smoke
  scripts store their log and reprint it when rerun.
- **Reloading:** after Lua changes, restart the map (`disconnect`, then relaunch). `script_reload` mid-match re-runs
  init and resets host options. HUD Panorama reloads on map restart, but the loading screen (the host settings menu)
  reloads only after restarting the client.
- **Focus:** keep the Dota window in the foreground. Otherwise Panorama stops laying out and screenshots
  (`jpeg_screenshot <name>` → `game/dota/screenshots/`) are stale.
- **Client logs:** Panorama `$.Msg` doesn't reach VConsole; with `-condebug` it goes to `game/dota/console.log`.
  `cl_script_reload_code <name>` runs a file in the client Lua VM. That VM lacks the `DOTA_GAMERULES_STATE_*`
  constants.

### Gotchas

- Item cooldowns are shared per item type on a hero, so call `EndCooldown` first.
- Enemy test units near a fountain die. With All Vision off, targets need vision (`AddFOWViewer`).
- For simulated multiplayer, add bots with real player IDs/teams:
  `GameRules:AddBotPlayerWithEntityScript(hero, name, team, "", false)` (see `backpack_items_multiplayer_smoke.lua`).
  - Idle heroes auto-attack each other, so call `SetIdleAcquire(false)`; the damage also disables Blink Dagger.
  - Teleported respawns keep `modifier_fountain_invulnerability`.
  - Native target casts turn first, so wait about 0.5s before checking.
  - The map-centre pit shortens blinks.
  - `ExecuteOrderFromTable` orders reach the order filter with issuer -1.
- There is no `script` console command. Panorama `Game.GetConvarInt` can't read Lua-registered convars.
- Modifier classes live in their own script scopes, not in `_G`: reach one through `getmetatable(instance).__index`.
  `LinkLuaModifier` doesn't reload a file already linked in the session, so classes added to it later are missing.
- The server VM has no `os`; time code with `Plat_FloatTime()`. Illusions deal no damage through `ApplyDamage`, and
  `entity_killed` doesn't fire for them.
- Removing a native item modifier (such as `modifier_item_skadi`) from a unit can crash the game.
- `net_fakelag` doesn't delay the host's own loopback client. `GameUI.SelectUnit` can't select enemy heroes.
- To drive the real UI, a temporary HUD hook can send orders (`Game.PrepareUnitOrders`) or clicks
  (`$.DispatchEvent("Activated", panel, "mouse")`) and report back to a server listener. Restore the HUD build afterwards.

### Real multiplayer

Real multiplayer with several clients is untested, and the bot simulation doesn't replace it. A `-tools` client
cannot create lobbies, so use the normal client:

1. Launch through Steam: `steam.exe -applaunch 570 -condebug`. Starting `dota2.exe` directly fails VAC.
2. Go to Arcade → the game → Create Custom Lobby, set Server Location to "Local Host", set a password, and start.

This runs the published Workshop build. The listen server may run on any member's PC. At match start the log
switches to `game/dota/console.<match_id>.log`, which begins with the lobby dump (leader, members, slots).

## Release and publishing

- **Build** (`.github/workflows/build.yml`): runs on PRs, pushes to `main`, manual dispatch, and when Release calls it.
  It runs luacheck, the offline suite and `panorama_resources.js verify`. It then zips the committed tree's nine
  runtime entries (`PACKAGE_ENTRIES`: `addoninfo.txt maps materials models panorama particles resource scripts
  soundevents`) and uploads the zip as an artifact.
- **Release** (`.github/workflows/release.yml`): manual, with input `release` = a semantic version. It checks that
  the tag is new, builds `overthrew_v<version>.zip`, tags the dispatched commit `v<version>` and creates the GitHub
  release. `-suffix` versions become prereleases.
- **Dependabot:** weekly grouped PRs for the SHA-pinned actions and `tools/runtime`, with a 7-day cooldown.
- **Workshop:** publish with Workshop Tools from a folder that holds only the nine runtime entries. Never include
  `.git`, `.github`, `.claude`, `.luacheckrc`, `tools/`, `CLAUDE.md`, `README.md`, editor caches or
  `panorama_debugger.cfg`. Keep `PACKAGE_ENTRIES` in sync with any new runtime folder. Players need no launch flags.
  Details are in `tools/PUBLISHING_CHECK.md`.
- Claude never uploads to the Workshop or creates releases/tags unless explicitly asked.

## Further docs

- `tools/README.md`: feature spec and design notes
- `tools/panorama_README.md`: Panorama resource format and build details
- `tools/TEST_RESULTS.md`: log of test runs
- `tools/PUBLISHING_CHECK.md`: publishing audit and packaging limits
- `tools/NEUTRAL_TIMINGS_INVESTIGATION.md`: neutral item timing investigation
