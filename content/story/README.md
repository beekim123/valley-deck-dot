# D2 presentation content contract

`pages.json` preserves the D1 21 sequences / 38 pages and their story meaning.
`when` is evaluated through the existing pure `rule_data.condition` predicate.
No presentation component changes gameplay state.

Each page has `speaker`, `text` (maximum 50 characters), `layers`, optional
`layout` (`illustration`, `memory`, `note`) and optional `when`.
Layers use `{asset, x, y, frames?, fps?, pan?}`. `asset` is an AssetCatalog ID;
coordinates and total `pan: [x, y]` displacement are integer pixels. Animation
selects atlas frames; pan is rounded each update, takes eight seconds and stops.
Memory layers use exported `.memory` palette variants, not runtime recoloring.
Illustrations are clipped to 320×180. Notes use 320×200 paper, a 160×120 sketch,
and readable right-column ink text. Missing required assets block the modal
with an explicit error, and never silently use final-build placeholders.

`banter.json` adds optional `match_resident` and `match_location` exact semantic
IDs to the existing event/condition rules. Hover uses a 0.4-second dwell and one
successful bubble per resident/location/day. Normal lines have a global four
second cooldown, plus per-speaker protection through the full bubble lifetime.
Duration is `2.5 + 0.08 * character_count`. The presentation keeps its own
seen/cycle/hover bookkeeping and never consumes gameplay RNG. Once lines are
once per director lifetime; the UI should retain one director for a play session.

Mount `story_player.gd` and `awaken_director.gd` as Controls in the UI's overlay.
`play(id_or_record, state, callback)` and `play_awaken(resident_id, state, callback)`
hide on completion, emit `completed`, then call the callback exactly once.
The owner frees the control. `blocked(reason)` deliberately does not complete.
Story `text_speed` is characters/second; zero displays immediately. Space,
Enter, and left click first reveal the page, then advance; Skip ends the sequence.
Awakening's initial three cracks cannot be skipped on the first viewing;
subsequent viewings can accelerate. First line is followed by optional memory
or a return-to-table button. Input during the optional memory belongs to it.

Banter exposes `trigger(event, payload, state) -> {id,speaker,text,duration}` (or
`{}`), `bubble_requested(speaker,text)`, `bubble_expired(speaker)`,
`hover(resident_id,location_id,state)`, and `clear_hover()`. UI owns bubble
mounting with mouse input ignored. Combo payloads use `id`; hover matching uses
`resident_id` / `location_id` (also accepts `res` / `loc`).

Focused runtime assertions: `res://scripts/story/story_smoke.gd`.
