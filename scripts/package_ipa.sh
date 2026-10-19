#!/usr/bin/env bash
set -euo pipefail
APP_PATH=${1:?Pass the built Heartbeat.app path}
OUTPUT_DIR=${2:-build/artifacts}
test -d "$APP_PATH/PlugIns/HeartbeatWidget.appex"
test -f "$APP_PATH/Heartbeat"
mkdir -p "$OUTPUT_DIR/Payload"
cp -R "$APP_PATH" "$OUTPUT_DIR/Payload/Heartbeat.app"
(
  cd "$OUTPUT_DIR"
  /usr/bin/ditto -c -k --keepParent Payload Heartbeat-unsigned.ipa
)
python3 - "$OUTPUT_DIR/Heartbeat-unsigned.ipa" <<'PY'
import sys,zipfile
with zipfile.ZipFile(sys.argv[1]) as archive:
    names=set(archive.namelist())
    for required in ['Payload/Heartbeat.app/Heartbeat','Payload/Heartbeat.app/Info.plist','Payload/Heartbeat.app/PlugIns/HeartbeatWidget.appex/HeartbeatWidget']:
        if required not in names: raise SystemExit('IPA missing '+required)
print('IPA verified: iPhone app and Live Activity extension included; signing still required.')
PY
rm -rf "$OUTPUT_DIR/Payload"
