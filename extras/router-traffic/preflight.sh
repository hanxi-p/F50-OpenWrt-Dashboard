#!/bin/sh
set -eu
cd "$(dirname "$0")"
for cmd in ucode ubus uci nft jsonfilter iw ip flock sha256sum tar;do command -v "$cmd" >/dev/null || { echo "Missing dependency: $cmd" >&2;exit 1;};done
[ "$(uname -m)" = aarch64 ] || { echo 'This binary is aarch64 only; rebuild for this router.' >&2;exit 1;}
[ -d /sys/module/nf_conntrack_netlink ] || { echo 'nf_conntrack_netlink must already be available (matching this kernel); no kernel module was installed or loaded.' >&2;exit 1;}
ucode -e 'import * as fs from "fs";import * as loop from "uloop";assert(type(fs.readfile)=="function"&&type(loop.signal)=="function","ucode fs/uloop signal support required");'
ucode app/detect.uc "${1:-lan}" "${2:-wan}"
