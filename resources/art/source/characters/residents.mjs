import { readFileSync } from 'node:fs';
import { PixelCanvas, palette, characterFrame } from '../../lib/pixel.mjs';
// Original first-party silhouette designs: oversized mantle, scout pigtails,
// herb bun, broad beaver muzzle, flour cap, seed-shaped hood and pine beard.
const toby=JSON.parse(readFileSync(new URL('../portrait/toby.json',import.meta.url),'utf8'));
const names=['anuan','toby','mira','mei','beavers','gutu','xiaosu','baiweng','mill_family'];
const coats={anuan:'coat',toby:'leaf1',mira:'ember2',mei:'bloom0',beavers:'wood2',gutu:'paper1',xiaosu:'leaf2',baiweng:'wpine1'};
const darks={anuan:'ice0',toby:'leaf0',mira:'ember0',mei:'skin0',beavers:'wood0',gutu:'paper0',xiaosu:'leaf0',baiweng:'wpine0'};
function face(id,expression=0){
 if(id==='toby')return characterFrame(toby.frames[Math.min(expression,2)],toby.size);
 const g=new PixelCanvas(40,40), old=['mei','baiweng','gutu'].includes(id), hair=old?'snow1':id==='mira'?'wood2':'wood0';
 if(id==='mill_family'){g.stamp(face('gutu',expression),-5,-2);g.stamp(face('xiaosu',expression),13,10);return g;}
 if(id==='beavers'){
  g.ellipse(19,29,15,9,'wood0').ellipse(17,27,12,8,'wood2');
  g.ellipse(8,8,5,5,'ink').ellipse(8,8,3,3,'wood3').ellipse(29,8,5,5,'ink').ellipse(29,8,3,3,'wood3');
  g.ellipse(19,18,15,13,'ink').ellipse(18,17,13,12,'wood1').ellipse(14,13,9,7,'wood2');
  g.ellipse(12,22,7,5,'wood4').ellipse(25,22,7,5,'wood3');g.rect(16,25,7,6,'ink').rect(17,25,2,5,'snow3').rect(20,25,2,5,'snow2');
  g.ellipse(19,20,3,2,'ink'); g.rect(11,15,2,3,'ink').rect(26,15,2,3,'ink');
  if(expression===1)g.line(10,15,13,14,'ink').line(25,14,28,15,'ink');
  if(expression===2)g.rect(10,12,4,1,'ink').rect(25,12,4,1,'ink');
  // Three kits peek up below their father's elbows.
  for(const [x,y] of [[5,33],[19,34],[33,33]]){g.ellipse(x,y,5,4,'ink').ellipse(x,y,4,3,'wood3').px(x-2,y-1,'ink').px(x+2,y-1,'ink').rect(x,y+1,1,2,'snow2');}return g;
 }
 if(id==='mira')g.polygon([[5,12],[1,20],[4,29],[10,26],[10,12]],'ink').polygon([[31,12],[38,17],[37,28],[31,25]],'ink').rect(4,17,4,7,'wood2').rect(33,16,3,8,'wood2');
 if(id==='mei')g.ellipse(27,5,7,4,'ink').ellipse(26,4,5,3,'snow1').line(21,3,32,7,'wood3');
 g.polygon([[11,27],[27,27],[34,32],[36,38],[4,38],[6,32]],'ink');g.polygon([[11,28],[27,28],[32,33],[33,37],[7,37],[8,32]],coats[id]);g.polygon([[26,28],[31,32],[32,37],[25,37]],darks[id]);
 g.ellipse(19,17,12,13,'ink').ellipse(18,17,10,11,'skin1').ellipse(17,15,9,10,'skin2').rect(11,11,4,4,'skin3');
 g.ellipse(7,18,2,3,'skin1').ellipse(30,18,2,3,'skin1');
 if(id==='baiweng'){
  g.polygon([[7,15],[7,7],[14,3],[27,5],[31,12],[28,15],[23,9],[14,10]],'ink').polygon([[8,11],[11,6],[20,5],[28,8],[29,12],[22,8],[15,9]],'snow1');
  g.polygon([[9,22],[14,25],[18,22],[23,25],[29,21],[27,30],[22,36],[18,39],[13,34]],'ink').polygon([[11,23],[16,27],[19,24],[23,27],[27,24],[25,31],[19,36],[14,32]],'snow1').line(16,29,18,33,'snow3');
 }else if(id==='gutu'){
  g.polygon([[6,12],[8,5],[12,2],[28,3],[32,8],[31,13]],'ink').polygon([[8,10],[10,5],[15,4],[28,5],[30,10]],'paper2').rect(7,11,25,3,'paper0').rect(9,11,21,1,'paper1');
  g.ellipse(15,23,5,2,'wood1').ellipse(23,23,5,2,'wood1');g.rect(14,29,11,9,'paper2').line(14,30,11,28,'paper2').line(24,30,27,28,'paper2');
 }else if(id==='xiaosu'){
  g.polygon([[5,20],[7,8],[13,3],[24,2],[31,9],[34,24],[29,29],[27,16],[23,9],[13,11],[10,25]],'ink').polygon([[7,20],[9,9],[14,5],[24,4],[29,10],[32,23],[29,25],[27,13],[22,7],[12,9],[9,22]],'leaf2');g.rect(16,4,5,2,'leaf4');
  g.rect(13,28,13,5,'ember3').rect(20,32,4,6,'ember2');
 }else{
  g.polygon([[7,17],[7,9],[12,4],[23,3],[29,7],[31,16],[27,13],[24,9],[20,12],[17,9],[11,13],[11,18]],'ink');g.polygon([[8,12],[10,8],[15,5],[23,5],[28,8],[28,11],[24,7],[19,10],[16,7],[11,11]],hair);
  if(id==='anuan'){g.rect(9,27,21,5,'scarf').rect(25,30,6,7,'ember0').rect(26,31,3,5,'scarf');g.line(9,28,23,28,'ember1');}
  if(id==='mira'){g.rect(4,13,5,3,'scarf').rect(31,12,5,3,'scarf').line(10,30,28,36,'wood0');g.rect(25,34,6,4,'wood3');}
  if(id==='mei'){g.ellipse(13,17,5,4,'wood0').ellipse(25,17,5,4,'wood0').ellipse(13,17,4,3,'skin2').ellipse(25,17,4,3,'skin2').line(18,17,20,17,'wood0');g.rect(12,32,14,5,'paper2').rect(18,30,2,6,'leaf1').line(18,32,15,30,'leaf2');}
 }
 for(const x of [13,25]){if(expression===1)g.line(x-1,17,x,16,'ink').line(x,16,x+1,17,'ink');else g.rect(x,expression===2?15:16,2,expression===2?4:3,'ink');}
 g.rect(10,21,3,1,'bloom0').rect(26,21,3,1,'bloom0');
 if(expression===2)g.ellipse(19,24,2,2,'skin0');else if(expression===1)g.line(17,24,21,24,'skin0').px(19,25,'skin0');else g.line(18,24,20,24,'skin0');
 return g;
}
function portrait(id,f){return f===3?face(id).recolor(palette.recolors.memory):face(id,f);}
function big(g,id,f){
 if(id==='mill_family'){const a=new PixelCanvas(96,96),b=new PixelCanvas(96,96);big(a,'gutu',f);big(b,'xiaosu',f);g.stamp(a,-20,0).stamp(b,24,9);return;}
 const c=coats[id],d=darks[id], bob=f;
 if(id==='beavers'){
  g.ellipse(49,90,29,3,'ink2').ellipse(74,73,15,10,'ink').ellipse(73,72,13,8,'wood1');
  for(let x=63;x<84;x+=5)g.line(x,67,x+3,77,'wood0');
  g.ellipse(48,65+f,25,23,'ink').ellipse(47,64+f,23,21,'wood1').ellipse(43,61+f,17,18,'wood2').ellipse(46,69+f,13,13,'wood3');
  g.ellipse(26,60+f,6,9,'ink').ellipse(26,59+f,4,7,'wood2').ellipse(69,61-f,6,9,'ink').ellipse(69,60-f,4,7,'wood2');
  const head=new PixelCanvas(40,31);head.stamp(face(id,f));g.stamp(head,28,15+f);
  for(const [x,y] of [[28,82],[48,85],[67,83]]){g.ellipse(x,y,8,8,'ink').ellipse(x,y,7,7,'wood2').ellipse(x-4,y-7,3,3,'wood0').ellipse(x+4,y-7,3,3,'wood0').ellipse(x,y+2,6,3,'wood4').px(x-3,y-1,'ink').px(x+3,y-1,'ink').rect(x-1,y+3,2,3,'snow3');}return;
 }
 if(id==='mira'||id==='xiaosu'){
  g.ellipse(48,87,23,3,'ink2').rect(38,73,7,13,'ink').rect(53,73,7,13,'ink').rect(35,83,11,4,'wood0').rect(53,83,11,4,'wood0');
  g.polygon([[37,44+f],[58,44+f],[63,52],[70,76],[64,79],[30,79],[25,75],[32,52]],'ink').polygon([[37,46+f],[57,46+f],[61,54],[67,75],[62,76],[32,76],[28,74],[34,53]],c).polygon([[56,48],[61,54],[67,75],[59,76]],d);
  g.ellipse(28,62-f*3,5,6,'ink').ellipse(28,61-f*3,3,4,'skin2').ellipse(67,63+f,5,6,'ink').ellipse(67,62+f,3,4,'skin1');
  const head=new PixelCanvas(40,31);head.stamp(face(id,f));g.stamp(head,28,14+f);
  if(id==='mira'){g.rect(22,48,9,20,'wood0').rect(23,49,6,16,'wood3').line(36,46,60,71,'wood0').rect(55,66,13,10,'wood1').rect(56,67,10,2,'wood3');g.rect(38,48,3,5,'paper2');}
  else {g.rect(35,44+f,26,5,'ember3').rect(55,48+f,6,13,'ember2');g.ellipse(47,68,12,9,'wood0').ellipse(46,66,10,7,'wood3');for(let x=40;x<55;x+=4)g.line(x,62,x,73,'wood1');g.line(44,60,42,51,'leaf1').line(48,59,52,50,'leaf2');}return;
 }
 g.ellipse(48,91,27,3,'ink2');
 if(id==='beavers'){g.ellipse(74,73,15,10,'ink').ellipse(73,73,13,8,'wood1');for(let x=63;x<84;x+=5)g.line(x,68,x+3,78,'wood0');}
 g.rect(34,76,12,15,'ink').rect(51,76,12,15,'ink').rect(36,78,8,10,d).rect(53,78,8,10,d).rect(31,88,15,4,'wood0').rect(51,88,16,4,'wood0');
 g.polygon([[31,34+bob],[63,34+bob],[72,46+bob],[69,75],[60,81],[34,81],[26,73],[24,47+bob]],'ink');
 g.polygon([[32,36+bob],[61,36+bob],[69,47+bob],[66,74],[58,78],[34,78],[29,72],[27,48+bob]],c);
 g.polygon([[57,38+bob],[65,45+bob],[65,74],[57,77]],d);g.rect(31,45,5,23,id==='anuan'?'paper1':c);g.line(48,43,48,76,d);
 g.ellipse(26,61-f*3,6,7,'ink').ellipse(26,60-f*3,4,5,'skin2').ellipse(69,61+f*2,6,7,'ink').ellipse(69,60+f*2,4,5,'skin1');
 for(let y=50;y<74;y+=10)g.rect(50,y,2,2,'wood4');
 const p=portrait(id,f);const head=new PixelCanvas(40,30);head.stamp(p,0,0);g.stamp(head,28,6+bob);
 if(id==='anuan'){g.rect(32,34+bob,30,6,'scarf').rect(57,39+bob,8,18,'scarf').line(58,40+bob,58,54,'ember1');g.rect(65,68,11,15,'ink').rect(67,70,7,10,'ember2').rect(69,73,3,6,'ember4');g.line(67,67,73,67,'rock1');}
 if(id==='toby'){g.line(74,30-f*2,65,85,'wood0').line(75,30-f*2,66,85,'wood3');g.polygon([[72,32-f*2],[82,29-f*2],[86,39-f*2],[73,42-f*2]],'ink').polygon([[75,33-f*2],[81,32-f*2],[83,38-f*2],[74,39-f*2]],'rock2');}
 if(id==='mira'){g.rect(22,46,9,22,'wood0').rect(23,47,6,18,'wood3');g.line(33,40,60,72,'wood0');g.rect(54,66,13,11,'wood1').rect(55,67,10,2,'wood3');}
 if(id==='mei'){g.rect(34,49,23,29,'paper1').rect(36,50,18,26,'paper2');g.ellipse(26,60-f*3,7,3,'wood0').rect(20,60-f*3,12,8,'paper2').rect(22,61-f*3,8,2,'ember0');}
 if(id==='gutu'){g.rect(34,45,25,33,'paper2').rect(38,65,17,9,'paper1');g.rect(38,46,3,7,'snow3');}
 if(id==='xiaosu'){g.ellipse(47,66,12,10,'wood0').ellipse(46,64,10,8,'wood3');for(let x=40;x<55;x+=4)g.line(x,60,x,71,'wood1');g.line(44,58,42,49,'leaf1').line(48,57,52,48,'leaf2');}
 if(id==='baiweng'){g.line(73,28,73,91,'wood0').line(74,29,74,90,'wood3');g.ellipse(73,27,4,4,'wood0').ellipse(73,26,2,2,'ember3');g.polygon([[35,32],[43,38],[52,34],[59,31],[55,48],[47,56],[39,47]],'snow1').line(43,39,46,49,'snow3');}
}
function walker(g,id,f){
 if(id==='mill_family'){walker(g,'gutu',f);g.rect(11,13,4,6,'leaf2').rect(12,12,3,3,'skin2').px(14,13,'ink').rect(12,20,1,3,'wood0').rect(15,20,1,3,'wood0');return;}
 const work=f>=4&&f<8,step=f<4?[0,1,0,-1][f]:0,bob=(f===1||f===3||f===9)?1:0,c=coats[id],d=darks[id];
 if(id==='beavers'){g.ellipse(12,18,3,4,'wood0').ellipse(7,15+bob,5,6,'wood1').ellipse(7,8+bob,6,5,'ink').ellipse(7,8+bob,5,4,'wood2').rect(3,3+bob,3,3,'wood1').rect(10,3+bob,3,3,'wood1').rect(3,9+bob,9,3,'wood3').px(5,7+bob,'ink').px(10,7+bob,'ink').rect(7,11+bob,2,3,'snow2');}
 else{
 g.rect(4,12+bob,8,8,'ink').rect(5,13+bob,6,6,c).rect(10,14+bob,1,5,d);
 g.ellipse(7,7+bob,5,5,'ink').ellipse(7,8+bob,4,4,'skin2').rect(3,3+bob,9,3,['mei','baiweng'].includes(id)?'snow1':'wood0').px(9,8+bob,'ink');
 if(id==='anuan')g.rect(3,12+bob,9,2,'scarf').rect(10,14+bob,3,3,'scarf').rect(12,17+bob,3,4,'ember3');
 if(id==='toby')g.rect(2,2+bob,11,4,'wood1').rect(3,10+bob,8,4,'wood1').rect(4,14+bob,8,5,'leaf1');
 if(id==='mira')g.rect(1,6+bob,2,5,'wood2').rect(12,6+bob,2,5,'wood2').px(1,5+bob,'scarf').px(12,5+bob,'scarf');
 if(id==='mei')g.ellipse(10,2+bob,3,2,'snow1').line(3,8+bob,11,8+bob,'wood0').rect(6,14+bob,4,5,'paper2');
 if(id==='gutu')g.rect(3,1+bob,9,4,'paper2').rect(2,5+bob,11,1,'paper0').rect(6,13+bob,5,7,'paper2');
 if(id==='xiaosu')g.polygon([[2,8+bob],[4,2+bob],[10,1+bob],[13,9+bob],[11,12+bob],[10,5+bob],[5,5+bob],[4,12+bob]],'leaf2');
 if(id==='baiweng')g.polygon([[3,10+bob],[7,12+bob],[11,10+bob],[10,15+bob],[7,18+bob],[4,14+bob]],'snow1');
 }
 g.rect(4+step,20,3,3,'wood0').rect(9-step,20,3,3,'wood0');
 g.rect(2,14+bob-(work?f%2*3:0),3,3,'skin1').rect(11,14+bob+(work?f%2:0),3,3,'skin2');
 if(work){const y=8+(f%2)*4;g.line(13,y,13,20,'wood3');if(id==='toby')g.rect(11,y,5,3,'rock2');else if(id==='mei')g.ellipse(12,y+4,3,2,'leaf2');else if(id==='anuan')g.ellipse(13,y,2,3,'ember3');else g.rect(11,y,4,3,'wood2');}
}
function meta(id,size,frames,animations){return {id,category:id.split('.')[0],size,anchor:[Math.floor(size[0]/2),size[1]],frames,animations};}
const still={idle:{fps:2,loop:true,frames:[0,1]}};
export const assets=[];
for(const id of names){
 if(id!=='toby')assets.push({meta:meta(`portrait.${id}`,[40,40],4,{idle:{fps:1,loop:true,frames:[0]},happy:{fps:1,loop:false,frames:[1]},surprised:{fps:1,loop:false,frames:[2]},frozen:{fps:1,loop:false,frames:[3]}}),draw(g,{frame}){g.stamp(portrait(id,frame));}});
 assets.push({meta:meta(`big.${id}`,[96,96],2,still),draw(g,{frame}){big(g,id,frame);}});
 assets.push({meta:meta(`walker.${id}`,[16,24],10,{walk:{fps:6,loop:true,frames:[0,1,2,3]},work:{fps:5,loop:true,frames:[4,5,6,7]},idle:{fps:2,loop:true,frames:[8,9]}}),draw(g,{frame}){walker(g,id,frame);}});
}
assets.push({meta:meta('char.ember',[24,32],12,{idle:{fps:4,loop:true,frames:[0,1,2,3]},talk:{fps:8,loop:true,frames:[4,5]},jump:{fps:8,loop:false,frames:[6,7,8,9]},sulk:{fps:3,loop:true,frames:[10,11]}}),draw(g,{frame:f}){
 const lift=f>=6&&f<=9?[0,3,5,2][f-6]:0,sulk=f>=10,tip=sulk?15:7+(f%3);
 g.ellipse(12,7-lift,4,4,'ink').ellipse(12,7-lift,2,2,'rock1');g.rect(5,11-lift,14,3,'ink').rect(4,26-lift,16,3,'ink').rect(6,12-lift,2,15,'rock0').rect(17,12-lift,2,15,'ink');
 g.polygon([[8,24-lift],[7,20-lift],[10,tip-lift],[12,15-lift],[16,tip+2-lift],[18,22-lift],[15,25-lift]],'ember1');g.polygon([[9,23-lift],[11,14-lift],[13,19-lift],[15,16-lift],[16,23-lift],[13,25-lift]],'ember3');g.rect(11,21-lift,3,4,'ember4');g.px(10,19-lift,'ink').px(15,19-lift,'ink');if(f===5)g.rect(12,21-lift,2,2,'ember0');else g.px(12,21-lift,sulk?'ember0':'ember1');g.rect(7,29-lift,10,2,'rock0');g.rect(6,11-lift,10,1,'rock2');
}});
for(const id of names)assets.push({meta:meta(`big.${id}.memory`,[96,96],2,still),draw(g,{frame}){big(g,id,frame);g.recolor(palette.recolors.memory);}});
