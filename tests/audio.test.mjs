import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { renderCue, seededNoise, noteHz, measure } from '../resources/audio/synth.ts';
import { cues } from '../resources/audio/cues/d0.ts';
import { encodeWav, validateWav, validateLevels, renderPack } from '../tools/resources/audio-pack.ts';

test('fixed seeds reproduce noise and distinct seeds change it', () => {
  const sequence = seed => { const random = seededNoise(seed); return Array.from({ length: 64 }, random); };
  assert.deepEqual(sequence(0), sequence(0));
  assert.notDeepEqual(sequence(0), sequence(1));
  assert.ok(sequence(17).every(x => x >= -1 && x < 1));
});

test('note parser handles pitches and rejects malformed names', () => {
  assert.equal(noteHz('A4'), 440);
  assert.equal(noteHz('C#4'), noteHz('Db4'));
  assert.throws(() => noteHz('A440'), /Invalid note/);
});

for (const cue of cues) {
  test(`${cue.id}: deterministic PCM, WAV headers, loudness and zero seam`, () => {
    const pcm = renderCue(cue);
    assert.deepEqual(pcm, renderCue(cue));
    assert.equal(pcm.length, cue.sampleRate * cue.duration);
    assert.deepEqual(validateWav(encodeWav(pcm, cue.sampleRate), cue), pcm);
    assert.equal(validateLevels(pcm, cue).seamDelta, 0);
    assert.ok(encodeWav(pcm, cue.sampleRate).length < 2_000_000);
  });
}

test('8-second original sketch has exactly four 3/4 bars', () => {
  const cue = cues.find(x => x.id === 'music.test');
  assert.equal(cue.duration, 8);
  assert.equal(cue.notes[0].frequency, noteHz('G4'));
  assert.equal(cue.notes.at(-1).frequency, noteHz('A4'));
  assert.equal(cue.notes.at(-1).at + cue.notes.at(-1).duration, 8);
});

test('synth rejects silent, invalid rate, timing and NaN sources', () => {
  const cue = cues[0];
  assert.throws(() => renderCue({ ...cue, notes: [] }), /Silent/);
  assert.throws(() => renderCue({ ...cue, sampleRate: 48000 }), /sample rate/);
  assert.throws(() => renderCue({ ...cue, duration: NaN }), /duration/);
  assert.throws(() => renderCue({ ...cue, notes: [{ ...cue.notes[0], at: 7.9 }] }), /exceeds/);
  assert.throws(() => renderCue({ ...cue, notes: [{ ...cue.notes[0], gain: NaN }] }), /gain/);
});

test('validator rejects corrupt/truncated headers', () => {
  const cue = cues[0];
  const wav = encodeWav(renderCue(cue), cue.sampleRate);
  for (const offset of [0, 4, 8, 12, 16, 20, 22, 24, 28, 32, 34, 36, 40]) {
    const corrupt = Buffer.from(wav);
    corrupt[offset] ^= 1;
    assert.throws(() => validateWav(corrupt, cue), /invalid mono PCM16/);
  }
  assert.throws(() => validateWav(wav.subarray(0, 25), cue), /invalid/);
});

test('validator catches silence, clipping, and broken loop endpoints/slopes', () => {
  const cue = cues[0];
  const pcm = renderCue(cue);
  assert.throws(() => validateLevels(new Int16Array(pcm.length), cue), /peak\/RMS/);
  const clipped = pcm.slice(); clipped[100] = 32767;
  assert.throws(() => validateLevels(clipped, cue), /peak\/RMS/);
  const seam = pcm.slice(); seam[0] = 1;
  assert.throws(() => validateLevels(seam, cue), /nonzero seam/);
  const slope = pcm.slice(); slope[1] = 100;
  assert.throws(() => validateLevels(slope, cue), /slope/);
  assert.throws(() => measure(new Int16Array()), /Empty/);
});

test('committed exports and metadata match source, not only repeated generation', async () => {
  const pack = renderPack();
  const manifest = JSON.parse(await readFile(new URL('../resources/audio/export/manifest.json', import.meta.url), 'utf8'));
  assert.deepEqual(manifest, { format: 'audio/1', assets: pack.map(item => item.meta) });
  for (const item of pack) {
    assert.deepEqual(await readFile(new URL(`../resources/audio/export/${item.meta.file}`, import.meta.url)), item.wav);
  }
});
