#!/bin/bash
# Renders 1024x1024 app-icon variants: a pickleball (ball + hex-packed holes)
# over a diagonal gradient background, drawn as SVG and rasterized with
# headless Chrome. Hole positions match the original icon's layout.
set -euo pipefail

SCRATCH="$(cd "$(dirname "$0")" && pwd)"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
OUT="$SCRATCH/icons"
mkdir -p "$OUT"

# emit_icon <slug> <bg-top> <bg-bottom> <ball-light> <ball-dark> <hole-fill> <hole-rim>
emit_icon() {
  local slug="$1" bgtop="$2" bgbot="$3" ball1="$4" ball2="$5" hole="$6" rim="$7"

  # Hole layout, real-ball style: a hex-packed grid of big holes clipped at
  # the ball's edge (partial holes at the rim read as a photographed ball).
  # Grid is rotated ~9deg so no row sits perfectly horizontal.
  local holes
  holes="$(python3 <<'PY'
import math
s = 240          # grid pitch (wider = fewer holes)
r = 64           # hole radius
ox, oy = 74, -52 # shift the whole pattern off the ball center
rows = []
for j in range(-3, 4):
    y = 512 + oy + j * s * math.sin(math.radians(60))
    for i in range(-3, 4):
        x = 512 + ox + (i + (abs(j) % 2) * 0.5) * s
        d = math.hypot(x - 512, y - 512)
        if d < 340 + r - 12:  # skip holes entirely outside the ball
            rows.append((x, y))
print(f"<g clip-path='url(#ballclip)' transform='rotate(9 512 512)'>")
for x, y in rows:
    print(f"<circle cx='{x:.1f}' cy='{y:.1f}' r='{r}' class='h'/>")
print("</g>")
PY
)"

  cat > "$OUT/$slug.html" <<HTML
<!doctype html><meta charset="utf-8">
<style>*{margin:0}html,body{width:1024px;height:1024px;overflow:hidden}</style>
<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="$bgtop"/><stop offset="1" stop-color="$bgbot"/>
    </linearGradient>
    <linearGradient id="ball" x1="0.25" y1="0" x2="0.75" y2="1">
      <stop offset="0" stop-color="$ball1"/><stop offset="1" stop-color="$ball2"/>
    </linearGradient>
    <filter id="drop" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="14" stdDeviation="26" flood-color="#000" flood-opacity="0.28"/>
    </filter>
    <clipPath id="ballclip"><circle cx="512" cy="512" r="336"/></clipPath>
  </defs>
  <style>.h{fill:$hole;stroke:$rim;stroke-width:5}</style>
  <rect width="1024" height="1024" fill="url(#bg)"/>
  <circle cx="512" cy="512" r="340" fill="url(#ball)" filter="url(#drop)"/>
  $holes
</svg>
HTML

  "$CHROME" --headless=new --screenshot="$OUT/$slug.png" \
    --window-size=1024,1024 --force-device-scale-factor=1 \
    --hide-scrollbars --disable-gpu "file://$OUT/$slug.html" 2>/dev/null
  echo "rendered $slug"
}

# Variants, all from Support/Theme.swift's palette
emit_icon "blue-court"   "#2E5A86" "#1E2D49" "#F9E76B" "#F4D62E" "#28507A" "#C9AD1E"
emit_icon "lime-midnight" "#243656" "#141F35" "#DCEC72" "#CFE24A" "#1B2A47" "#9FB332"
emit_icon "terracotta-ivory" "#F3ECDA" "#E2D6BC" "#E07C53" "#C8442B" "#EDE4CE" "#A83A24"
emit_icon "tomato-sunshine" "#F4D62E" "#E29A33" "#D14A2E" "#B03A20" "#EFC72C" "#8F2F1A"
