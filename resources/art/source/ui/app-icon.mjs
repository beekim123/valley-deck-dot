import { PixelCanvas } from '../../lib/pixel.mjs';
import { assets as characters } from '../characters/residents.mjs';
// Original app emblem: a living lantern warms one half of a frosted valley card.
// Composed from this repository's source geometry, never from exported images.
export const assets=[{meta:{id:'icon.app',category:'icon',size:[128,128],anchor:[64,64],frames:1,animations:{idle:{fps:1,loop:true,frames:[0]}}},draw(g){
 g.rect(15,4,98,120,'ink').rect(7,12,114,104,'ink').rect(11,8,106,112,'ink');
 g.rect(17,8,94,112,'wood2').rect(11,16,106,96,'wood2');
 g.rect(19,12,90,104,'wood4').rect(15,18,98,92,'wood4');
 g.rect(21,17,86,94,'ice0').rect(18,22,92,84,'ice0');
 g.rect(64,17,43,94,'leaf0').rect(64,22,46,84,'leaf0');
 g.polygon([[20,70],[35,34],[49,57],[62,30],[75,69]],'ice1');
 g.polygon([[24,64],[35,37],[45,56],[39,53],[35,47],[31,58]],'snow2');
 g.polygon([[66,72],[82,35],[106,73]],'leaf1');
 g.polygon([[77,47],[82,35],[91,49],[85,47],[82,42]],'snow1');
 g.polygon([[19,83],[34,73],[50,78],[64,72],[64,108],[21,108]],'snow1');
 g.polygon([[19,87],[35,80],[51,84],[64,79],[64,108],[21,108]],'snow2');
 g.polygon([[64,79],[79,72],[108,80],[108,108],[64,108]],'leaf2');
 g.polygon([[64,91],[80,83],[108,88],[108,108],[64,108]],'leaf3');
 g.polygon([[55,99],[65,96],[83,107],[98,108],[71,110]],'water1');
 for(const [x,y] of [[26,95],[34,89],[95,92],[103,99]]){g.line(x,y,x,y+7,x<64?'ice1':'leaf0');g.rect(x-2,y,5,2,x<64?'snow3':'bloom1');g.rect(x,y-2,1,5,x<64?'snow3':'bloom0');}
 const lantern=new PixelCanvas(24,32);characters.find(a=>a.meta.id==='char.ember').draw(lantern,{frame:1});
 g.stamp(lantern,40,26,2);
 g.line(22,14,105,14,'paper2').line(16,23,16,105,'wood3');
 g.rect(29,115,70,2,'wood0');
}}];
