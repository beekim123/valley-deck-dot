import {meta,scene,rock,wheel} from './world.mjs';
const uses={pines:['chop','gather'],hut:['fire','read_notes','feed'],flower_slope:['sun','herbs'],herb_garden:['brew','tea'],river_bend:['driftwood','chisel','build_dam'],misty_bank:['gnaw'],tree_hole:['shelter','search'],mill:['repair_wheel','warm_family'],gravel:['stones','haul'],old_bridge:['watch','reinforce'],flood_beach:['shells']};
function person(g,x,y,pose,{toby=false,mei=false}={}){const bend=pose===1?2:0;g.rect(x-3,y-13+bend,7,7,'ink');g.rect(x-2,y-12+bend,5,5,'skin2');g.rect(x-3,y-14+bend,7,3,mei?'snow1':'wood0');g.px(x+2,y-10+bend,'ink');if(toby)g.rect(x-2,y-7+bend,5,3,'wood3');g.rect(x-3,y-6+bend,7,6-bend,mei?'bloom0':'coat');g.rect(x-3,y-6+bend,7,1,'scarf');g.rect(x-3,y,2,3,'ink');g.rect(x+2,y,2,3,'ink');g.line(x+3,y-5+bend,x+6,y-4+bend,'skin2');}
function animate(g,name,use,f){scene(g,name,{night:true});const bob=[0,1,2,1][f],act=f===1||f===2;let x=34,y=42;
 const beaver=use==='gnaw'||use==='build_dam';
 if(beaver){g.ellipse(32,39,7,4,'wood1');g.ellipse(40,36+bob,4,4,'wood2');g.ellipse(40,33+bob,2,2,'wood0');g.ellipse(24,41,5,2,'wood0');g.px(42,35+bob,'ink');g.rect(42,38+bob,2,2,'snow2');}else person(g,x,y,(['herbs','gather','shells','stones'].includes(use)&&act)?1:0,{toby:['chop','haul','repair_wheel','reinforce','chisel'].includes(use),mei:['brew','tea','herbs'].includes(use)});
 if(use==='chop'){g.rect(44,37,9,5,'wood0');g.rect(44,36,9,2,'wood3');const end=act?[48,35]:[40,23];g.line(39,36,...end,'wood3');g.polygon([[end[0]-2,end[1]-2],[end[0]+3,end[1]-2],[end[0]+4,end[1]+2],[end[0],end[1]+3]],'rock2');if(f===2){g.line(49,33,52,30,'wood3');g.line(54,37,58,35,'wood3');}}
 if(use==='gather'||use==='driftwood'){g.line(41,40-bob,54,37-bob,'wood3');g.line(42,39-bob,51,35-bob,'wood1');g.line(46,36-bob,44,33-bob,'wood2');}
 if(use==='fire'||use==='brew'){g.rect(43,42,12,2,'wood0');g.line(45,40,53,43,'wood3');g.polygon([[44,40],[46,34-bob],[49,37],[52,32+bob],[55,41]],'ember1');g.polygon([[47,41],[49,36-bob],[52,40]],'ember3');if(use==='brew'){g.rect(44,31,12,5,'ink');g.rect(46,30,8,2,'rock1');g.line(48,27-bob,50,24-bob,'snow1');g.line(50,24-bob,48,21-bob,'snow1');}}
 if(use==='read_notes'){g.polygon([[39,34],[46,32],[49,34],[55,32],[55,39],[48,41],[39,40]],'paper2');g.line(48,34,48,40,'paper0');g.line(41,36,45,35,'paper1');g.line(50,36,53,35,'paper1');if(act)g.line(48,34,52,31,'paper2');}
 if(use==='feed'){g.rect(43,41,3,1,'wood4');g.ellipse(50+bob,38,3,2,'wood1');g.rect(49+bob,38,2,2,'ember2');g.px(52+bob,37,'ink');g.px(54+bob,38,'wood3');}
 if(use==='sun'){g.rect(25,44,23,2,'wood3');g.line(41,35,45,31-bob,'skin2');g.line(28,35,24,31-bob,'skin2');g.px(43,25-bob,'ember4');}
 if(use==='herbs'){g.rect(44,39,10,5,'wood1');g.line(44,38,53,38,'wood3');for(let k=0;k<3;k++){g.line(40+k*2,36-bob,41+k*2,31-bob,'leaf3');g.px(42+k*2,31-bob,'bloom1');}}
 if(use==='tea'){g.rect(40,33-bob,6,5,'paper2');g.rect(46,34-bob,2,3,'wood3');g.line(42,30-bob,44,27-bob,'snow1');}
 if(use==='chisel'){g.line(41,39,47,29-bob,'rock2');g.line(41,40,46,43,'ice2');g.line(41,40,38,44,'ice2');if(act)g.rect(47,41,3,2,'ice3');}
 if(use==='build_dam'||use==='gnaw'){for(let k=0;k<3;k++)g.line(43,40+k*2,58,36+k*2,'wood2');g.line(48,34,51,44,'wood3');if(use==='gnaw'){g.rect(44,38+bob,2,2,'wood4');g.px(47,42,'wood3');}}
 if(use==='shelter'){g.rect(30,35,11,5,'scarf');g.line(30,35,39,35,'ember2');g.rect(43,39,5,4,'paper2');g.line(44,36-bob,46,33-bob,'snow1');}
 if(use==='search'){g.line(29,35,27,30-bob,'skin2');g.rect(24,27-bob,5,4,'paper2');g.line(25,28-bob,27,29-bob,'paper1');}
 if(use==='repair_wheel'){wheel(g,49,34,9,f);g.line(39,36,42,27+bob*2,'wood3');g.rect(39,26+bob*2,7,3,'rock2');}
 if(use==='warm_family'){g.ellipse(45,33,5+bob,6+bob,'ember1');g.ellipse(45,33,3+bob,4+bob,'ember3');g.ellipse(45,33,2,2,'ember4');g.line(39,36,43,34,'skin2');}
 if(use==='haul'||use==='stones'){rock(g,40,act?29:37,use==='haul'?15:8,use==='haul'?9:5);g.line(37,37,42,act?34:40,'skin2');}
 if(use==='watch'){g.rect(44,26,1,17,'wood3');g.rect(42,25,5,7,'ink');g.rect(43,26,3,4,'ember3');g.px(44,27+bob,'ember4');}
 if(use==='reinforce'){g.line(44,30,53,43,'wood3');g.line(39,36,46,28+bob*3,'wood2');g.rect(43,27+bob*3,6,3,'rock2');}
 if(use==='shells'){g.rect(44,38,10,6,'wood1');g.rect(45,37,8,2,'wood3');g.rect(39,34-bob,4,3,'snow2');g.px(40,33-bob,'bloom1');}
}
export const assets=Object.entries(uses).flatMap(([n,uu])=>uu.map(u=>({meta:meta(`locart.${n}.anim.${u}`,[64,48],4),draw(g,{frame}){animate(g,n,u,frame);}})));
