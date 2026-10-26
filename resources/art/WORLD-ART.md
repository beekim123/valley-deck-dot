# D2 world artwork

All work is repository-authored integer PixelCanvas geometry, using only the existing 48-color palette and binary alpha. No generated-model or external images. These are asset proofs; in-game screenshots are a separate integration gate.

## Contract

| IDs | Count | Frame size | Frames |
|---|---:|---:|---:|
| `locart.<location>.spring`, `.winter` | 22 | 64 × 48 | 1 |
| `locart.<location>.anim.<use>` | 22 | 64 × 48 | 4 |
| `pano.<location>.spring`, `.winter` | 22 | 128 × 80 | 1 |
| `still.<scene>`, `still.<scene>.memory` | 12 | 320 × 180 | 2 |

All anchors are `[0, 0]`. Multi-frame PNGs use horizontal strips, selected without runtime rotation or resampling. Stills hold frame zero three beats then frame one; all movement is drawn into the exported frames. Memory variants use `palette.recolors.memory`, not runtime color tinting. The six still scene suffixes are `valley_gate`, `hut`, `pines`, `herb_garden`, `river`, `mill`.

Existing D0 `source/location/pines.mjs` and its two semantic IDs remain unchanged. Its three pine / stump / path composition is repeated by the D2 helper vocabulary for consistency. `locations/world.mjs` exports an empty asset list because it is a helper discovered by the same recursive build tool.

## Location and night-use coverage

| Location | Recognizable silhouette | Animated uses |
|---|---|---|
| pines | three spires, stump, winding path | chop, gather |
| hut | chimney, lighted window, wood bench | fire, read_notes, feed |
| flower_slope | rising flower meadow, bench | sun, herbs |
| herb_garden | herb beds, labels, garden house | brew, tea |
| river_bend | bend, driftwood, reeds and rock | driftwood, chisel, build_dam |
| misty_bank | deciduous tree, fog bands, beaver lodge | gnaw |
| tree_hole | broad roots, dark arched hollow | shelter, search |
| mill | timber mill and eight-pose-axis waterwheel | repair_wheel, warm_family |
| gravel | large angular layered stone groups | stones, haul |
| old_bridge | two stone piers, raised wooden span | watch, reinforce |
| flood_beach | sandy flood line, shells, washed-up envelope | shells |

Night scenes show their action through objects and poses, not just a palette swap: raised/lowered axe and chips, lifting stones, herb stalks into baskets, steaming kettle or cup, open notebook, hopping robin, ice chisel/cracks, beavers/logs, mallet/wheel, lantern, and spreading warmth. Characters here are tiny scene actors, not substitutes for the resident portrait/walker assets.

## Panorama topology

Narrative order: pines → tree_hole → hut → flower_slope → herb_garden → river_bend → flood_beach → misty_bank → mill → gravel → old_bridge.

Every same-season boundary column has byte-identical pixels: distant ridge joins at y=31, middle ridge at y=45, ground at y=58, path at y=72. Individual peaks/cloud positions vary without shifting edge anchors. Transparent landmark layers avoid rectangular card-background patches. Foreground features stay inside the joining margins. Winter and spring keep identical geometry; winter recolor and snapshot snow caps form connected bands.

## Review and verification

Local review entrypoint: `.local/world-review/render.mjs` (scratch only, not runtime dependency). Proofs:
- `locations-3x.png`: 22 cards, sorted suffix then spring/winter, three-times nearest neighbor.
- `night-scenes.png`: all 22 actions, four frames across each row, in the coverage-table order.
- `panorama.png`: narrative strip, winter above spring.
- `stills.png`: six backgrounds, two columns × three rows.

Reviewed all four proofs: seasonal landmark identity retained, snow forms caps rather than noise, tool/action props differ, panorama edge columns are checked exactly. All 78 assets / 156 frames passed metadata, 48-color and binary-alpha checks. Parent runs the shared build/verify/paginated proof gallery and Godot sync after both art workers freeze sources. Runtime typography, cropping, actual card size and panorama transitions remain part of that integration review.
