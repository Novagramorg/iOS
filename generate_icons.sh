#!/bin/bash
INPUT="/Users/azimjon/.gemini/antigravity/brain/45ab97d8-9fc0-4dc8-ab3a-18c5ed949620/media__1772525440210.jpg"
OUTDIR="Telegram/Telegram-iOS/ProMessager.xcassets/AppIcon.appiconset"

# Resize images using sips and enforce PNG format
sips -s format png -z 40 40 "$INPUT" --out "$OUTDIR/Icon-20@2x.png" > /dev/null
sips -s format png -z 60 60 "$INPUT" --out "$OUTDIR/Icon-20@3x.png" > /dev/null
sips -s format png -z 58 58 "$INPUT" --out "$OUTDIR/Icon-29@2x.png" > /dev/null
sips -s format png -z 87 87 "$INPUT" --out "$OUTDIR/Icon-29@3x.png" > /dev/null
sips -s format png -z 80 80 "$INPUT" --out "$OUTDIR/Icon-40@2x.png" > /dev/null
sips -s format png -z 120 120 "$INPUT" --out "$OUTDIR/Icon-40@3x.png" > /dev/null
sips -s format png -z 120 120 "$INPUT" --out "$OUTDIR/Icon-60@2x.png" > /dev/null
sips -s format png -z 180 180 "$INPUT" --out "$OUTDIR/Icon-60@3x.png" > /dev/null
sips -s format png -z 152 152 "$INPUT" --out "$OUTDIR/Icon-76@2x.png" > /dev/null
sips -s format png -z 167 167 "$INPUT" --out "$OUTDIR/Icon-83.5@2x.png" > /dev/null
sips -s format png -z 1024 1024 "$INPUT" --out "$OUTDIR/Icon-1024.png" > /dev/null

echo "Done"
