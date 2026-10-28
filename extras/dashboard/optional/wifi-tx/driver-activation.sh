#!/bin/sh
set -eu
B=/root/f50-arp-fix-20261028
M=/lib/modules/5.4.254-gb50db5b6224c/sprd_wlan_combo.ko
hash(){ sha256sum "$1" | awk '{print $1}'; }
test "$(uname -r)" = 5.4.254-gb50db5b6224c
current=$(hash "$M")
[ "$current" != efddc24b6791c4147f02a07b436eda22ee5b550f24b3bedc17ff758c07f6b071 ] || { echo "Already applied"; exit 0; }
case "$current" in 2ade081cb0db136dcd5eca36ed903793041c4b086c204761d4d2d44f62416e2d|7c7d77a2aecc96d085f830795d24f1f4c95e2a5322455e75bff580629706f63d) :;; *) echo "Unsupported active build"; exit 1;; esac
test "$(hash "$B/sprd_wlan_combo-original.ko")" = "$current"
test "$(hash "$B/sprd_wlan_combo-arp-candidate.ko")" = efddc24b6791c4147f02a07b436eda22ee5b550f24b3bedc17ff758c07f6b071
cp "$B/driver-recovery.sh" /usr/libexec/f50-driver-recovery
chmod 755 /usr/libexec/f50-driver-recovery
cp "$B/driver-recovery.init" /etc/init.d/f50-driver-recovery
chmod 755 /etc/init.d/f50-driver-recovery
/etc/init.d/f50-driver-recovery enable
touch "$B/activation-pending"
cp "$B/sprd_wlan_combo-arp-candidate.ko" "$M.next"
chmod 644 "$M.next"
mv "$M.next" "$M"
sync
reboot
