/* Extract only the patched guard/descriptor instructions into a user-mode fixture. */
const fs=require('fs'),path=require('path'),crypto=require('crypto'),assert=require('assert/strict');
const [input,dir]=process.argv.slice(2);if(!input||!dir)throw Error('Usage: node prepare-test.cjs TX-FIXED.ko EMPTY-OUTPUT-DIR');
const b=fs.readFileSync(input);assert.equal(crypto.createHash('sha256').update(b).digest('hex'),'efddc24b6791c4147f02a07b436eda22ee5b550f24b3bedc17ff758c07f6b071');
const sh=Number(b.readBigUInt64LE(40)),size=b.readUInt16LE(58),count=b.readUInt16LE(60),strings=Number(b.readBigUInt64LE(sh+b.readUInt16LE(62)*size+24));let text;
for(let i=0;i<count;i++){const p=sh+i*size,start=strings+b.readUInt32LE(p);if(b.subarray(start,b.indexOf(0,start)).toString()==='.text')text=Number(b.readBigUInt64LE(p+24));}
assert.ok(Number.isSafeInteger(text));fs.mkdirSync(dir,{recursive:true});
const save=(name,data)=>fs.writeFileSync(path.join(dir,name),data,{flag:'wx'});
const fixture=Buffer.alloc(0x2efe8);b.copy(fixture,0x2ea14,text+0x2ea14,text+0x2ea18);fixture.writeUInt32LE(0x52800000,0x2ec14);fixture.writeUInt32LE(0xd65f03c0,0x2ec18);b.copy(fixture,0x2ed54,text+0x2ed54,text+0x2ed58);b.copy(fixture,0x2ef94,text+0x2ef94,text+0x2efe8);
fixture.writeUInt32LE(0x52800020,0x2ed58);fixture.writeUInt32LE(0xd65f03c0,0x2ed5c);fixture.writeUInt32LE(0x52800000,0x2ee38);fixture.writeUInt32LE(0xd65f03c0,0x2ee3c);save('tx-guard-test.bin',fixture);
for(const [name,at] of [['lut',0x2027c],['tid-read',0x202f8],['tid-write',0x20318]])save('desc-'+name+'.bin',b.subarray(text+at,text+at+4));
console.log('Prepared isolated instruction fixtures. This does not load a driver or send network traffic.');
