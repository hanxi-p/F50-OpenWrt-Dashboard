#!/bin/sh
set -eu
B=/root/f50-cpu-fix-20261028
M=/lib/modules/5.4.254-gb50db5b6224c/sprd_wlan_combo.ko
hash(){ sha256sum "$1" | awk '{print $1}'; }
test "$(uname -r)" = 5.4.254-gb50db5b6224c
test "$(hash "$M")" = d6a42377cab3ff62a2c990ff7a08c1cf2cf5c7f270aedd15491e267897098481
test "$(hash "$B/sprd_wlan_combo-original.ko")" = d6a42377cab3ff62a2c990ff7a08c1cf2cf5c7f270aedd15491e267897098481
test "$(hash "$B/sprd_wlan_combo-quiet.ko")" = 7c7d77a2aecc96d085f830795d24f1f4c95e2a5322455e75bff580629706f63d
cp "$B/driver-recovery.sh" /usr/libexec/f50-driver-recovery
chmod 755 /usr/libexec/f50-driver-recovery
cp "$B/driver-recovery.init" /etc/init.d/f50-driver-recovery
chmod 755 /etc/init.d/f50-driver-recovery
/etc/init.d/f50-driver-recovery enable
touch "$B/activation-pending"
cp "$B/sprd_wlan_combo-quiet.ko" "$M.next"
chmod 644 "$M.next"
mv "$M.next" "$M"
sync
reboot
