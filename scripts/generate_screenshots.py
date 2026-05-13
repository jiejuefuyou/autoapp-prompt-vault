"""
generate_screenshots.py — PromptVault App Store marketing screenshots
Produces 6 x 1290×2796 PNG (iPhone 6.7" format)
Output: fastlane/screenshots/en-US/0N-*.png
"""
from __future__ import annotations

import math
import os
from typing import Tuple

from PIL import Image, ImageDraw, ImageFont

# --- Constants ---
W, H = 1290, 2796
C1 = (0x7C, 0x3A, 0xED)  # violet-600
C2 = (0x1E, 0x1B, 0x4B)  # indigo-950
WHITE = (255, 255, 255)
LIGHT = (220, 210, 255)   # soft lavender for subtitles
CARD_BG = (255, 255, 255, 26)  # ~10% white overlay
ACCENT = (167, 139, 250)   # violet-400


def lerp_color(
    a: Tuple[int, int, int], b: Tuple[int, int, int], t: float
) -> Tuple[int, int, int]:
    return (
        int(a[0] * (1 - t) + b[0] * t),
        int(a[1] * (1 - t) + b[1] * t),
        int(a[2] * (1 - t) + b[2] * t),
    )


def make_gradient_bg(w: int = W, h: int = H) -> Image.Image:
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        for x in range(w):
            t = (x * 0.3 + y * 0.7) / (w * 0.3 + h * 0.7 - 2)
            px[x, y] = lerp_color(C1, C2, t)
    return img


def find_font(size: int, mono: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    if mono:
        candidates = [
            "C:/Windows/Fonts/consola.ttf",
            "C:/Windows/Fonts/cour.ttf",
            "C:/Windows/Fonts/lucon.ttf",
        ]
    else:
        candidates = [
            "C:/Windows/Fonts/segoeui.ttf",
            "C:/Windows/Fonts/arial.ttf",
            "C:/Windows/Fonts/tahoma.ttf",
            "C:/Windows/Fonts/calibri.ttf",
        ]
    for c in candidates:
        if os.path.exists(c):
            try:
                return ImageFont.truetype(c, size)
            except Exception:
                pass
    # Bold fallback — try segoeui bold
    bold_candidates = [
        "C:/Windows/Fonts/segoeuib.ttf",
        "C:/Windows/Fonts/arialbd.ttf",
    ]
    if not mono:
        for c in bold_candidates:
            if os.path.exists(c):
                try:
                    return ImageFont.truetype(c, size)
                except Exception:
                    pass
    return ImageFont.load_default()


def draw_sparkle(
    img: Image.Image,
    cx: int,
    cy: int,
    outer_r: int,
    inner_r: int,
    points: int = 4,
    alpha: int = 220,
) -> None:
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    verts: list[Tuple[float, float]] = []
    for i in range(points * 2):
        angle = math.pi * i / points - math.pi / 2
        r = outer_r if i % 2 == 0 else inner_r
        verts.append((cx + r * math.cos(angle), cy + r * math.sin(angle)))
    draw.polygon(verts, fill=(255, 255, 255, alpha))
    img.paste(overlay, mask=overlay.split()[3])


def draw_centered_text(
    draw: ImageDraw.ImageDraw,
    img_w: int,
    y: int,
    text: str,
    font: ImageFont.ImageFont | ImageFont.FreeTypeFont,
    color: Tuple[int, int, int] = WHITE,
    shadow: bool = False,
) -> int:
    """Draw horizontally-centered text; return bottom y."""
    bb = draw.textbbox((0, 0), text, font=font)
    tw = bb[2] - bb[0]
    th = bb[3] - bb[1]
    x = (img_w - tw) // 2 - bb[0]
    if shadow:
        draw.text((x + 3, y + 4), text, fill=(0, 0, 0, 80), font=font)
    draw.text((x, y), text, fill=color, font=font)
    return y + th


def rounded_rect(
    draw: ImageDraw.ImageDraw,
    xy: Tuple[int, int, int, int],
    radius: int,
    fill: Tuple[int, int, int, int],
) -> None:
    draw.rounded_rectangle(xy, radius=radius, fill=fill)


def add_status_bar(img: Image.Image) -> None:
    """Minimal fake status bar (time top-left, signal icons top-right)."""
    draw = ImageDraw.Draw(img)
    f = find_font(38)
    draw.text((80, 68), "9:41", font=f, fill=WHITE)
    # battery rect
    bx, by = W - 170, 72
    draw.rounded_rectangle((bx, by, bx + 72, by + 32), radius=6, outline=WHITE, width=3)
    draw.rounded_rectangle((bx + 75, by + 9, bx + 82, by + 23), radius=3, fill=WHITE)
    draw.rounded_rectangle((bx + 4, by + 4, bx + 60, by + 28), radius=4, fill=WHITE)
    # signal dots
    for i in range(4):
        r = 7 + i * 3
        cx = W - 270 + i * 22
        cy = by + 16
        draw.ellipse((cx - r // 2, cy - r // 2, cx + r // 2, cy + r // 2), fill=WHITE)


def make_card(
    img: Image.Image,
    x: int,
    y: int,
    w: int,
    h: int,
    lines: list[Tuple[str, int, Tuple[int, int, int]]],
    radius: int = 36,
) -> None:
    """Draw a frosted card with text lines; each line = (text, font_size, color)."""
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw_o = ImageDraw.Draw(overlay)
    draw_o.rounded_rectangle((x, y, x + w, y + h), radius=radius, fill=(255, 255, 255, 38))
    img.paste(overlay, mask=overlay.split()[3])

    draw = ImageDraw.Draw(img)
    cur_y = y + 40
    for text, size, color in lines:
        f = find_font(size)
        bb = draw.textbbox((0, 0), text, font=f)
        tw = bb[2] - bb[0]
        tx = x + (w - tw) // 2 - bb[0]
        draw.text((tx, cur_y), text, fill=color, font=f)
        cur_y += bb[3] - bb[1] + 18
    # subtle top-left accent dot
    draw.ellipse((x + 24, y + 24, x + 38, y + 38), fill=ACCENT)


# ---------------------------------------------------------------------------
# Individual screenshot generators
# ---------------------------------------------------------------------------

def make_hero() -> Image.Image:
    """01-hero: Brand mark + tagline + key CTAs."""
    img = make_gradient_bg()
    draw = ImageDraw.Draw(img)

    add_status_bar(img)

    # Large {{ }} mark
    mono_font = find_font(220, mono=True)
    draw_centered_text(draw, W, 300, "{{ }}", mono_font, WHITE, shadow=True)

    # Sparkles
    draw_sparkle(img, W - 160, 260, 55, 18, points=4, alpha=240)
    draw_sparkle(img, 160, 1150, 30, 10, points=4, alpha=160)
    draw_sparkle(img, W - 80, 1400, 22, 7, points=4, alpha=140)

    # App name
    title_font = find_font(120)
    draw_centered_text(draw, W, 700, "PromptVault", title_font, WHITE, shadow=True)

    # Tagline
    tag_font = find_font(64)
    draw_centered_text(draw, W, 860, "Your AI Tools Shelf", tag_font, LIGHT)

    # Divider
    draw.line(((W // 2 - 120, 980), (W // 2 + 120, 980)), fill=ACCENT, width=4)

    # Feature pills
    pill_font = find_font(52)
    pills = ["200+ Pro Prompts", "Variable System", "One-Tap Copy"]
    pill_y = 1030
    for pill in pills:
        bb = draw.textbbox((0, 0), pill, font=pill_font)
        pw = bb[2] - bb[0] + 80
        ph = 80
        px = (W - pw) // 2
        draw.rounded_rectangle((px, pill_y, px + pw, pill_y + ph), radius=40, fill=(*ACCENT, 180))
        draw.text((px + 40 - bb[0], pill_y + (ph - (bb[3] - bb[1])) // 2 - bb[1]), pill, font=pill_font, fill=WHITE)
        pill_y += 110

    # Bottom badge
    badge_font = find_font(48)
    make_card(img, W // 2 - 320, H - 480, 640, 160,
              [("Premium  ·  $4.99  ·  One-Time", 48, LIGHT)], radius=32)

    return img


def make_prompts() -> Image.Image:
    """02-prompts: 200+ Pro Prompts showcase."""
    img = make_gradient_bg()
    draw = ImageDraw.Draw(img)
    add_status_bar(img)

    title_font = find_font(100)
    draw_centered_text(draw, W, 200, "200+ Pro Prompts", title_font, WHITE, shadow=True)

    sub_font = find_font(58)
    draw_centered_text(draw, W, 340, "Curated for AI workflows", sub_font, LIGHT)

    draw.line(((W // 2 - 100, 440), (W // 2 + 100, 440)), fill=ACCENT, width=4)

    categories = [
        ("Writing & Editing", "✍️  47 prompts"),
        ("Code & Dev", "💻  38 prompts"),
        ("Analysis", "🔍  31 prompts"),
        ("Marketing", "📢  29 prompts"),
        ("Research", "📚  26 prompts"),
        ("Creative", "🎨  23 prompts"),
    ]
    card_y = 500
    card_h = 160
    pad = 40
    card_w = W - pad * 2
    label_f = find_font(58)
    count_f = find_font(50)
    for cat, cnt in categories:
        make_card(img, pad, card_y, card_w, card_h,
                  [(cat, 58, WHITE), (cnt, 46, LIGHT)], radius=28)
        card_y += card_h + 28

    draw_sparkle(img, W - 80, H - 300, 40, 14, points=4, alpha=200)
    tag_f = find_font(60)
    draw_centered_text(draw, W, H - 240, "Tap → Copy → Paste  ·  Zero friction", tag_f, LIGHT)

    return img


def make_variables() -> Image.Image:
    """03-variables: Variable system demo."""
    img = make_gradient_bg()
    draw = ImageDraw.Draw(img)
    add_status_bar(img)

    title_font = find_font(96)
    draw_centered_text(draw, W, 200, "Variable System", title_font, WHITE, shadow=True)

    sub_font = find_font(56)
    draw_centered_text(draw, W, 340, "Dynamic prompts that adapt to you", sub_font, LIGHT)

    draw.line(((W // 2 - 120, 440), (W // 2 + 120, 440)), fill=ACCENT, width=4)

    # Show a prompt card with variable highlighting
    card_x, card_y = 60, 520
    card_w, card_h = W - 120, 320
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw_o = ImageDraw.Draw(overlay)
    draw_o.rounded_rectangle((card_x, card_y, card_x + card_w, card_y + card_h),
                               radius=36, fill=(255, 255, 255, 45))
    img.paste(overlay, mask=overlay.split()[3])
    draw = ImageDraw.Draw(img)

    mono_f = find_font(52, mono=True)
    label_f = find_font(44)
    draw.text((card_x + 48, card_y + 40), "Translate {{text}} to {{lang:string=Japanese}}",
              font=mono_f, fill=WHITE)
    draw.text((card_x + 48, card_y + 120), "for {{audience:string=developers}} audience",
              font=mono_f, fill=WHITE)
    draw.text((card_x + 48, card_y + 200), "in {{tone:string=professional}} tone.",
              font=mono_f, fill=WHITE)

    # Variable badges
    var_examples = [
        ("{{text}}", "string", "required"),
        ("{{lang}}", "string", "default: Japanese"),
        ("{{audience}}", "string", "default: developers"),
        ("{{tone}}", "string", "default: professional"),
        ("{{count}}", "int", "default: 5"),
    ]
    badge_y = 900
    badge_f = find_font(48)
    type_f = find_font(40)
    for var, typ, hint in var_examples:
        # var pill
        vb = draw.textbbox((0, 0), var, font=badge_f)
        vw = vb[2] - vb[0] + 60
        draw.rounded_rectangle((80, badge_y, 80 + vw, badge_y + 72), radius=36,
                                fill=(*ACCENT, 200))
        draw.text((80 + 30, badge_y + 12), var, font=badge_f, fill=WHITE)
        # type
        draw.text((80 + vw + 30, badge_y + 14), typ, font=type_f, fill=LIGHT)
        # hint
        draw.text((80 + vw + 180, badge_y + 14), hint, font=type_f, fill=(180, 170, 210))
        badge_y += 100

    tag_f = find_font(58)
    draw_sparkle(img, W - 100, H - 350, 44, 15, points=4, alpha=200)
    draw_centered_text(draw, W, H - 240, "string  ·  int  ·  multiline  types", tag_f, LIGHT)

    return img


def make_copy() -> Image.Image:
    """04-copy: One-Tap Copy feature."""
    img = make_gradient_bg()
    draw = ImageDraw.Draw(img)
    add_status_bar(img)

    title_font = find_font(100)
    draw_centered_text(draw, W, 200, "One-Tap Copy", title_font, WHITE, shadow=True)

    sub_font = find_font(56)
    draw_centered_text(draw, W, 340, "Copy any prompt in under a second", sub_font, LIGHT)

    draw.line(((W // 2 - 100, 440), (W // 2 + 100, 440)), fill=ACCENT, width=4)

    # Workflow steps
    steps = [
        ("1", "Find your prompt", "Search or browse by tag"),
        ("2", "Tap once", "Instantly copied to clipboard"),
        ("3", "Paste anywhere", "ChatGPT  ·  Claude  ·  Gemini"),
        ("4", "Track usage", "See your most-used prompts"),
    ]
    step_y = 520
    step_f = find_font(58)
    num_f = find_font(72)
    sub_f = find_font(46)
    for num, title, sub in steps:
        # Circle
        draw.ellipse((80, step_y, 80 + 90, step_y + 90), fill=(*ACCENT, 180))
        nb = draw.textbbox((0, 0), num, font=num_f)
        draw.text((80 + (90 - (nb[2] - nb[0])) // 2 - nb[0],
                   step_y + (90 - (nb[3] - nb[1])) // 2 - nb[1]),
                  num, font=num_f, fill=WHITE)
        draw.text((200, step_y + 4), title, font=step_f, fill=WHITE)
        draw.text((200, step_y + 68), sub, font=sub_f, fill=LIGHT)
        step_y += 160

    draw_sparkle(img, W - 100, H - 400, 46, 16, points=4, alpha=210)
    tag_f = find_font(62)
    draw_centered_text(draw, W, H - 260, "Workflow velocity  ×10", tag_f, LIGHT)

    return img


def make_tags() -> Image.Image:
    """05-tags: Tag Organization."""
    img = make_gradient_bg()
    draw = ImageDraw.Draw(img)
    add_status_bar(img)

    title_font = find_font(100)
    draw_centered_text(draw, W, 200, "Tag Organization", title_font, WHITE, shadow=True)

    sub_font = find_font(56)
    draw_centered_text(draw, W, 340, "Find any prompt instantly", sub_font, LIGHT)

    draw.line(((W // 2 - 100, 440), (W // 2 + 100, 440)), fill=ACCENT, width=4)

    # Tag cloud
    tags = [
        "writing", "code", "analysis", "marketing",
        "research", "creative", "productivity", "translation",
        "debugging", "summarize", "SEO", "email",
        "social", "pitch", "review",
    ]
    import random
    random.seed(42)
    tag_f = find_font(54)
    cur_x, cur_y = 60, 520
    max_x = W - 60
    row_h = 90
    for tag in tags:
        bb = draw.textbbox((0, 0), tag, font=tag_f)
        tw = bb[2] - bb[0] + 60
        if cur_x + tw > max_x:
            cur_x = 60
            cur_y += row_h + 20
        shade = random.randint(140, 200)
        pill_color = (shade, shade // 2, 255, 180)
        overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
        d2 = ImageDraw.Draw(overlay)
        d2.rounded_rectangle((cur_x, cur_y, cur_x + tw, cur_y + row_h - 10),
                              radius=38, fill=pill_color)
        img.paste(overlay, mask=overlay.split()[3])
        draw = ImageDraw.Draw(img)
        draw.text((cur_x + 30 - bb[0], cur_y + (row_h - 10 - (bb[3] - bb[1])) // 2 - bb[1]),
                  tag, font=tag_f, fill=WHITE)
        cur_x += tw + 20

    draw_sparkle(img, 100, H - 400, 44, 15, points=4, alpha=200)
    f60 = find_font(60)
    draw_centered_text(draw, W, H - 260, "Unlimited tags with Premium", f60, LIGHT)

    return img


def make_scan() -> Image.Image:
    """06-scan: QR Scan Import."""
    img = make_gradient_bg()
    draw = ImageDraw.Draw(img)
    add_status_bar(img)

    title_font = find_font(100)
    draw_centered_text(draw, W, 200, "QR Scan Import", title_font, WHITE, shadow=True)

    sub_font = find_font(56)
    draw_centered_text(draw, W, 340, "Share prompts between devices instantly", sub_font, LIGHT)

    draw.line(((W // 2 - 120, 440), (W // 2 + 120, 440)), fill=ACCENT, width=4)

    # QR code mock
    qr_size = 500
    qr_x = (W - qr_size) // 2
    qr_y = 550
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d2 = ImageDraw.Draw(overlay)
    d2.rounded_rectangle((qr_x - 20, qr_y - 20, qr_x + qr_size + 20, qr_y + qr_size + 20),
                          radius=32, fill=(255, 255, 255, 240))
    img.paste(overlay, mask=overlay.split()[3])
    draw = ImageDraw.Draw(img)
    # Pixel grid for QR mock
    cell = qr_size // 10
    import random
    random.seed(77)
    for row in range(10):
        for col in range(10):
            # Finder patterns at corners
            if (row < 2 and col < 2) or (row < 2 and col > 7) or (row > 7 and col < 2):
                color = (30, 20, 80)
            elif random.random() > 0.55:
                color = (30, 20, 80)
            else:
                color = (245, 240, 255)
            rx = qr_x + col * cell + 4
            ry = qr_y + row * cell + 4
            draw.rectangle((rx, ry, rx + cell - 6, ry + cell - 6), fill=color)

    # Caption
    cap_f = find_font(56)
    draw_centered_text(draw, W, qr_y + qr_size + 60, "Scan to import a shared prompt", cap_f, LIGHT)

    # Features list
    feats = ["Works offline", "No account needed", "Instant import"]
    feat_y = qr_y + qr_size + 180
    feat_f = find_font(56)
    for feat in feats:
        fb = draw.textbbox((0, 0), feat, font=feat_f)
        fw = fb[2] - fb[0] + 80
        fx = (W - fw) // 2
        draw.rounded_rectangle((fx, feat_y, fx + fw, feat_y + 76), radius=38,
                                fill=(*ACCENT, 150))
        draw.text((fx + 40 - fb[0], feat_y + (76 - (fb[3] - fb[1])) // 2 - fb[1]),
                  feat, font=feat_f, fill=WHITE)
        feat_y += 110

    draw_sparkle(img, W - 100, H - 380, 44, 15, points=4, alpha=210)
    f58 = find_font(58)
    draw_centered_text(draw, W, H - 240, "Share your AI toolkit with the world", f58, LIGHT)

    return img


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    base_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.dirname(base_dir)
    out_dir = os.path.join(repo_root, "fastlane", "screenshots", "en-US")
    os.makedirs(out_dir, exist_ok=True)

    screenshots = [
        ("01-hero.png", make_hero),
        ("02-prompts.png", make_prompts),
        ("03-variables.png", make_variables),
        ("04-copy.png", make_copy),
        ("05-tags.png", make_tags),
        ("06-scan.png", make_scan),
    ]

    for filename, fn in screenshots:
        print(f"Generating {filename}…")
        img = fn()
        path = os.path.join(out_dir, filename)
        img.save(path, "PNG")
        size_kb = os.path.getsize(path) // 1024
        print(f"  Saved: {path}  ({img.size[0]}x{img.size[1]}, {size_kb} KB)")

    print(f"\nAll {len(screenshots)} screenshots saved to {out_dir}")


if __name__ == "__main__":
    main()
