Panorama changes are stored both as editable JavaScript in `panorama_sources/`
and as rebuilt `.vjs_c` files at their original addon paths. Original resources
are backed up in `panorama_backups/`.

Run with Node.js:

```
node tools/epic_only/panorama_resources.js build
node tools/epic_only/panorama_resources.js verify
node tools/epic_only/panorama_test.js
```

The resource script preserves non-DATA blocks and validates JavaScript syntax,
resource sizes, block bounds, UTF-8 round trips, and version 3 script CRC32.
Version 4 scripts store plaintext DATA, as documented in
[ValveResourceFormat's Panorama implementation](https://github.com/ValveResourceFormat/ValveResourceFormat/blob/master/ValveResourceFormat/Resource/ResourceTypes/Panorama.cs).
Builds use the saved original container each time. RED2 source dependency
metadata is retained; it describes the original compiler input and is not a
checksum of the runtime DATA. No XML/CSS containers are modified.

`MAP_NAME` remains the real map identity. `MAP_BASE_NAME` supplies the original
FFA layout, art, and map-specific UI constants. The private map is not added to
the public leaderboard/profile map list. The loading screen uses the same
mapping locally because it does not load the shared HUD utilities.

Both Epic Only variants and standard Single Draft use that FFA mapping.
`IS_EPIC_ONLY_MAP` excludes standard Single Draft, which keeps normal orb
visuals, shop items and rarity-dependent reroll prices. On both draft copies,
`IS_SINGLE_DRAFT_MAP` hides smart random and bypasses the supporter pick delay.
The native hero picker receives its four legal choices from server-side player
availability; normal random remains available and uses the restricted pool.

Progress bars keep source channels 1 (time) and 2 (kills). Their reward visuals
and tooltips use `reward_rarity`, with an epic fallback during initialization on
the variant. Gift descriptions and the hero bonus icon also show epic rewards.
Gift inventory counts and consumption remain attached to the original items.
The upgrade panel uses the server-provided reroll price for affordability and
click handling. Epic Only charges 1 regardless of reward rarity and displays
its own price tooltip; other maps retain their existing rarity prices.
The missing `panorama/images/items/orb_epic_png.vtex_c` shop image is supplied
as an identical copy of the addon's existing compiled epic orb texture; the
builder maintains and verifies this alias. Existing common/rare assets are
unmodified.

The behavior checks use mocked Panorama panels. A Dota client is still needed
to visually verify panel appearance, clipping, map loading, and HUD lifecycle.
