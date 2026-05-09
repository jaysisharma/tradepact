"""
Generate TradePact logo PNG.
Renders at 4× (2048px) then downscales to 1024px for smooth anti-aliasing.
Output: assets/images/logo.png
"""

import math
import os
from PIL import Image, ImageDraw

# ── Palette ────────────────────────────────────────────────────────────────
BG        = (13,  13,  13,  255)   # #0d0d0d
SURFACE   = (26,  26,  26,  255)   # #1a1a1a
GOLD      = (201, 168,  76,  255)  # #c9a84c
GOLD_15   = (201, 168,  76,   38)  # gold 15% opacity
GOLD_45   = (201, 168,  76,  115)  # gold 45% opacity
TRANSP    = (0, 0, 0, 0)

# ── Render at 4× design space (512 * 4 = 2048) ────────────────────────────
SCALE  = 4
DS     = 512       # design-space size
SIZE   = DS * SCALE


def px(v):
    return int(round(v * SCALE))


def draw_rounded_rect(draw, x, y, w, h, r, fill=None, outline=None, outline_width=1):
    """Draw a rounded rectangle."""
    draw.rounded_rectangle([x, y, x + w, y + h], radius=r, fill=fill,
                           outline=outline, width=outline_width)


def draw_line(draw, x1, y1, x2, y2, color, width):
    draw.line([(x1, y1), (x2, y2)], fill=color, width=width)


def draw_circle(draw, cx, cy, r, fill=None, outline=None, outline_width=1):
    draw.ellipse([cx - r, cy - r, cx + r, cy + r],
                 fill=fill, outline=outline, width=outline_width)


def draw_checkmark(draw, cx, cy, r, color, width):
    """Draw a ✓ inside a circle of radius r centred at (cx, cy)."""
    # Points calibrated for a balanced check inside the circle
    # Left leg: bottom-left to mid, Right leg: mid to top-right
    scale_f = r / 31.0  # original design radius was 31 px
    # Original coords (design space, circle centred at 390,113)
    # p1=(375,113) p2=(386,125) p3=(407,96)  -> relative to centre (390,113):
    # p1=(-15, 0)  p2=(-4, 12)  p3=(17, -17)
    pts = [
        (cx + int(-15 * scale_f), cy + int(  0 * scale_f)),
        (cx + int( -4 * scale_f), cy + int( 12 * scale_f)),
        (cx + int( 17 * scale_f), cy + int(-17 * scale_f)),
    ]
    draw.line([pts[0], pts[1]], fill=color, width=width)
    draw.line([pts[1], pts[2]], fill=color, width=width)


def draw_candle(draw, cx, body_top, body_bottom, wick_top, wick_bottom, bullish):
    half_w = px(24)   # half of 48
    r      = px(5)

    # Upper wick
    draw_line(draw, px(cx), px(wick_top), px(cx), px(body_top),
              GOLD, px(6))
    # Lower wick
    draw_line(draw, px(cx), px(body_bottom), px(cx), px(wick_bottom),
              GOLD, px(6))

    bx = px(cx) - half_w
    by = px(body_top)
    bw = half_w * 2
    bh = px(body_bottom) - by

    if bullish:
        draw_rounded_rect(draw, bx, by, bw, bh, r, fill=GOLD)
    else:
        # Bearish: dark fill + gold outline
        draw_rounded_rect(draw, bx, by, bw, bh, r,
                          fill=SURFACE, outline=GOLD, outline_width=px(5))


# ── Build image ───────────────────────────────────────────────────────────
img  = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Background (rounded square, rx=96)
draw_rounded_rect(draw, 0, 0, SIZE, SIZE, px(96), fill=BG)

# Grid lines
for gy in [160, 220, 280, 340]:
    draw_line(draw, px(72), px(gy), px(440), px(gy), GOLD_15, px(2))

# Candles
# 1 — Bearish (hollow)
draw_candle(draw, 120, 272, 330, 252, 348, bullish=False)
# 2 — Bullish small
draw_candle(draw, 210, 243, 325, 218, 345, bullish=True)
# 3 — Bullish medium
draw_candle(draw, 300, 202, 317, 175, 340, bullish=True)
# 4 — Bullish tall
draw_candle(draw, 390, 158, 310, 148, 335, bullish=True)

# Pact seal on candle 4
cx, cy, r = px(390), px(113), px(31)
draw_circle(draw, cx, cy, r, fill=BG)                          # dark fill
draw_circle(draw, cx, cy, r, outline=GOLD, outline_width=px(6))  # gold ring
draw_checkmark(draw, cx, cy, r, GOLD, width=px(6))             # ✓

# Baseline
draw_line(draw, px(72), px(345), px(440), px(345), GOLD_45, px(3))

# ── Downscale 4× → 1× with LANCZOS for smooth anti-aliasing ──────────────
final = img.resize((1024, 1024), Image.LANCZOS)

out_dir = os.path.join(os.path.dirname(__file__), "..", "assets", "images")
os.makedirs(out_dir, exist_ok=True)
out_path = os.path.join(out_dir, "logo.png")
final.save(out_path, "PNG")
print(f"Saved {out_path}  ({final.width}×{final.height})")
