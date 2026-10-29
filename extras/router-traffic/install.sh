#!/bin/sh
set -eu
cd "$(dirname "$0")"
[ "$(id -u)" = 0 ] || { echo 'root required' >&2;exit 1;}
[ -f bin/flow-account ] || { echo 'Use the compiled offline bundle or build it first.' >&2;exit 1;}
sha256sum -c MANIFEST.sha256 >/dev/null
tmp=$(mktemp -d /tmp/routertraffic-install.XXXXXX)
changed=0;backup=
finish(){
 code=$?
 if [ "$code" != 0 ] && [ "$changed" = 1 ];then
  echo "Install failed; restoring previous code. Backup: $backup" >&2
  sh "$backup/rollback.sh" "$backup" >"$backup/automatic-rollback.log" 2>&1 || echo "Automatic rollback needs inspection: $backup/automatic-rollback.log" >&2
 fi
 rm -f "$tmp/config.json" "$tmp/check.ucb" "$tmp/existing"
 rmdir "$tmp" 2>/dev/null || :
 trap - EXIT
 exit "$code"
}
trap finish EXIT
oldcfg=/etc/router-traffic/config.json
lan=${1:-$(jsonfilter -i "$oldcfg" -e '@.lan_network' 2>/dev/null || echo lan)}
wan=${2:-$(jsonfilter -i "$oldcfg" -e '@.wan_network' 2>/dev/null || echo wan)}
sh preflight.sh "${lan:-lan}" "${wan:-wan}" > "$tmp/config.json"
ucode -c -o "$tmp/check.ucb" app/collector.uc
free=$(df -k /overlay | awk 'END{print $4}')
[ "$free" -ge 2048 ] || { echo 'At least 2 MiB free overlay space required.' >&2;exit 1;}
backup=/root/router-traffic-backups/$(date +%Y%m%d-%H%M%S)-v022-$$
mkdir -p "$backup";chmod 700 "$backup"
for service in router-traffic f50-traffic;do
 enabled=0;running=0
 if [ -x /etc/init.d/$service ];then
  /etc/init.d/$service enabled && enabled=1 || :
  /etc/init.d/$service running && running=1 || :
 fi
 echo "$enabled" > "$backup/$service.enabled"
 echo "$running" > "$backup/$service.running"
done
[ ! -f /usr/libexec/router-traffic/wan-ledger.uc ] && echo 0 > "$backup/had-wan-backend" || echo 1 > "$backup/had-wan-backend"
cat > "$backup/targets" <<'EOF'
usr/libexec/router-traffic
usr/libexec/rpcd/routertraffic
etc/init.d/router-traffic
etc/router-traffic/config.json
usr/share/rpcd/acl.d/luci-app-routertraffic.json
www/luci-static/resources/routertraffic
etc/sysupgrade.conf
EOF
for file in /www/luci-static/resources/view/status/include/00_f50_traffic*.js /www/luci-static/resources/view/status/include/00_routertraffic_wan*.js /www/luci-static/resources/view/status/include/01_routertraffic*.js /www/luci-static/resources/view/status/include/02_native_folds*.js;do
 [ ! -f "$file" ] || echo "${file#/}" >> "$backup/targets"
done
for file in 19_cpu.js 20_memory.js 25_storage.js 19_cpu.js.routertraffic-disabled 20_memory.js.routertraffic-disabled 25_storage.js.routertraffic-disabled;do
 echo "www/luci-static/resources/view/status/include/$file" >> "$backup/targets"
done
while IFS= read -r file;do [ ! -e "/$file" ] || echo "$file";done < "$backup/targets" > "$tmp/existing"
tar czf "$backup/files.tgz" -C / -T "$tmp/existing"
for dir in /etc/router-traffic /etc/f50-traffic /tmp/f50-traffic;do
 if [ -d "$dir" ];then cp -a "$dir" "$backup/$(echo "$dir" | tr / _)";fi
done
sha256sum /etc/config/network /etc/config/firewall /etc/config/wireless > "$backup/network.sha256"
cp rollback.sh app/export-legacy-wan.uc app/ledger.uc "$backup/"
hot=0
if [ "$(cat "$backup/router-traffic.running")" = 1 ] && [ -f /usr/libexec/router-traffic/flow-account ] && cmp -s bin/flow-account /usr/libexec/router-traffic/flow-account;then
 if ucode -e 'import * as fs from "fs";let a=json(fs.readfile(ARGV[0])),b=json(fs.readfile(ARGV[1]));for(let k in ["lan_ip","lan_prefix","lan_device","redirect_port"])if(a[k]!=b[k])exit(1);' "$oldcfg" "$tmp/config.json";then hot=1;fi
fi
ucode -e 'import * as fs from "fs";let p=ARGV[0],v=json(fs.readfile(p));v.install_id=ARGV[1];fs.writefile(p,sprintf("%J",v));' "$tmp/config.json" "${backup##*/}"
changed=1
legacy_mode=
if [ "$(cat "$backup/f50-traffic.running")" = 1 ];then /etc/init.d/f50-traffic stop;legacy_mode=stopped-live;fi
if [ -x /etc/init.d/f50-traffic ];then /etc/init.d/f50-traffic disable;fi
if [ "$hot" = 0 ] && [ -x /etc/init.d/router-traffic ];then /etc/init.d/router-traffic stop;fi
mkdir -p /usr/libexec/router-traffic /etc/router-traffic /www/luci-static/resources/routertraffic/fonts
chmod 700 /etc/router-traffic
cp app/*.uc /usr/libexec/router-traffic/
if [ "$hot" = 0 ];then cp bin/flow-account /usr/libexec/router-traffic/flow-account.new;chmod 755 /usr/libexec/router-traffic/flow-account.new;mv /usr/libexec/router-traffic/flow-account.new /usr/libexec/router-traffic/flow-account;fi
cp app/rpc-wrapper /usr/libexec/rpcd/routertraffic
cp app/service /etc/init.d/router-traffic
cp app/acl.json /usr/share/rpcd/acl.d/luci-app-routertraffic.json
cp "$tmp/config.json" /etc/router-traffic/config.json
ucode /usr/libexec/router-traffic/migrate-wan.uc "$legacy_mode" > "$backup/wan-migration.json"
cp ui/*.js ui/style.css /www/luci-static/resources/routertraffic/
for name in units devices livechart resources today;do cp "ui/$name.js" "/www/luci-static/resources/routertraffic/${name}_v022.js";done
cp wan/style.css /www/luci-static/resources/routertraffic/wan.css
cp wan/fonts/* /www/luci-static/resources/routertraffic/fonts/
for file in /www/luci-static/resources/view/status/include/00_f50_traffic*.js /www/luci-static/resources/view/status/include/00_routertraffic_wan*.js /www/luci-static/resources/view/status/include/01_routertraffic*.js /www/luci-static/resources/view/status/include/02_native_folds*.js;do [ ! -f "$file" ] || rm -f "$file";done
cp wan/view.js /www/luci-static/resources/view/status/include/00_routertraffic_wan_v022.js
cp ui/status.js /www/luci-static/resources/view/status/include/01_routertraffic_v022.js
cp ui/native-folds.js /www/luci-static/resources/view/status/include/02_native_folds_v022.js
for name in 19_cpu.js 20_memory.js 25_storage.js;do
 path=/www/luci-static/resources/view/status/include/$name
 if [ -f "$path" ];then mv "$path" "$path.routertraffic-disabled";fi
done
chmod 600 /etc/router-traffic/*.json
chmod 755 /usr/libexec/router-traffic/flow-account /usr/libexec/rpcd/routertraffic /etc/init.d/router-traffic
grep -qxF '/etc/router-traffic/' /etc/sysupgrade.conf || echo '/etc/router-traffic/' >> /etc/sysupgrade.conf
/etc/init.d/router-traffic enable
if [ "$hot" = 1 ];then ubus call service signal '{"name":"router-traffic","instance":"ledger","signal":15}';else /etc/init.d/router-traffic start;fi
/etc/init.d/rpcd reload
ready=0
for attempt in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15;do
 if ucode -e 'import * as fs from "fs";let d=json(fs.readfile("/tmp/router-traffic/devices.json")),w=json(fs.readfile("/tmp/f50-traffic/status.json")),c=json(fs.readfile("/etc/router-traffic/config.json"));exit(d.collector_id!=c.install_id||w.collector_id!=c.install_id||d.stale||time()-d.timestamp>4||w.engine!="router-traffic-wan-v2"||w.stale||time()-w.timestamp>4||w.rx_rate==null?1:0);' 2>/dev/null;then ready=1;break;fi
 sleep 1
done
[ "$ready" = 1 ] || { echo 'Collector health check failed' >&2;exit 1;}
sha256sum -c "$backup/network.sha256"
echo "Installed v0.2.2. Backup and rollback: sh $backup/rollback.sh $backup"
changed=0
