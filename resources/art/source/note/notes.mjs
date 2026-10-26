// Baiweng's hand-drawn field diagrams: scenery and clues, not baked-in text.
const base=(id,size)=>({id,category:'note',size,anchor:[0,0],frames:1,animations:{idle:{fps:1,loop:true,frames:[0]}}});
const line=(g,...p)=>g.line(...p,'paper0');
export const assets=[
{meta:base('note.paper',[320,200]),draw(g){g.polygon([[4,2],[104,4],[168,1],[236,3],[314,2],[318,64],[316,113],[319,194],[248,197],[175,195],[98,198],[2,195],[4,130],[1,73]],'paper0');g.polygon([[6,4],[105,6],[168,3],[235,5],[312,4],[316,64],[314,113],[317,192],[248,195],[175,193],[98,196],[4,193],[6,130],[3,73]],'paper2');g.line(13,10,304,10,'wood4');g.line(12,188,306,188,'paper1');g.line(24,18,24,180,'paper1');g.line(160,7,161,189,'paper1');g.polygon([[300,173],[316,172],[316,192]],'paper1');g.line(300,173,315,191,'paper0');for(const [x,y] of [[10,35],[306,31],[9,156],[296,184]]){g.line(x,y,x+7,y,'paper1');g.px(x+2,y+2,'wood4');}}},
{meta:base('note.sketch.1',[160,120]),draw(g){for(let i=0;i<4;i++){const x=21+i*34,y=32+(i%2)*8;g.rect(x,y,22,34,'paper0').rect(x+2,y+2,18,30,'paper2');line(g,x+5,y+9,x+17,y+9);line(g,x+5,y+23,x+17,y+23);g.polygon([[x+11,y+12],[x+15,y+17],[x+11,y+21],[x+7,y+17]],'paper1');}line(g,15,82,145,82);line(g,15,85,145,85);for(let x=22;x<145;x+=31){line(g,x,87,x+7,98);line(g,x+7,98,x+16,87);}g.ellipse(79,13,6,7,'paper0');g.ellipse(79,13,4,5,'paper2');line(g,79,3,79,0);line(g,67,13,63,13);line(g,91,13,95,13);}},
{meta:base('note.sketch.2',[160,120]),draw(g){g.rect(25,42,62,56,'paper1');line(g,15,43,56,17);line(g,56,17,96,43);line(g,28,45,28,97);line(g,84,45,84,97);g.rect(39,68,19,30,'paper0').rect(41,70,15,28,'paper2');g.ellipse(108,77,27,27,'paper0');g.ellipse(108,77,23,23,'paper2');g.ellipse(108,77,17,17,'paper0');g.ellipse(108,77,14,14,'paper2');for(const [x,y] of [[0,-25],[18,-18],[25,0],[18,18],[0,25],[-18,18],[-25,0],[-18,-18]]){if(x===18&&y===18){line(g,108,77,113,91);line(g,113,91,126,95);}else line(g,108,77,108+x,77+y);}g.ellipse(108,77,3,3,'paper0');line(g,12,108,148,108);line(g,17,112,79,112);line(g,98,113,151,113);line(g,86,46,144,46);line(g,86,49,143,49);line(g,143,46,143,66);}},
{meta:base('note.sketch.3',[160,120]),draw(g){
 // Hearth and the little lantern: the fire entrusted to Anuan, not a house plan.
 g.polygon([[24,99],[24,38],[38,21],[91,21],[105,38],[105,99]],'paper1');
 line(g,18,100,111,100);line(g,21,37,108,37);line(g,23,34,107,34);
 g.rect(39,43,51,55,'paper0').rect(42,46,45,49,'paper2');
 for(const [x,y] of [[25,46],[28,59],[24,73],[29,87],[94,46],[92,59],[96,73],[92,87]]){line(g,x,y,x+8,y);line(g,x+4,y,x+4,y+6);}
 g.polygon([[47,84],[51,72],[59,76],[66,54],[70,72],[77,66],[83,82],[77,90],[55,90]],'paper0');
 g.polygon([[53,83],[56,77],[61,82],[67,66],[70,81],[76,75],[78,83],[73,87],[57,87]],'paper1');
 g.polygon([[61,85],[65,77],[68,82],[71,80],[73,86]],'paper2');
 line(g,47,94,81,90);line(g,47,91,81,95);line(g,48,28,81,28);
 g.ellipse(128,53,7,8,'paper0').ellipse(128,53,5,6,'paper2');
 g.rect(114,62,28,4,'paper0').rect(116,66,3,31,'paper0').rect(138,66,3,31,'paper0').rect(113,97,31,4,'paper0');
 g.polygon([[122,92],[121,83],[126,73],[129,81],[133,78],[136,89],[132,94]],'paper1');
 line(g,120,67,135,67);line(g,118,103,139,103);line(g,112,109,146,109);
 line(g,56,15,54,9);line(g,70,14,74,8);line(g,62,11,63,4);
}}
];
