#!/usr/bin/env bash
#
# Builds the web app and stages the legal documents alongside it.
#
# The legal documents are NOT staged here. They belong to the public site
# (docs/, deployed with `firebase deploy --only hosting:site`), which is where
# someone who has not signed in can still read them.
#
# Usage: tool/build_web.sh
set -euo pipefail

cd "$(dirname "$0")/.."

BUILD_STAMP="${BUILD_STAMP:-$(date +%s)}"
PHOTO_CDN_HOST="${PHOTO_CDN_HOST:-img.pintaminis.com}"
RECAPTCHA_SITE_KEY="${RECAPTCHA_SITE_KEY:-6Lf5DostAAAAANnv7IzCSzrTPmrdO5H45Dca4QX9}"

echo "==> flutter build web (stamp $BUILD_STAMP)"
flutter build web --release \
  --dart-define=BUILD_STAMP="$BUILD_STAMP" \
  --dart-define=PHOTO_CDN_HOST="$PHOTO_CDN_HOST" \
  --dart-define=RECAPTCHA_SITE_KEY="$RECAPTCHA_SITE_KEY"

echo "==> done"
