// Ice overlay dissolves by discrete shards, never half-alpha.
const meta=(id,frames)=>({id,category:'fx',size:[72,88],anchor:[36,44],frames,animations:{play:{fps:9,loop:false,frames:Array.from({length:frames},(_,i)=>i)}}});
const cracks=[[[36,9],[31,23],[38,34],[30,47],[34,62],[24,78]],[[37,34],[49,31],[60,18]],[[31,47],[19,42],[8,48]],[[34,62],[47,68],[58,81]],[[32,23],[20,19],[14,6]],[[47,68],[57,56],[67,54]]];
export const assets=[
{meta:meta('fx.ice_crack',3),draw(g,{frame}){for(let n=0;n<2+frame*2;n++){const p=cracks[n];for(let i=1;i<p.length;i++){g.line(p[i-1][0]+1,p[i-1][1],p[i][0]+1,p[i][1],'ice0');g.line(...p[i-1],...p[i],'ice3');}}}},
{meta:meta('fx.ice_shatter',6),draw(g,{frame}){if(frame===5)return;const shards=[[[9,11],[25,14],[17,31]],[[37,8],[54,16],[42,31]],[[62,25],[68,43],[48,35]],[[5,41],[26,40],[15,57]],[[30,34],[43,44],[35,64]],[[57,49],[65,69],[45,61]],[[9,67],[24,61],[30,80]],[[40,70],[57,79],[36,84]]];shards.forEach((p,i)=>{if(frame===4&&i%2===0)return;const dx=(i%3-1)*frame*3,dy=frame*frame+(i%2?-frame*3:0);const q=p.map(([x,y])=>[x+dx,y+dy]);g.polygon(q,i%2?'ice2':'ice3');g.line(...q[0],...q[1],'snow3');});}}
];
