#!/bin/sh
set -eu
cd "$(dirname "$0")"
for cmd in ucode ubus uci nft jsonfilter iw ip flock sha256sum tar;do command -v "$cmd" >/dev/null || { echo "Missing dependency: $cmd" >&2;exit 1;};done
[ "$(uname -m)" = aarch64 ] || { echo 'This binary is aarch64 only; rebuild for this router.' >&2;exit 1;}
[ -d /sys/module/nf_conntrack_netlink ] || { echo 'nf_conntrack_netlink must already be available (matching this kernel); no kernel module was installed or loaded.' >&2;exit 1;}
ucode -e 'import * as uci from "uci";import * as fs from "fs";import * as loop from "uloop";assert(type(fs.readfile)=="function"&&type(loop.signal)=="function","ucode fs/uloop signal support required");'
board=$(ubus call system board | jsonfilter -e '@.board_name')
[ "$board" = xiaomi,redmi-router-ax6s ] || { echo 'Physical WAN MIB is verified only for Xiaomi Redmi AX6S; no installation performed.' >&2;exit 1; }
wan=$(ubus call network.interface."${2:-wan}" status | jsonfilter -e '@.l3_device')
case "$wan" in ''|*[!a-zA-Z0-9_.:-]*) echo 'WAN device unavailable' >&2;exit 1;; esac
chmod 755 bin/read-port-stats
bin/read-port-stats "$wan" --bytes >/dev/null || { echo 'Physical WAN RxBytes/TxBytes unavailable; no installation performed.' >&2;exit 1; }
ucode app/detect.uc "${1:-lan}" "${2:-wan}"
