const fs=require('fs'),crypto=require('crypto'),assert=require('assert/strict'),args=process.argv.slice(2);
if(args.length!==2)throw Error('Usage: node driver-tx-fix.cjs QUIET-ORIGINAL.ko NEW.ko');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const original=fs.readFileSync(args[0]);
assert.equal(hash(original),'7c7d77a2aecc96d085f830795d24f1f4c95e2a5322455e75bff580629706f63d');
const out=Buffer.from(original),sections=[],u64=o=>Number(original.readBigUInt64LE(o)),sh=u64(40),ents=original.readUInt16LE(58),num=original.readUInt16LE(60);
for(let i=0;i<num;i++){let o=sh+i*ents;sections.push({i,nameOffset:original.readUInt32LE(o),type:original.readUInt32LE(o+4),off:u64(o+24),size:u64(o+32),info:original.readUInt32LE(o+44),entsize:u64(o+56)});}
const names=sections[original.readUInt16LE(62)],z=off=>original.subarray(off,original.indexOf(0,off)).toString();sections.forEach(s=>s.name=z(names.off+s.nameOffset));
const text=sections.find(s=>s.name==='.text'),rela=sections.find(s=>s.type===4&&s.info===text.i),allow=new Set(),changes=[];
function edit(offset,bytes,why){for(let n=0;n<bytes.length;n++)allow.add(offset+n);bytes.copy(out,offset);changes.push({offset,length:bytes.length,why});}
function word(at,expected,replacement,why){assert.equal(original.readUInt32LE(text.off+at),expected,why);const b=Buffer.alloc(4);b.writeUInt32LE(replacement);edit(text.off+at,b,why);}
word(0x2eb00,0x540024a0,0xd503201f,'PCIe AP IPv6 multicast falls through to the data/special classification instead of the unconditional multicast command path');
// Generated from tx-guard.s; absolute offsets are for the exact hash above.
const guard=Buffer.alloc(0x2efe8);guard.writeUInt32LE(0x14000090,0x2ed54);guard.writeUInt32LE(1409297824,0x2ea14);Buffer.from('750100348ab24bb94a011e325f190071e1000054c8000035b70000368a5f40b95f0d00714100005467ffff17c9f3ff3565ffff1789b24bb929011e323f19007101e2ff54e95e40b93f0d0071a1e1ff545dffff17','hex').copy(guard,0x2ef94);
word(0x2ea14,0x54001000,guard.readUInt32LE(0x2ea14),'AP/GO PCIe ARP returns to data queue; other modes retain original ARP handling');
word(0x2ed54,0x35000729,guard.readUInt32LE(0x2ed54),'enter AP/GO PCIe DNS guard before checksum or spinlock');
edit(text.off+0x2ef94,guard.subarray(0x2ef94),'reuse multicast-only block made unreachable by the preceding fix');
let relocations=0;
for(let off=rela.off;off<rela.off+rela.size;off+=rela.entsize){let at=u64(off),kind=original.readUInt32LE(off+8);if(at>=0x2ef94&&at<0x2efe8){assert.ok([275,277,283].includes(kind));edit(off+8,Buffer.alloc(4),'disable overwritten diagnostic-code relocation');relocations++;}}
assert.equal(relocations,5);
word(0x2027c,0x39401909,0x39402d09,'read actual station LUT at descriptor offset 6 plus five-byte prefix');
word(0x202f8,0x39401509,0x39402909,'read TID at descriptor offset 5 plus prefix');
word(0x20318,0x39001509,0x39002909,'write group BK TID at actual descriptor');
/* No original direct branch may enter the reused block except the replaced one. */
for(let at=0x2e9c4;at<0x2f254;at+=4){let w=original.readUInt32LE(text.off+at),target=null;
 if((w>>>26)===5){let imm=w&0x3ffffff;if(imm&0x2000000)imm-=0x4000000;target=at+imm*4;}
 else if((w&0xff000010)===0x54000000||(w&0x7e000000)===0x34000000){let imm=(w>>>5)&0x7ffff;if(imm&0x40000)imm-=0x80000;target=at+imm*4;}
 else if((w&0x7e000000)===0x36000000){let imm=(w>>>5)&0x3fff;if(imm&0x2000)imm-=0x4000;target=at+imm*4;}
 if(target>=0x2ef94&&target<0x2efe8&&at!==0x2eb00)throw Error('Unexpected inbound branch into reused block at '+at.toString(16));
}
let diff=0;for(let i=0;i<out.length;i++)if(out[i]!==original[i]){assert.ok(allow.has(i));diff++;}
assert.equal(hash(out),'efddc24b6791c4147f02a07b436eda22ee5b550f24b3bedc17ff758c07f6b071');
fs.writeFileSync(args[1],out,{flag:'wx'});
console.log(JSON.stringify({before:hash(original),after:hash(out),changed_bytes:diff,changes},null,2));
