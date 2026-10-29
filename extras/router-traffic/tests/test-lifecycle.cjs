/* The overview re-invokes include.load/render on each LuCI poll. */
const fs=require('node:fs'),assert=require('node:assert/strict'),{parseHTML}=require('linkedom');
const {document,window}=parseHTML('<html><body></body></html>');
function E(tag,attrs={},children=[]){const n=document.createElement(tag);for(const [k,v] of Object.entries(attrs))n.setAttribute(k,v);for(const c of [children].flat(Infinity))if(c!=null)n.append(typeof c==='string'?document.createTextNode(c):c);return n;}
class Base{static extend(m){class View extends this{}Object.assign(View.prototype,m);return View;}}
let calls=0,mounts=0,disposals=0;
const rpc={declare:()=>()=>{calls++;return Promise.resolve({timestamp:1000,show_wan:false});}};
const Devices={mount:()=>{mounts++;return()=>disposals++;}};
const Class=new Function('baseclass','rpc','Devices','Chart','Units','Resources','E','L','document','window',fs.readFileSync(__dirname+'/../ui/status.js','utf8'))(Base,rpc,Devices,{}, {fmtRate:()=> '—'},{mount:()=>()=>{}},E,{resource:p=>p},document,window);
(async()=>{
 for(let round=0;round<3;round++){
  const view=new Class(),initial=await view.load(),root=view.render(initial);document.body.appendChild(root);
  const before=calls;
  for(let poll=0;poll<60;poll++){assert.equal(await view.load(),null);assert.equal(view.render(null),null);assert.equal(view._rtRoot,root);assert.equal(root.querySelectorAll('link').length,1);}
  assert.equal(calls,before,'outer polls must not create duplicate RPC loops');
  root.remove();const again=view.render(await view.load());assert.notEqual(again,root);document.body.appendChild(again);view._rtDispose();again.remove();
 }
 assert.equal(mounts,6);assert.equal(disposals,6);
 console.log('PASS three rounds / 180 overview polls: stable root, no remount, no stylesheet duplication, no duplicate RPC, detach/remount cleanup');
})().catch(e=>{console.error(e);process.exitCode=1;});
