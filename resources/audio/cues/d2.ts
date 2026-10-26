import { noteHz } from '../synth.ts';
import type { Cue, Note, Voice } from '../synth.ts';

// Spring Waking: original 3/4 theme, eighth-note units; suspension resolves only at ending.
export const theme: readonly [string, number][] = [
  ['G4',2],['A4',1],['B4',1],['D5',2],
  ['E5',3],['D5',1],['B4',2],
  ['G4',2],['E4',1],['G4',1],['C5',2],
  ['B4',2],['A4',4],
];
const roots = ['G3','E3','C3','D3'];
function note(at: number, duration: number, pitch: string, voice: Voice, gain = 1, seed = 1): Note {
  return { at, duration, frequency: noteHz(pitch), voice, gain, seed };
}
function score(id: string, bpm: number, bars: number, part: 'base'|'strings'|'counter'|'memory'|'full'): Cue {
  const eighth = 30 / bpm, duration = bars * 6 * eighth;
  const notes: Note[] = [];
  if (['base','memory','full'].includes(part)) {
    for (let section = 0; section < bars / 4; section++) {
      let cursor = section * 24;
      const phrase = part === 'memory' ? [...theme.slice(0,7), ...theme.slice(0,7)] : theme;
      // Memory repeats the first two bars, not the resolution.
      for (let j=0; j<phrase.length; j++) {
        const [pitch, length] = phrase[j];
        const final = id === 'music.ending' && section === bars / 4 - 1 && j === phrase.length-1;
        notes.push(note(cursor*eighth, length*eighth, final ? 'G4' : pitch,'bell',0.65));
        cursor += length;
      }
    }
    if (part !== 'memory') for (let bar=0;bar<bars;bar++) {
      notes.push(note(bar*6*eighth,6*eighth, id === 'music.ending' && bar === bars-1 ? 'G3' : roots[bar%4], 'pad',0.32));
    }
  }
  if (part === 'strings' || part === 'full') for (let bar=0;bar<bars;bar++) {
    const pitches = id === 'music.ending' && bar === bars-1 ? ['G3','D4','B3'] : [roots[bar%4], ['D4','B3','G3','A3'][bar%4], ['B3','G3','E3','F#3'][bar%4]];
    for (let beat=0;beat<3;beat++) notes.push(note((bar*6+beat*2)*eighth,2*eighth,pitches[beat],'pluck',0.7,100+bar*3+beat));
  }
  if (part === 'counter' || part === 'full') for (let bar=0;bar<bars;bar++) {
    notes.push(note(bar*6*eighth,4*eighth,id === 'music.ending' && bar === bars-1 ? 'B4' : ['B4','G4','E5','F#4'][bar%4],'flute',0.65));
    notes.push(note((bar*6+4)*eighth,2*eighth,id === 'music.ending' && bar === bars-1 ? 'G4' : ['A4','B4','D5','A4'][bar%4],'flute',0.4));
    for (let beat=0;beat<3;beat++) notes.push(note((bar*6+beat*2)*eighth,0.16,'G2','wood',0.16,500+bar*3+beat));
  }
  return { id, kind:'music',sampleRate:22050,duration,loop:true,targetRmsDbfs: id.startsWith('music.day') ? -21.8 : -20, notes,
    ...(id.startsWith('music.day') ? {layerGroup:'day'} : {}) };
}
const music = [score('music.title',72,8,'base'),score('music.day.l1',88,8,'base'),score('music.day.l2',88,8,'strings'),score('music.day.l3',88,8,'counter'),score('music.night',66,8,'base'),score('music.memory',60,8,'memory'),score('music.ending',96,12,'full')];
const stingSpecs: [string,number,string[]][] = [
 ['awaken',2.5,['G4','A4','B4','D5','E5']],['restore',2,['G4','B4','D5','G5']],
 ['combo',1,['A4','D5','E5']],['event_new',0.8,['G4','C5']],['event_done',1,['B4','D5','G5']],
 ['event_expire',1,['D5','B4','A4']],['goal_step',1.5,['G4','B4','E5','D5']],['dawn',1.5,['G4','A4','D5']],
];
const stings: Cue[] = stingSpecs.map(([name,duration,pitches]) => ({id:`sting.${name}`,kind:'sfx',sampleRate:44100,duration,loop:false,targetRmsDbfs:-18,notes:pitches.map((pitch,i)=>note(i*duration/pitches.length,duration/pitches.length,pitch,'bell'))}));
// Timbral families, not sampled Foley. Each gesture has a fixed source and seed.
const effects: [string,Voice,string,number][] = [
 ['ui_hover','bell','D5',0.10],['ui_click','wood','C5',0.12],['ui_cancel','pluck','A3',0.22],['ui_deny','flute','D4',0.26],
 ['page_turn','wind','G3',0.45],['scroll_unroll','wind','D3',0.7],['card_pick','wood','G4',0.15],['card_return','wood','E3',0.22],
 ['preview_tick','bell','G5',0.08],['card_flip','wind','B4',0.25],['ice_crack_low','ice','D5',0.48],['ice_crack_high','ice','A6',0.48],
 ['ice_shatter','ice','D6',0.65],['snow_puff','wind','G3',0.35],['gain_wood','wood','G3',0.3],['gain_stone','bell','B5',0.3],
 ['gain_warmth','flute','E5',0.45],['chop','wood','C3',0.32],['stone_clink','bell','D6',0.2],['splash','wind','C3',0.4],
 ['skip_stone','bell','E5',0.45],['beaver_gnaw','wood','A3',0.22],['hammer','wood','D3',0.23],['fire_crackle','ice','G4',0.35],
 ['teacup','bell','G6',0.3],['pipe_puff','wind','E3',0.35],['clock_tick','wood','B4',0.1],['ember_huff','wind','G4',0.25],
];
const sfx: Cue[] = effects.map(([name,voice,pitch,duration],i) => ({id:`sfx.${name}`,kind:'sfx',sampleRate:44100,duration,loop:false,targetRmsDbfs:name==='fire_crackle'?-20:-18,notes:[note(0,duration,pitch,voice,1,701+i)]}));
const talks: [string,Voice,string,number][] = [['ember','pulse','A5',0.065],['anuan','flute','A4',0.16],['toby','triangle','G3',0.2],['mira','pulse','E5',0.07],['mei','pluck','B4',0.09],['beavers','pulse','C3',0.09]];
const talk: Cue[] = talks.map(([name,voice,pitch,duration],i) => ({id:`talk.${name}`,kind:'sfx',sampleRate:44100,duration,loop:false,targetRmsDbfs:name==='beavers'?-16:-19,notes:[note(0,duration,pitch,voice,1,900+i)]}));
const amb: Cue[] = [
 {id:'amb.wind',kind:'sfx',sampleRate:44100,duration:16,loop:true,targetRmsDbfs:-20,notes:[note(0,16,'G3','wind',1,72109)]},
 {id:'amb.birds',kind:'sfx',sampleRate:44100,duration:16,loop:true,targetRmsDbfs:-20,notes:Array.from({length:32},(_,i)=>note(i*0.5,0.48,['D6','G6','E6','A6'][i%4],'flute',0.5,800+i))},
];
// A 12 s audition: icy title, full warm day, resolved ending excerpt.
const previewNotes = [music[0], score('music.audition',88,8,'full'), music[6]].flatMap((cue, section) =>
  cue.notes.filter(n => n.at < 3.95).map(n => ({...n, at:n.at+section*4, duration:Math.min(n.duration,3.95-n.at)})));
const preview: Cue = {id:'music.preview',kind:'music',sampleRate:22050,duration:12,loop:false,targetRmsDbfs:-20,notes:previewNotes};
export const cues: readonly Cue[] = [...music,...stings,...sfx,...talk,...amb,preview];
