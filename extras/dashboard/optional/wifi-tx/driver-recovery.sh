#!/bin/sh
B=/root/f50-arp-fix-20261028
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
case "$(sha256sum "$B/sprd_wlan_combo-original.ko" | awk '{print $1}')" in 2ade081cb0db136dcd5eca36ed903793041c4b086c204761d4d2d44f62416e2d|7c7d77a2aecc96d085f830795d24f1f4c95e2a5322455e75bff580629706f63d) :;; *) exit 1;; esac
cp "$B/sprd_wlan_combo-original.ko" "$M.next" && chmod 644 "$M.next" && mv "$M.next" "$M" || exit 1
rm -f "$B/activation-pending"
date > "$B/activation-rolled-back"
/etc/init.d/f50-driver-recovery disable
sync
reboot
