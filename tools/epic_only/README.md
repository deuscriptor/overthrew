# Configurable FFA

Select **Ffa** (`ot3_necropolis_ffa`) in the lobby. Before hero selection, the
host can enable Single Draft, Turbo, and Epic-Only independently in the **Core**
category, in that order. Epic-Only also makes
every reroll cost 1; there is no separate reroll option.
Turbo doubles kill Madstones. Timed Madstone grants use the original schedule
for both modes: 2:01, 4:31, 7:01, 9:31 and 15:01. The experimental Turbo
config and accelerated grant schedule have been removed. Native neutral
crafting timings and recraft costs remain unchanged.
Aghanim's Shard becomes available at 1:00 in Turbo, versus 2:00 otherwise.
Gift-orb buttons and their popovers are removed from the minimap overlay.
The top-left menu keeps Dashboard, Dota Settings, Scoreboard and Collection; the
In-Game Settings, Inbox, Leaderboard, Feedback and Promo Events buttons (and the
new-mail banner) are hidden on every map. Randomed heroes receive Faerie Fire and
Enchanted Mango; Infused Raindrop is no longer included.
**Kill Goal** is a numeric input at the bottom of Core, prefilled with 50. The
host can enter a positive whole number. Apply locks this as the match's fixed
kill cap and updates the scoreboard; disconnects and goal-increase events no
longer alter it on configurable FFA. Existing match-time adjustments still apply.
Single Draft and Turbo are on by default; Epic-Only is off. Settings replace
the guides/videos as the only first page on configurable FFA; page indicators
and navigation remain for future settings pages. The menu shows category
tabs, options, and the apply button; it omits explanatory paragraphs. Each option
row shows an on/off switch and a one-line hover tooltip (`host_rules_<name>_tip`),
and Kill Goal shows the resulting base time limit (40 seconds per kill).
**Apply & Start** freezes the settings and begins hero selection. There is no
automatic host: the settings stay hidden (the usual loading tips show instead) until
setup has begun and every player has loaded, so nobody edits them before the others
arrive. After 120 seconds of setup, players still loading are skipped, so setup cannot
stall. Then every player sees the current settings read-only (switches greyed out:
desaturated and half-transparent) and a gold-lit **Claim
host** card in Apply & Start's place, with the same size and position. The first
player to claim becomes the host (the server accepts one claim, and the button sends
one request at a time). A host who disconnects or abandons before starting frees the
role, and anyone can claim again; a returning player does not get it back. The rules
lock with the host once started. Other maps keep native custom-game host privileges.

Only the host can change the settings and sees coloured switches; for everyone else,
and for all players once the rules lock, the switches stay greyed out. The server rejects changes after setup and
duplicate start requests. Other players see a **Waiting for the host** status card
naming the host (`<name> is choosing the match rules`), also in Apply & Start's
footprint, so all five rows still fit. Its three gold dots pulse in turn every 0.3
seconds. The server logs claims and releases (`[Host Options]` lines).

Automatic selection was dropped. Native privileges and `GetListenServerHost()` follow
connection order, the server process belongs to whoever Dota picks to host (not
always the lobby owner), and scripts cannot read the lobby's owner.

**Invincible Wards**, last on the Other page, defaults on. It
protects placed Observer and Sentry wards from attacks and damage without
changing their expiry or requiring Longer Wards. `invincible_wards_smoke.lua`
checks native attacks, damage and expiry in a disposable tools match.

**All Vision**, first on the Other page, defaults on. It disables fog of war for
all teams without granting True Sight; invisible enemies still require detection.

Turbo doubles earned gold and experience, including passive and central-ring
income, kills, creeps, objectives, and custom ability rewards. Starting gold stays
700. Sales, refunds, redistributed gold, and spending retain their original
amounts. Turbo defaults on and does not change any other Turbo-mode mechanics.

Single Draft disables bans and offers each player four heroes, one per attribute,
without shared offers. Epic mode converts all existing orb rewards, including
shop purchases, while retaining prices and source-specific triggers. The shop
uses its original item names/icons; rewards follow the selected rule. Rerolls
start at 30 and cost their original 1/2/4 with normal orbs, or always 1 with
Epic Orbs. Other original maps retain their behavior.

Only the original FFA map is registered now. The three older variant VPKs have
been removed; the configurable mode uses the original VPK and overview.
Historical build tools remain available.

Localization: the addon ships English (`resource/addon_english.txt`, the default
and fallback for every other client language), Russian
(`resource/addon_russian.txt`) and Ukrainian (`resource/addon_ukrainian.txt`).
Every token added, renamed or removed in one file must be changed in the other
two in the same commit, with real translations rather than copied English text.
Russian keeps item, hero and game-mode names (Divine Rapier, Dagon, Single Draft,
Turbo) in English, as in the Russian Dota client. Ukrainian follows the official
Dota 2 Ukrainian client, whose files (`resource/localization/*_ukrainian.txt`)
are inside `game/dota/pak01_dir.vpk` and serve as the terminology reference:
formal «ви» address, the ’ apostrophe, official Ukrainian hero and ability names
in prose (Некрофос, «Серцеспинна аура»), English item titles (Divine Rapier) with
Ukrainian names in prose (Скіпетр Аґаніма), «Турбо» but «Single Draft», «кріп»,
«зарядка» for cooldown, «лютит» for Madstone, «сфера» for orb and «переобрання»
for reroll. Ability descriptions start with the official
«Англійською: <b><font color='#F2A93E'>English name</font></b>\n» line.
`run_tests.js` fails when the three files' token sets differ.

Validation: `test_host_rules.lua` covers all eight rule combinations, host changes,
invalid values, locking, and repeated Apply. `panorama_test.js` covers delayed
settings arrival, read-only controls, the Apply payload, Epic-linked reroll costs,
and removal of the separate reroll toggle and overlapping logos.
`test_turbo.lua` checks earning multipliers and excluded transactions through the
production filters. `turbo_smoke.lua` exercises the actual engine gold/XP calls
in a disposable local tools session. Its live checks passed: starting gold 700,
scripted grants doubled exactly once, a native creep kill awarded 202 gold/XP
from a 101 bounty, and sales/refunds/redistribution/spending stayed unchanged.
The smoke script suppresses demo gold and single-player auto-victory only inside
the disposable test session. Scripted grants use `game/turbo_rewards.lua` because
the native Lua grant methods can bypass the engine filters; its suppression
guard prevents duplicate multiplication when an engine callback also runs.
Run these with the existing Node/Fengari runtime. Multiplayer testing is skipped
at the user's request. Local in-game checks passed through the actual settings
controls for All Pick + Epic orbs + 1-point rerolls, and Single Draft + normal
orbs + normal reroll costs. The latter produced four native hero offers. The
settings page was visually checked in the original guide panel, with one page
indicator and no guides/videos. `script_reload_code host_rules_smoke` validates
the locked rules in a tools-mode FFA session without changing them.

## Historical variant implementation

The following records the earlier separate-map implementation and its tooling;
its lobby-registration and launch instructions have been superseded above.

`ot3_ffa_epic` is a separately selectable copy of Necropolis FFA.
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

`ot3_ffa_epic_draft` is an additional private-play copy,
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
dota_launch_custom_game overthrew ot3_ffa_epic_draft
```

`ot3_ffa_draft` / `Ffa Single Draft` provides the same
four-choice, no-ban draft with standard FFA orb rules. Common, rare and epic
rewards, timed epic events, shop items and rarity-dependent reroll costs
(1 / 2 / 4, with the existing 30-point allowance) match the original FFA map.
Both Epic Only variants remain available separately.

```text
dota_launch_custom_game overthrew ot3_ffa_draft
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
dota_launch_custom_game overthrew ot3_ffa_epic
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
& ./tools/epic_only/Build-Map.ps1 -TargetMap ot3_ffa_epic_draft
& ./tools/epic_only/Build-Map.ps1 -TargetMap ot3_ffa_epic_draft -VerifyOnly
& ./tools/epic_only/Build-Map.ps1 -TargetMap ot3_ffa_draft
& ./tools/epic_only/Build-Map.ps1 -TargetMap ot3_ffa_draft -VerifyOnly
```

If local PowerShell execution policy disables scripts, use a process-local
invocation (this does not change the machine's policy):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ./tools/epic_only/Build-Map.ps1 -VerifyOnly
```

The builder creates `maps/ot3_ffa_epic.vpk` from the existing
`maps/ot3_necropolis_ffa.vpk`. The editable Necropolis map source is not present
in this checkout. This is a package alias copy, not a Hammer rebuild.

Each variant also needs `resource/overviews/<map_name>.txt` outside its VPK.
The builder writes and verifies this file, retaining the original Necropolis
terrain material and minimap position/scale. Include these overview files when
publishing. Missing them causes absent minimap terrain and incorrect projection.

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

After building, launch the addon with `ot3_ffa_epic` and verify
the map loads, pathing/minimap work, and Lua reports the new map name. Also load
`ot3_necropolis_ffa` separately to verify the existing map still works.
# Cross-team hero swaps

The configurable FFA exposes **Hero Swaps** at the upper right after choosing a
hero. Players can request, accept, decline, or cancel swaps across teams in any
pick mode, including heroes outside their original Single Draft offers. Requests
expire after 30 seconds and require the recipient's consent. Accepted requests
during selection or strategy are held until both hero entities spawn. Swaps close
at match start; disconnects or changed selections invalidate pending requests.

Teams, gold, inventory slots/items and remaining rerolls stay with each player.
The actual hero entity, facet and learned abilities change owners. Orb upgrades
are reset, including generic modifiers and their rune/stat effects. Consumed
orbs are returned as upgrade choices of their original rarities to the player
who used them; unspent choices remain queued. Refunds do not rerun lucky-trinket
rolls or grant new starting rewards. Non-orb account bonuses stay with the player.

A swapped hero keeps its pre-game stun. The stun is re-created under the hero's new team
with the time it had left. The old stun still counted as coming from the previous team,
so the new fountain's debuff immunity suppressed it: the hero could walk until it left
the fountain and was then stunned. `swap_pregame_stun_smoke.lua` reproduces this in
Tools (which skips the production stun) and checks the fix.

The menu uses the host settings' style: a dark gradient panel with a gold hairline and
gold title. Rows are cards with portraits and player-colour strips, as on the tip toast.
The row accent is gold for an incoming request and faint gold for one you sent. Accept
and Request are green, Decline red and Cancel neutral; names stay on one line.
`hero_swaps_look_smoke.lua` fills it with every row state for screenshots.

The regression runner includes server request/consent tests and Panorama panel
tests. `hero_swaps_smoke.lua` checks engine reassignment and refund behavior in a
disposable local Tools session with a synthetic second player;
`hero_swaps_ui_smoke.lua` checks acceptance through the actual client button.
These checks do not replace an online multiplayer test.

## Items and Other settings

The setup menu has one category per page: Core, Items, Other. Clickable
Core/Items/Other tabs switch pages, and unvisited tabs glow gold. Apply & Start is
available on every page.

Below the panel, the loading screen's own arrows and page bullets are regrouped into a
single row, `‹ • • • ›` (`MatchRulesPager`), and restyled like the settings:
- The arrows are slate buttons with a gold chevron and a gold border on hover. Each
  glows until first hovered or pressed.
- At the first or last page the arrow dims and is disabled rather than hidden, so the
  row does not shift.
- The current page is a gold pill. Bullets of unvisited pages glow like their tabs, and
  visited ones are grey; bullets are clickable.
- The loading-screen frame art (with the notch under the bullets) is removed in settings
  mode. Other maps keep the original hint pager.

Other lists All Vision, Infinite Rerolls, Longer Wards and Invincible Wards in that
order. Infinite Rerolls (999 instead of 30) defaults on, as does Longer Wards
(60-minute Observer/Sentry lifetime, including Sentry detection, and initial
Observer shop stock of four per team). Reroll
prices still follow the Epic-Only setting. Items contains Divine Rapier and Dagon
(all levels), both default on. Settings remain host-only and lock before picking.

Disabled item assemblies are disassembled by the engine into their components
and recipe, with native combine locks to prevent an immediate rebuild. Components
can be unlocked for other recipes. Inventory events and the inventory filter
cover hero/courier assembly, stash and quick-buy paths. Purchase and item-use
orders are also checked. No global item whitelist is used: it greys out custom
replacement items. Other maps retain the Rapier/Dagon restrictions.

`host_settings_smoke.lua` checks defaults/setup, rerolls and placed wards in a
disposable local game. `host_items_smoke.lua` checks hero/courier assembly with
options on/off, component preservation and an unrelated shared-component recipe.

Kill Goal scales the starting match limit as DEFAULT_MATCH_LENGTH * (Kill Goal / 30).
DEFAULT_MATCH_LENGTH is 1200 seconds: 30 kills gives 20 minutes, 60 gives 40 minutes.
The same limit is used by the server and published to the HUD.

Because the host fixes the Kill Goal, the early-game "+1 kill goal" menu
(`early_consumables_menu`: the vote, GG Token and Double MMR Token) is never shown on
this map, and the server ignores a vote there. Before this change, a vote left the goal
unchanged but still extended the time limit. Other maps keep the menu.
`test_early_consumables.lua` covers both cases.
Using a GG Token (e.g. from the collection) is refused before it is consumed, with
"The host set the Kill Goal, so it can't be changed"
(`WebInventory:ItemConsumeEvent`, covered in `test_free_collection.lua`).
`kill_goal_lock_smoke.lua` checks the vote, the menu state and the token in a tools match.

## Free local collection

Premium benefits (tier 2) and all 269 bundled collection items are available in
this addon without purchases or currency. Vanity items can be equipped directly;
consumable collection items have a reusable local supply. The shop displays
"Premium & Vanity - Free" and omits currency, subscription and gift-code purchase
controls. Host-configured orb reroll allowances are unchanged.

Unlocks and equipment selections are local to the running match. Account
subscription data and balances are not rewritten. Equipment sync, payments,
inventory writes and match reward submissions to the original backend are blocked.
`test_free_collection.lua` checks local entitlements, item use and backend-write
isolation; `free_collection_smoke.lua` checks native access and equipping.

## Backpack Items

**Backpack Items**, below Epic-Only in Core, defaults off. When on, items in a
hero's three backpack slots keep working:

- Passive items, stat bonuses and the passives of active items apply as in main
  slots. Only the first copy of each item name in the backpack works; duplicates
  stay inactive. A copy in a main slot does not deactivate one in the backpack.
- Linken's Sphere, Aeon Disk, neutral items and recipes stay fully inert.
- Swapping Linken's Sphere or Aeon Disk between main slots and the backpack (either
  way) puts both swapped items on a 6 second cooldown; a longer cooldown already
  running is kept. A freshly swapped Linken's Sphere therefore cannot block.
- Clicking a backpack item uses it: no-target items cast at once, targeted items
  start the normal targeting cursor. Backpack slots still have no hotkeys.
- Moving items from the backpack into main slots has no reactivation delay, and
  backpack cooldowns recover at the normal rate.
- Moving items between main slots and the backpack never interrupts their stats
  or passives, however quickly they are switched.

The server equips backpack items with the engine's own `OnEquip`, so each item's
native modifiers apply without being moved. It also marks each active backpack
item with `SetCanBeUsedOutOfInventory(true)`, so the engine casts it natively like
a main slot item: validation and error messages, walking into cast range, turning,
and every cast event (invisibility and fountain protection break, Linken's Sphere
and Lotus Orb react). The flag is cleared again when an item leaves the backpack
or stops being active (a duplicate, or moved to the stash); illusions never get it.
`BackpackItems:FilterOrder` only refuses casts of inactive copies and toggles,
with an error.

The engine unequips both items whenever a swap crosses between main slots and
the backpack, and re-equips the main slot one only later. The order filter
therefore performs those moves itself (`BackpackItems:MoveItem`) and re-equips
both items in the same server step; health and mana keep their percentages.
Moves within main slots, within the backpack or to the stash stay native. Other
inventory changes are reconciled every server tick.

Limits: toggle items (Armlet) are refused: the engine toggles them in the
backpack, but their toggled effect needs a main slot. Channelled items (Meteor
Hammer) work. The engine drops shift-queued backpack casts. An item entering the
backpack becomes castable on the next server tick. Illusions get the passives but,
as usual, cannot use items; Tempest Double can. Apart from the Linken's Sphere /
Aeon Disk rule, there is no swap delay.

`test_backpack_items.lua` covers the rules, uniqueness, exclusions, the cast flag
and order checks. `backpack_items_smoke.lua` checks them in a disposable tools
match, including a Scythe of Vyse cast from out of range.
`backpack_items_multiplayer_smoke.lua` simulates a match with three bot players on
separate FFA teams: casts between players, Linken's Sphere / Aeon Disk / Lotus Orb,
invisibility and fountain protection, hero swaps, illusions and Tempest Double
(`backpack_items_multiplayer_off_smoke.lua` runs it with the option off).

## Player tips

Tipping works like Dota Plus / Battle Pass tipping, but no currency is moved.
Every player row on the scoreboard except your own has a **Tip** button. Allies
and enemies can both be tipped. A tip:

- shows a 6 second toast to all players: tipper portrait, the Glory icon with
  "50", target portrait (the original Overthrow 3.0 `player_tip` toast), restyled after
  Dota's own tip notification as a compact dark card (`toasts.css`). Each
  portrait has a player-colour strip underneath; players without a Steam account
  (bots) show their name as plain text. The card glints once as it slides in
  and the coin pops (CSS keyframes). The tipped player sees a gold frame with a single
  pulse (`TipToLocalPlayer`) and hears a
  second chime (`Loot_Drop_Sfx_Minor` after `General.Coins`). At most three tip
  toasts are on screen at once; the oldest leaves early;
- posts a chat line to all players, worded like Valve's `DOTA_Tip_Chat`:
  "<tipper> has tipped <target> [coin] 50 Glory!". Names use
  `C_CHAT_ENUM.PLAYER_COLOR_READABLE`, which lifts dark player colours (FFA
  Brown, Blue, Purple) towards white to a luminance of 0.45 so they stay readable
  on the chat background. Brighter colours are unchanged;
- adds one to the target's `tips_received` stat. On the end screen, each tipped
  player's row shows a Glory icon and the count, with a "Tips received" tooltip.

Nobody gains or loses Glory; "50" is display only (`TIPS_CURRENCY_PER_TIP`).
There is no reason field and no way to refuse a tip, so what a tip means depends on
when it is sent. Each player can send 3 tips per match (`TIPS_PER_GAME_MAX`), with a
30 second cooldown between them (`TIPS_COOLDOWN`). The server enforces both and
shows the existing error messages; the Tip button is greyed out while either limit
applies. Self tips are ignored. Tipping is always on, on all maps.

Tips never reach the original backend. The daily and subscription-tier limits,
the `api/lua/match/tip` request, which sent both players' Steam IDs, and the
developer bypass were removed.
`test_tips.lua` covers the rules and the absence of HTTP requests, and
`panorama_test.js` covers the button state and the end-screen badge.
`tips_smoke.lua` checks tips between player 0 and two bot players in a tools match,
then shows a toast, a chat line and the end screen for screenshots.

## Fountain smoke (All Vision)

All Vision turns off the engine's fog everywhere, so enemies could watch every
fountain. With All Vision on (configurable FFA map only), a team's heroes and units
inside their own fountain zone (the fountain aura, radius 1,194 around the tower)
are smoked:

- invisible to enemies, including true sight (Gem, Sentry Wards) and the minimap;
- the smoke never breaks while inside, even with enemies nearby;
- the owning team sees the Smoke of Deceit particle (`smoke_of_deceit_buff`,
  created per team) and the usual translucency;
- couriers are not covered.

The effect ends about 0.5 s after leaving the zone (aura linger). It lives in
`modifier_fountain_rejuvenation_effect_lua`. The server decides in `OnCreated`
and passes the decision to clients through the stack count, which `CheckState` and
the invisibility level read. `test_fountain_smoke.lua` covers the rules;
`fountain_smoke_smoke.lua` checks it in a tools match with an enemy bot.

