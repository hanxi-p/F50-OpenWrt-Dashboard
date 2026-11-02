import * as fs from 'fs';
function text(v){return "CAST(X'"+hexenc(''+(v??''))+"' AS TEXT)";}
function archive(root,registry,devices,history,router,now,snapshots){
 if(registry?.version!=1||type(registry.profiles)!='object')return {ok:false,error:'registry_unavailable'};
 let path=root+'/archive.sqlite',file=fs.open(path,'a',0600);if(!file)return {ok:false,error:'database_unavailable'};file.close();
 let version=fs.popen("sqlite3 -batch '"+replace(path,"'","'\\''")+"' 'PRAGMA user_version'",'r');
 if(!version)return {ok:false,error:'sqlite3_unavailable'};let v=trim(version.read('all')??'');let vs=version.close();if(vs!=0||(v!='0'&&v!='1'))return {ok:false,error:'unsupported_or_corrupt_archive'};
 let sql='PRAGMA foreign_keys=ON; PRAGMA page_size=4096; PRAGMA max_page_count=8192; PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; PRAGMA busy_timeout=2000;\nBEGIN IMMEDIATE;\n';
 sql+='CREATE TABLE IF NOT EXISTS devices(device_id TEXT PRIMARY KEY,name TEXT,status TEXT,updated_at INTEGER);\n';
 sql+='CREATE TABLE IF NOT EXISTS identifiers(router_id TEXT,mac TEXT,device_id TEXT REFERENCES devices(device_id),active INTEGER,updated_at INTEGER,PRIMARY KEY(router_id,mac));\n';
 sql+='CREATE TABLE IF NOT EXISTS source_snapshots(router_id TEXT,source TEXT,payload_json TEXT,updated_at INTEGER,PRIMARY KEY(router_id,source));\n';
 sql+='CREATE TABLE IF NOT EXISTS features(router_id TEXT,mac TEXT,device_id TEXT,history_json TEXT,updated_at INTEGER,PRIMARY KEY(router_id,mac));\n';
 for(let id,p in registry.profiles)sql+='INSERT INTO devices VALUES('+text(id)+','+text(p.name)+",'known',"+int(now)+') ON CONFLICT(device_id) DO UPDATE SET name=excluded.name,status=excluded.status,updated_at=excluded.updated_at;\n';
 for(let mac,d in devices)if(d.device_id){
  if(d.identity_state!='known')sql+='INSERT OR IGNORE INTO devices VALUES('+text(d.device_id)+",'',"+text(d.identity_state)+','+int(now)+');\n';
  sql+='INSERT OR REPLACE INTO features VALUES('+text(router)+','+text(mac)+','+text(d.device_id)+','+text(sprintf('%J',history?.devices?.[mac]??{}))+','+int(now)+');\n';
 }
 sql+='UPDATE identifiers SET active=0 WHERE router_id='+text(router)+';\n';
 let links={};for(let mac,d in devices)if(d.device_id)links[mac]=d.device_id;
 for(let mac,b in registry.bindings??{})if(registry.profiles[b.id])links[mac]=b.id;
 for(let mac,id in links)sql+='INSERT OR REPLACE INTO identifiers VALUES('+text(router)+','+text(mac)+','+text(id)+',1,'+int(now)+');\n';
 for(let source,data in snapshots??{})if(data&&length(sprintf('%J',data))<=262144)sql+='INSERT OR REPLACE INTO source_snapshots VALUES('+text(router)+','+text(source)+','+text(sprintf('%J',data))+','+int(now)+');\n';
 sql+='DELETE FROM features WHERE updated_at<'+int(now-604800)+';\n';
 sql+='PRAGMA user_version=1; COMMIT; PRAGMA wal_checkpoint(TRUNCATE);\n';
 let p=fs.popen("sqlite3 -batch '"+replace(path,"'","'\\''")+"' >/dev/null",'w');
 if(!p)return {ok:false,error:'sqlite3_unavailable'};
 let n=p.write('.bail on\n'+sql),status=p.close();
 return {ok:n==length('.bail on\n'+sql)&&status==0,timestamp:now,scope:'uuid_profile_archive',authoritative_source:'existing_registry'};
}
export {archive};
