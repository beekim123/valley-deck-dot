import { noteHz } from '../synth.ts';
import type { Cue, Note } from '../synth.ts';

// Original D0 sketch: four 3/4 bars at 90 BPM (24 eighth-notes = 8 s).
// Rising from G, with the last A deliberately suspended rather than resolved.
const melody: [string, number][] = [
  ['G4', 2], ['B4', 1], ['A4', 1], ['D5', 2],
  ['E5', 2], ['D5', 3], ['B4', 1],
  ['G4', 3], ['A4', 1], ['C5', 2],
  ['B4', 2], ['A4', 4],
];
let eighth = 0;
const notes: Note[] = melody.map(([pitch, length]) => {
  const note: Note = { at: eighth / 3, duration: length / 3, frequency: noteHz(pitch), gain: 1, voice: 'bell' };
  eighth += length;
  return note;
});

export const cues: readonly Cue[] = [
  {
    id: 'music.test', kind: 'music', sampleRate: 22050, duration: 8, loop: true, targetRmsDbfs: -20,
    notes,
  },
  {
    id: 'sfx.card_drop', kind: 'sfx', sampleRate: 44100, duration: 0.24, loop: false, targetRmsDbfs: -18,
    notes: [
      { at: 0, duration: 0.24, frequency: 180, gain: 1, voice: 'wood', seed: 2718 },
      { at: 0.025, duration: 0.14, frequency: 330, gain: 0.25, voice: 'wood', seed: 1414 },
    ],
  },
  {
    id: 'sfx.ice_crack', kind: 'sfx', sampleRate: 44100, duration: 0.48, loop: false, targetRmsDbfs: -18,
    notes: [
      { at: 0, duration: 0.25, frequency: 1700, gain: 0.75, voice: 'ice', seed: 31415 },
      { at: 0.07, duration: 0.3, frequency: 2200, gain: 0.5, voice: 'ice', seed: 27182 },
      { at: 0.16, duration: 0.32, frequency: 1250, gain: 0.35, voice: 'ice', seed: 16180 },
    ],
  },
];
