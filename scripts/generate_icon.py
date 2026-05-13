"""
generate_icon.py — PromptVault app icon generator
Produces a 1024x1024 icon with:
  - Diagonal gradient #7C3AED (violet-600) → #1E1B4B (indigo-950)
  - Centered monospace {{ }} glyph in white (~50% of canvas)
  - 4-point sparkle star top-right (15% size)
Output: PromptVault/Resources/Assets.xcassets/AppIcon.appiconset/icon.png
"""
from __future__ import annotations

import math
import os
import sys
from typing import Tuple

from PIL import Image, ImageDraw, ImageFont


def hex_to_rgb(hex_color: str) -> Tuple[int, int, int]:
    h = hex_color.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def lerp_color(
    c1: Tuple[int, int, int], c2: Tuple[int, int, int], t: float
) -> Tuple[int, int, int]:
    return (
        int(c1[0] * (1 - t) + c2[0] * t),
        int(c1[1] * (1 - t) + c2[1] * t),
        int(c1[2] * (1 - t) + c2[2] * t),
    )


def draw_sparkle(
    img: Image.Image,
    cx: int,
    cy: int,
    outer_r: int,
    inner_r: int,
    points: int = 4,
    color: Tuple[int, int, int] = (255, 255, 255),
    alpha: int = 230,
) -> None:
    """Draw a multi-point star (sparkle) using polygon on RGBA canvas then paste."""
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    vertices: list[Tuple[float, float]] = []
    for i in range(points * 2):
        angle = math.pi * i / points - math.pi / 2
        r = outer_r if i % 2 == 0 else inner_r
        x = cx + r * math.cos(angle)
        y = cy + r * math.sin(angle)
        vertices.append((x, y))
    draw.polygon(vertices, fill=(*color, alpha))
    img.paste(overlay, mask=overlay.split()[3])


def generate_icon(size: int = 1024) -> Image.Image:
    # --- Background: diagonal gradient ---
    c1 = hex_to_rgb("7C3AED")  # violet-600
    c2 = hex_to_rgb("1E1B4B")  # indigo-950
    img = Image.new("RGB", (size, size))
    pixels = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * size - 2)  # 0..1 diagonal
            pixels[x, y] = lerp_color(c1, c2, t)

    draw = ImageDraw.Draw(img)

    # --- Central {{ }} text ---
    text = "{{ }}"
    target_width = int(size * 0.54)

    # Try to find a reasonable monospace font; fall back gracefully
    font_candidates = [
        "C:/Windows/Fonts/cour.ttf",       # Courier New (Windows)
        "C:/Windows/Fonts/consola.ttf",    # Consolas (Windows)
        "C:/Windows/Fonts/lucon.ttf",      # Lucida Console (Windows)
        "/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf",
        "/usr/share/fonts/TTF/DejaVuSansMono.ttf",
    ]

    font: ImageFont.ImageFont | ImageFont.FreeTypeFont = ImageFont.load_default()
    for candidate in font_candidates:
        if os.path.exists(candidate):
            # Binary-search for font size that fills ~54% of canvas width
            lo, hi = 10, 600
            while lo < hi - 1:
                mid = (lo + hi) // 2
                try:
                    f = ImageFont.truetype(candidate, mid)
                    bb = draw.textbbox((0, 0), text, font=f)
                    w = bb[2] - bb[0]
                    if w < target_width:
                        lo = mid
                    else:
                        hi = mid
                except Exception:
                    break
            try:
                font = ImageFont.truetype(candidate, lo)
            except Exception:
                pass
            break

    bb = draw.textbbox((0, 0), text, font=font)
    tw, th = bb[2] - bb[0], bb[3] - bb[1]
    tx = (size - tw) // 2 - bb[0]
    ty = (size - th) // 2 - bb[1]
    # Soft shadow for depth
    draw.text((tx + 4, ty + 6), text, fill=(0, 0, 0, 80), font=font)
    draw.text((tx, ty), text, fill=(255, 255, 255), font=font)

    # --- Sparkle top-right ---
    spark_outer = int(size * 0.065)
    spark_inner = int(size * 0.022)
    spark_margin = int(size * 0.09)
    scx = size - spark_margin
    scy = spark_margin
    draw_sparkle(img, scx, scy, spark_outer, spark_inner, points=4, alpha=235)
    # Smaller secondary sparkle slightly inside
    draw_sparkle(
        img,
        scx - int(size * 0.04),
        scy + int(size * 0.04),
        int(spark_outer * 0.45),
        int(spark_inner * 0.45),
        points=4,
        alpha=160,
    )

    return img


def main() -> None:
    base_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.dirname(base_dir)
    icon_dir = os.path.join(
        repo_root,
        "PromptVault",
        "Resources",
        "Assets.xcassets",
        "AppIcon.appiconset",
    )
    os.makedirs(icon_dir, exist_ok=True)

    print("Generating 1024x1024 icon…")
    img = generate_icon(1024)
    out_path = os.path.join(icon_dir, "icon.png")
    img.save(out_path, "PNG")
    print(f"Saved: {out_path}")

    # Contents.json only references icon.png (1024x1024) — no extra sizes needed
    import hashlib
    md5 = hashlib.md5(open(out_path, "rb").read()).hexdigest()
    print(f"MD5: {md5}")

    # Verify against DaysUntil icon
    du_path = os.path.join(
        repo_root,
        "..",
        "autoapp-days-until",
        "DaysUntil",
        "Resources",
        "Assets.xcassets",
        "AppIcon.appiconset",
        "icon.png",
    )
    if os.path.exists(du_path):
        du_md5 = hashlib.md5(open(du_path, "rb").read()).hexdigest()
        if md5 == du_md5:
            print("ERROR: icons are still identical — generation failed!")
            sys.exit(1)
        else:
            print(f"OK: icons differ (DaysUntil MD5: {du_md5})")
    else:
        print("DaysUntil icon not found for comparison — skipping diff check")

    print("Done.")


if __name__ == "__main__":
    main()
