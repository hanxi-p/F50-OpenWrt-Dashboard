const fs=require('fs'),crypto=require('crypto'),args=process.argv.slice(2);
if(args.length<1||args.length>2)throw Error('Usage: node driver-quiet.cjs ORIGINAL.ko [NEW.ko]');
const b=fs.readFileSync(args[0]);
if(crypto.createHash('sha256').update(b).digest('hex')!=='d6a42377cab3ff62a2c990ff7a08c1cf2cf5c7f270aedd15491e267897098481')throw Error('Unsupported original driver SHA256; no output written');
const u64=o=>Number(b.readBigUInt64LE(o));const sh=u64(40),n=b.readUInt16LE(60),namesIndex=b.readUInt16LE(62),ents=b.readUInt16LE(58);
let sections=[];for(let i=0;i<n;i++){let o=sh+i*ents;sections.push({i,nameOffset:b.readUInt32LE(o),type:b.readUInt32LE(o+4),off:u64(o+24),size:u64(o+32),link:b.readUInt32LE(o+40),info:b.readUInt32LE(o+44),entsize:u64(o+56)});}
const z=(buf,off)=>buf.subarray(off,buf.indexOf(0,off)).toString();const names=sections[namesIndex];sections.forEach(s=>s.name=z(b,names.off+s.nameOffset));
const symsec=sections.find(s=>s.type===2),strsec=sections[symsec.link],syms=[];
for(let o=symsec.off;o<symsec.off+symsec.size;o+=symsec.entsize){syms.push({name:z(b,strsec.off+b.readUInt32LE(o)),kind:b[o+4]&15,section:b.readUInt16LE(o+6),value:u64(o+8),size:u64(o+16)});}
const text=sections.find(s=>s.name==='.text'),rela=sections.find(s=>s.type===4&&s.info===text.i),rels=[];
for(let o=rela.off;o<rela.off+rela.size;o+=rela.entsize){let info=b.readBigUInt64LE(o+8);rels.push({at:u64(o),type:Number(info&0xffffffffn),sym:syms[Number(info>>32n)],addend:Number(b.readBigInt64LE(o+16)),record:o});}
let funcs=syms.filter(s=>s.kind===2&&s.section===text.i&&s.size);
let calls=[];for(const r of rels){if(r.sym.name!=='printk'||r.type!==283)continue;
 let fn=funcs.find(f=>r.at>=f.value&&r.at<f.value+f.size);if(!fn||!['sc2355_pcie_handle_tx_return','sc2355_tx_free_pcie_data','sprdwl_tx_free_pcie_data'].includes(fn.name))continue;
 let ref=rels.filter(x=>x.at<r.at&&x.at>=r.at-100&&x.type===275&&(b.readUInt32LE(text.off+x.at)&31)===0&&sections[x.sym.section]?.name==='.rodata').at(-1);
 let format=ref?z(b,sections[ref.sym.section].off+ref.sym.value+ref.addend):'';
 calls.push({function:fn.name,offset:r.at,format,relocation:r.record});
}
console.log(JSON.stringify(calls,null,2));
if(args[1]){
 const patched=Buffer.from(b);let chosen=calls.filter(c=>c.function==='sc2355_pcie_handle_tx_return'&&c.format.includes('debug:')||c.function==='sc2355_tx_free_pcie_data'&&c.format.includes('total free num'));
 if(chosen.length!==3)throw Error('Expected exactly two return debug sites and one free counter site; got '+chosen.length);
 for(const c of chosen){if((patched.readUInt32LE(text.off+c.offset)>>>26)!==0b100101)throw Error('Not an AArch64 BL');patched.writeUInt32LE(0xd503201f,text.off+c.offset);let rinfo=patched.readBigUInt64LE(c.relocation+8);patched.writeBigUInt64LE(rinfo&0xffffffff00000000n,c.relocation+8);}
 if(crypto.createHash('sha256').update(patched).digest('hex')!=='7c7d77a2aecc96d085f830795d24f1f4c95e2a5322455e75bff580629706f63d')throw Error('Unexpected patched driver hash; no output written');
 fs.writeFileSync(args[1],patched,{flag:'wx'});console.log('Prepared exact-build patch for '+chosen.length+' informational printk call sites; other code and error logs preserved.');
}
