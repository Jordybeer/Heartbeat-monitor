#!/usr/bin/env bash
set -euo pipefail
APP_PATH=${1:?Pass the built Heartbeat.app path}
OUTPUT_DIR=${2:-build/artifacts}
ENTITLEMENTS_PATH=${3:-App/Heartbeat.entitlements}
test -d "$APP_PATH/PlugIns/HeartbeatWidget.appex"
test -f "$APP_PATH/Heartbeat"
mkdir -p "$OUTPUT_DIR/Payload"
cp -R "$APP_PATH" "$OUTPUT_DIR/Payload/Heartbeat.app"
# An ad hoc signature carries the requested entitlements for the re-signer.
# It has no certificate/profile and cannot authorize installation on an iPhone.
PACKAGED_APP="$OUTPUT_DIR/Payload/Heartbeat.app"
/usr/bin/codesign --force --sign - --generate-entitlement-der "$PACKAGED_APP/PlugIns/HeartbeatWidget.appex"
/usr/bin/codesign --force --sign - --generate-entitlement-der --entitlements "$ENTITLEMENTS_PATH" "$PACKAGED_APP"
/usr/bin/codesign --verify --strict "$PACKAGED_APP/PlugIns/HeartbeatWidget.appex"
/usr/bin/codesign --verify --strict "$PACKAGED_APP"
/usr/bin/codesign --display --entitlements - --xml "$PACKAGED_APP" > "$OUTPUT_DIR/Embedded-entitlements.plist"
python3 - "$OUTPUT_DIR/Embedded-entitlements.plist" <<'PY'
import plistlib,sys
with open(sys.argv[1], 'rb') as stream:
    assert plistlib.load(stream).get('com.apple.developer.healthkit') is True, 'HealthKit entitlement missing from IPA signature'
print('HealthKit entitlement embedded for SideStore re-signing; no developer certificate used.')
PY
(
  cd "$OUTPUT_DIR"
  /usr/bin/ditto -c -k --keepParent Payload Heartbeat-sideload.ipa
)
python3 - "$OUTPUT_DIR/Heartbeat-sideload.ipa" <<'PY'
import sys,zipfile
with zipfile.ZipFile(sys.argv[1]) as archive:
    names=set(archive.namelist())
    for required in ['Payload/Heartbeat.app/Heartbeat','Payload/Heartbeat.app/Info.plist','Payload/Heartbeat.app/PlugIns/HeartbeatWidget.appex/HeartbeatWidget']:
        if required not in names: raise SystemExit('IPA missing '+required)
print('IPA verified: iPhone app and Live Activity extension included; signing still required.')
PY
rm -rf "$OUTPUT_DIR/Payload"
