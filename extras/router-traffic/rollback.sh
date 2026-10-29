#!/bin/sh
set -eu
backup=${1:?Usage: rollback.sh /root/router-traffic-backups/BACKUP}
case "$backup" in /root/router-traffic-backups/*) ;; *) echo 'Invalid backup directory' >&2;exit 1;;esac
[ -f "$backup/files.tgz" ] && [ -f "$backup/router-traffic.running" ]
if [ -x /etc/init.d/router-traffic ];then /etc/init.d/router-traffic stop;/etc/init.d/router-traffic disable;fi
if [ -d /etc/router-traffic ];then cp -a /etc/router-traffic "$backup/latest-statistics-at-rollback";fi
if [ "$(cat "$backup/had-wan-backend")" = 0 ];then
 ucode "$backup/export-legacy-wan.uc" || :
 if [ -f /etc/router-traffic/wan-ledger.json ];then mv /etc/router-traffic/wan-ledger.json "$backup/latest-wan-ledger.json";fi
 if [ -f /tmp/router-traffic/wan-ledger.json ];then mv /tmp/router-traffic/wan-ledger.json "$backup/latest-wan-runtime.json";fi
fi
for file in /www/luci-static/resources/view/status/include/00_f50_traffic*.js /www/luci-static/resources/view/status/include/00_routertraffic_wan*.js /www/luci-static/resources/view/status/include/01_routertraffic*.js /www/luci-static/resources/view/status/include/02_native_folds*.js;do [ ! -f "$file" ] || rm -f "$file";done
for name in 19_cpu.js 20_memory.js 25_storage.js;do rm -f /www/luci-static/resources/view/status/include/$name /www/luci-static/resources/view/status/include/$name.routertraffic-disabled;done
# Both namespaces contain package code only, and were fully backed up.
rm -rf /usr/libexec/router-traffic /www/luci-static/resources/routertraffic
rm -f /usr/libexec/rpcd/routertraffic /etc/init.d/router-traffic /usr/share/rpcd/acl.d/luci-app-routertraffic.json
tar xzf "$backup/files.tgz" -C /
for service in router-traffic f50-traffic;do
 if [ -x /etc/init.d/$service ];then
  if [ "$(cat "$backup/$service.enabled")" = 1 ];then /etc/init.d/$service enable;else /etc/init.d/$service disable;fi
  if [ "$(cat "$backup/$service.running")" = 1 ];then /etc/init.d/$service start;fi
 fi
done
/etc/init.d/rpcd reload
echo 'Previous code restored; latest per-device ledger retained and WAN totals exported/archived.'
