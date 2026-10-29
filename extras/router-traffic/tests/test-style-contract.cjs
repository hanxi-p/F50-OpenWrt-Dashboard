const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.join(__dirname,'..'),read=p=>fs.readFileSync(path.join(root,p),'utf8'),contract=JSON.parse(read('STYLE-CONTRACT.json'));
const extract=s=>s.match(/section\.appendChild\(E\('style',\{\},`([\s\S]*?)`\)\);/)[1];
const css=extract(read('ui/devices.js'));assert.equal(crypto.createHash('sha256').update(css).digest('hex'),contract.device_css_sha256);
const source=path.join(root,'../dashboard/f50devices.js');if(fs.existsSync(source))assert.equal(css,extract(fs.readFileSync(source,'utf8')).replaceAll('.f50-home','.rt-root').replaceAll('.f50-','.rt-'));
const wan=read('wan/style.css'),ui=read('ui/style.css');for(const[k,v]of Object.entries(contract.palette)){assert(wan.includes('--'+k+':'+v[0]));assert(wan.includes('--'+k+':'+v[1]));}
for(const token of ['font-size:1.4rem','gap:6px','font-size:.65rem','font-size:.62rem','padding:7px 6px'])assert(ui.includes(token),token);
assert(!/\.rt-root \.mud-sec\{[^}]*border:/.test(ui));assert(wan.includes('font-size: 1.7rem')&&wan.includes('font-size: 1.4rem'));assert(wan.includes('font-family: "Lato"'));assert(!/\.f50-home \*\s*\{\s*font-family/.test(wan));
const view=read('wan/view.js');assert(view.includes('Devices.mount(this.root)')&&view.includes('Resources.mount(this.root)'));assert(read('install.sh').includes('_v031.js'));
console.log('PASS F50 style contract: exact device CSS, palette/light/dark, fonts, typography, responsive spacing, single owner and cache version');
