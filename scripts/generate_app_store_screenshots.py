from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont


OUT_DIR = Path("screenshots")
OUT_DIR.mkdir(exist_ok=True)
IPHONE_CONCEPT = Path("MarketingAssets/Screenshots/super-spy-guard-imagegen-concept.png")
IPAD_CONCEPT = Path("MarketingAssets/Screenshots/super-spy-guard-ipad-imagegen-concept.png")


def fit_concept(source_path, out_path, size):
    source = Image.open(source_path).convert("RGB")
    target_w, target_h = size
    src_w, src_h = source.size

    scale = max(target_w / src_w, target_h / src_h)
    cover = source.resize((round(src_w * scale), round(src_h * scale)), Image.Resampling.LANCZOS)
    x = (cover.width - target_w) // 2
    y = (cover.height - target_h) // 2
    crop = cover.crop((x, y, x + target_w, y + target_h))

    contain_scale = min(target_w / src_w, target_h / src_h)
    contain = source.resize((round(src_w * contain_scale), round(src_h * contain_scale)), Image.Resampling.LANCZOS)
    bg = crop.filter(ImageFilter.GaussianBlur(36))
    bg = Image.blend(Image.new("RGB", size, (5, 8, 16)), bg, 0.45)
    px = (target_w - contain.width) // 2
    py = (target_h - contain.height) // 2
    bg.paste(contain, (px, py))
    bg.save(out_path, "PNG", optimize=True)


if IPHONE_CONCEPT.exists() and IPAD_CONCEPT.exists():
    fit_concept(IPHONE_CONCEPT, OUT_DIR / "iphone65.png", (1242, 2688))
    fit_concept(IPAD_CONCEPT, OUT_DIR / "ipad129.png", (2048, 2732))
    raise SystemExit(0)


def font(size, bold=False):
    candidates = [
        "C:/Windows/Fonts/arialbd.ttf" if bold else "C:/Windows/Fonts/arial.ttf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size)
        except Exception:
            pass
    return ImageFont.load_default()


def centered(draw, text, y, width, fnt, fill):
    bbox = draw.textbbox((0, 0), text, font=fnt)
    x = (width - (bbox[2] - bbox[0])) // 2
    draw.text((x, y), text, font=fnt, fill=fill)


def centered_in_box(draw, text, box, fnt, fill):
    x1, y1, x2, y2 = box
    bbox = draw.textbbox((0, 0), text, font=fnt)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    draw.text((x1 + (x2 - x1 - tw) // 2, y1 + (y2 - y1 - th) // 2), text, font=fnt, fill=fill)


def make(path, size):
    w, h = size
    base = Image.new("RGB", size, (5, 8, 16))
    d = ImageDraw.Draw(base)

    margin = int(w * 0.06)
    title_font = font(int(w * 0.070), True)
    body_font = font(int(w * 0.040))
    label_font = font(int(w * 0.034), True)
    small_font = font(int(w * 0.029))
    button_font = font(int(w * 0.045), True)

    green = (74, 255, 167)
    blue = (61, 196, 255)
    gold = (235, 190, 82)
    purple = (200, 117, 255)
    surface = (14, 25, 38)
    line = (44, 91, 105)
    muted = (154, 173, 188)
    text = (238, 247, 255)

    d.rounded_rectangle(
        (margin, margin, w - margin, h - margin),
        radius=28,
        fill=(7, 12, 22),
        outline=(30, 79, 73),
        width=2,
    )

    y = margin + int(h * 0.03)
    centered(d, "Super Spy Guard", y, w, title_font, text)
    y += int(h * 0.075)

    cx = w // 2
    radar = int(w * 0.30)
    for i in range(4):
        r = int(radar * (i + 1) / 4)
        d.ellipse(
            (cx - r, y + radar // 2 - r, cx + r, y + radar // 2 + r),
            outline=(20, 115, 91),
            width=2,
        )
    d.line((cx, y + radar // 2, cx + radar // 2, y + radar // 2 - radar // 5), fill=green, width=5)
    d.ellipse((cx - 30, y + radar // 2 - 30, cx + 30, y + radar // 2 + 30), fill=(18, 64, 52), outline=green, width=3)
    centered(d, "S", y + radar // 2 - int(w * 0.023), w, button_font, green)
    y += radar + int(h * 0.035)

    centered(d, "8-step room safety scan", y, w, body_font, muted)
    y += int(h * 0.050)

    phases = [
        ("CAM", "Camera"),
        ("MIC", "Sound"),
        ("MAG", "Magnetic"),
        ("NET", "Network"),
        ("BT", "Bluetooth"),
        ("IR", "Light"),
        ("RF", "Signal"),
        ("LOG", "Report"),
    ]
    cols = 4
    gap = int(w * 0.018)
    tile_w = (w - margin * 2 - gap * (cols - 1)) // cols
    tile_h = int(h * 0.082)
    palette = [green, blue, gold, purple]
    for idx, (code, label) in enumerate(phases):
        row = idx // cols
        col = idx % cols
        x = margin + col * (tile_w + gap)
        ty = y + row * (tile_h + gap)
        color = palette[idx % len(palette)]
        d.rounded_rectangle((x, ty, x + tile_w, ty + tile_h), radius=14, fill=surface, outline=color, width=2)
        centered_in_box(d, code, (x, ty + int(tile_h * 0.12), x + tile_w, ty + int(tile_h * 0.45)), label_font, color)
        centered_in_box(d, label, (x, ty + int(tile_h * 0.48), x + tile_w, ty + int(tile_h * 0.86)), small_font, muted)
    y += tile_h * 2 + gap + int(h * 0.045)

    card_h = int(h * 0.105)
    d.rounded_rectangle((margin, y, w - margin, y + card_h), radius=18, fill=surface, outline=line, width=2)
    d.text((margin + 28, y + 24), "Nearby device check", font=label_font, fill=text)
    d.text(
        (margin + 28, y + 24 + int(w * 0.052)),
        "Check Wi-Fi, Bluetooth, camera reflection, and sensors.",
        font=small_font,
        fill=muted,
    )
    y += card_h + int(h * 0.035)

    button_h = int(h * 0.078)
    d.rounded_rectangle((margin, y, w - margin, y + button_h), radius=18, fill=green)
    centered(d, "Start Full Scan", y + int(button_h * 0.27), w, button_font, (5, 8, 16))

    tab_y = h - margin - int(h * 0.08)
    d.line((margin, tab_y, w - margin, tab_y), fill=(24, 44, 60), width=2)
    tabs = ["Scan", "Tools", "History", "Check", "Settings"]
    slot = (w - margin * 2) // len(tabs)
    for i, tab in enumerate(tabs):
        bbox = d.textbbox((0, 0), tab, font=small_font)
        tx = margin + i * slot + (slot - (bbox[2] - bbox[0])) // 2
        d.text((tx, tab_y + int(h * 0.025)), tab, font=small_font, fill=green if i == 0 else muted)

    base.save(path, "PNG", optimize=True)


make(OUT_DIR / "iphone65.png", (1242, 2688))
make(OUT_DIR / "ipad129.png", (2048, 2732))
