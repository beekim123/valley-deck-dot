import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, mkdtemp, mkdir, writeFile, symlink, rm } from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import { checkContent, resourcePreview, validateLocations, validateRegistry } from '../tools/qa/content-check.mjs';
const source = JSON.parse(await readFile(new URL('../content/data/locations.json', import.meta.url), 'utf8'));
const registry = { format: 'content/1', files: [{ id: 'locations', path: 'data/locations.json' }] };
const artIds = new Set(['locart.pines.winter', 'locart.pines.spring']);
function modified(edit) { const value = structuredClone(source); edit(value.locations[0], value); return value; }

test('D0 data uses design IDs, exact 2x6 origin, and wood outputs', () => {
  assert.deepEqual(validateLocations(source, { artIds }), { locations: 1 });
  assert.equal(source.locations[0].id, 'loc.pines');
  assert.deepEqual(source.locations[0].slot, [0, 0]);
  assert.deepEqual(source.locations[0].uses.map(use => use.ops[0].n), [2, 1]);
});
test('preview template preserves cost, gain, and conditional axe bonus', () => {
  assert.equal(resourcePreview([{ op: 'spend', res: 'wood', n: 1 }, { op: 'gain', res: 'warmth', n: 1 }]), '-1 木，+1 暖意');
  assert.equal(resourcePreview(source.locations[0].uses[0].ops), '+2 木（斧头磨好后 +3 木）');
  assert.throws(() => validateLocations(modified(loc => { loc.uses[0].preview = '+99 木'; })), /preview/);
  assert.throws(() => validateLocations(modified(loc => { loc.uses[0].label = '伐木 +99 木'; })), /label/);
});
test('invalid resources, amounts, conditional bonuses, and unknown operations fail', () => {
  for (const op of [
    { op: 'gain', res: 'food', n: 1 }, { op: 'gain', res: 'wood', n: -1 },
    { op: 'spend', res: 'wood', n: 0 }, { op: 'gain', res: 'wood', n: 0.5 },
    { op: 'gain', res: 'wood', n: 1, bonus: 1 }, { op: 'restore', loc: 'loc.pines' },
    { op: 'gain', res: 'wood', n: 1, unexpected: true },
  ]) assert.throws(() => resourcePreview([op]));
});
test('duplicate IDs, duplicate slots, invalid states and selectors are rejected', () => {
  assert.throws(() => validateLocations(modified((loc, all) => all.locations.push(structuredClone(loc)))), /duplicate location/);
  assert.throws(() => validateLocations(modified((loc, all) => all.locations.push({ ...structuredClone(loc), id: 'loc.hut' }))), /duplicate slot/);
  for (const edit of [
    loc => { loc.slot = [2, 0]; }, loc => { loc.start = 'defeated'; },
    loc => { loc.uses[0].who = 'res.missing'; }, loc => { loc.uses.push(structuredClone(loc.uses[0])); },
    loc => { loc.restore = { combo: 'combo.missing' }; },
  ]) assert.throws(() => validateLocations(modified(edit)));
});
test('resource references must exist when manifest IDs are supplied', () => {
  assert.throws(() => validateLocations(source, { artIds: new Set() }), /missing art asset/);
  assert.throws(() => validateLocations(modified(loc => { loc.art.spring = ''; })), /invalid spring/);
});
test('registry rejects duplicate IDs, duplicate files and nonlocal paths', () => {
  assert.deepEqual(validateRegistry(registry), registry.files);
  for (const unsafe of ['../secret.json', '/tmp/a.json', 'data/../../a.json', 'data/./a.json', 'data//a.json', 'data\\a.json', 'https://example.com/a.json']) {
    assert.throws(() => validateRegistry({ ...registry, files: [{ id: 'locations', path: unsafe }] }), /unsafe/);
  }
  assert.throws(() => validateRegistry({ ...registry, files: [...registry.files, ...registry.files] }), /duplicate/);
  assert.throws(() => validateRegistry({ ...registry, files: [...registry.files, { id: 'other', path: 'data/locations.json' }] }), /duplicate registry path/);
});

test('file integration: optional assets warn; mandatory assets fail; symlink escape fails', async t => {
  const root = await mkdtemp(path.join(os.tmpdir(), 'valley-content-'));
  t.after(() => rm(root, { recursive: true, force: true }));
  await mkdir(path.join(root, 'content/data'), { recursive: true });
  await writeFile(path.join(root, 'content/registry.json'), JSON.stringify(registry));
  const locationsPath = path.join(root, 'content/data/locations.json');
  await writeFile(locationsPath, JSON.stringify(source));
  const result = await checkContent({ root });
  assert.equal(result.locations, 1); assert.equal(result.warnings.length, 2);
  await assert.rejects(checkContent({ root, requireAssets: true }), /ENOENT/);
  for (const kind of ['art', 'audio']) {
    const dir = path.join(root, `resources/${kind}/export`);
    await mkdir(dir, { recursive: true });
    await writeFile(path.join(dir, 'manifest.json'), JSON.stringify({ assets: kind === 'art' ? [...artIds].map(id => ({ id })) : [] }));
  }
  assert.equal((await checkContent({ root, requireAssets: true })).warnings.length, 0);
  await rm(locationsPath);
  await writeFile(path.join(root, 'outside.json'), JSON.stringify(source));
  await symlink(path.join(root, 'outside.json'), locationsPath);
  await assert.rejects(checkContent({ root }), /symlink escapes/);
});
