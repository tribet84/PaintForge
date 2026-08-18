#!/usr/bin/env bash
#
# Builds the web app and stages the legal documents alongside it.
#
# The policies are served from the app's own domain rather than from GitHub
# Pages so the link in Settings carries the brand, and because pintaminis.com
# already sits behind Cloudflare — a separate static host would add moving
# parts without adding a CDN the site does not already have.
#
# Firebase Hosting serves real files before applying the single-page rewrite,
# so /legal/privacy.html resolves to the file and never reaches Flutter's
# router.
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

echo "==> staging legal documents at /legal"
mkdir -p build/web/legal
# The landing page stays on GitHub Pages; only the documents the app links to
# are served here.
for f in legal.html privacy.html terms.html cookies.html \
         privacy.es.html terms.es.html cookies.es.html \
         legal.css logo.svg logo-light.svg; do
  [ -f "docs/$f" ] && cp "docs/$f" build/web/legal/
done
# /legal on its own lands on the privacy policy rather than a directory
# listing, which Hosting would answer with the app's index.html.
cp docs/legal.html build/web/legal/index.html

echo "==> done"
ls build/web/legal
