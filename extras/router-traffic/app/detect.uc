#!/usr/bin/ucode
import * as fs from 'fs';
function command(s){let p=fs.popen(s,'r');if(!p)return '';let v=p.read('all');p.close();return trim(v??'');}
function valid(s){return match(s??'',/^[a-zA-Z0-9_.:-]+$/);}
let lanName=ARGV[0]??'lan',wanName=ARGV[1]??'wan';
if(!match(lanName,/^[a-zA-Z0-9_]+$/)||!match(wanName,/^[a-zA-Z0-9_]+$/))die('invalid logical interface');
let lan=json(command('ubus call network.interface.'+lanName+' status')),wan=json(command('ubus call network.interface.'+wanName+' status'));
let dev=lan.l3_device??lan.device,wanDev=wan.l3_device??wan.device,ip=lan['ipv4-address']?.[0];
if(!valid(dev)||!valid(wanDev)||!ip?.address||!(ip.mask>=1&&ip.mask<=32))die('LAN/WAN is unavailable');
if(!fs.stat('/sys/class/net/'+dev+'/bridge')||!fs.stat('/sys/class/net/'+dev+'/brforward'))die('LAN must be a readable Linux bridge');
if(trim(fs.readfile('/proc/sys/net/netfilter/nf_conntrack_acct')??'')!='1')die('nf_conntrack_acct is disabled: no network setting was changed');
if(time()<1577836800)die('Set a valid local system date before enabling daily statistics');
let software=command("uci -q get firewall.@defaults[0].flow_offloading")=='1',hardware=command("uci -q get firewall.@defaults[0].flow_offloading_hw")=='1';
let flowtable=command('nft list flowtable inet fw4 ft 2>/dev/null'),hasCounter=!!match(flowtable,/(^|[[:space:];])counter([[:space:];]|$)/);
if((software||hardware)&&!hasCounter)die('Accelerated fw4 flowtable has no verified counter support; acceleration and firewall were not changed');
let port=0;
// Only emit the numeric redirect port; never expose proxy passwords or nodes.
if(command('command -v ruby')!=''){
 let p=command("ruby -ryaml -e 'Dir[\"/proc/[0-9]*/cmdline\"].each{|f|begin;a=File.binread(f).split(\"\\0\");next unless a[0].to_s.match?(/(?:clash|mihomo)$/);i=a.index(\"-f\");next unless i&&a[i+1];c=YAML.load_file(a[i+1]);v=c[\"redir-port\"];if v.to_i>0;puts v.to_i;exit;end;rescue;end}' 2>/dev/null");
 if(match(p,/^[0-9]+$/)&&+p<=65535)port=+p;
}
if(!port){let fallback=command('uci -q get openclash.config.proxy_port');if(match(fallback,/^[0-9]+$/)&&+fallback>0&&+fallback<=65535)port=+fallback;}
print(sprintf('%J',{version:2,lan_network:lanName,wan_network:wanName,lan_device:dev,lan_ip:ip.address,lan_prefix:ip.mask,redirect_port:port,show_wan:false,software_offload:software,hardware_offload:hardware,flowtable_counter:hasCounter}));
