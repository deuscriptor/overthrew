Panorama changes are stored both as editable JavaScript in `panorama_sources/`
and as rebuilt `.vjs_c` files at their original addon paths. Original resources
are backed up in `panorama_backups/`.

Run with Node.js:

```
node tools/panorama_resources.js build
node tools/panorama_resources.js verify
node tools/panorama_test.js
```

The resource script preserves non-DATA blocks and validates JavaScript syntax,
resource sizes, block bounds, UTF-8 round trips, and version 3 script CRC32.
Version 4 scripts store plaintext DATA, as documented in
[ValveResourceFormat's Panorama implementation](https://github.com/ValveResourceFormat/ValveResourceFormat/blob/master/ValveResourceFormat/Resource/ResourceTypes/Panorama.cs).
Builds use the saved original container each time. RED2 source dependency
metadata is retained; it describes the original compiler input and is not a
checksum of the runtime DATA. No XML containers are modified.

Styles (`.css` in `panorama_sources/`) are compiled, not patched: `build` copies each
source into `content/dota_addons/overthrew/` and runs `game/bin/win64/resourcecompiler.exe`;
`build` and `verify` then compare the compiled DATA CSS with the source, ignoring
whitespace and comments. `toasts.css` was recovered from the original `toasts.vcss_c`
(backed up), and an unmodified recompile reproduced its CSS byte for byte. Keep image
URLs as `s2r://panorama/images/..._png.vtex`: there are no PNG sources, and
`file://{images}` URLs compile to empty paths. The compiler accepts unknown
properties, so check the client log after style changes.

`MAP_NAME` (in `scripts/utils.js`) is the map name, `ot3_necropolis_ffa`, and keys the
map-specific UI constants. `IS_SINGLE_DRAFT_MAP` and `IS_EPIC_ONLY_MAP` follow the
host's `single_draft` and `epic_orbs` match rules from the `game_options` net table.
With Single Draft, `IS_SINGLE_DRAFT_MAP` hides smart random and bypasses the
supporter pick delay. The native hero picker receives its four legal choices from
server-side player availability; normal random remains available and uses the
restricted pool.

Progress bars keep source channels 1 (time) and 2 (kills). Their reward visuals
and tooltips use `reward_rarity`, with an epic fallback during initialization with
Epic-Only orbs. Gift descriptions and the hero bonus icon also show epic rewards.
Gift inventory counts and consumption remain attached to the original items.
The upgrade panel uses the server-provided reroll price for affordability and
click handling. Epic Only charges 1 regardless of reward rarity and displays
its own price tooltip; normal orbs keep their rarity prices.
The missing `panorama/images/items/orb_epic_png.vtex_c` shop image is supplied
as an identical copy of the addon's existing compiled epic orb texture; the
builder maintains and verifies this alias. Existing common/rare assets are
unmodified.

The behavior checks use mocked Panorama panels. A Dota client is still needed
to visually verify panel appearance, clipping, map loading, and HUD lifecycle.

Textures listed in `panorama_textures.json` are re-encoded by `panorama_textures.js` (see "Texture memory" in
[README.md](README.md)). `build` regenerates them from their originals in git: it writes `name.png` sources for
`name_png.vtex_c` into `content/dota_addons/overthrew/`, compiles them through a temporary stylesheet and removes
both. `verify`, also run by `panorama_resources.js verify`, checks the committed textures' format and size, and
that no uncompressed texture keeps an alpha channel it does not use. New art should be no larger than 4/3 of the
largest box it is drawn in, and saved without alpha when it has no transparency.
