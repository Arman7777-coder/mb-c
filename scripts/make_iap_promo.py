#!/usr/bin/env python3
"""
Generate the App Store IAP promotional image for the Survey Rewards
Premium subscription.

Output: appstore_screenshots/iap_promo_premium_1024.png
Format: 1024x1024 PNG, no alpha (App Store requirement).
"""
from __future__ import annotations
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from pathlib import Path
import math
import os

OUT = Path(__file__).resolve().parent.parent / "appstore_screenshots" / "iap_promo_premium_1024.png"
SIZE = 1024

# Brand palette (from lib/theme/app_theme.dart)
PURPLE_TOP    = (108,  99, 255)   # #6C63FF
PURPLE_BOTTOM = ( 47,  40, 130)   # deeper indigo for depth
GOLD          = (255, 199,  64)   # warm gold
GOLD_DEEP     = (227, 152,  32)
GOLD_BRIGHT   = (255, 224, 120)
WHITE         = (255, 255, 255)
SOFT_WHITE    = (245, 240, 255)

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

def make_background(size: int) -> Image.Image:
    img = Image.new("RGB", (size, size), PURPLE_TOP)
    px  = img.load()
    # Vertical gradient with a slight diagonal for depth.
    for y in range(size):
        t = y / (size - 1)
        # Ease-in-out curve so the bottom is richer.
        t = t * t * (3 - 2 * t)
        row = lerp(PURPLE_TOP, PURPLE_BOTTOM, t)
        for x in range(size):
            px[x, y] = row
    return img

def add_radial_glow(img: Image.Image, cx: int, cy: int, radius: int, color, strength: float) -> None:
    """Soft radial halo behind the badge."""
    overlay = Image.new("RGB", img.size, (0, 0, 0))
    mask    = Image.new("L",   img.size, 0)
    draw    = ImageDraw.Draw(mask)
    # Concentric circles, fading out.
    steps = 40
    for i in range(steps, 0, -1):
        r = int(radius * (i / steps))
        a = int(255 * strength * (1 - i / steps) ** 1.6)
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=a)
    overlay_color = Image.new("RGB", img.size, color)
    img.paste(overlay_color, (0, 0), mask.filter(ImageFilter.GaussianBlur(40)))

def draw_crown(draw: ImageDraw.ImageDraw, cx: int, cy: int, width: int) -> None:
    """Five-spike crown, drawn as separate band + spike + tip layers
    so the gold sheen on each spike can't bleed across the valleys."""
    w = width
    # Five spikes: outer-tall, middle-mid, center-tall (matches a classic
    # heraldic crown silhouette).
    spike_w     = int(w * 0.18)
    spike_gap_x = [
        int(cx - w * 0.40),  # left tall
        int(cx - w * 0.20),  # left mid
        int(cx),             # center tall
        int(cx + w * 0.20),  # right mid
        int(cx + w * 0.40),  # right tall
    ]
    spike_h = [int(w * 0.55), int(w * 0.38), int(w * 0.60), int(w * 0.38), int(w * 0.55)]

    band_w      = int(w * 0.88)
    band_h      = int(w * 0.26)
    band_left   = cx - band_w // 2
    band_right  = cx + band_w // 2
    band_top    = cy - band_h // 4
    band_bottom = band_top + band_h

    # Drop shadow under the whole crown.
    shadow_off = 10
    shadow_pad = 14
    draw.rounded_rectangle(
        (band_left - shadow_pad + shadow_off,
         band_top - shadow_pad + shadow_off,
         band_right + shadow_pad + shadow_off,
         band_bottom + shadow_pad + shadow_off),
        radius=18,
        fill=(15, 8, 50),
    )

    # Spikes (drawn BEFORE the band so the band hides their bases).
    for x, sh in zip(spike_gap_x, spike_h):
        spike_top = (x, band_top - sh)
        spike_bl  = (x - spike_w // 2, band_top + 8)
        spike_br  = (x + spike_w // 2, band_top + 8)
        # Spike fill (gold).
        draw.polygon([spike_bl, spike_top, spike_br], fill=GOLD)
        # Left-side highlight on each spike.
        mid = (x, band_top - sh + sh // 4)
        draw.polygon([spike_bl, spike_top, mid], fill=GOLD_BRIGHT)
        # Tip ball.
        tr = int(w * 0.035)
        draw.ellipse(
            (spike_top[0] - tr, spike_top[1] - tr * 2,
             spike_top[0] + tr, spike_top[1]),
            fill=GOLD_BRIGHT, outline=GOLD_DEEP,
        )

    # Band (rounded gold bar).
    draw.rounded_rectangle(
        (band_left, band_top, band_right, band_bottom),
        radius=16,
        fill=GOLD,
        outline=GOLD_DEEP,
        width=4,
    )
    # Upper rim highlight.
    draw.rounded_rectangle(
        (band_left + 6, band_top + 6, band_right - 6, band_top + band_h // 4),
        radius=10,
        fill=GOLD_BRIGHT,
    )

    # Three gems centered on the band.
    gem_y      = (band_top + band_bottom) // 2
    gem_r      = int(band_h * 0.30)
    gem_xs     = [int(cx - band_w * 0.28), cx, int(cx + band_w * 0.28)]
    gem_colors = [(230, 70, 110), (255, 255, 255), (80, 175, 255)]
    for gx, gc in zip(gem_xs, gem_colors):
        # Outer dark setting.
        draw.ellipse(
            (gx - gem_r - 4, gem_y - gem_r - 4, gx + gem_r + 4, gem_y + gem_r + 4),
            fill=GOLD_DEEP,
        )
        draw.ellipse(
            (gx - gem_r, gem_y - gem_r, gx + gem_r, gem_y + gem_r),
            fill=gc,
        )
        # Specular highlight.
        hr = int(gem_r * 0.45)
        draw.ellipse(
            (gx - gem_r + hr // 3, gem_y - gem_r + hr // 3,
             gx - gem_r + hr // 3 + hr, gem_y - gem_r + hr // 3 + hr),
            fill=WHITE,
        )

def draw_sparkles(draw: ImageDraw.ImageDraw, size: int) -> None:
    """Scattered 4-point stars + tiny dots, mostly in the upper hemisphere."""
    positions = [
        # (x, y, radius, brightness 0..1)
        (160, 200, 14, 0.95),
        (860, 240, 18, 1.00),
        (240, 700, 10, 0.70),
        (820, 720, 12, 0.85),
        (130, 420, 8,  0.80),
        (900, 480, 9,  0.85),
        (380, 130, 6,  0.65),
        (660, 110, 7,  0.70),
    ]
    for (x, y, r, b) in positions:
        col = tuple(int(c * b) for c in SOFT_WHITE)
        # 4-point star: two crossed diamonds.
        diamond_v = [(x, y - r), (x + r // 3, y), (x, y + r), (x - r // 3, y)]
        diamond_h = [(x - r, y), (x, y - r // 3), (x + r, y), (x, y + r // 3)]
        draw.polygon(diamond_v, fill=col)
        draw.polygon(diamond_h, fill=col)

    # Small fill-dots.
    dots = [(70, 90), (980, 160), (60, 600), (970, 600), (200, 940), (820, 940)]
    for (x, y) in dots:
        draw.ellipse((x - 4, y - 4, x + 4, y + 4), fill=SOFT_WHITE)

def pick_font(candidates, size):
    """First system font that loads at `size`; falls back to PIL default."""
    for name in candidates:
        try:
            return ImageFont.truetype(name, size)
        except (OSError, IOError):
            continue
    return ImageFont.load_default()

def draw_centered_text(draw, text, y, font, fill, shadow=None):
    bbox = draw.textbbox((0, 0), text, font=font)
    w = bbox[2] - bbox[0]
    h = bbox[3] - bbox[1]
    x = (SIZE - w) // 2 - bbox[0]
    if shadow:
        sx, sy, scol = shadow
        draw.text((x + sx, y + sy), text, font=font, fill=scol)
    draw.text((x, y), text, font=font, fill=fill)
    return h

def main() -> None:
    img  = make_background(SIZE)

    # Halo behind where the crown will sit.
    add_radial_glow(img, cx=SIZE // 2, cy=int(SIZE * 0.38), radius=420,
                    color=(160, 140, 255), strength=0.45)

    draw = ImageDraw.Draw(img)
    draw_sparkles(draw, SIZE)
    draw_crown(draw, cx=SIZE // 2, cy=int(SIZE * 0.36), width=460)

    # Typography. Prefer a heavy display font; fall back gracefully.
    bold_fonts = [
        "/System/Library/Fonts/SFCompactDisplay-Black.otf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/Library/Fonts/Arial Bold.ttf",
        "Helvetica-Bold",
    ]
    regular_fonts = [
        "/System/Library/Fonts/SFCompactDisplay-Medium.otf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/Library/Fonts/Arial.ttf",
        "Helvetica",
    ]

    title_font = pick_font(bold_fonts, 168)
    sub_font   = pick_font(regular_fonts, 56)
    tag_font   = pick_font(regular_fonts, 40)

    title_y = int(SIZE * 0.66)
    h1 = draw_centered_text(
        draw, "PREMIUM", title_y, title_font, fill=WHITE,
        shadow=(0, 6, (10, 6, 50)),
    )
    # Subtitle below the wordmark.
    draw_centered_text(
        draw, "Unlock More Surveys",
        title_y + h1 + 50, sub_font, fill=SOFT_WHITE,
    )
    draw_centered_text(
        draw, "Earn More Rewards",
        title_y + h1 + 50 + 70, tag_font, fill=(220, 215, 255),
    )

    OUT.parent.mkdir(parents=True, exist_ok=True)
    # PNG without alpha — App Store rejects transparent or rounded promos.
    img.save(OUT, "PNG", optimize=True)
    print(f"wrote {OUT}  ({os.path.getsize(OUT)} bytes)")

if __name__ == "__main__":
    main()
