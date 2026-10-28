#!/bin/sh
B=/root/f50-cpu-fix-20261028
M=/lib/modules/5.4.254-gb50db5b6224c/sprd_wlan_combo.ko
sleep 90
[ -f "$B/activation-pending" ] || exit 0
for try in 1 2 3; do
 if [ -d /sys/class/net/wlan0 ] && /usr/libexec/f50-bounded 5 iw wlan0 info | grep -q 'type AP'; then
  date > "$B/activation-ap-ready"
  rm -f "$B/activation-pending"
  /etc/init.d/f50-driver-recovery disable
  exit 0
 fi
 sleep 10
done
# One automatic recovery attempt, with the original exact-build module.
[ "$(sha256sum "$B/sprd_wlan_combo-original.ko" | awk '{print $1}')" = d6a42377cab3ff62a2c990ff7a08c1cf2cf5c7f270aedd15491e267897098481 ] || exit 1
cp "$B/sprd_wlan_combo-original.ko" "$M.next" && chmod 644 "$M.next" && mv "$M.next" "$M" || exit 1
rm -f "$B/activation-pending"
date > "$B/activation-rolled-back"
/etc/init.d/f50-driver-recovery disable
sync
reboot
