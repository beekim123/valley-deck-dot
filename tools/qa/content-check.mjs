import { readFile, realpath } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const ID = /^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)*$/;
const NAMES = { wood: '木', stone: '石', warmth: '暖意' };
const BONUS_NAMES = { axe_sharp: '斧头磨好后' };
const object = value => value !== null && typeof value === 'object' && !Array.isArray(value);
const positive = value => Number.isSafeInteger(value) && value > 0;
function demand(ok, message) { if (!ok) throw new Error(message); }

/** Explicit D0 operation vocabulary: unsupported operations fail closed until D1. */
export function resourcePreview(ops) {
  demand(Array.isArray(ops) && ops.length > 0, 'ops must be a nonempty array');
  return ops.map(op => {
    demand(object(op), 'operation must be an object');
    demand(['gain', 'spend'].includes(op.op), `unsupported operation: ${op.op}`);
    demand(Object.hasOwn(NAMES, op.res), `unknown resource: ${op.res}`);
    demand(positive(op.n), 'resource amount must be a positive safe integer');
    const sign = op.op === 'gain' ? '+' : '-';
    let result = `${sign}${op.n} ${NAMES[op.res]}`;
    if (op.bonus_flag !== undefined || op.bonus !== undefined) {
      demand(op.op === 'gain' && Object.hasOwn(BONUS_NAMES, op.bonus_flag) && positive(op.bonus)
        && Number.isSafeInteger(op.n + op.bonus), 'invalid conditional resource bonus');
      result += `（${BONUS_NAMES[op.bonus_flag]} +${op.n + op.bonus} ${NAMES[op.res]}）`;
    }
    const allowed = ['op', 'res', 'n', 'bonus_flag', 'bonus'];
    demand(Object.keys(op).every(key => allowed.includes(key)), 'unsupported operation field');
    return result;
  }).join('，');
}

export function validateLocations(data, { artIds } = {}) {
  demand(object(data) && data.format === 'content/1', 'locations format must be content/1');
  demand(Array.isArray(data.locations) && data.locations.length > 0, 'locations must be nonempty');
  const ids = new Set(), slots = new Set();
  for (const loc of data.locations) {
    demand(object(loc) && typeof loc.id === 'string' && ID.test(loc.id) && loc.id.startsWith('loc.'), 'invalid location id');
    demand(!ids.has(loc.id), `duplicate location id: ${loc.id}`); ids.add(loc.id);
    demand(typeof loc.name === 'string' && loc.name.trim().length > 0, `${loc.id}: missing name`);
    demand(['fog', 'frozen', 'thawed', 'restored', 'hidden'].includes(loc.start), `${loc.id}: invalid start`);
    demand(Array.isArray(loc.slot) && loc.slot.length === 2 && Number.isInteger(loc.slot[0])
      && loc.slot[0] >= 0 && loc.slot[0] < 2 && Number.isInteger(loc.slot[1])
      && loc.slot[1] >= 0 && loc.slot[1] < 6, `${loc.id}: slot outside 2x6 board`);
    const slot = loc.slot.join(',');
    demand(!slots.has(slot), `duplicate slot: ${slot}`); slots.add(slot);
    demand(Array.isArray(loc.uses) && loc.uses.length > 0, `${loc.id}: uses must be nonempty`);
    const uses = new Set();
    for (const use of loc.uses) {
      demand(object(use) && typeof use.id === 'string' && ID.test(use.id), `${loc.id}: invalid use id`);
      demand(!uses.has(use.id), `${loc.id}: duplicate use ${use.id}`); uses.add(use.id);
      demand(use.who === 'any' || (object(use.who) && Object.keys(use.who).length === 1
        && typeof use.who.tag === 'string' && use.who.tag.trim().length > 0), `${loc.id}/${use.id}: invalid who selector`);
      demand(typeof use.label === 'string' && use.label.trim().length > 0 && !/[+\-\d]/.test(use.label), `${loc.id}/${use.id}: label must be an action name`);
      demand(use.preview === resourcePreview(use.ops), `${loc.id}/${use.id}: preview does not match ops`);
    }
    demand(object(loc.art), `${loc.id}: missing art`);
    for (const season of ['winter', 'spring']) {
      const id = loc.art[season];
      demand(typeof id === 'string' && ID.test(id), `${loc.id}: invalid ${season} art id`);
      if (artIds) demand(artIds.has(id), `${loc.id}: missing art asset ${id}`);
    }
    // Reject premature references rather than pretending D1 reference validation exists.
    demand(Object.keys(loc).every(key => ['id', 'name', 'start', 'slot', 'uses', 'art'].includes(key)), `${loc.id}: unsupported D0 location field`);
  }
  return { locations: ids.size };
}

export function validateRegistry(registry) {
  demand(object(registry) && registry.format === 'content/1', 'registry format must be content/1');
  demand(Array.isArray(registry.files) && registry.files.length > 0, 'registry files must be nonempty');
  const ids = new Set(), paths = new Set();
  for (const file of registry.files) {
    demand(object(file) && typeof file.id === 'string' && ID.test(file.id), 'invalid registry id');
    demand(!ids.has(file.id), `duplicate registry id: ${file.id}`); ids.add(file.id);
    demand(typeof file.path === 'string' && /^(data|story)\/[a-z0-9_./-]+\.json$/.test(file.path)
      && file.path.split('/').every(part => part !== '.' && part !== '..' && part.length > 0), 'unsafe registry path');
    demand(!paths.has(file.path), `duplicate registry path: ${file.path}`); paths.add(file.path);
  }
  return registry.files;
}

async function json(file) { return JSON.parse(await readFile(file, 'utf8')); }
async function manifestIds(file, required, warnings) {
  let manifest;
  try { manifest = await json(file); }
  catch (error) {
    if (error.code !== 'ENOENT' || required) throw error;
    warnings.push(`Asset check skipped: ${path.basename(path.dirname(path.dirname(file)))}/export/${path.basename(file)} missing`);
    return undefined;
  }
  demand(object(manifest) && Array.isArray(manifest.assets), `invalid asset manifest: ${file}`);
  const ids = new Set();
  for (const asset of manifest.assets) {
    demand(object(asset) && typeof asset.id === 'string' && ID.test(asset.id) && !ids.has(asset.id), 'invalid or duplicate asset id');
    ids.add(asset.id);
  }
  return ids;
}

export async function checkContent({ root = ROOT, requireAssets = false } = {}) {
  const content = path.resolve(root, 'content');
  const files = validateRegistry(await json(path.join(content, 'registry.json')));
  const warnings = [];
  const artIds = await manifestIds(path.join(root, 'resources/art/export/manifest.json'), requireAssets, warnings);
  await manifestIds(path.join(root, 'resources/audio/export/manifest.json'), requireAssets, warnings);
  let locations = 0;
  for (const file of files) {
    const resolved = await realpath(path.join(content, file.path));
    const actualContent = await realpath(content);
    demand(resolved.startsWith(actualContent + path.sep), 'registry symlink escapes content root');
    demand(file.id === 'locations', `unsupported D0 content collection: ${file.id}`);
    locations += validateLocations(await json(resolved), { artIds }).locations;
  }
  return { files: files.length, locations, warnings };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    demand(process.argv.slice(2).every(arg => arg === '--require-assets'), 'usage: content-check.mjs [--require-assets]');
    const result = await checkContent({ requireAssets: process.argv.includes('--require-assets') });
    for (const warning of result.warnings) console.warn(warning);
    console.log(`Content D0 OK: ${result.files} file(s), ${result.locations} location(s). D1 reachability checks are not implemented yet.`);
  } catch (error) { console.error(`Content check failed: ${error.message}`); process.exitCode = 1; }
}
