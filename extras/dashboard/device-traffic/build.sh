#!/bin/sh
# Build on a Linux computer/build host, never install a compiler on the router.
set -eu
cd "$(dirname "$0")"
export LC_ALL=C
compiler=${CC:-aarch64-linux-gnu-gcc}
for cmd in "$compiler" readelf sha256sum; do command -v "$cmd" >/dev/null; done
"$compiler" -static -Os flow-account.c -o flow-account.build
readelf -h flow-account.build | grep -q 'Machine:.*AArch64' || { echo 'Not an AArch64 binary'; exit 1; }
mv flow-account.build flow-account
sha256sum flow-account flow-account.c > SHA256SUMS.local
echo 'Prepared local AArch64 collector and SHA256SUMS.local. Keep generated binaries local.'
