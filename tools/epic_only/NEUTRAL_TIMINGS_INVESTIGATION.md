# Neutral availability investigation — 2026-09-25

The experimental Turbo grant schedule and `neutral_items_turbo.txt` were removed.
Both modes now grant Madstones at 121, 271, 421, 571 and 901 seconds. Turbo still
doubles kill Madstones and retains its early Shard stock. Regression suite passes.

## Local evidence

- Parsed all 157 entries in `maps/ot3_necropolis_ffa.vpk`: no NPC configuration or
  neutral-item configuration. It contains compiled map resources, including
  `world.vwrld_c` and `entities/default_ents.vents_c`.
- Existing `MapPackage.cs` supports rewriting this unsigned, single-file VPK v2
  with rebuilt checksums. Thus the archive is editable; there is no existing
  neutral timing file inside it to patch.
- Dota's base `pak01_dir.vpk` indexes `scripts/npc/neutral_items.txt` in chunk 236.
  That base file contains `neutral_tiers`, `start_time`, `craft_cost` and
  `recraft_cost`. Its current tier times are 0:00, 15:00, 25:00, 35:00 and 60:00.
- Both installed `server.dll` and `client.dll` contain the paths
  `scripts/npc/neutral_items.txt` and `scripts/npc/npc_neutral_items_custom.txt`.
  The custom path appears beside other custom NPC schema paths and
  `DOTANeutralItems`. These strings establish references, not override semantics.
- The client also contains `escalating_recraft_cost`. Its presence alone does
  not establish a supported configuration key or a server-side setter.

## Conclusion and limits

Adding configuration to a map VPK is technically possible. It remains unproven
whether native crafting would read it with sufficient precedence and at the
right time. Packaging alone provides no demonstrated way to select settings
from the host's Turbo toggle after the map has loaded.

The most useful next experiment is a controlled native crafting test of
`npc_neutral_items_custom.txt`, first loose in the addon and then packaged if
necessary. Verify actual early crafting acceptance on both client and server,
not just Lua LoadKeyValues or displayed labels. Also test non-Turbo isolation.
No map VPK or installed base-game files were modified during this investigation;
no runtime configuration override is claimed verified.
