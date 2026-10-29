const fs=require('node:fs'),assert=require('node:assert/strict'),{parseHTML}=require('linkedom');
class Base{static extend(m){class X{}Object.assign(X.prototype,m);return X;}}
const flush=async()=>{for(let i=0;i<20;i++)await Promise.resolve();};
async function round(){
 const {document}=parseHTML('<html><head></head><body></body></html>');
 function E(tag,a={},children=[]){const el=document.createElement(tag);for(const [k,v] of Object.entries(a))el.setAttribute(k,v);for(const c of [children].flat(Infinity))if(c!=null)el.append(typeof c==='string'?document.createTextNode(c):c);return el;}
 const names=['10_system','29_ports','30_network','40_dhcp','60_wifi','80_upnp'],modules={},calls={};
 for(const name of names){calls[name]=0;modules[name]={title:name,load:()=>Promise.resolve(++calls[name]),render:data=>name==='40_dhcp'?E('div',{},[E('h3',{},'DHCPv4'),E('table',{},'v4-'+data),E('h3',{},'DHCPv6'),E('table',{},'v6-'+data)]):name==='60_wifi'?E('div',{},[E('p',{},'radios'),E('h3',{},'Associated Stations'),E('table',{},'stations-'+data)]):E('p',{},'data-'+data)};}
 const dom={content:(el,c)=>el.replaceChildren(...[c].flat(Infinity))};
 const Class=new Function('baseclass','fs','dom','document','E','L','_',fs.readFileSync(__dirname+'/../ui/native-folds.js','utf8'))(Base,{list:()=>Promise.resolve(names.map(n=>({name:n+'.js'})))},dom,document,E,{resource:p=>'/resources/'+p,require:n=>Promise.resolve(modules[n.split('.').pop()])},s=>s);
 const bootstrap=new Class();await bootstrap.load();await bootstrap.load();assert.equal(document.querySelectorAll('#rt-native-fold-style').length,1);
 const system=modules['10_system'];assert.equal(await system.load(),null);assert.equal(calls['10_system'],0);
 const root=system.render(null);document.body.appendChild(root);assert(!root.open);
 for(let i=0;i<30;i++){assert.equal(await system.load(),null);assert.equal(system.render(null),null);assert(!root.open);}
 root.open=true;root.ontoggle();await flush();assert(root.textContent.includes('data-1'));
 for(let i=0;i<10;i++){assert.equal(system.render(await system.load()),null);assert(root.open);}
 root.open=false;root.ontoggle();const count=calls['10_system'];await system.load();assert.equal(calls['10_system'],count);
 const dhcp=modules['40_dhcp'],group=dhcp.render(await dhcp.load());document.body.appendChild(group);let sections=[...group.querySelectorAll('details')];assert.equal(sections.length,2);assert(sections.every(d=>!d.open));
 sections[0].open=true;sections[0].ontoggle();await flush();assert(group.textContent.includes('v4-2'));
 for(let i=0;i<10;i++){assert.equal(dhcp.render(await dhcp.load()),null);assert(sections[0].open);assert(!sections[1].open);}
 sections[0].open=false;const before=calls['40_dhcp'];await dhcp.load();assert.equal(calls['40_dhcp'],before);
 const wifi=modules['60_wifi'],wireless=wifi.render(await wifi.load());document.body.appendChild(wireless);assert(!wireless.open);wireless.open=true;wireless.ontoggle();await flush();let stations=wireless.querySelector('.rt-native-subfold');assert(stations&&!stations.open);stations.open=true;stations.ontoggle();wifi.render(await wifi.load());stations=wireless.querySelector('.rt-native-subfold');assert(stations.open);
 for(const n of ['29_ports','30_network','80_upnp']){const m=modules[n];const node=m.render(await m.load());document.body.appendChild(node);assert(!node.open);assert.equal(calls[n],0);}
 root.remove();const reset=system.render(await system.load());assert.notEqual(reset,root);assert(!reset.open);
}
(async()=>{for(let i=0;i<3;i++)await round();console.log('PASS three rounds: all native drawers closed by default, manual opening, retained polling state, independent v4/v6 and stations, paused closed loads, stable roots and navigation reset');})().catch(e=>{console.error(e);process.exitCode=1;});
