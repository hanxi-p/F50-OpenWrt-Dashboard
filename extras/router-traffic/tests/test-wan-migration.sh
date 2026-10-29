#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
testroot=$(mktemp -d /tmp/routertraffic-migration-test.XXXXXX)
trap 'rm -f "$testroot"/config/* "$testroot"/runtime/* "$testroot"/wan/* "$testroot"/legacy.state "$testroot"/export.state; rmdir "$testroot"/config "$testroot"/runtime "$testroot"/wan "$testroot" 2>/dev/null || :' EXIT
mkdir "$testroot/config" "$testroot/runtime" "$testroot/wan"
export ROUTER_TRAFFIC_CONFIG_DIR="$testroot/config"
export ROUTER_TRAFFIC_RUNTIME_DIR="$testroot/runtime"
export ROUTER_TRAFFIC_WAN_RUNTIME_DIR="$testroot/wan"
export ROUTER_TRAFFIC_LEGACY_STATE="$testroot/legacy.state"
today=$(date +%F);hour=$(date +%F-%H);now=$(date +%s)
cat > "$testroot/legacy.state" <<EOF
DATE_KEY='$today'
HOUR_KEY='$hour'
LAST_DEVICE='lo'
DAILY_RX=1000
DAILY_TX=2000
HOUR_RX=100
HOUR_TX=200
PEAK_RX=300
PEAK_TX=400
LAST_RX=123
LAST_TX=456
EOF
printf '{"timestamp":%s,"device":"lo","date":"%s","hour":"%s","daily_rx":1000,"daily_tx":2000,"hour_rx":100,"hour_tx":200,"peak_rx":300,"peak_tx":400,"rx_total":500,"tx_total":600}\n' "$now" "$today" "$hour" > "$testroot/wan/status.json"
ucode app/migrate-wan.uc stopped-live
ucode -e 'import * as fs from "fs";let s=json(fs.readfile(getenv("ROUTER_TRAFFIC_CONFIG_DIR")+"/wan-ledger.json"));assert(s.daily_rx==1000&&s.daily_tx==2000&&s.session_rx==500&&s.last.rx==123&&s.last.device=="lo");print("PASS live migration and exact totals\n");'
ucode app/migrate-wan.uc stopped-live
export ROUTER_TRAFFIC_LEGACY_STATE="$testroot/export.state"
ucode app/export-legacy-wan.uc
grep -qx 'DAILY_RX=1000' "$testroot/export.state"
grep -qx 'LAST_TX=456' "$testroot/export.state"
echo 'PASS idempotent migration and rollback export, production data untouched'
