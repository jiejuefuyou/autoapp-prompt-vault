#!/usr/bin/env bash
set -euo pipefail

APP_DIR="PromptVault"
OUT_DIR="$APP_DIR/Resources/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$OUT_DIR"

if command -v swift >/dev/null 2>&1 && [ "$(uname)" = "Darwin" ]; then
    swift scripts/IconGenerator.swift "$OUT_DIR/icon.png"
elif command -v convert >/dev/null 2>&1; then
    convert -size 1024x1024 \
      -define gradient:angle=135 \
      gradient:"#E63946-#7209B7" \
      -alpha off \
      -fill white -font Helvetica-Bold -pointsize 600 -gravity center \
      -annotate +0+0 "D" \
      "$OUT_DIR/icon.png"
else
    echo "[generate_icons] Neither swift (macOS) nor imagemagick found — skipping."
    exit 0
fi

cat > "$OUT_DIR/Contents.json" <<'JSON'
{
  "images" : [
    {
      "filename" : "icon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

echo "[generate_icons] wrote $OUT_DIR/icon.png"
