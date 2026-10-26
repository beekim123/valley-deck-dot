// Side-on woodcut: one composition, two seasons. All geometry on integer pixels.
import { PixelCanvas, palette } from '../../lib/pixel.mjs';
function pine(g,x,y,height,width){
  const trunkTop=y+Math.floor(height/3);g.rect(x-1,trunkTop,3,height+4-(trunkTop-y),'ink');g.rect(x,trunkTop,1,height+3-(trunkTop-y),'wood1');
  for(let tier=0;tier<3;tier++){
    const top=y+Math.floor(tier*height/4),bottom=top+Math.floor(height/2),half=Math.floor(width*(tier+2)/7);
    g.polygon([[x,top],[x-half,bottom],[x+half,bottom]],'ink');
    g.polygon([[x,top+1],[x-half+2,bottom-1],[x+half-1,bottom-1]],'leaf1');
    g.polygon([[x,top+2],[x-half+2,bottom-2],[x,bottom-2]],'leaf2');
    g.line(x-1,top+3,x-half+3,bottom-3,'leaf3');
  }
}
function spring(g){
  g.fill('ice3');g.rect(0,19,64,14,'water2');
  g.polygon([[0,24],[14,8],[29,25],[43,12],[63,24],[63,35],[0,35]],'snow0');
  g.polygon([[1,24],[14,8],[19,15],[15,14],[12,16],[10,14]],'snow2');
  g.polygon([[26,26],[43,12],[49,18],[44,16],[40,19]],'snow1');
  g.polygon([[0,29],[10,25],[28,28],[45,22],[63,27],[63,40],[0,40]],'wpine1');
  const land=new PixelCanvas(64,48);
  land.polygon([[0,34],[16,32],[31,35],[48,31],[63,33],[63,47],[0,47]],'leaf1');
  land.polygon([[0,35],[16,33],[31,36],[48,32],[63,34],[63,38],[43,36],[26,39],[10,37],[0,39]],'leaf3');
  land.polygon([[0,41],[12,39],[28,41],[44,38],[63,39],[63,47],[0,47]],'leaf0');
  land.polygon([[24,47],[34,41],[41,37],[48,35],[51,36],[44,39],[39,43],[35,47]],'wood2');
  land.line(29,46,38,41,'wood3');
  const ground=land.clone();
  land.pixels.fill(0);
  pine(land,7,9,25,10);pine(land,23,4,31,12);pine(land,54,13,21,11);
  land.rect(13,37,10,5,'ink');land.rect(14,37,8,4,'wood1');land.rect(14,37,8,1,'wood3');
  land.rect(23,37,3,4,'wood3');land.px(24,38,'wood0');
  land.line(3,42,8,40,'leaf2');land.line(46,45,50,42,'leaf2');
  for(const [x,y] of [[11,38],[43,41],[58,38]]){land.px(x,y,'bloom0');land.px(x+1,y,'bloom1');land.px(x,y+1,'leaf2');}
  g.stamp(ground).stamp(land);return {land,ground};
}
const meta=(season)=>({id:`locart.pines.${season}`,category:'location',size:[64,48],anchor:[0,0],frames:1,animations:{idle:{fps:1,loop:true,frames:[0]}}});
export const assets=[
  {meta:meta('spring'),draw(g){spring(g);}},
  {meta:meta('winter'),draw(g){const {land,ground}=spring(g);g.recolor(palette.recolors.winter);ground.recolor({...palette.recolors.winter,leaf0:'snow0',leaf1:'snow1',leaf2:'snow1',leaf3:'snow2'});land.recolor(palette.recolors.winter).snowcap(1,{sky:[]});g.stamp(ground).stamp(land);}},
];
