import { names, meta, scene } from './world.mjs';
// Pines' D0 semantic IDs live in source/location/pines.mjs.
export const assets=names.filter(n=>n!=='pines').flatMap(name=>['spring','winter'].map(season=>({meta:meta(`locart.${name}.${season}`,[64,48]),draw(g){scene(g,name,{winter:season==='winter'});}})));
