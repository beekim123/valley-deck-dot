import {PixelCanvas,palette} from '../../lib/pixel.mjs';
import {meta,scene,pine,flower} from '../locations/world.mjs';
export const order=['pines','tree_hole','hut','flower_slope','herb_garden','river_bend','flood_beach','misty_bank','mill','gravel','old_bridge'];
// Boundary columns are exactly identical for either neighbor/order: land y=58, road y=72.
// Ridges are authored piecewise triangles and meet at fixed y=31/45 at x=0,127.
export function panorama(g,name,winter){
 const k=order.indexOf(name), peak=10+(k%4)*3, ridge=35+(k%3)*2;
 g.fill('ice3');g.rect(19+(k%4)*5,8+(k%3)*2,21,2,'snow2');g.rect(26+(k%4)*5,6+(k%3)*2,10,2,'snow2');
 g.polygon([[0,31],[22,16+(k%3)*3],[39,29],[61,peak],[88,29],[107,19+(k%4)*2],[127,31],[127,59],[0,59]],'snow0');g.polygon([[51,peak+10],[61,peak],[73,peak+12],[63,peak+8],[59,peak+11]],'snow2');
 g.polygon([[0,45],[16,39],[39,44],[64,ridge],[87,42],[111,38],[127,45],[127,60],[0,60]],'wpine1');
 g.rect(0,58,128,22,'leaf1');g.rect(0,58,128,2,'leaf3');g.rect(0,72,128,5,'wood2');g.rect(0,72,128,1,'wood3');g.rect(0,78,128,2,'leaf0');
 if(winter)g.recolor({...palette.recolors.winter,leaf1:'snow1',leaf0:'snow0',leaf3:'snow2'});
 const temp=new PixelCanvas(64,48);const {obj}=scene(temp,name,{winter});
 // The landmark is a transparent layer, not a rectangular copy of a card.
 g.stamp(obj,32,23);
 if(['river_bend','misty_bank','mill','old_bridge','flood_beach'].includes(name)){
  const water=new PixelCanvas(128,80);water.polygon([[12,65],[28,60],[51,61],[69,65],[92,63],[115,66],[114,69],[89,67],[69,69],[47,65],[27,64]],'water0');water.line(20,66,36,64,'water2');water.line(77,67,96,66,'water1');if(winter)water.recolor(palette.recolors.winter);g.stamp(water);g.stamp(obj,32,23);
 }
 const trim=new PixelCanvas(128,80);if(['pines','tree_hole','hut','misty_bank'].includes(name)){pine(trim,14,29,32,10);pine(trim,112,34,29,9);}else{for(const[x,y]of [[15,64],[25,66],[103,64],[112,67]])flower(trim,x,y,'bloom1');}if(winter)trim.recolor(palette.recolors.winter).snowcap(1,{sky:[]});g.stamp(trim);
 // Intentionally untouched two-pixel safety margin makes the exact join test meaningful.
}
export const assets=order.flatMap(n=>['spring','winter'].map(s=>({meta:meta(`pano.${n}.${s}`,[128,80],1,'panorama'),draw(g){panorama(g,n,s==='winter');}})));
