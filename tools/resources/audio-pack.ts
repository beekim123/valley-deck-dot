import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
import { cues as d0 } from '../../resources/audio/cues/d0.ts';
import { cues as d2 } from '../../resources/audio/cues/d2.ts';
export const cues = [...d0, ...d2];
import { renderCue, measure } from '../../resources/audio/synth.ts';
import type { Cue } from '../../resources/audio/synth.ts';

const output = new URL('../../resources/audio/export/', import.meta.url);
export function encodeWav(samples: Int16Array, sampleRate: number): Buffer {
  const wav = Buffer.alloc(44 + samples.length * 2);
  wav.write('RIFF', 0); wav.writeUInt32LE(wav.length - 8, 4); wav.write('WAVE', 8);
  wav.write('fmt ', 12); wav.writeUInt32LE(16, 16); wav.writeUInt16LE(1, 20);
  wav.writeUInt16LE(1, 22); wav.writeUInt32LE(sampleRate, 24);
  wav.writeUInt32LE(sampleRate * 2, 28); wav.writeUInt16LE(2, 32); wav.writeUInt16LE(16, 34);
  wav.write('data', 36); wav.writeUInt32LE(samples.length * 2, 40);
  for (let i = 0; i < samples.length; i++) wav.writeInt16LE(samples[i], 44 + i * 2);
  return wav;
}

export function validateWav(wav: Buffer, cue: Cue): Int16Array {
  if (wav.length < 44 || wav.toString('ascii', 0, 4) !== 'RIFF' || wav.toString('ascii', 8, 12) !== 'WAVE'
    || wav.toString('ascii', 12, 16) !== 'fmt ' || wav.readUInt32LE(16) !== 16
    || wav.readUInt16LE(20) !== 1 || wav.readUInt16LE(22) !== 1 || wav.readUInt16LE(34) !== 16
    || wav.readUInt32LE(24) !== cue.sampleRate || wav.readUInt32LE(28) !== cue.sampleRate * 2
    || wav.readUInt16LE(32) !== 2 || wav.toString('ascii', 36, 40) !== 'data'
    || wav.readUInt32LE(4) !== wav.length - 8 || wav.readUInt32LE(40) !== wav.length - 44
    || wav.length !== 44 + Math.round(cue.sampleRate * cue.duration) * 2 || wav.length >= 2_000_000) {
    throw new Error(`${cue.id}: invalid mono PCM16 WAV`);
  }
  const samples = new Int16Array((wav.length - 44) / 2);
  for (let i = 0; i < samples.length; i++) samples[i] = wav.readInt16LE(44 + i * 2);
  return samples;
}

export function validateLevels(samples: Int16Array, cue: Cue) {
  const stats = measure(samples);
  const target = cue.kind === 'music' ? -20 : -18;
  const tolerance = cue.kind === 'music' ? 2 : 3;
  if (!Number.isFinite(stats.rmsDbfs) || stats.peakDbfs > -1 || Math.abs(stats.rmsDbfs - target) > tolerance) {
    throw new Error(`${cue.id}: peak/RMS outside documented limits`);
  }
  if (stats.first !== 0 || stats.last !== 0 || stats.seamDelta !== 0) throw new Error(`${cue.id}: nonzero seam`);
  // Check adjacent edge slopes as well as the exact wrap point (<= -60 dBFS).
  if (Math.abs(samples[1]) > 32 || Math.abs(samples[samples.length - 2]) > 32) throw new Error(`${cue.id}: abrupt seam slope`);
  return stats;
}

export function renderPack() {
  const seen = new Set<string>();
  const layers = new Map<string, string>();
  const pack = cues.map(cue => {
    if (seen.has(cue.id)) throw new Error(`Duplicate audio id: ${cue.id}`);
    seen.add(cue.id);
    const samples = renderCue(cue);
    const stats = validateLevels(samples, cue);
    const wav = encodeWav(samples, cue.sampleRate);
    validateWav(wav, cue);
    if (cue.layerGroup) {
      const signature = `${cue.sampleRate}/${samples.length}/${cue.loop}`;
      if (layers.has(cue.layerGroup) && layers.get(cue.layerGroup) !== signature) throw new Error('Layer length/rate/loop mismatch');
      layers.set(cue.layerGroup, signature);
    }
    return { wav, meta: {
      id: cue.id, file: `${cue.id}.wav`, kind: cue.kind, sampleRate: cue.sampleRate,
      channels: 1, bitsPerSample: 16, frames: samples.length, duration: cue.duration, loop: cue.loop,
      ...(cue.layerGroup ? { layerGroup: cue.layerGroup } : {}),
      hash: createHash('sha256').update(wav).digest('hex'),
      peakDbfs: Number(stats.peakDbfs.toFixed(6)), rmsDbfs: Number(stats.rmsDbfs.toFixed(6)), seamDelta: stats.seamDelta,
    } };
  });
  // Verify the actual sum using float arithmetic, never an overflowing Int16 accumulator.
  const day = pack.filter(item => item.meta.layerGroup === 'day');
  const pcm = day.map(item => validateWav(item.wav, cues.find(cue => cue.id === item.meta.id)!));
  for (const active of [1, 2, 3]) {
    let peak = 0;
    for (let frame=0; frame<pcm[0].length; frame++) {
      let sample = 0;
      for (let layer=0; layer<active; layer++) sample += pcm[layer][frame] / 32768;
      peak = Math.max(peak, Math.abs(sample));
    }
    if (peak > 10 ** (-1/20)) throw new Error(`Day ${active}-layer sum exceeds -1 dBFS; revise arrangement`);
  }
  return pack;
}

export async function run(command: string) {
  if (!['build', 'check'].includes(command)) throw new Error('Usage: audio-pack.ts build|check');
  const pack = renderPack();
  const manifest = `${JSON.stringify({ format: 'audio/1', assets: pack.map(item => item.meta) }, null, 2)}\n`;
  if (command === 'build') {
    await mkdir(output, { recursive: true });
    for (const item of pack) await writeFile(new URL(item.meta.file, output), item.wav);
    await writeFile(new URL('manifest.json', output), manifest);
  } else {
    const second = renderPack();
    for (let i = 0; i < pack.length; i++) {
      const item = pack[i];
      if (!item.wav.equals(second[i].wav)) throw new Error(`${item.meta.id}: nondeterministic synthesis`);
      const saved = await readFile(new URL(item.meta.file, output));
      validateLevels(validateWav(saved, cues[i]), cues[i]);
      if (!item.wav.equals(saved)) throw new Error(`${item.meta.id}: stale export; run audio:build`);
    }
    if (await readFile(new URL('manifest.json', output), 'utf8') !== manifest) throw new Error('Stale audio manifest; run audio:build');
  }
  for (const { meta } of pack) {
    console.log(`${meta.id}: ${meta.frames} frames, peak ${meta.peakDbfs} dBFS, RMS ${meta.rmsDbfs} dBFS, seam ${meta.seamDelta}, SHA-256 ${meta.hash}`);
  }
  console.log(`Audio ${command}: ${pack.length} assets passed${command === 'check' ? ' (double render + saved bytes)' : ''}.`);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  run(process.argv[2] ?? '').catch(error => { console.error(error.message); process.exitCode = 1; });
}
