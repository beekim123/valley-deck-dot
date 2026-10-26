/** Pure offline synthesis: no I/O, engine, wall-clock time, or global RNG. */
export type Voice = 'bell' | 'flute' | 'wood' | 'ice';
export interface Note {
  at: number;
  duration: number;
  frequency: number;
  gain: number;
  voice: Voice;
  seed?: number;
}
export interface Cue {
  id: string;
  kind: 'music' | 'sfx';
  sampleRate: number;
  duration: number;
  loop: boolean;
  targetRmsDbfs: number;
  notes: readonly Note[];
  layerGroup?: string;
}

export function seededNoise(seed: number): () => number {
  let state = seed >>> 0;
  return () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let n = Math.imul(state ^ (state >>> 15), state | 1);
    n ^= n + Math.imul(n ^ (n >>> 7), n | 61);
    return ((n ^ (n >>> 14)) >>> 0) / 4294967296 * 2 - 1;
  };
}

export function noteHz(name: string): number {
  const match = /^([A-G])([#b]?)([0-8])$/.exec(name);
  if (!match) throw new Error(`Invalid note: ${name}`);
  const semitones = { C: 0, D: 2, E: 4, F: 5, G: 7, A: 9, B: 11 };
  const midi = (Number(match[3]) + 1) * 12 + semitones[match[1] as keyof typeof semitones]
    + (match[2] === '#' ? 1 : match[2] === 'b' ? -1 : 0);
  return 440 * 2 ** ((midi - 69) / 12);
}

function finite(value: number, name: string, min: number, max: number): void {
  if (!Number.isFinite(value) || value < min || value > max) throw new Error(`Invalid ${name}: ${value}`);
}

export function renderCue(cue: Cue): Int16Array {
  if (!/^(music|sfx)\.[a-z0-9_.]+$/.test(cue.id)) throw new Error('Invalid cue id');
  if (cue.kind !== 'music' && cue.kind !== 'sfx') throw new Error('Invalid cue kind');
  if (cue.sampleRate !== (cue.kind === 'music' ? 22050 : 44100)) throw new Error('Invalid sample rate');
  finite(cue.duration, 'duration', 0.01, 40);
  finite(cue.targetRmsDbfs, 'RMS target', -40, -10);
  const count = Math.round(cue.duration * cue.sampleRate);
  if (count * 2 + 44 >= 2_000_000) throw new Error('Cue exceeds 2 MB');
  const mix = new Float64Array(count);
  for (const note of cue.notes) {
    finite(note.at, 'onset', 0, cue.duration);
    finite(note.duration, 'note duration', 0.005, cue.duration);
    finite(note.frequency, 'frequency', 20, cue.sampleRate / 8);
    finite(note.gain, 'gain', 0, 4);
    if (note.at + note.duration > cue.duration + 1e-9) throw new Error('Note exceeds cue');
    if (!['bell', 'flute', 'wood', 'ice'].includes(note.voice)) throw new Error('Invalid voice');
    const random = seededNoise(note.seed ?? 1);
    const start = Math.round(note.at * cue.sampleRate);
    const length = Math.round(note.duration * cue.sampleRate);
    let lowpass = 0;
    for (let i = 0; i < length && start + i < count; i++) {
      const t = i / cue.sampleRate;
      const phase = 2 * Math.PI * note.frequency * t;
      const position = i / (length - 1);
      // Smooth attack and release keep both note endpoints at zero.
      const edge = Math.sin(Math.PI / 2 * Math.min(1, t / 0.006)) ** 2
        * Math.sin(Math.PI / 2 * Math.min(1, (length - 1 - i) / (cue.sampleRate * 0.035))) ** 2;
      let value = 0;
      if (note.voice === 'bell') {
        value = Math.sin(phase + 0.65 * Math.exp(-5 * position) * Math.sin(phase * 2)) * Math.exp(-2.1 * position);
      } else if (note.voice === 'flute') {
        value = (Math.sin(phase + 0.012 * Math.sin(2 * Math.PI * 4.5 * t)) + 0.12 * Math.sin(phase * 2)) * Math.sin(Math.PI * position);
      } else if (note.voice === 'wood') {
        lowpass += 0.14 * (random() - lowpass);
        value = (0.5 * Math.sin(phase * (1 - 0.15 * position)) + lowpass) * Math.exp(-5 * position);
      } else {
        const noise = random();
        lowpass += 0.12 * (noise - lowpass);
        value = (0.5 * (noise - lowpass) + 0.3 * Math.sin(phase) + 0.2 * Math.sin(phase * 1.43)) * Math.exp(-3.8 * position);
      }
      mix[start + i] += value * edge * note.gain;
    }
  }
  // Global edge fade is applied before RMS normalization; no hidden limiter/clipping.
  const fade = Math.min(Math.floor(count / 2), Math.round(cue.sampleRate * 0.012));
  let energy = 0;
  for (let i = 0; i < count; i++) {
    mix[i] *= Math.sin(Math.PI / 2 * Math.min(1, i / fade, (count - 1 - i) / fade)) ** 2;
    energy += mix[i] ** 2;
  }
  if (energy === 0) throw new Error('Silent cue');
  const gain = 10 ** (cue.targetRmsDbfs / 20) / Math.sqrt(energy / count);
  const pcm = new Int16Array(count);
  for (let i = 0; i < count; i++) {
    const sample = mix[i] * gain;
    if (!Number.isFinite(sample) || Math.abs(sample) > 10 ** (-1 / 20)) throw new Error('Peak exceeds -1 dBFS; revise arrangement');
    pcm[i] = Math.round(sample * 32767);
  }
  return pcm;
}

export function measure(samples: Int16Array) {
  if (!samples.length) throw new Error('Empty PCM');
  let peak = 0, energy = 0;
  for (const sample of samples) {
    const value = sample / 32768;
    peak = Math.max(peak, Math.abs(value));
    energy += value * value;
  }
  return {
    peakDbfs: 20 * Math.log10(peak),
    rmsDbfs: 10 * Math.log10(energy / samples.length),
    seamDelta: Math.abs(samples[0] - samples[samples.length - 1]),
    first: samples[0], last: samples[samples.length - 1],
  };
}
