# First-party pixel art

All pixels are authored by this repository's source code or character matrices. No external images, image-generation models, runtime image downloads, or nondeterministic randomness are used.

## D0 index

| Semantic ID | Frame size | Anchor | Frames | Use |
| --- | --- | --- | --- | --- |
| `locart.pines.spring` | 64 × 48 | 0, 0 | 1 | Side-view spring pine grove |
| `locart.pines.winter` | 64 × 48 | 0, 0 | 1 | Same composition recolored, with deterministic snow caps |
| `portrait.toby` | 40 × 40 | 20, 40 | 4 | Neutral, happy, surprised, frozen lumberjack portrait |

`portrait/toby.json` is a hand-authored character matrix with three expression frames. A fourth `variants` entry derives the frozen frame from frame 0 through the `memory` map. Its large beard and broad shoulders are silhouette cues for Toby; Mira's contrasting silhouette will be checked when her art exists in D2.

`location/pines.mjs` draws a distant mountain layer, middle ridge, ground and foreground trees/stump. The winter variant reuses exactly those coordinates. Ground has a snow-specific recolor override so conifer needles remain dark while the terrain is snow-covered. Snow caps inspect an immutable copy of each foreground column; they never recursively grow down the tree.

## Build and review

From the repository root:

```sh
node tools/resources/art.mjs build
node tools/resources/art.mjs verify
node tools/resources/art.mjs sheet
node --test tests/art.test.mjs
```

Equivalent `npm run art:build`, `art:verify`, and `art:sheet` scripts are provided by the root toolchain.

- `palette.json`: exactly 48 named colors, character-to-name map, winter and memory recolors.
- `lib/png.mjs`: deterministic RGBA8 encoder and CRC-validating PNG decoder (filters 0–4); only first-party generated files are read.
- `lib/pixel.mjs`: integer-only canvas; geometry, stamping, outlines, mirroring, recolor, snowcap, coordinate-hash dissolve and clustered textures.
- `source/`: sole authoring source. Never edit exported PNGs.
- `export/manifest.json`: `{format: "art-manifest/1", assets: [...]}`. Each entry has `id`, `category`, `file`, single-frame `size`, `frames`, `anchor`, `animations` and PNG SHA-256 `hash`; optional `nineSlice` is `[left, top, right, bottom]`. Files are relative to `export/`; multi-frame PNGs are horizontal strips.
- `export/sheets/d0.png`: labeled three-times nearest-neighbor proof sheet, not a runtime asset.

`verify` rebuilds in memory, compares every byte against committed exports, checks decoded dimensions/colors/binary alpha, validates anchors/animation references/nine-slice bounds, renders twice for determinism, checks semantic art references in content JSON, and warns about content-unreferenced IDs (title/QA-only assets can legitimately warn).

D0 visual review: opened the proof sheet at 3×. Winter/spring retain the same mountains, three tree positions, stump and path; snow forms connected caps and ground bands, not random white noise. Toby has a readable broad silhouette and four distinguishable expressions. No off-palette or partially transparent pixels. Four card states, panorama seams and actual in-game typography require later batches and the Godot screenshot check; this sheet does not claim to validate them.

The tiny first-party annotation alphabet in `art.mjs` is exclusively for proof-sheet labels. Game text must use the licensed Fusion Pixel font through Godot, not these glyphs.
