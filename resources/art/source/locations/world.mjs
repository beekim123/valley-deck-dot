// First-party side-view environment vocabulary. Coordinates, clusters and poses are authored.
import { PixelCanvas, palette } from '../../lib/pixel.mjs';
export const names=['pines','hut','flower_slope','herb_garden','river_bend','misty_bank','tree_hole','mill','gravel','old_bridge','flood_beach'];
export const assets=[]; // Helper module participates safely in source discovery.
export const meta=(id,size,frames=1,category='location')=>({id,category,size,frames,anchor:[0,0],animations:{idle:{fps:frames>1?4:1,loop:true,frames:frames===2?[0,0,0,1]:Array.from({length:frames},(_,i)=>i)}}});
export function pine(g,x,y,h,w){
 g.rect(x-1,y+8,3,h-5,'ink');g.rect(x,y+8,1,h-6,'wood2');
 for(let t=0;t<3;t++){const yy=y+Math.floor(t*h/5),ww=Math.floor(w*(t+3)/5),hh=Math.floor(h/2);g.polygon([[x,yy],[x-ww,yy+hh],[x+ww,yy+hh]],'ink');g.polygon([[x,yy+1],[x-ww+2,yy+hh-1],[x+ww-1,yy+hh-1]],'leaf1');g.polygon([[x,yy+2],[x-ww+2,yy+hh-2],[x,yy+hh-2]],'leaf2');}
}
export function rock(g,x,y,w=10,h=6){g.polygon([[x,y+h],[x+1,y+2],[x+Math.floor(w/3),y],[x+w-2,y+1],[x+w,y+h]],'ink');g.polygon([[x+1,y+h-1],[x+2,y+2],[x+Math.floor(w/3),y+1],[x+w-3,y+2],[x+w-1,y+h-1]],'rock1');g.line(x+2,y+2,x+Math.floor(w/2),y+1,'rock3');g.line(x+Math.floor(w/2),y+2,x+w-2,y+h-1,'rock2');}
export function house(g,x,y,w=28,h=20,mill=false){
 g.rect(x,y,w,h,'ink');g.rect(x+1,y+1,w-2,h-2,'wood2');g.rect(x+w-8,y+1,7,h-2,'wood1');
 for(let yy=y+4;yy<y+h-2;yy+=4)g.line(x+1,yy,x+w-2,yy,'wood0');
 g.rect(x+5,y-10,5,10,'rock0');g.rect(x+5,y-10,4,2,'rock2');
 g.polygon([[x-3,y+2],[x+Math.floor(w/2),y-10],[x+w+3,y+2]],'ink');g.polygon([[x-1,y],[x+Math.floor(w/2),y-8],[x+w,y]],'wood0');g.line(x+1,y-1,x+Math.floor(w/2),y-7,'wood3');g.line(x+3,y,x+w-3,y,'wood1');
 g.rect(x+4,y+5,7,7,'ink');g.rect(x+5,y+6,5,5,'ember3');g.line(x+7,y+6,x+7,y+10,'wood0');g.line(x+5,y+8,x+9,y+8,'wood0');g.rect(x+w-12,y+h-11,7,10,'wood0');g.line(x+w-11,y+h-10,x+w-11,y+h-3,'wood3');g.px(x+w-7,y+h-6,'ember3');
 if(mill)wheel(g,x+w+2,y+h-5,10,0);
}
export function wheel(g,x,y,r,phase){g.ellipse(x,y,r,r,'ink');g.ellipse(x,y,r-1,r-1,'wood2');g.ellipse(x,y,r-3,r-3,'water0');const spokes=phase%2?[[0,-r],[r,0],[0,r],[-r,0]]:[[-r+2,-r+2],[r-2,-r+2],[r-2,r-2],[-r+2,r-2]];for(const [dx,dy]of spokes)g.line(x,y,x+dx,y+dy,'wood3');g.ellipse(x,y,2,2,'wood0');g.px(x,y,'wood4');}
export function flower(g,x,y,c='bloom0'){g.line(x,y,x,y+4,'leaf1');g.px(x-1,y+3,'leaf3');g.rect(x-1,y-1,3,3,c);g.px(x,y,'ember4');}
export function scene(g,name,{winter=false,night=false,frame=0}={}){
 g.fill('ice3');g.rect(3,6,13,2,'snow2');g.rect(8,4,7,2,'snow2');g.rect(47,9,12,2,'snow2');
 g.polygon([[0,27],[12,15],[20,21],[34,9],[48,24],[59,16],[63,21],[63,39],[0,39]],'snow0');g.polygon([[27,16],[34,9],[42,19],[35,16],[33,18]],'snow2');
 g.polygon([[0,30],[13,26],[26,30],[44,25],[63,28],[63,40],[0,40]],'wpine1');
 const ground=new PixelCanvas(64,48);ground.rect(0,35,64,13,'leaf1');ground.line(0,35,63,35,'leaf3');ground.polygon([[0,44],[15,41],[29,43],[49,39],[63,41],[63,47],[0,47]],'leaf0');
 const obj=new PixelCanvas(64,48);
 if(name==='pines'){pine(obj,7,9,28,8);pine(obj,23,4,33,10);pine(obj,54,13,24,9);obj.rect(15,36,10,6,'ink');obj.rect(16,37,8,4,'wood1');obj.rect(16,36,8,2,'wood3');obj.line(25,38,28,36,'wood2');ground.polygon([[29,47],[37,40],[46,36],[50,36],[42,41],[37,47]],'wood2');}
 if(name==='hut'){pine(obj,57,15,24,8);house(obj,15,19);obj.rect(4,33,9,3,'wood0');obj.rect(5,32,7,2,'wood3');obj.rect(6,36,2,4,'wood0');obj.rect(11,36,2,4,'wood0');ground.polygon([[24,47],[29,38],[35,38],[39,47]],'wood2');}
 if(name==='flower_slope'){ground.polygon([[0,40],[12,34],[27,30],[43,31],[63,37],[63,47],[0,47]],'leaf2');ground.line(14,34,28,31,'leaf4');for(const[x,y,c]of [[8,37,'bloom1'],[18,32,'bloom0'],[30,29,'bloom2'],[42,31,'bloom1'],[52,37,'bloom0'],[24,39,'bloom1'],[38,40,'bloom0']])flower(obj,x,y,c);obj.rect(45,27,13,2,'wood0');obj.rect(47,29,2,6,'wood1');obj.rect(55,29,2,7,'wood1');}
 if(name==='herb_garden'){house(obj,36,23,23,16);for(let row=0;row<2;row++){obj.rect(5,32+row*8,26,6,'wood0');obj.line(6,32+row*8,30,32+row*8,'wood3');for(let j=0;j<4;j++){const x=9+j*6,y=31+row*8;obj.line(x,y-3,x,y+2,'leaf1');obj.line(x,y,x-2,y-2,'leaf3');obj.line(x,y-1,x+2,y-3,'leaf4');}}obj.rect(32,31,2,12,'wood1');obj.rect(31,29,5,3,'paper2');}
 if(['river_bend','misty_bank','mill','old_bridge','flood_beach'].includes(name)){ground.polygon([[0,39],[18,35],[39,36],[63,40],[63,47],[0,47]],'water0');ground.polygon([[0,41],[20,38],[39,39],[63,42],[63,46],[40,43],[20,42],[0,45]],'water1');ground.line(3,43,15,41,'water2');ground.line(36,41,51,42,'water2');}
 if(name==='river_bend'){pine(obj,7,11,25,8);obj.line(18,39,35,36,'wood0');obj.line(19,38,35,35,'wood3');obj.line(25,36,29,32,'wood2');rock(obj,47,31,12,7);obj.line(52,30,54,22,'leaf1');obj.line(54,24,58,20,'leaf2');}
 if(name==='misty_bank'){obj.rect(11,13,7,25,'wood0');obj.rect(12,14,3,21,'wood2');obj.line(15,20,6,12,'wood1');obj.line(17,24,28,13,'wood1');obj.ellipse(15,10,11,7,'leaf1');obj.ellipse(10,8,8,5,'leaf2');obj.ellipse(28,12,9,5,'leaf2');obj.polygon([[36,37],[43,26],[54,29],[60,38]],'wood0');obj.line(39,35,48,29,'wood3');obj.line(43,36,52,30,'wood2');obj.ellipse(49,36,3,3,'ink');obj.rect(0,28,32,2,'snow1');obj.rect(25,23,39,2,'snow1');}
 if(name==='tree_hole'){obj.polygon([[19,40],[23,21],[20,4],[36,2],[40,22],[45,40]],'ink');obj.polygon([[21,38],[25,21],[23,5],[34,4],[36,23],[42,39]],'wood1');obj.line(26,6,28,20,'wood3');obj.line(34,7,32,18,'wood0');obj.ellipse(32,31,7,10,'wood0');obj.ellipse(32,32,5,8,'ink');obj.line(24,17,12,11,'wood1');obj.line(38,20,52,9,'wood0');obj.ellipse(19,8,15,8,'leaf1');obj.ellipse(16,5,11,5,'leaf2');obj.ellipse(43,8,15,8,'leaf1');obj.ellipse(42,4,11,5,'leaf2');flower(obj,17,38,'bloom0');}
 if(name==='mill'){house(obj,13,17,29,23,true);obj.rect(2,31,13,4,'wood0');obj.line(2,31,14,31,'wood3');obj.rect(4,35,2,6,'wood1');}
 if(name==='gravel'){ground.rect(0,35,64,13,'rock1');ground.rect(0,42,64,6,'rock0');for(const[x,y,w,h]of [[3,31,15,8],[25,28,19,11],[48,33,13,8],[17,40,9,5],[36,41,12,6]])rock(obj,x,y,w,h);obj.line(3,45,10,45,'rock2');obj.line(51,44,61,43,'rock2');}
 if(name==='old_bridge'){obj.rect(8,28,5,15,'rock0');obj.rect(49,28,5,15,'rock0');obj.rect(9,29,3,13,'rock2');obj.rect(50,29,3,13,'rock1');obj.polygon([[4,27],[20,25],[42,25],[59,27],[59,31],[43,29],[20,29],[4,31]],'wood0');obj.line(5,27,20,26,'wood3');obj.line(20,26,42,26,'wood3');obj.line(42,26,58,28,'wood3');for(const x of [8,20,42,54])obj.rect(x,19,2,9,'wood0');obj.line(8,19,20,18,'wood2');obj.line(20,18,42,18,'wood2');obj.line(42,18,55,20,'wood2');}
 if(name==='flood_beach'){ground.polygon([[0,36],[17,35],[28,38],[48,39],[63,37],[63,43],[45,45],[26,42],[0,42]],'wood3');obj.line(8,38,25,37,'wood0');obj.line(9,37,24,36,'wood2');for(const[x,y]of [[32,39],[45,41],[56,38]]){obj.rect(x,y,4,2,'snow2');obj.px(x+1,y-1,'bloom1');obj.px(x+2,y,'wood3');}obj.rect(17,41,6,3,'paper2');obj.line(17,41,20,43,'paper1');obj.line(20,43,22,41,'paper1');}
 if(winter){g.recolor(palette.recolors.winter);ground.recolor({...palette.recolors.winter,leaf0:'snow0',leaf1:'snow1',leaf2:'snow2',leaf3:'snow3',wood2:'snow1',wood3:'snow2',rock1:'snow1'});obj.recolor(palette.recolors.winter).snowcap(1,{sky:[]});}
 g.stamp(ground).stamp(obj);
 if(night)g.recolor({ice3:'night0',snow2:'ice2',snow0:'night1',wpine1:'ice0',leaf2:'leaf1',leaf3:'leaf2',leaf4:'leaf3',wood3:'wood2',water1:'water0',water2:'ice1'});
 return {ground,obj};
}
