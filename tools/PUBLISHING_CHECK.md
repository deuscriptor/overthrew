# Publication check — 2026-09-24

The static/runtime-asset audit found no launch-flag blocker for the configurable
FFA map. This is not a successful Workshop upload or downloaded-package test.

## Checked

- `addoninfo.txt`: `IsPlayable = 1`, `IsTemplate = false`, `HideInTools = false`.
- Default map changed, with approval, to `ot3_necropolis_ffa`.
- Since 2026-09-30 `ot3_necropolis_ffa` is the only registered map, with a compiled
  VPK, an eight-player limit (also the root `MaxPlayers`) and a one-player minimum.
  The other original maps and the custom variants were removed.
- Host options operate outside tools mode. Debug respawns, automatic demo setup
  and cheat enabling are guarded by tools mode.
- All 27 edited Panorama resources match their editable sources; resource bounds,
  CRCs, JavaScript syntax and the shop image alias verify successfully.
- Full regression suite passes, including host authorization and Turbo item timing.

## Local launch options

Saved Steam configuration contains this Dota launch string:

```
-language tempcontent -console -high -novid -vulkan -map dota
```

Other inspected Dota entries have no launch options. Steam configuration was not
changed. For a clean release test, remove the forced map and custom-language
arguments; empty launch options, or just `-console -novid`, avoid those overrides.
Local Steam options are not distributed with Workshop addon files.

Use Workshop Tools to publish. Friends should launch ordinary Dota, subscribe to
the Workshop item, and create/join its Local Host lobby. They do not need `-tools`,
`-addon`, `-dev`, `-insecure`, or console launch commands to play the published game.
Reference: https://developer.valvesoftware.com/wiki/Dota_2_Workshop_Tools/Addon_Overview/Playing_Addons

## Packaging and remaining limits

- Keep runtime files: `addoninfo.txt`, maps, scripts, resource, Panorama, materials,
  models, particles and soundevents. `maps` is more than the VPKs: since #36,
  `maps/ot3_necropolis_ffa/` holds three loose water/fog textures the map needs.
  Do not include development folders `.git` (about 163 MiB) or `tools`, AGENTS.md, CLAUDE.md, editor thumbnail/asset caches or
  `panorama_debugger.cfg`. Inspect the publisher's file list; this check did not
  run the publisher or assume it excludes these automatically.
- Some original backend integrations still run outside tools mode. Local premium
  and vanity access is independent of backend success; this check does not
  certify original account, leaderboard or online-service features.
- Local Host ownership resolution is implemented. Dedicated-region lobby-owner
  behavior and a downloaded Workshop package have not been tested.
- The GitHub **Build** workflow (`.github/workflows/build.yml`, also run by the manual
  **Release** workflow) builds the same nine-entry package from the committed tree with
  `git archive`; Release attaches it to the GitHub release. Local builds copy the working tree instead; a comparison on 2026-09-29
  found all 3,646 files identical except 53 inherited text files that the working tree
  holds with CRLF line endings and git stores with LF.
- The final validation is the publisher's own validation followed by a subscribed
  copy running in ordinary Dota. No upload or publication was performed.
