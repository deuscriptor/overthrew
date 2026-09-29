# CLAUDE.md

See also AGENTS.md (workflow rules). Development-only file; exclude from Workshop publishing.

## What this is

Dota 2 custom game addon `overthrew`, a fork of Overthrow 3.0. Work branch `map-config`, main `main`.

- **Entry point:** `ot3_necropolis_ffa` (DefaultMap in `addoninfo.txt`, 8 players, min 1). Other registered maps (gardens_duo, jungle_quintet, desert_octet, ot3_demo) keep original behavior.
- Earlier separate-map variants (`ot3_ffa_epic`, `ot3_ffa_draft`, `ot3_ffa_epic_draft`) were removed; `tools/epic_only/Build-Map.ps1` is historical. No Hammer map source exists — VPKs are compiled only.

**Host settings** (hidden until every player has loaded, then edited by whoever presses **Claim host** first — no automatic host; before hero pick; shown instead of guides/videos; **Apply & Start** locks them and begins picking):
- Core: Single Draft (on), Turbo (on; 2x earned gold/XP), Epic-Only orbs (off; rerolls cost 1), Backpack Items (off; backpack slots keep working, see README), Kill Goal (default 50; match time = 1200s × goal/30); the early "+1 kill goal" voting menu is suppressed server-side and GG Tokens are refused
- Items: Divine Rapier (on), Dagon (on); off = item disabled/disassembled
- Other, in menu order: All Vision (on; units on their own fountain are smoked: invisible to enemies incl. true sight/minimap), Infinite Rerolls (on; 999), Longer Wards (on), Invincible Wards (on)
- Also: cross-team Hero Swaps; free local premium/collection (backend writes blocked; Misc-slot gameplay boosts are not granted; the Collection shows Cosmetics only, without Chat Wheel/Treasures/Misc tabs); scoreboard player tips (always on, local only: toast + chat + end-screen tally, 3/match, 30s cooldown, no currency moved; `libraries/webapi/tips.lua`).

## Key code

- `scripts/vscripts/libraries/host_options.lua` — option state, `MATCH_FLAGS`, net table `game_options` (`host_options`, `match_rules`), events `HostOptions:apply_rules` / `HostOptions:set_option_state`
- `scripts/vscripts/core_declarations.lua` — `UsesHostRules()`, `IsSingleDraftMap()`, `IsEpicOnlyMap()`, `IsFlatRerollMap()`
- `scripts/vscripts/game/` — `single_draft.lua`, `turbo_rewards.lua`, `hero_swaps.lua`, `host_items.lua`, `backpack_items.lua`, `game_loop.lua`, `neutral_item_drop.lua`
- **Panorama:** runtime uses compiled `.vjs_c`. Editable JS lives in `tools/epic_only/panorama_sources/` and must be rebuilt (below). Originals in `tools/epic_only/panorama_backups/`. XML containers are not modified. CSS: only `toasts/toasts.css` has an editable source (recovered from the compiled file); `panorama_resources.js build` compiles it with Valve's `resourcecompiler.exe` via `content/dota_addons/overthrew/` (outside git). Image URLs in CSS sources must stay `s2r://…_png.vtex` (no PNG sources exist; `file://{images}` compiles to empty paths). The compiler does not validate property names; check the client log (`-condebug`).
- **Docs:** `tools/epic_only/README.md` (authoritative feature spec), `panorama_README.md`, `TEST_RESULTS.md`, `PUBLISHING_CHECK.md`, `NEUTRAL_TIMINGS_INVESTIGATION.md`.
- **Localization:** English (`resource/addon_english.txt`, default/fallback for other client languages), Russian (`resource/addon_russian.txt`) and Ukrainian (`resource/addon_ukrainian.txt`). Every token change goes into **all three** files, with real translations. Russian keeps item/hero/game-mode names in English, as the Russian Dota client does. Ukrainian follows the official Dota 2 Ukrainian client (reference: `resource/localization/*_ukrainian.txt` in `game/dota/pak01_dir.vpk`): «ви» address, ’ apostrophe, official hero/ability names in prose, item titles in English, «Англійською: …» line on ability descriptions. `run_tests.js` fails if the token sets differ.

### Adding a host option (a boolean match flag)

One toggle touches five places — keep them in sync:
1. `host_options.lua` — add the name to `MATCH_FLAGS`; add it to `DEFAULT_ON_FLAGS` only if it should start checked (absent = default off). `ApplyRules` validates every flag as 0/1/false/true and publishes through the `match_rules` net table.
2. Panorama source `tools/epic_only/panorama_sources/.../custom_loading_screen/custom_loading_screen.js` — add `"<name>"` to the right category in the `categories` array (`core`/`other`/`items`); array position = on-screen order. Then rebuild (see Testing).
3. Localization — add `"host_rules_<name>" "<Label>"` and its hover tooltip `"host_rules_<name>_tip"` to `resource/addon_english.txt` **and** translated to `resource/addon_russian.txt` and `resource/addon_ukrainian.txt`. Category headings are `host_rules_category_<id>`.
4. Consumer code — read the flag where its effect applies, via `HostOptions:GetOption("<name>")`, guarded by `HostOptions.locked` / `UsesHostRules()`. Existing consumers: `core_declarations.lua` (single_draft, epic_orbs, turbo), `host_items.lua` (divine_rapier, dagon), `game/upgrades/rerolls.lua` (infinite_rerolls), `host_options.lua` (all_vision → fog), `game/backpack_items.lua` (backpack_items; applied from `HostOptions:ApplyRules`, casts hooked in `filters/order.lua`).
5. Tests — update `tools/epic_only/test_host_rules.lua` (defaults + apply payloads list every flag) and `panorama_test.js` (category order assertions). `ApplyRules` rejects a payload missing any flag, so also add the flag to every `ApplyRules({...})` call in `scripts/vscripts/*_smoke.lua`.

## Testing

Environment (verified 2026-09-26): Node.js v24 at `C:\Program Files\nodejs` (on the **PowerShell** PATH; **not** on the Git-Bash PATH — in Bash first run `export PATH="/c/Program Files/nodejs:$PATH"`). Dota Workshop Tools binaries present under `game/bin/win64` (resourcecompiler, resourceinfo, vconsole2). All offline suites currently pass.

**1. Offline (Node.js, from addon root)** — run first, cheapest:
- `node tools/epic_only/run_tests.js` — Lua tests (`tools/epic_only/test_*.lua`) run production code on Fengari with a mocked engine
- `node tools/epic_only/panorama_test.js` — Panorama logic with mocked panels
- `node tools/epic_only/panorama_resources.js build` then `... verify` — after editing JS in `panorama_sources/`
- `luacheck scripts/vscripts` (luacheck 1.2.0, from the addon root) — `.luacheckrc` collects the repo's own globals and `table`/`string`/`math` extensions from `scripts/vscripts` at load time; new engine API names go into its `engine` list
- Restore runner deps if missing: `npm ci --prefix tools/epic_only/runtime --ignore-scripts --no-audit --no-fund`
- Record results in `tools/epic_only/TEST_RESULTS.md`.

**2. In-game (Dota 2 Workshop Tools):**
- Launch Dota with `-tools`, pick addon `overthrew`, then console: `dota_launch_custom_game overthrew ot3_necropolis_ffa` (Local Host lobby; host settings appear pre-pick).
- Smoke scripts `scripts/vscripts/*_smoke.lua` run in a disposable tools session via `script_reload_code <name>` (e.g. `host_rules_smoke`, `turbo_smoke`, `host_settings_smoke`, `host_items_smoke`, `hero_swaps_smoke`, `hero_swaps_ui_smoke`, `invincible_wards_smoke`, `all_vision_smoke`, `free_collection_smoke`, `single_draft_smoke`, `backpack_items_smoke`, `host_claim_smoke`, `tips_smoke`, `kill_goal_lock_smoke`, `fountain_smoke_smoke`, `swap_pregame_stun_smoke`, `hero_swaps_look_smoke`). They print `..._PASS` markers or assert. Some mutate state — use fresh sessions.
- Send console commands from a terminal via VConsole (port 29000): `node tools/epic_only/vconsole.js 'script_reload_code host_rules_smoke'` (options `--port --wait-ms --listen-ms`).
- Reloading: after Lua changes restart the map (`disconnect`, then `dota_launch_custom_game ...`); `script_reload` mid-match re-runs init and resets host options. HUD Panorama scripts reload on map restart, but the loading screen (host settings menu) only reloads after quitting and relaunching the client.
- The Dota game window must be in the foreground, or Panorama stops laying out and screenshots are stale. `jpeg_screenshot <name>` writes to `game/dota/screenshots/`.
- `vconsole.js` output can include the console backlog: send `echo <unique marker>` first and read only what follows it.
- Server-to-client events are wrapped by `ProtectedCustomEvents`: payloads arrive under `event_data`; subscribe with `GameEvents.NewProtectedFrame(panel).SubscribeProtected(...)`.
- Test gotchas: item cooldowns are shared per item type on a hero (`EndCooldown` first); enemy test units near a fountain die; targets need vision (`AddFOWViewer`) with All Vision off.
- Simulated multiplayer: bot players with real player IDs/teams via `GameRules:AddBotPlayerWithEntityScript(hero, name, team, "", false)` (see `backpack_items_multiplayer_smoke.lua`, `hero_swaps_smoke.lua`). Gotchas: idle heroes auto-attack each other (`SetIdleAcquire(false)`; damage disables Blink Dagger); teleported respawns keep `modifier_fountain_invulnerability` (out of game, untargetable); native target casts turn first (wait ~0.5s before checking); the map-centre pit shortens blinks; `ExecuteOrderFromTable` orders reach the filter with issuer -1. VConsole keeps little backlog, so long smokes store their log and reprint it when rerun. There is no `script` console command.
- Client-side checks: Panorama `$.Msg` does not reach VConsole, but launching with `-condebug` writes it (HUD and loading screen) to `game/dota/console.log`. `cl_script_reload_code <name>` runs a file in the client Lua VM. The client VM lacks the `DOTA_GAMERULES_STATE_*` constants. Panorama `Game.GetConvarInt` cannot read Lua-registered convars; the client VM of a client in the server process can. A temporary HUD hook can listen on a net table key and send real orders (`Game.PrepareUnitOrders`) or clicks (`$.DispatchEvent("Activated", panel, "mouse")`), and report back with `GameEvents.SendCustomGameEventToServer` to a `CustomGameEventManager:RegisterListener`. Restore the HUD build afterwards. `net_fakelag` does not delay the host's own loopback client, and `GameUI.SelectUnit` cannot select enemy heroes.
- Real multiplayer (several clients) is not tested; bot simulation doesn't replace it. Lobbies cannot be created from a `-tools` client ("Cannot start matchmaking with -insecure, -dev or -tools"), so real Local Host lobbies (which run the published Workshop build) need the normal client. Launch it through Steam (`steam.exe -applaunch 570 -condebug`; starting `dota2.exe` directly fails VAC), then Arcade → the game → Create Custom Lobby → Server Location "Local Host", set a password, Start Game. A Local Host server is an in-process listen server (`ActivateServerFromLobby - IsLan: YES, IsDedicatedServer: NO`), but it may run on a member's PC other than the lobby owner's. At match start the log tears off to `game/dota/console.<match_id>.log`, which begins with a CSODOTALobby dump (`leader_id`, members, slots) and `Initializing from lobby ... preferred PlayerID` lines. None of this is exposed to scripts.

**3. Publishing:** see `tools/epic_only/PUBLISHING_CHECK.md`. Publish via Workshop Tools; exclude `.git`, `.github`, `.luacheckrc`, `tools/`, AGENTS.md, CLAUDE.md, editor caches, `panorama_debugger.cfg`. Players need no launch flags. CI (`.github/workflows/`): **Build** (`build.yml`; PRs, pushes to main, manual, and called by Release) runs luacheck, the offline suite and `panorama_resources.js verify`, then zips the nine runtime entries of the committed tree (`PACKAGE_ENTRIES`) and uploads the zip as an artifact; its `Build` job is the required PR check. **Release** (`release.yml`, manual, input `release` = semantic version) checks the tag is new, runs Build with folder `overthrew_v<version>`, tags the dispatched branch's latest commit `v<version>` and creates the GitHub release with the zip (prerelease for `-suffix` versions). Dependabot (`.github/dependabot.yml`) opens weekly grouped update PRs for the SHA-pinned workflow actions and the Fengari test runner (`tools/epic_only/runtime`), with a 7-day cooldown on new releases.
