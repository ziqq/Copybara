#!/usr/bin/env bash
# Copyright (c) 2026 Anton Ustinoff. All rights reserved.
# Use and redistribution are subject to LICENSE.

# Submit a signed app or DMG, require acceptance, then staple and assess it.
set -euo pipefail

ARTIFACT="${1:?Usage: notarize.sh <app-or-dmg> <report-directory>}"
REPORT_DIR="${2:?A report directory is required}"
: "${COPYBARA_TEAM_ID:?The Developer ID team is required}"
: "${APPLE_ID:?The notarization Apple ID is required}"
: "${APPLE_APP_PASSWORD:?An app-specific notarization password is required}"

mkdir -p "$REPORT_DIR"
PAYLOAD="$ARTIFACT"
ARCHIVE=""
trap '[ -z "$ARCHIVE" ] || rm -f "$ARCHIVE"' EXIT
case "$ARTIFACT" in
  *.app)
    ARCHIVE="$REPORT_DIR/submission.zip"
    ditto -c -k --keepParent "$ARTIFACT" "$ARCHIVE"
    PAYLOAD="$ARCHIVE"
    ;;
  *.dmg) ;;
  *) echo "Only .app and .dmg artifacts can be notarized"; exit 1 ;;
esac

AUTH=(--apple-id "$APPLE_ID" --team-id "$COPYBARA_TEAM_ID" --password "$APPLE_APP_PASSWORD")
SUBMIT_EXIT=0
xcrun notarytool submit "$PAYLOAD" "${AUTH[@]}" --wait --timeout 30m --output-format json \
  > "$REPORT_DIR/submission.json" || SUBMIT_EXIT=$?
SUBMISSION_ID=$(python3 - "$REPORT_DIR/submission.json" <<'PY_SUBMISSION'
import json, sys, uuid
report = json.load(open(sys.argv[1]))
print(uuid.UUID(report['id']))
PY_SUBMISSION
)
xcrun notarytool log "$SUBMISSION_ID" "${AUTH[@]}" "$REPORT_DIR/log.json"
python3 - "$REPORT_DIR/submission.json" "$REPORT_DIR/log.json" "$SUBMIT_EXIT" <<'PY_STATUS'
import json, os, sys
submission = json.load(open(sys.argv[1]))
log = json.load(open(sys.argv[2]))
summary = f"Notarization {submission['id']}: {submission.get('status', 'unknown')}"
print(summary)
if os.environ.get('GITHUB_STEP_SUMMARY'):
    with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as output:
        output.write(summary + '\n')
if sys.argv[3] != '0' or submission.get('status') != 'Accepted' or log.get('status') != 'Accepted':
    raise SystemExit('Notarization was not accepted; inspect the saved notary log')
if log.get('issues'):
    print('Notary log contains issues; inspect the saved log before distribution')
PY_STATUS

xcrun stapler staple "$ARTIFACT"
xcrun stapler validate "$ARTIFACT"
if [[ "$ARTIFACT" == *.app ]]; then
  codesign --verify --deep --strict "$ARTIFACT"
  spctl --assess --type execute --verbose=2 "$ARTIFACT"
else
  codesign --verify --strict "$ARTIFACT"
  spctl --assess --type open --context context:primary-signature --verbose=2 "$ARTIFACT"
fi
