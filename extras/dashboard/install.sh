#!/bin/sh
set -eu
cd "$(dirname "$0")"
[ "$(id -u)" = 0 ] || { echo '请使用 root SSH 执行'; exit 1; }
version=$(cat /etc/mu300/image-version 2>/dev/null || true)
[ "$version" = v2026.10.11 ] || { echo "此补丁匹配 v2026.10.11，当前为 $version；请先核对页面与 RPC 差异。"; exit 1; }
for cmd in vnstat ubus uci jsonfilter setsid flock sha256sum curl ucode iw; do command -v "$cmd" >/dev/null || { echo "缺少 $cmd，请先安装对应依赖"; exit 1; }; done
[ -r /usr/libexec/unisoc-modem/dashboard-info ] && [ -r /www/luci-static/resources/view/mu300/home.js ] || { echo '缺少 MU300 面板'; exit 1; }
ip link show sipa_eth0 >/dev/null || { echo '当前蜂窝接口不是 sipa_eth0，请先适配统计接口'; exit 1; }
[ "$(uci -q get wireless.radio0.band)" = 5g ] && [ "$(uci -q get wireless.ap0.device)" = radio0 ] || { echo '此版本匹配 radio0 / ap0 和 5GHz 无线，请先适配'; exit 1; }
[ "$(uname -m)" = aarch64 ] || { echo '设备采集器只匹配 aarch64；请先重新构建与适配'; exit 1; }
[ "$(cat /proc/sys/net/netfilter/nf_conntrack_acct 2>/dev/null)" = 1 ] || { echo 'conntrack 字节计数不可用；未修改网络或加速设置，请先评估兼容采集方式。'; exit 1; }
sha256sum -c SHA256SUMS >/dev/null
[ -f device-traffic/SHA256SUMS.local ] || { echo '请先在 Linux 构建主机执行 sh extras/dashboard/device-traffic/build.sh，准备本地采集器。'; exit 1; }
(cd device-traffic && sha256sum -c SHA256SUMS.local >/dev/null)
case "$(sha256sum /usr/sbin/vnstatd | awk '{print $1}')" in
 7eca0a8d4d07f7c01c1703a096afde01e133d73c963b2a58e2a035ffeda219a9|436b3a8dd8efe250d21a908ba6ab36a70872832285d3a70dffeb2ddcf3507026) ;;
 *) echo 'vnstatd 版本不匹配计数复位补丁，请先适配；尚未修改服务。'; exit 1;;
esac
for path in /usr/share/ucode/luci/template/themes/aurora/header.ut /usr/share/ucode/luci/template/header.ut /etc/init.d/mu300-hw; do
 [ -r "$path" ] || { echo "缺少 $path；此版本首屏优化需要 Aurora UT 主题，请先适配。"; exit 1; }
done
backup="/root/f50-dashboard-backups/$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$backup"
chmod 700 "$backup"
if /etc/init.d/vnstat enabled; then echo 1 > "$backup/vnstat.enabled"; else echo 0 > "$backup/vnstat.enabled"; fi
if /etc/init.d/vnstat running; then echo 1 > "$backup/vnstat.running"; else echo 0 > "$backup/vnstat.running"; fi
if [ -x /etc/init.d/f50power ] && /etc/init.d/f50power enabled; then echo 1 > "$backup/f50power.enabled"; else echo 0 > "$backup/f50power.enabled"; fi
if [ -x /etc/init.d/f50history ] && /etc/init.d/f50history enabled; then echo 1 > "$backup/f50history.enabled"; else echo 0 > "$backup/f50history.enabled"; fi
for service in f50-devices f50-wifi-guard f50-dns-guard f50-diagnostics f50-traffic-archive f50-speed-peaks; do
 if [ -x /etc/init.d/$service ] && /etc/init.d/$service enabled; then echo 1 > "$backup/$service.enabled"; else echo 0 > "$backup/$service.enabled"; fi
 if [ -x /etc/init.d/$service ] && /etc/init.d/$service running; then echo 1 > "$backup/$service.running"; else echo 0 > "$backup/$service.running"; fi
done
cat > "$backup/paths" <<'PATHS'
/www/luci-static/resources/f50nettest.js
/www/cgi-bin/f50-nettest
/usr/libexec/f50-nettest-stream.uc
/usr/libexec/rpcd/f50nettest
/usr/share/rpcd/acl.d/luci-app-f50nettest.json
/www/luci-static/resources/f50powerradio25.js
/usr/libexec/f50-lock
/usr/libexec/f50-run-worker
/usr/libexec/f50-diagnostics
/usr/libexec/f50-diagnostics-worker
/etc/init.d/f50-diagnostics
/usr/libexec/f50-traffic-archive
/usr/libexec/f50-traffic-export.uc
/usr/libexec/f50-counter-audit.uc
/etc/init.d/f50-traffic-archive
/usr/libexec/f50-speed-peaks.uc
/usr/libexec/f50-speed-peaks-worker
/etc/init.d/f50-speed-peaks
/www/luci-static/resources/f50speedpeaks.js
/www/luci-static/resources/f50livechart.js
/www/luci-static/resources/f50devices.js
/www/luci-static/resources/f50units.js
/usr/libexec/f50-devices/flow-account
/usr/libexec/f50-devices/ledger.uc
/usr/libexec/f50-devices/collector.uc
/usr/libexec/f50-devices/peers.uc
/usr/libexec/f50-devices/rpc.uc
/etc/init.d/f50-devices
/usr/libexec/rpcd/f50devices
/usr/share/rpcd/acl.d/luci-app-f50devices.json
/usr/libexec/unisoc-modem/cell
/www/luci-static/resources/view/mu300/home.js
/www/luci-static/resources/mu300/common.js
/usr/libexec/unisoc-modem/lock
/usr/libexec/rpcd/mu300dash
/usr/libexec/unisoc-modem/dashboard-info
/www/luci-static/resources/f50quota5.js
/www/luci-static/resources/f50channel.js
/www/luci-static/resources/f50channelstate.js
/www/luci-static/resources/f50openclash.js
/usr/libexec/rpcd/f50quota
/usr/libexec/rpcd/f50channel
/usr/libexec/rpcd/f50openclash
/usr/libexec/f50openclash-worker
/usr/share/rpcd/acl.d/luci-app-f50quota.json
/usr/share/rpcd/acl.d/luci-app-f50channel.json
/usr/share/rpcd/acl.d/luci-app-f50openclash.json
/etc/config/f50quota
/usr/sbin/vnstatd
/etc/config/vnstat
/etc/vnstat.conf
/www/luci-static/resources/f50power.js
/usr/libexec/rpcd/f50power
/usr/libexec/f50power-worker
/etc/init.d/f50power
/usr/share/rpcd/acl.d/luci-app-f50power.json
/etc/config/f50dashboard
/etc/config/luci
/www/luci-static/resources/f50powerlittle.js
/www/luci-static/resources/f50power20.js
/www/luci-static/resources/f50openclash2.js
/usr/libexec/rpcd/f50history
/usr/libexec/f50history-worker
/etc/init.d/f50history
/usr/share/rpcd/acl.d/luci-app-f50history.json
/www/luci-static/resources/f50adguard.js
/usr/libexec/rpcd/f50adguard
/usr/libexec/f50adguard-worker
/usr/libexec/f50-dns-route
/usr/share/rpcd/acl.d/luci-app-f50adguard.json
/usr/libexec/f50-wifi-nondfs
/usr/libexec/f50-wifi-start-safe
/etc/init.d/mu300-hw
/etc/config/wireless
/etc/config/unisoc_modem
/usr/share/ucode/luci/template/themes/aurora/header.ut
/usr/share/ucode/luci/template/header.ut
/usr/libexec/f50-bounded
/usr/libexec/f50-wifi-guard
/usr/libexec/f50-wifi-evaluate
/etc/init.d/f50-wifi-guard
/usr/libexec/f50-dns-guard
/usr/libexec/f50-dns-health
/etc/init.d/f50-dns-guard
PATHS
while IFS= read -r path; do
 if [ -e "$path" ]; then mkdir -p "$backup$(dirname "$path")"; cp -p "$path" "$backup$path"; fi
done < "$backup/paths"
cp restore.sh "$backup/restore.sh"
if [ -d /etc/f50-devices ]; then
 mkdir -p "$backup/device-traffic-state"
 cp -p /etc/f50-devices/*.json "$backup/device-traffic-state/" 2>/dev/null || true
fi
[ ! -x /etc/init.d/f50-devices ] || /etc/init.d/f50-devices stop
[ ! -x /etc/init.d/f50history ] || /etc/init.d/f50history stop
/etc/init.d/vnstat stop
sh f50-vnstat-counterfix.sh
old_dir=$(vnstat --showconfig | awk '/^[;]?DatabaseDir / {gsub(/"/,"",$2); print $2; exit}')
case "$old_dir" in /tmp*|/var*|'')
 mkdir -p /opt/vnstat
 if [ -n "$old_dir" ] && [ -f "$old_dir/vnstat.db" ] && [ "$old_dir" != /opt/vnstat ]; then
  [ ! -f /opt/vnstat/vnstat.db ] || { echo "新旧数据库都存在，请先合并；恢复命令：sh $backup/restore.sh"; exit 1; }
  cp -p "$old_dir/vnstat.db" /opt/vnstat/vnstat.db
 fi
 sed -i '/^[[:space:]]*DatabaseDir[[:space:]]/d' /etc/vnstat.conf
 printf '\nDatabaseDir "/opt/vnstat"\n' >> /etc/vnstat.conf
 ;;
esac
for setting in 'SaveInterval 5' 'MonthRotate 1' 'MonthlyMonths -1' 'DailyDays 365' '64bitInterfaceCounters 1'; do
 key=${setting%% *}
 sed -i "/^[[:space:]]*$key[[:space:]]/d" /etc/vnstat.conf
 printf '%s\n' "$setting" >> /etc/vnstat.conf
done
sh f50-vnstat-reset-guard.sh
uci -q show vnstat.@vnstat[0] >/dev/null || uci add vnstat vnstat >/dev/null
if ! uci -q get vnstat.@vnstat[0].interface | tr ' ' '\n' | grep -qx sipa_eth0; then uci add_list vnstat.@vnstat[0].interface=sipa_eth0; fi
uci commit vnstat
if [ ! -f /etc/config/f50quota ]; then printf "config plan 'plan'\n\toption quota_gb '0'\n" > /etc/config/f50quota; fi
while IFS=' ' read -r src target; do
 mkdir -p "$(dirname "$target")"
 cp "$src" "$target.f50-new"
 chmod 644 "$target.f50-new"
 mv "$target.f50-new" "$target"
done <<'FILES'
f50nettest.js /www/luci-static/resources/f50nettest.js
f50-nettest-cgi /www/cgi-bin/f50-nettest
f50-nettest-stream.uc /usr/libexec/f50-nettest-stream.uc
f50-nettest /usr/libexec/rpcd/f50nettest
luci-app-f50nettest.json /usr/share/rpcd/acl.d/luci-app-f50nettest.json
f50-bounded /usr/libexec/f50-bounded
f50-wifi-guard /usr/libexec/f50-wifi-guard
f50-wifi-evaluate /usr/libexec/f50-wifi-evaluate
f50-wifi-guard-init /etc/init.d/f50-wifi-guard
f50-dns-guard /usr/libexec/f50-dns-guard
f50-dns-health /usr/libexec/f50-dns-health
f50-dns-guard-init /etc/init.d/f50-dns-guard
f50channel.js /www/luci-static/resources/f50channelstate.js
f50power.js /www/luci-static/resources/f50powerradio25.js
f50-lock /usr/libexec/f50-lock
f50-run-worker /usr/libexec/f50-run-worker
f50-diagnostics /usr/libexec/f50-diagnostics
f50-diagnostics-worker /usr/libexec/f50-diagnostics-worker
f50-diagnostics-init /etc/init.d/f50-diagnostics
f50-traffic-archive /usr/libexec/f50-traffic-archive
f50-traffic-export.uc /usr/libexec/f50-traffic-export.uc
f50-counter-audit.uc /usr/libexec/f50-counter-audit.uc
f50-traffic-archive-init /etc/init.d/f50-traffic-archive
f50-speed-peaks.uc /usr/libexec/f50-speed-peaks.uc
f50-speed-peaks-worker /usr/libexec/f50-speed-peaks-worker
f50-speed-peaks-init /etc/init.d/f50-speed-peaks
f50speedpeaks.js /www/luci-static/resources/f50speedpeaks.js
f50livechart.js /www/luci-static/resources/f50livechart.js
f50devices.js /www/luci-static/resources/f50devices.js
device-traffic/flow-account /usr/libexec/f50-devices/flow-account
device-traffic/ledger.uc /usr/libexec/f50-devices/ledger.uc
device-traffic/peers.uc /usr/libexec/f50-devices/peers.uc
device-traffic/collector.uc /usr/libexec/f50-devices/collector.uc
device-traffic/rpc.uc /usr/libexec/f50-devices/rpc.uc
device-traffic/service /etc/init.d/f50-devices
device-traffic/rpc-wrapper /usr/libexec/rpcd/f50devices
device-traffic/acl.json /usr/share/rpcd/acl.d/luci-app-f50devices.json
cell /usr/libexec/unisoc-modem/cell
modem-lock /usr/libexec/unisoc-modem/lock
mu300dash /usr/libexec/rpcd/mu300dash
home.js /www/luci-static/resources/view/mu300/home.js
f50units.js /www/luci-static/resources/f50units.js
dashboard-info /usr/libexec/unisoc-modem/dashboard-info
f50quota5.js /www/luci-static/resources/f50quota5.js
f50channel.js /www/luci-static/resources/f50channel.js
f50openclash.js /www/luci-static/resources/f50openclash.js
f50quota /usr/libexec/rpcd/f50quota
f50channel /usr/libexec/rpcd/f50channel
f50openclash /usr/libexec/rpcd/f50openclash
f50openclash-worker /usr/libexec/f50openclash-worker
luci-app-f50quota.json /usr/share/rpcd/acl.d/luci-app-f50quota.json
luci-app-f50channel.json /usr/share/rpcd/acl.d/luci-app-f50channel.json
luci-app-f50openclash.json /usr/share/rpcd/acl.d/luci-app-f50openclash.json
f50power.js /www/luci-static/resources/f50power.js
f50power /usr/libexec/rpcd/f50power
f50power-worker /usr/libexec/f50power-worker
f50power-init /etc/init.d/f50power
luci-app-f50power.json /usr/share/rpcd/acl.d/luci-app-f50power.json
f50power.js /www/luci-static/resources/f50powerlittle.js
f50power.js /www/luci-static/resources/f50power20.js
f50openclash.js /www/luci-static/resources/f50openclash2.js
f50history /usr/libexec/rpcd/f50history
f50history-worker /usr/libexec/f50history-worker
f50history-init /etc/init.d/f50history
luci-app-f50history.json /usr/share/rpcd/acl.d/luci-app-f50history.json
f50adguard.js /www/luci-static/resources/f50adguard.js
f50adguard /usr/libexec/rpcd/f50adguard
f50adguard-worker /usr/libexec/f50adguard-worker
f50-dns-route /usr/libexec/f50-dns-route
luci-app-f50adguard.json /usr/share/rpcd/acl.d/luci-app-f50adguard.json
f50-wifi-nondfs /usr/libexec/f50-wifi-nondfs
f50-wifi-start-safe /usr/libexec/f50-wifi-start-safe
FILES
chmod 755 /usr/libexec/unisoc-modem/lock /usr/libexec/unisoc-modem/cell /usr/libexec/f50-run-worker /usr/libexec/rpcd/mu300dash
chmod 755 /usr/libexec/f50-diagnostics /usr/libexec/f50-diagnostics-worker /etc/init.d/f50-diagnostics
chmod 755 /usr/libexec/f50-traffic-archive /etc/init.d/f50-traffic-archive
chmod 755 /usr/libexec/f50-speed-peaks-worker /etc/init.d/f50-speed-peaks
chmod 755 /usr/libexec/f50-wifi-nondfs /usr/libexec/f50-wifi-start-safe
chmod 755 /usr/libexec/f50-bounded /usr/libexec/f50-wifi-guard /usr/libexec/f50-wifi-evaluate /etc/init.d/f50-wifi-guard /usr/libexec/f50-dns-guard /usr/libexec/f50-dns-health /etc/init.d/f50-dns-guard /usr/libexec/f50-lock
chmod 755 /usr/libexec/f50-devices/flow-account /usr/libexec/rpcd/f50devices /etc/init.d/f50-devices
sh apply-reliability.sh
chmod 755 /www/cgi-bin/f50-nettest /usr/libexec/rpcd/f50nettest
chmod 755 /usr/libexec/unisoc-modem/dashboard-info /usr/libexec/rpcd/f50quota /usr/libexec/rpcd/f50channel /usr/libexec/rpcd/f50openclash /usr/libexec/f50openclash-worker
chmod 755 /usr/libexec/rpcd/f50power /usr/libexec/f50power-worker /etc/init.d/f50power
chmod 755 /usr/libexec/rpcd/f50adguard /usr/libexec/f50adguard-worker /usr/libexec/f50-dns-route
/etc/init.d/f50power enable
/etc/init.d/f50power start
/etc/init.d/vnstat enable
/etc/init.d/vnstat start
chmod 755 /usr/libexec/rpcd/f50history /usr/libexec/f50history-worker /etc/init.d/f50history
# Session lifetime is LuCI sauth.sessiontime, not rpcd executable timeout.
if [ -z "$(uci -q get luci.sauth.sessiontime)" ]; then
 uci set luci.sauth.sessiontime=7200
 uci commit luci
fi
uci set unisoc_modem.main.home_refresh_interval=1
uci commit unisoc_modem
chmod 755 /usr/libexec/f50-lock
# Remove retired dashboard extension when upgrading.
rm -f /www/luci-static/resources/f50highrail.js /usr/libexec/rpcd/f50highrail /usr/libexec/f50highrail-worker /usr/libexec/f50highrail-run /usr/share/rpcd/acl.d/luci-app-f50highrail.json
/etc/init.d/rpcd restart
/etc/init.d/f50-devices enable
/etc/init.d/f50-devices start
/etc/init.d/f50history enable
/etc/init.d/f50history start
/etc/init.d/f50-wifi-guard enable
/etc/init.d/f50-wifi-guard restart
/etc/init.d/f50-dns-guard enable
/etc/init.d/f50-dns-guard restart
/etc/init.d/f50-diagnostics enable
/etc/init.d/f50-diagnostics restart
/etc/init.d/f50-traffic-archive enable
/etc/init.d/f50-traffic-archive restart
/etc/init.d/f50-speed-peaks enable
/etc/init.d/f50-speed-peaks restart
sync
printf '安装完成；请重新登录并强制刷新首页。\n原页面和配置备份：%s\n恢复命令：sh %s/restore.sh\n' "$backup" "$backup"
ubus call f50power status >/dev/null
ubus call f50quota status >/dev/null
ubus call f50devices status >/dev/null
ubus call f50channel status >/dev/null
ubus call f50openclash status >/dev/null
