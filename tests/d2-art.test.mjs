import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { renderAssets, validateMeta, validatePixels } from '../tools/resources/art.mjs';

// Source-only assertions deliberately do not rewrite exports or race a shared build.
const rendered = renderAssets();
const json = async name => JSON.parse(await readFile(new URL(`../content/${name}`, import.meta.url), 'utf8'));
const residents = ['anuan', 'toby', 'mira', 'mei', 'beavers', 'gutu', 'xiaosu', 'baiweng', 'mill_family'];
const landmarks = ['pines', 'hut', 'flower_slope', 'herb_garden', 'river_bend', 'misty_bank', 'tree_hole', 'mill', 'gravel', 'old_bridge', 'flood_beach'];
const scenes = ['valley_gate', 'hut', 'pines', 'herb_garden', 'river', 'mill'];
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const map = async () => new Map((await rendered).map(a => [a.meta.id, a]));

test('D2 inventory explicitly covers every character, landmark, content use, illustration and UI group', async () => {
  const assets = await map(), required = new Set();
  for (const name of residents) for (const id of [`portrait.${name}`, `big.${name}`, `big.${name}.memory`, `walker.${name}`]) required.add(id);
  for (const name of landmarks) for (const prefix of ['locart', 'pano']) for (const season of ['spring', 'winter']) required.add(`${prefix}.${name}.${season}`);
  const { locations } = await json('data/locations.json');
  assert.deepEqual(locations.map(l => l.id.slice(4)).sort(), [...landmarks].sort());
  for (const location of locations) for (const use of location.uses) required.add(`locart.${location.id.slice(4)}.anim.${use.id}`);
  for (const scene of scenes) for (const suffix of ['', '.memory']) required.add(`still.${scene}${suffix}`);
  for (const id of ['board.table', 'char.ember', 'card.res_frame', 'card.event_frame', 'card.spell_frame', 'fx.ice_crack', 'fx.ice_shatter', 'note.paper']) required.add(id);
  for (const state of ['fog', 'frozen', 'thawed', 'restored']) required.add(`card.loc_frame.${state}`);
  for (const name of ['clock', 'lantern', 'pipe', 'teacup', 'window']) required.add(`deco.${name}`);
  for (const name of ['wood', 'stone', 'warmth']) required.add(`icon.${name}`);
  for (const name of ['bubble', 'paper', 'preview', 'wood']) required.add(`ui.panel.${name}`);
  for (const n of [1, 2, 3]) required.add(`note.sketch.${n}`);
  for (const id of required) assert.ok(assets.has(id), `missing required D2 asset ${id}`);
  assert.equal(required.size, 141, 'review baseline changes by semantic group, not by weakening a total');
  assert.ok(assets.size >= required.size);
});

test('all D2 pixels and metadata validate and repeat rendering is byte-identical', async () => {
  const assets = await rendered, again = await renderAssets();
  assert.deepEqual(assets.map(a => a.meta.id), again.map(a => a.meta.id));
  assets.forEach((asset, index) => {
    validateMeta(asset.meta);
    asset.frames.forEach(validatePixels);
    assert.deepEqual(asset.png, again[index].png, asset.meta.id);
  });
});

test('winter/spring pairs preserve size and silhouette while changing visible colors', async () => {
  const assets = await map();
  for (const name of landmarks) for (const prefix of ['locart', 'pano']) {
    const a = assets.get(`${prefix}.${name}.spring`), b = assets.get(`${prefix}.${name}.winter`);
    assert.deepEqual(a.meta.size, b.meta.size);
    assert.notEqual(digest(a.png), digest(b.png), `${prefix}.${name}: season is unchanged`);
    const pa = a.frames[0].pixels, pb = b.frames[0].pixels;
    for (let i = 3; i < pa.length; i += 4) assert.equal(pa[i], pb[i], `${prefix}.${name}: alpha ${i}`);
  }
});

test('all panorama neighbors have pixel-exact joining boundary columns in each season', async () => {
  const assets = await map();
  for (const season of ['winter', 'spring']) {
    const baseline = assets.get(`pano.pines.${season}`).frames[0];
    for (const name of landmarks) {
      const frame = assets.get(`pano.${name}.${season}`).frames[0];
      assert.deepEqual([frame.width, frame.height], [128, 80]);
      for (let y = 0; y < frame.height; y++) {
        assert.deepEqual(frame.get(0, y), baseline.get(0, y), `${name}/${season}: left seam at ${y}`);
        assert.deepEqual(frame.get(frame.width - 1, y), baseline.get(0, y), `${name}/${season}: right seam at ${y}`);
      }
    }
  }
});

test('multi-frame strips contain real motion or distinct expressions, not repeated placeholders', async () => {
  for (const asset of await rendered) if (asset.meta.frames > 1) {
    assert.ok(new Set(asset.frames.map(f => digest(f.pixels))).size >= 2, asset.meta.id);
  }
  const assets = await map();
  for (const name of residents) {
    const walker = assets.get(`walker.${name}`);
    assert.deepEqual(walker.meta.size, [16, 24]);
    for (const animation of ['walk', 'work', 'idle']) {
      const frames = walker.meta.animations[animation].frames;
      assert.ok(new Set(frames.map(i => digest(walker.frames[i].pixels))).size >= 2, `${name}/${animation}`);
    }
  }
});

test('all story layer references exist and requested frames fit the exact authored atlas', async () => {
  const assets = await map(), { pages } = await json('story/pages.json');
  for (const sequence of pages) for (const page of sequence.pages) for (const layer of page.layers) {
    const asset = assets.get(layer.asset);
    assert.ok(asset, `${sequence.id}: missing ${layer.asset}`);
    assert.ok((layer.frames ?? 1) <= asset.meta.frames, `${sequence.id}: frame overflow ${layer.asset}`);
    assert.ok(Number.isInteger(layer.x) && Number.isInteger(layer.y));
    if (layer.pan) assert.ok(layer.pan.every(Number.isInteger));
  }
});
