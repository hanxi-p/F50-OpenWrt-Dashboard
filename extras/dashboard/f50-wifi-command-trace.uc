import * as fs from 'fs';
const path=ARGV[0] || '/lib/netifd/wireless/mac80211.sh';
if(path!='/lib/netifd/wireless/mac80211.sh' && !match(path,/^\/tmp\/f50-wifi-trace-test-[a-zA-Z0-9-]+$/))die('Invalid trace target');
let text=fs.readfile(path);
if (!text) die('Missing mac80211 driver script');
if (index(text,'function f50_phy_command(')>=0) {
 let old='if (rc) log(`F50 phy command failed rc=${rc}: ${command}`);';
 let upgraded='if (rc) warn(`f50-wifi-command: rc=${rc}: ${label || command}\\n`);';
 if(index(text,old)>=0){text=replace(text,'function f50_phy_command(command) {','function f50_phy_command(command, label) {');text=replace(text,old,upgraded);}
 else if(index(text,'f50-wifi-command: rc=')<0)die('Unknown existing trace version');
} else {
const anchor='function setup_phy(phy, config, data) {';
let begin=index(text,anchor),end=index(text,'function iw_htmode(config) {');
if(begin<0 || end<begin)die('Unknown mac80211 layout');
let block=substr(text,begin,end-begin);
if(index(block,'system(`iw phy ${phy} set antenna')<0)die('Unknown phy command layout');
block=replace(block,'system(`iw ','f50_phy_command(`iw ');
const helper='function f50_phy_command(command, label) {\n\tlet rc = system(command);\n\tif (rc) warn(`f50-wifi-command: rc=${rc}: ${label || command}\\n`);\n\treturn rc;\n}\n\n';
text=substr(text,0,begin)+helper+block+substr(text,end);
}
// Wdev payloads can contain interface settings: record only a safe operation label.
text=replace(text,"system(`ucode /usr/share/hostap/wdev.uc ${name} set_config '{}'`);","f50_phy_command(`ucode /usr/share/hostap/wdev.uc ${name} set_config '{}'`, 'wdev reset-config');");
text=replace(text,"system(`ucode /usr/share/hostap/wdev.uc ${data.phy}${data.phy_suffix} set_config '${if_config}'`);","f50_phy_command(`ucode /usr/share/hostap/wdev.uc ${data.phy}${data.phy_suffix} set_config '${if_config}'`, 'wdev apply-config');");
let result=text;
// ucode resolves lexical function names at declaration time: reset_config must
// see the helper before its own definition, even though setup_phy is later.
let helperStart=index(result,'function f50_phy_command(');
let helperEnd=index(result,'function setup_phy(');
let resetStart=index(result,'function reset_config(');
if(helperStart<0 || helperEnd<helperStart || resetStart<0)die('Unknown helper placement');
if(helperStart>resetStart){
 let helper=substr(result,helperStart,helperEnd-helperStart);
 result=substr(result,0,helperStart)+substr(result,helperEnd);
 resetStart=index(result,'function reset_config(');
 result=substr(result,0,resetStart)+helper+substr(result,resetStart);
}
if(fs.writefile(path,result)!=length(result))die('Write failed');
fs.chmod(path,0755);
print('PHY command errors now identify the command\n');
