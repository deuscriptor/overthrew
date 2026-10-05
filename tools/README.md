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
Gifting orbs is removed: the minimap gift-orb buttons and the gift-orb items
(Legendary Lagresse, Breathtaking Benefaction) are gone, so no rare/epic orb can
be gifted to every team.
The top-left menu has Dashboard, Dota Settings, Scoreboard and Collection; the
In-Game Settings, Inbox, Leaderboard, Feedback and Promo Events buttons and the
new-mail banner were removed with the backend (see "Backend removal"). Randomed
heroes receive Faerie Fire and Enchanted Mango; Infused Raindrop is no longer included.
**Kill Goal** is a numeric input at the bottom of Core, prefilled with 50. The
host can enter a positive whole number. Apply locks this as the match's fixed
kill cap and updates the scoreboard; disconnects no longer alter it on
configurable FFA. Existing match-time adjustments still apply.
Single Draft and Turbo are on by default; Epic-Only is off. Settings replace
the guides/videos as the only first page on configurable FFA; page indicators
and navigation remain for future settings pages. The menu shows category
tabs, options, and the apply button; it omits explanatory paragraphs. Each option
row shows an on/off switch and a one-line hover tooltip (`host_rules_<name>_tip`),
and Kill Goal shows the resulting base time limit (40 seconds per kill).
**Apply & Start** freezes the settings; the loading screen fades out and hero selection begins half a
second later (see "Texture memory"). There is no
automatic host: the settings stay hidden (the usual loading tips show instead) until
setup has begun and every player has loaded, so nobody edits them before the others
arrive. After 120 seconds of setup, players still loading are skipped, so setup cannot
stall. Then every player sees the current settings read-only (switches greyed out:
desaturated and half-transparent) and a gold-lit **Claim
host** card in Apply & Start's place, with the same size and position. The first
player to claim becomes the host (the server accepts one claim, and the button sends
one request at a time). A host who disconnects or abandons before starting frees the
role, and anyone can claim again; a returning player does not get it back. The rules
lock with the host once started.

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
uses its original item names/icons; rewards follow the selected rule. The source
rarity is kept separately for orb placement and never downgrades a reward.
Rerolls start at 30 and cost their original 1/2/4 with normal orbs, or always 1 with
Epic Orbs.

Only `ot3_necropolis_ffa` is registered. The other Overthrow maps (`ot3_gardens_duo`,
`ot3_jungle_quintet`, `ot3_desert_octet`, `ot3_demo`) and the earlier separate-map
variants (`ot3_ffa_epic`, `ot3_ffa_epic_draft`, `ot3_ffa_draft`) were removed with their
map packages, overviews, shops, upgrade overrides, Duo/Quintet/Octet and epic-only shop
orbs, and the variant build tools. `run_tests.js` fails if a map package, overview, preview
image, shop or upgrade override exists for a map that is not registered. The Hero Demo tooling
(`game/demo`, the `ot3_demo` Panorama panel) still loads in Tools mode on the FFA map,
where the smoke scripts use it. Lua and the editable Panorama scripts no longer branch on
the map name. The removed maps are still named in places that never match: `ot3_demo` checks
in the demo panel and selected upgrades, and style rules for the other maps (loading screen, end
screen, team selection). Their preview images went with issue #34 (see "Package contents").

Localization: the addon ships English (`resource/addon_english.txt`, the default
and fallback for every other client language), Russian
(`resource/addon_russian.txt`) and Ukrainian (`resource/addon_ukrainian.txt`).
Every token added, renamed or removed in one file must be changed in the other
two in the same commit, with real translations rather than copied English text.
Russian keeps item, hero and game-mode names (Divine Rapier, Dagon, Aeon Disk, Single Draft,
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

## Single Draft and Epic-Only smoke checks

Single Draft gives each player one Strength, Agility, Intelligence and Universal hero,
drawn from the addon's enabled heroes. No hero appears in more than one player's offers,
and offers persist across reconnects. The native picker enforces per-player
availability; the custom Random button chooses only from that player's four heroes. Smart
random (a backend feature) is removed, and the supporter pick-delay overlay is bypassed.

Run these in a disposable Tools-mode session on `ot3_necropolis_ffa`:

- `script_reload_code single_draft_smoke` (Single Draft on) checks the offers and any
  selected hero.
- `script_reload_code single_draft_random_smoke` (Single Draft on, during hero
  selection) deliberately randoms player 0 from their offers.
- `script_reload_code standard_single_draft_smoke` (Single Draft on, Epic-Only off,
  after a hero initializes) checks real shop-orb rewards and reroll spending. It grants
  three item rewards and spends 7 reroll points (of 999 with Infinite Rerolls, else 30).
- `script_reload_code epic_only_smoke` (after addon initialization) checks the FFA
  layout, world entities and that physical common/rare/epic orbs follow the Epic-Only
  setting. It removes its three temporary capture units. Once a hero is initialized, it
  also queues three rewards through the real selection renderer.

## Automated checks

With Node.js available:

```text
node tools/run_tests.js
node tools/panorama_resources.js verify
node tools/panorama_test.js
```

The Lua test harness executes production code with mocked engine services. Its
pinned development-only runner can be restored with
`npm ci --prefix tools/runtime --ignore-scripts --no-audit --no-fund`.
Panorama resources, sources and regeneration are described in
[panorama_README.md](panorama_README.md).

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
who used them; unspent choices remain queued. Refunds do not grant new starting rewards.

A swapped hero keeps its pre-game stun. The stun is re-created under the hero's new team
with the time it had left. The old stun still counted as coming from the previous team,
so the new fountain's debuff immunity suppressed it: the hero could walk until it left
the fountain and was then stunned. `swap_pregame_stun_smoke.lua` reproduces this in
Tools (which skips the production stun) and checks the fix.

An accepted swap waits until each hero is precached with its new owner's cosmetics
(`HeroSwaps:PrecacheHeroFor`: `PrecacheUnitByNameAsync` with the new owner's player ID, once
per hero and player for the match), which usually takes a fraction of a second. A pick
precaches the hero with its picker's cosmetics only, while the engine dresses its copies of
a hero, such as Arc Warden's Tempest Double, in their owner's cosmetics. So a swapped Arc
Warden's Tempest Double wore cosmetics no client had loaded, and players crashed or
disconnected, depending on what the new owner had equipped (issue #26).
`hero_swaps_tempest_smoke.lua` swaps a bot's Arc Warden to player 0 and casts Tempest
Double. With an account that has Arc Warden cosmetics equipped, it crashed the Tools client
before the fix, with "requested is not loaded" errors for those models.

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

The setup menu has one category per page: Core, Balance, Items, Other. Clickable
Core/Balance/Items/Other tabs switch pages, and unvisited tabs glow gold. Apply & Start is
available on every page. Balance holds Fountain Sloth (see "Fountain Sloth").

Below the panel, the loading screen's own arrows and page bullets are regrouped into a
single row, `‹ • • • • ›` (`MatchRulesPager`), and restyled like the settings:
- The arrows are slate buttons with a gold chevron and a gold border on hover. Each
  glows until first hovered or pressed.
- At the first or last page the arrow dims and is disabled rather than hidden, so the
  row does not shift.
- The current page is a gold pill. Bullets of unvisited pages glow like their tabs, and
  visited ones are grey; bullets are clickable.
- The loading-screen frame art (with the notch under the bullets) is removed in settings
  mode.

Other lists All Vision, Infinite Rerolls, Longer Wards and Invincible Wards in that
order. Infinite Rerolls (999 instead of 30) defaults on, as does Longer Wards
(60-minute Observer/Sentry lifetime, including Sentry detection, and initial
Observer shop stock of four per team). Reroll
prices still follow the Epic-Only setting. Items contains Divine Rapier, Dagon
(all levels) and Aeon Disk, all default on. Settings remain host-only and lock before picking.

Disabled item assemblies are disassembled by the engine into their components
and recipe, with native combine locks to prevent an immediate rebuild. Components
can be unlocked for other recipes. Inventory events and the inventory filter
cover hero/courier assembly, stash and quick-buy paths. Purchase and item-use
orders are also checked. No global item whitelist is used: it greys out custom
replacement items.

`host_settings_smoke.lua` checks defaults/setup, rerolls and placed wards in a
disposable local game. `host_items_smoke.lua` checks hero/courier assembly with
options on/off, component preservation and an unrelated shared-component recipe.

Kill Goal scales the starting match limit as DEFAULT_MATCH_LENGTH * (Kill Goal / 30).
DEFAULT_MATCH_LENGTH is 1200 seconds: 30 kills gives 20 minutes, 60 gives 40 minutes.
The same limit is used by the server and published to the HUD.

The host fixes the Kill Goal, and nothing else changes it during the match. The original
early-game "+1 kill goal" vote and the GG and Double MMR Tokens were removed with the
backend (see "Backend removal").

## Free local collection

Every player has the top premium tier (tier 2, "Golden Supporter") and owns every bundled
cosmetic, locally and for free. `WebPlayer` reports a fixed local subscription
(`{tier = 2, type = "local"}`) and `WebInventory` treats every item in `ITEM_DEFINITIONS` as
owned; nothing is bought, granted, synced or saved. Tier 2 gives every player:

- the third (supporter-only) choice in every orb selection and the Generic Upgrades toggle;
- eight favourite-upgrade builds (instead of two) and the favourite auto-select with its delay;
- the supporter courier speed bonus;
- no hero pick delay, and the supporters' protection threshold in kick votes.

The 139 cosmetics are auras, pets, kill effects, cosmetic skills, high fives, sprays and hero
effects, with no unlock conditions. The Collection has one tab, Cosmetics, opening on Auras;
its header shows the player's tier and "Premium & Vanity - Free". Items equip and unequip
directly. Equipment, favourite builds and the orb selection's settings (Generic Upgrades,
auto-select and its delay; `WebSettings`) last for the running match. Host-configured orb
reroll allowances are unchanged.

`test_free_collection.lua` checks the local tier, that every cosmetic is owned and free,
item validation, per-match settings and that no HTTP request is made.
`free_collection_smoke.lua` checks access and equipping in a Tools match. `run_tests.js`
checks that the client's item list (`scripts/collection_generated.js`) names exactly the
server's items.

## Backend removal

The original addon talked to the Overthrow backend (`api.overthrow3.dota2unofficial.com`,
authenticated with the dedicated server key) for player data, purchases, rating and most
account features. This fork runs in Local Host lobbies, where none of it works: in a real lobby
(`console.9019653788.log`, 2026-09-28) the server reported `ActivateServerFromLobby - IsLan:
YES, IsDedicatedServer: NO`, sent the before-match request and never got an answer, and a
Tools match ended with "Failed to load match data from remote server" on the end screen.
Issue #39 removed the backend client and everything that only worked through it:

- **Account and shop:** the HTTP client (`WebApi`), the before- and after-match requests,
  rating and its end-screen column, season resets, player stats, locale reporting, error
  reports, mail, leaderboards, payments and currency top-ups, subscriptions, gift codes,
  feedback, promo events, the Battle Pass and seasonal events (Christmas orb effects).
- **Gameplay boosts:** Misc items and treasures: Lucky Trinkets, Early Bird Charm, Power
  Crystal, Conqueror's Presence, Teamwork Enhancer, reroll packs, GG and Double MMR Tokens, the
  trial subscription and the gift orbs; the early-game "+1 kill goal" vote; win-rate orbs.
- **Screens and HUD:** smart random, hero challenges and win streaks, the loadout promo, MVP
  rewards, the In-Game Settings window, tournament mode and the loading screen's event banners.
- **Chat wheel:** the in-game wheel, its sounds, colours and emoji, and its Collection page.

What stays, all local to the match: the free collection and tier 2 (above), equipment,
favourite builds and the orb selection's settings, player tips, the end screen (MVP,
statistics, tips received) and kick votes. Code that ran only for removed features went with
them: 31 Lua scripts, 88 Panorama resources, 277 images, 13 particles (Christmas orbs and
unreferenced supporter-gift effects), the chat wheel's soundevents, the treasure wheel scene
(`maps/collection/spin_glow.vpk`), 710 localization tokens, their manifest entries, top-menu
buttons and minimap panels.

The Panorama layouts that had to change (manifest, top menu, collection, cosmetics, scoreboard,
end screen, loading screen, minimap, chat, toasts, upgrades panel, pick-screen player row) now
have editable XML sources (see [panorama_README.md](panorama_README.md)). `run_tests.js` fails if
a Lua script creates an HTTP request, reads the dedicated server key or names the backend
host, if the client and server item lists differ, or if a Panorama resource, source, Lua script
or localization file references a `custom_game` image, layout, script or style that does not
exist.

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
inventory changes are reconciled every server tick. An illusion's inventory never
changes, so each illusion is reconciled once, on the first tick it exists; Monkey
King soldiers are reused and stay in the per-tick pass.

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
applies. Self tips are ignored. Tipping is always on.

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
- there are no smoke visuals: no particle, and the invisibility level is 0, so the owning team sees an
  opaque model with the dark fountain protection look (see Fountain protection) instead of the translucent
  invisibility model;
- couriers are not covered.

The effect ends about 0.5 s after leaving the zone (aura linger). It lives in
`modifier_fountain_rejuvenation_effect_lua`. The server decides in `OnCreated`
and passes the decision to clients through the stack count, which `CheckState` reads. `test_fountain_smoke.lua` covers the rules;
`fountain_smoke_smoke.lua` checks it in a tools match with an enemy bot.


## Fountain protection

On the configurable FFA map a fountain is a safe zone for its own team. The zone is the same as
fountain rejuvenation (radius 1,194 around the tower) and covers heroes and units alike. It exists to
stop deaths on the fountain and spawn-camping, and to stop damage dealt from the safety of the base.
The protection ends as soon as a unit leaves the zone by any means (walking, blinks, teleports, forced
movement); there is no linger.

While protected, a unit:

- turns black with light marbled streaks, like a dark hero under Dota's own AFK fountain invulnerability;
- is disarmed;
- deals no damage of any kind (attacks, spells, damage over time applied earlier, HP removal,
  self damage);
- cannot capture or contest orbs (`capture_point_area:ValidCapturingUnit`);
- cannot be targeted by enemies and takes no damage of any kind.

Debuffs are not restricted: a protected unit can stun, slow or hex enemies with its abilities and auras,
though any damage they carry is dropped while it stays on the fountain. Damage over time it applied
there hurts again once it leaves.

Fountain rejuvenation's own aura still lingers 0.5 s, so its debuff immunity, which also stops pure
damage, covers the first half second after leaving.

`modifier_fountain_protection_lua` is an aura on each tower (added in `GameLoop:InitTowers`) with an aura
duration of 0, so the effect is removed on the aura's next update after the unit leaves the zone. The
effect blocks incoming damage with the absolute no-damage properties and sets the disarm and
enemy-untargetable states. `Filters:FountainDamageFilter`, registered only on this map, drops damage from
and to protected units (`FountainProtection:Protects`), which also catches HP removal and flagged damage.
It costs two modifier lookups per damage instance; the older full damage and modifier filters stay disabled.

The look is the status effect of Dota's own AFK fountain invulnerability. In `client.dll`,
`CDOTA_Modifier_FountainInvulnerabilityBuff` (found through its RTTI vtable) returns
`particles/status_fx/status_effect_dark_willow_shadow_realm.vpcf` from vtable slot 89, the status effect getter:
Dark Willow's Shadow Realm buff returns the same particle from the same slot. Slot 91 returns 20000 (Shadow
Realm: 20010), the status effect priority. No other function of that modifier references a particle. The
status effect drives the hero shader with `materials/models/heroes/statuseffects/colorwarp_icechrome.vtex` and
`electric.vtex`. It keeps the model's own brightness: dark heroes (Primal Beast) turn black, light ones (Sven)
icy chrome.

`modifier_fountain_protection_effect_lua` returns that status effect with priority 20000, and tints the model and
its cosmetics (`dota_item_wearable`, `additional_wearable` and `prop_dynamic` children) to render color 40,
so every hero turns black like a dark one. It re-applies the tint every 0.5 s for cosmetics equipped on the fountain,
and restores 255 when it ends; nothing else in the addon sets render colors. The engine reads a status effect only
when its modifier is created, which is enough because the look lasts as long as the effect. The particle is
precached in `precache.lua`: without it, the native modifier added from script showed no effect.

`test_fountain_protection.lua` covers the aura, the effect states, the look and tint, and the damage filter.
`fountain_protection_smoke.lua` checks it in a tools match: on the fountain (no damage either way, debuffs
land, the effect stays one instance), the protection ending at once after leaving, a real Storm Bolt cast
right after leaving, the look and tint at each step, and a real orb at the zone's edge: protected Sven
doesn't capture it, and captures one step outside.

## Fountain Sloth

**Fountain Sloth**, the only option on the Balance page, defaults on. A hero on its own fountain (the fountain
protection zone, radius 1,194 around the tower) recovers ability cooldowns at half speed: each second of cooldown
takes two. It exists so that waiting out cooldowns in the safety of the base costs time.

- It covers ability cooldowns and charge restores, including those already running when the hero arrives.
- Item cooldowns are unaffected.
- Leaving the zone restores the normal speed at once; there is no linger.
- Each spawn of a hero (the first spawn, every respawn and buyback, a new Tempest Double or Meepo clone) starts a
  5-second grace period of game time, so pauses don't count. The sloth applies only after it ends.
- Illusions are never slowed.
- A respawned hero that stays idle keeps Dota's fountain invulnerability (`modifier_fountain_invulnerability`),
  which makes it invulnerable and out of game until it acts. Fountain protection and rejuvenation don't reach it
  then, but the sloth does.
- While slowed, the hero shows a **Fountain Sloth** debuff with the Time Dilation icon.

`FountainSloth:ApplyRules` (`game/fountain_sloth.lua`) runs when the rules lock. With the option on, it adds
`modifier_fountain_sloth_lua` to each fountain tower and records each hero's spawn from the raw `npc_spawned`
event. That event fires during the spawn, so the grace period begins before the aura can see the hero. The aura has
an aura duration of 0. It searches friendly heroes with `DOTA_UNIT_TARGET_FLAG_INVULNERABLE +
DOTA_UNIT_TARGET_FLAG_OUT_OF_WORLD`, and rejects illusions and heroes still in their grace period
(`GetAuraEntityReject`). With the option off there is no aura.

The engine offers no direct way to slow a running cooldown from script:

- `MODIFIER_PROPERTY_COOLDOWN_PERCENTAGE_ONGOING`, which Visage's Lurker uses, is never called on a Lua modifier:
  a counting handler saw zero calls and no value changed the speed, while the native Lurker sped cooldowns up.
- `StartCooldown` restarts the HUD's cooldown sweep at full, so extending the remaining time each tick would keep the
  sweep full.
- `SetFrozenCooldown` pauses a cooldown and keeps the number and the sweep where they are. It also pauses charge
  restores: a 20 s restore took 28 s with 8 s frozen. Freezes are counted: two freezes need two thaws.

So `modifier_fountain_sloth_effect_lua` freezes every recovering ability for every other 0.1 s think (three
server ticks). A recovering ability is one on cooldown, or one below its maximum charges. The next think thaws
exactly the abilities it froze, and so does the end of the effect (leaving, death). Freezes from other sources are
kept. The HUD's number and sweep advance at half speed in 0.1 s steps. The effect costs one ability scan every
0.2 s for each hero on its own fountain after the grace period.

`test_fountain_sloth.lua` covers the aura, the grace period, the rules and the freeze cycle.
`fountain_sloth_smoke.lua` checks it in a tools match. `fountain_sloth_off_smoke.lua` checks the option off in a
fresh session. The smoke checks:

- the cooldown speed on and off the fountain, and of items;
- an invulnerable hero and an illusion on the fountain;
- a death on the fountain, which thaws the cooldowns;
- the grace period after a respawn and after a buyback.

## Illusions and performance

Heroes with many illusions (Phantom Lancer above all, also Naga Siren, Terrorblade, Chaos Knight or
Manta Style) made the server lag: every attack, damage instance and modifier application anywhere got slower
with each illusion alive, so Pangolier's Swashbuckle through a crowd of Phantom Lancer illusions stalled the
server (issue #24). Measured in Workshop Tools with `illusion_perf_smoke.lua`:

- The engine visits every Lua modifier of every hero unit, illusions included, on each attack or damage
  instance anywhere on the map: about 40 calls to the default `GetPriority` per Lua modifier, through the script
  VM. Creeps carrying the same modifiers cost nothing. Each illusion copied the hero's upgrade modifiers (one per
  generic upgrade, plus the ability upgrade controller, the primary attribute reader and the BAT handler), so
  with 30 illusions of a hero with 14 generic upgrades one damage instance cost 14 ms, against 0.7 ms without
  illusions. Defining `GetPriority` in Lua does not avoid the calls; fewer Lua modifiers do.
- A modifier that declares a global event (`MODIFIER_EVENT_ON_MODIFIER_ADDED`, `MODIFIER_EVENT_ON_TAKEDAMAGE`,
  ...) is called for every such event on any unit, once per modifier instance. The BAT handler, on every hero and
  illusion, handled every modifier added anywhere.
- Killed illusions stay in the world for 5-15 seconds and keep the modifiers that are not removed on death, at
  the same cost per event. The `entity_killed` game event does not fire for illusions, but the engine asks each
  modifier's `RemoveOnDeath` when the unit dies.
- The kill-leader crown is not a factor: the leader is decided on real hero kills only (`GameLoop:OnUnitKilled`
  ignores illusions), `modifier_kill_leader` is not copied to illusions, and a crowned hero's illusions cost the
  same. (So the crown does tell the real hero from its illusions.)

What the code does:

- Global modifier events have a single listener, `modifier_event_proxy` on the overboss. Modifiers on heroes and
  illusions that need an event for their own unit register with `UnitEvents` (`libraries/unit_events.lua`)
  instead of declaring it: the BAT handler and Status Resistance on Disable (modifiers added to the parent),
  Universal Lifesteal (damage dealt by the parent) and Magic Resistance Reduction (spells cast by the parent).
- An illusion carries its generic upgrades in one modifier, `modifier_illusion_generic_upgrades`, instead of one
  per upgrade: 18 modifiers instead of 30 in the measurements below. Each hosted upgrade runs its own modifier
  class as a plain object (`game/upgrades/illusion_generic_upgrades.lua`), and the host forwards the engine's
  property calls to the upgrades implementing them, summing the stats several share. `IllusionGenericUpgrades.HOSTED`
  lists the upgrades that can be hosted: hidden, with no thinker, particle effect, state, transmitted data or
  global event, and only properties the host declares. Universal Shield and Flying Movement show a buff and stay
  modifiers of their own, as do all upgrades of heroes, Meepo clones, Tempest Double and summons.
  - The engine asks a modifier for its declared functions before creating it, and clients get its transmitted
    data before `OnCreated`, when `GetParent` fails. So the host declares every hosted property, the server passes
    the counts as creation keys (`generic_armor = 2`), and both sides build the upgrades in `OnCreated`. The
    upgrades never change: processing an illusion again (Monkey King soldiers, hero swaps) creates a new host.
  - With hosted upgrades an illusion has the same stats as with upgrade modifiers, on the server and on clients.
    On the server the engine applies no armor or magic resistance from Lua modifiers to illusions, hosted or not
    (clients show them); that predates this change.
- Generic upgrade modifiers, the host, the ability upgrade controller and the primary attribute reader return
  true from `RemoveOnDeath` on illusions that do not come back (`CDOTA_BaseNPC:IsIllusionGoneOnDeath`; Monkey
  King soldiers and Tempest Double excluded), so a killed illusion keeps only engine modifiers. Heroes keep them
  through death as before.
- A clone's stats are recalculated once after its generic upgrades are applied, not once per upgrade; summons
  with generic upgrades too.
- The BAT handler recalculates for modifiers added to its own unit only, and keeps one expiry watch on the timed
  modifier that sets the BAT. It used to start another per-frame timer, printing to the console, for every
  modifier added while such a buff was active.
- Backpack Items reconciles each illusion once (see above).
- Cosmetics (issue #31): illusions keep their hero's look (aura, hero effect particles and colours), so they can't
  be told apart, but cost no extra Lua modifier and don't outlive their death:
  - A hero effect's status effect (its `PATTACH_SPECIAL_STATUS_FX` part, which recolours the model) comes with
    the illusion's host, `modifier_illusion_generic_upgrades` (creation key and transmitted `status_fx`), instead
    of a `modifier_hero_status_fx` per illusion. Before, it added a Lua modifier to every illusion: +19% damage
    processing cost with 30 illusions. The hero, Meepo clones and Tempest Double keep `modifier_hero_status_fx`.
  - An illusion whose owner has cosmetics equipped always gets a host, even without generic upgrades.
    `Equipment:GetCopiedLook` tells `Upgrades:AddIllusionGenericUpgrades` the status effect and whether lasting
    particles are copied (auras, hero effects; not kill effects, pets, sprays, cosmetic skills or high fives).
  - The cosmetic particles were destroyed on `entity_killed`, which doesn't fire for illusions, so killed
    illusions kept them for their 5-15 seconds in the world. The host now destroys them when the engine removes it
    at death (`RemoveOnDeath`, illusions that don't come back). A live illusion that gets a new host (Monkey King
    soldiers, hero swaps) keeps them. Meepo clones still drop theirs on `entity_killed`.
  - Living illusions still draw their auras and hero effects: with 30 on screen they add about 0.36 ms of client
    frame time, the price of looking like the hero.
  - Cosmetics equipped or removed while illusions exist apply to illusions created afterwards, as before.

Server wall-clock times with 30 Phantom Lancer illusions, both heroes level 30 with the same 14 generic upgrades
and items (same machine, Tools mode): before, with the event routing and death cleanup, and with hosted upgrades.

| 30 illusions | Before | Routed events | Hosted upgrades |
| --- | --- | --- | --- |
| Illusion setup (`ProcessClone`, next frame) | 1343 ms | 46 ms | 16 ms |
| Illusion spawn (`CreateIllusions`) | 187 ms | 72 ms | 80 ms |
| One modifier added anywhere | 5.1 ms | 0.18 ms | 0.17 ms |
| One damage instance, illusions alive | 14.3 ms | 4.7 ms | 1.4 ms |
| One damage instance, illusions just killed | 11.0 ms | 0.42 ms | 0.43 ms |
| Four Swashbuckle strikes (scripted attacks) | 3838 ms | 1959 ms | 630 ms |
| Real Swashbuckle cast, worst frame | 507-1055 ms | 142-230 ms | 40-87 ms |
| Backpack Items reconcile, per second | 11.0 ms | 2.0 ms | 1.0 ms |

With 10 illusions a damage instance costs 0.66 ms (was 3.5 ms), four Swashbuckle strikes 104 ms (was 402 ms) and
the real cast's worst frame 41-49 ms. Without illusions a damage instance costs 0.36 ms (was 0.7 ms) and a
modifier application 0.16 ms (was 0.51 ms). The server frame is 33 ms. What remains per illusion is the engine's
cost for its other Lua modifiers (the controller, the attribute reader, the BAT handler and the host).

`test_illusion_performance.lua` covers the event routing, the BAT handler, the death rule, the hosting rules
(every hosted upgrade qualifies, and shares only additive properties), the host on the server and the client, the
single stat recalculation, the hosted status effect, when an illusion gets a host for its cosmetics, which
cosmetics it copies and their removal at death; `test_backpack_items.lua` the reconcile-once rule.
`illusion_cosmetics_smoke.lua` (fresh Tools session, a few seconds) checks the status effect in the host, the copied
particles, their removal from a killed illusion and their survival on a live one processed again.
`illusion_perf_smoke.lua`
(fresh Tools session, about two minutes) prints the measurements above and checks that hosted upgrades give an
illusion the same stats as upgrade modifiers, a hosted attack proc, the routed lifesteal, disable status
resistance, magic resistance reduction and BAT handler, the backpack of an illusion and the modifiers left on a
killed one.

## Script log

Code that runs during play writes nothing to the console, so script errors stand out (issue #35). The server
used to print a line for every item change (including the items each new illusion receives), every server event dispatched without listeners, every accepted Panorama event and the expiry of its
token, and every hero kill (with the whole score table), death, orb spawn and capture, staged orb launch and
reroll. The projectile speed upgrade printed on every read of the property and Undying's Tombstone on every Flesh
Golem attack without the zombie facet. Each hero's upgrade data was dumped on its first spawn, and the order filter,
cosmetics (equips, precache lists, particle IDs), Dark Seer's Wall of Replica, the chat wheel (mutes and favorites)
and the disable-help toggle printed debug output.

Console output that stays: one-time lines (initialization, precache, game state changes, host claim, end-of-game
summaries), warnings about abnormal conditions, Tools-only request logging and chat command output.

`illusion_perf_smoke.lua` in Tools, from the bot's creation to `ILLPERF DONE` (about 30 seconds, waves of 10 and 30
Phantom Lancer illusions): 985 script lines besides the smoke's own before (762 of them item changes, 58 dispatches
without listeners), 4 one-time lines after. `test_log_noise.lua` runs the main per-event paths with `print` and
`DeepPrintTable` captured and fails on any output.

## Base game KeyValues

The server loaded every base game ability, item, unit and hero file into Lua tables at start-up
(`libraries/keyvalues.lua`, merged with the addon's custom and override files) for five lookups: each hero's
primary attribute (Single Draft) and guide name (smart random), the Shard's initial stock time (Turbo) and the two
neutral item flags (Backpack Items). Win rate setup loaded the base hero file again only to list hero names, and the
client loaded every ability for a function nothing called (issue #32).

- The lookups use the engine's `GetUnitKeyValuesByName` (heroes too) and `GetAbilityKeyValuesByName` (items too).
  They return the data the engine itself uses, with the addon's custom and override files applied (the Shard's
  120 s comes from `npc_abilities_override.txt`), and `nil` for an unknown name. Each call builds a new table:
  Single Draft's 127 heroes take about 10 ms, once, at Apply & Start. Backpack Items checks every backpack item each
  tick, so it looks each item name up once and keeps the answer.
- Win rates took hero names from `scripts/npc/herolist.txt`, like Single Draft. Win-rate orbs and smart random were
  later removed with the backend (see "Backend removal"), so only Single Draft, Turbo and Backpack Items remain.
- The client's ability table and `GetKeyValueNoOverride` are removed.

Measured in Workshop Tools, one client, during custom game setup right after the map loads (temporary probe with
`collectgarbage("count")` and `Plat_FloatTime`; the old loads were timed by running them again):

| | Before | After |
| --- | --- | --- |
| Server Lua memory | 7362 KB, of which 4376 KB KeyValues tables | 2852 KB |
| Client Lua memory | 1281 KB, of which 520 KB ability table | 761 KB |
| Server KeyValues tables | 54.7 ms | none |
| Win rate setup | 40.7 ms | 0.24 ms |
| Client ability table | 4.7 ms | none |

Before the switch, the engine functions matched the old tables for all 127 heroes (attribute and guide name), all
555 items (both neutral flags; 179 items are neutral), the Shard's stock time and the recipes' requirements and
costs. `run_tests.js` fails if a script under `scripts/vscripts` names one of the base files
(`scripts/npc/npc_abilities.txt`, `items.txt`, `npc_units.txt` or `npc_heroes.txt`).

## HUD script time

Four HUD scripts ran a `$.Schedule(0)` loop, every frame for the whole match (issue #33). Measured in Workshop Tools
with `vprof` (`$.Schedule() - run JS func`, 20 s, one hero idle on its own fountain, about 140 fps, same client):

| Scheduled HUD scripts | Before | After |
| --- | --- | --- |
| Time per frame | 0.345 ms | 0.152 ms |
| Calls per frame | 4.33 | 0.46 |

Inside an enemy fountain's ring the indicator runs every frame again: 0.301 ms and 1.40 calls per frame. What is
left comes from scripts on timers of 0.1 s and longer, about 65 calls per second.

- **Fountain range indicator** (`scripts/fountain_range.js`): it set the in-range, target and targeted controls of
  every enemy fountain's ring (7 on a full map) each frame, and forced the rings to simulate off-screen
  (`SetParticleAlwaysSimulate`). It now checks every 0.1 s and sends a control only when its value changes, so
  entering or leaving a ring, and holding Alt (every ring, target on its fountain), shows up to 0.1 s late. While the
  selected unit is inside a ring (attack range + 450) without Alt, it runs every frame and moves that ring's target
  to the unit, as before. The target marker (`fountain_indicator_alt_target`) follows its control point through
  `C_OP_PositionLock`, which does not track a control point attached to the unit (`SetParticleControlEnt`), and a
  marker moved every 0.1 s would trail a running hero. The rings are no longer forced to simulate, so the engine
  treats them like other world effects. That gain could not be measured: particles simulate off the main thread,
  and `cl_particles_dumpsimlist` shows no system asleep either way.
- **Chat** (`custom_chat/custom_chat.js`): the custom chat moves the lines Dota adds to its own chat panel into the
  custom chat area, and drops Dota's spacer panels, so both kinds of lines share one list. It checked Dota's panel
  every frame. Panel events bubble up to the parents: a new line raises `PanelLayoutInvalidated` on Dota's panel,
  and the line's own panels raise more. A handler on Dota's panel now schedules one move for the next frame when the
  panel has children, so lines still move one frame after they arrive. In Tools, a typed line and a
  `GameRules:SendCustomMessage` line each raised the event, idle chat raised none, and handlers registered by an
  earlier map load in the same client did not fire.
- **Top bar** (`top_bar/top_bar.js`): holding Alt shows the Tip button on the other players' slots
  (`.BAltPressed #TopBar_Tip`). It checked Alt every frame and now checks it every 0.1 s, changing the class only
  when Alt goes down or up, so the button can appear up to 0.1 s after the key. Dota sets its own `AltPressed` class,
  but only on 19 of its own panels (buffs, stats, buyback, XP and others), none of them a parent of the custom HUD,
  so the custom stylesheet cannot use it.
- **Collection** (`collection/collection.js`): it set `ShiftPressed`, `AltPressed` and `CtrlPressed` on `DotaHud`
  every frame. Their only use was to light the ×5, ×10 and ×50 quantity hints in the currency purchase dialog and
  the payments window, which never open with the free collection, so the loop is removed (both were later removed
  with the backend). Dota's own key styles do not depend on it: Dota sets `AltPressed` on its panels itself, and
  `ShiftPressed` and `CtrlPressed` on its quick buy.

`panorama_test.js` runs these scripts with mocked panels and particles: the fountain checks (interval, controls only
on change, per-frame target inside a ring only, a newly selected unit, Alt, no forced simulation), the chat redirect
(one move per arrival, spacers dropped, nothing scheduled while the chat is idle), and the top bar's Alt check
(interval, class only on change). It also checks that the collection reads no modifier keys.

## Texture memory

Custom UI textures took 76 MB mid-match (issue #30): loading screen art stayed loaded for the whole match, the
collection, end screen and team selection kept their art while hidden, images with an unused alpha channel were
stored uncompressed, and much of the art was larger than it is ever drawn. Measured in Workshop Tools with
`mat_print_textures_size_in_memory custom_game` (1 player, Dota window focused):

| Phase | Before | After |
| --- | --- | --- |
| Custom game setup (loading screen, host settings) | 33.2 MB | 22.6 MB |
| Hero selection | 28.3 MB | 4.2 MB |
| Mid-match | 76.4 MB | 9.7 MB |
| Mid-match, collection opened | 76.4 MB | 27.5 MB |
| End screen (collection opened before) | 76.4 MB | 33.0 MB |

3.6 MB of each "after" figure is the in-world spray decal materials (`*_spray_png_<hash>.vtex_c`), which are not UI.

How Panorama holds images, measured in Tools:

- A panel's images load as soon as the panel exists and its style applies, even when it or a parent is collapsed
  or transparent. `visible = false` frees nothing. Deleting the panel, `SetImage("")` and an inline
  `style.backgroundImage = "none"` free the texture at once; `ClearPropertyFromCode("background-image")` (the CSS
  name: `"backgroundImage"` leaves the override) brings a stylesheet image back.
- The custom loading screen stops being processed the moment the HUD replaces it. Its script still runs, but
  deletions and image changes made after that never take effect, so its art must be freed while it still updates.

What the code does:

- **Loading screen:** `HostOptions:ApplyRules` publishes the locked rules at once and ends setup 0.5 s later. When
  the locked rules arrive, the loading screen fades its content out (0.2 s) to its black background and deletes it.
  A player loading into a match already past setup gets the loading screen without its content. A client whose Dota
  window is not focused at that moment may not update in time and then keeps the art (Panorama does not lay out an
  unfocused window).
- **Team selection:** deleted once setup ends; not built at all for a player joining later.
- **Hidden until needed:** `ParkImages` (`scripts/utils.js`) overrides the stylesheet images of a layout and its
  children with an inline `none` and empties the given `Image` panels; the returned function restores them. The
  collection parks its art and builds its tabs (all cosmetics item images) on first open; code outside it reaches
  the cosmetics tab through stubs that load it first. The end screen parks its art until the game ends. (The
  leaderboard, promo events and season-reset notice, which parked theirs too, were removed with the backend.) A few
  small `Image` icons in the end screen (about 0.2 MB in total) stay loaded.
- **Encoding:** the Panorama compiler stores a PNG with an alpha channel uncompressed (RGBA8888, 4 bytes per pixel)
  and one without as DXT5 (1 byte per pixel), whatever the alpha values. Textures whose alpha is at least 245
  everywhere (at most 4% see-through, on edge pixels) drop it. Everything else really uses alpha, including the
  translucent panel backgrounds (alpha 214-220 over most of the image), and stays uncompressed.
- **Size:** textures shown in the UI are downscaled to 4/3 of the largest box they are drawn in (CSS pixels are
  1080p units, so they stay sharp up to 1440p), when that saves at least 10%. Boxes come from the stylesheets,
  from panel sizes measured in Tools, and for images set from scripts from the panels that show them (cosmetics
  items: cards and tooltips, 124 px). A texture drawn at its own size, or in a box that could not be resolved,
  keeps its size; so do textures this fork never shows.

`tools/panorama_textures.json` lists the 78 re-encoded textures with their size, whether alpha is dropped and
where they are shown (92 before 11 went with the backend features and 3 unused ones with issue #34). `node tools/panorama_textures.js build` regenerates them from the originals in commit
`bc5b937` (decoded from PNG, raw BGRA8888 or DXT including scaled YCoCg, downscaled by area in linear light with
alpha weighting, recompiled by Valve's resourcecompiler). `node tools/panorama_resources.js verify` checks that
the committed textures match the list and that no uncompressed texture keeps an unused alpha channel.
`panorama_test.js` covers the loading screen release, `ParkImages` and the texture decoding, resizing and PNG
encoding; `test_host_rules.lua` that setup ends only after the locked rules are published.

## Map textures

The map's two `ent_dota_lightinfo` entities reference `maps/ot3_necropolis_ffa/water_flow_map.vtex`,
`fog_flow_map.vtex` and `fog_opacity_map.vtex` (issue #36). Hammer bakes these next to a map, and Valve's maps and the
original Overthrow maps carry them in their VPKs, but the `ot3_necropolis_ffa` VPK does not. Without them the client
logged `Failed loading resource ... (ERROR_FILEOPEN: File not found)` for each at map load, then a burst of 50
`Texture manager doesn't know about texture "maps/ot3_necropolis_ffa/water_flow_map.vtex" ... returning error
texture` lines once the world was drawn.

The addon ships them as loose files in `maps/ot3_necropolis_ffa/`, which the engine loads as if they were in the VPK.
Each holds the uniform value Hammer bakes when nothing is painted, the same in Valve's `test_basic` and the original
Overthrow maps: source RGB (10, 20, 0), decoded (11, 20, 0), for both flow maps, and (0, 255, 0) for fog opacity. Like
Hammer's they are linear, DXT1, single-mip and exempt from texture quality (`NO_LOD`). A uniform texture samples the
same at any size, so each is one 4x4 block (2 KB per file). `node tools/map_textures.js build` recompiles them with
Valve's resourcecompiler (Windows, Workshop Tools). `run_tests.js` runs `map_textures.js verify`, which fails if one is
missing, is not single-mip DXT1, or holds other values.

Checked in Tools with All Vision off: screenshots of the centre pool from its south stairs (hero vision 1800 and 400)
match before and after, apart from animation. No water is visible on this map: its water plane (`phys_level_water`,
z ≈ 106) lies under the floor everywhere inside the walls (the centre pool's floor is at z ≈ 129), and only the void
outside them drops lower. Fog of war looks the same too. The fix removes the failed loads and error-texture lookups,
without a visible change.

## Package contents

Issue #34 removed 812 files (46.4 MiB) that the game never loads. The nine package entries went from 2,838 files
(103.2 MiB) to 2,026 (56.8 MiB):

- **Precache stylesheets** (31.5 MiB): `precache.css`, included by the HUD manifest, and
  `collection/cosmetics/cosmetics_precache.css` listed images under selectors no panel matches (`#CustomPrecache`,
  `.collection_cosmetics_precache`), so they loaded nothing. They made the compiler build images that scripts set at
  runtime; the addon ships its images compiled, so at runtime they did nothing. The 131 images only they named went
  with them, among them the old animated loading screen (`loading_screen/loading_seq_*`, 24 MiB), its banners and
  buttons, the guide art (`game_info`), unused Dota HUD imports and old scoreboard textures.
- **Images nothing names** (59, 6.1 MiB): the removed maps' previews; the large upgrade icons in `upgrades/` (the
  upgrade panel shows the ones in `upgrades/generics/`); the old 1 MiB minimap texture
  (`materials/overviews/ot3_necropolis_ffa_tga_*`, the minimap material uses
  `custom_game/maps/ot3_necropolis_ffa_png_*`); collection tab icons and currency art of removed tabs; icons of items
  and generic upgrades that do not exist (season 6 top-10/100 auras, the white high five, damage shield, extra common
  choice, health and mana on kill); the QR, Patreon and mail icons; the ox and rabbit team icons, which no team uses;
  the old kick vote's reason images.
- **Flash icons** (86, 1.1 MiB): `resource/flash3/images` icons no `AbilityTextureName` or `GetTexture` names (old
  neutral items, perks, seasonal items, ban hammer).
- **Throne models** (71, 6.5 MiB): the map places `npc_dota_kobold_overboss`, whose model
  (`midas_throne/kobold_overboss.vmdl`) embeds its mesh, morphs and animations, and the throne's desert cushions. The
  external meshes, morphs, animation groups and animations of an older compile were never loaded, nor were the radiant
  and underboss variants, the temp poses and the other thrones. Also two unused `gardenofskulls` models and the
  treasure courier wings' external meshes.
- **Particles** (444, 1.0 MiB): the chat wheel's sprays (`particles/sprays/chc_*`), aura sets no collection item uses
  (crystal, sunken and Diretide emblems, TI fountain effects), the fountain range's target marker from before #42, and
  old orb drop, last hit, ping, kill leader, promo and trap effects.
- **Other:** five UI scene maps (`maps/ui/*.vpk`) no layout shows, two orb materials, the old kick vote layout
  (`voting_to_kick`, replaced by `kick_voting`), the `dev_panel` and `flow_test` layouts (the demo panel has its own
  dev controls) and four scripts nothing includes, among them the original chat script.

Kept on purpose: 17 particles at base game paths (the pendulum trap, `ti10_emblem_effect_ground_spot`), which override
Dota's own, differ from them and may be loaded by base game content; the icons of features that are only commented
out (the `neutral_item_stats` generic upgrade, the `wards` and `kills_and_assists` MVP badges); the loading screen's
hint videos, which play until every player has loaded.

Checked in Workshop Tools: before the removal, `resource_list` at setup listed from the throne folder only
`kobold_overboss.vmdl`, its `kobold_overboss/kobold_overboss_vmorf.vtex` and the desert cushions, and none of the
13,606 models, particles and materials it listed was on the removal list. Afterwards a match ran from setup through
hero selection, the game and the end screen (MVP view, collection): the boss rendered and animated on its throne, the
team logos and badges showed, and the client log named no removed file.

`run_tests.js` runs `package_images.js`, which fails if a shipped image (a `.vtex_c` under `panorama`, `materials` or
`models`, or a PNG under `resource/flash3/images`) is not used. An image counts as used when one of these names it:

- Lua, KeyValues or localization;
- a Panorama layout, style or script reachable from `custom_ui_manifest.xml`, `custom_loading_screen.xml` or a path in
  Lua or KeyValues. Compiled layouts are read from their LZ4-compressed KV3 block (`layoutStrings` in
  `panorama_resources.js`), so layouts without an XML source count too. An unloaded layout or stylesheet does not
  keep its images.
- the external references (RERL) of a compiled material, model or particle;
- for item and ability icons, a texture name in Lua or KeyValues.

Scripts build some paths at runtime: a `${...}` in a template literal stands for one path segment, and a folder swap
such as `.replace("/team_icons/", "/team_icons_hr/")` names both folders. Such a path matches every file of its
folder that fits, so two families are checked by name as well: map previews (`custom_game/maps/<map>_png.vtex_c`) must
belong to registered maps, and collection item images to the items of `collection_generated.js`. Not covered: the map
VPK is not read (`maps/` is left out; its textures are checked by `map_textures.js`), compiled materials, models and
particles count as loaded whether or not anything uses them, and models and particles themselves are not checked.

Delete art together with the last code that shows it. A new image set only from a script needs no precache
stylesheet in the package: compile it once through a temporary stylesheet, as `panorama_textures.js build` does, and
commit the compiled file.
