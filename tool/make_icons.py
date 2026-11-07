"""Generates the Shrinkly launcher icons into tool/icons/ (run once locally; output is committed)."""
import os
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "icons")
os.makedirs(OUT, exist_ok=True)

AMBER = (79, 70, 229)    # indigo
ORANGE = (147, 51, 234)
DEEP = (217, 70, 239)    # fuchsia


def gradient(size):
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2.0 * (size - 1))
            px[x, y] = tuple(int(AMBER[i] + (DEEP[i] - AMBER[i]) * t) for i in range(3))
    return img


def glyph(size, scale):
    """White download arrow + tray on a transparent canvas. `scale` = fraction of canvas used."""
    ss = 4
    s = size * ss
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    u = s * scale  # glyph box edge
    ox = (s - u) / 2
    oy = (s - u) / 2

    def P(x, y):
        return (ox + x * u, oy + y * u)

    w = (255, 255, 255, 255)
    # vertical 9:16 frame with a play triangle (a short video)
    d.rounded_rectangle([*P(0.28, 0.08), *P(0.72, 0.92)], radius=u * 0.1, outline=w, width=int(u * 0.06))
    d.polygon([P(0.43, 0.36), P(0.43, 0.64), P(0.62, 0.50)], fill=w)
    return im.resize((size, size), Image.LANCZOS)


def legacy(size):
    base = gradient(size).convert("RGBA")
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size - 1, size - 1], radius=int(size * 0.22), fill=255)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(base, (0, 0), mask)
    out.alpha_composite(glyph(size, 0.60))
    return out


def foreground(size):
    # Adaptive icons: keep content inside the central 66% safe zone.
    return glyph(size, 0.48)


densities = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
for name, px in densities.items():
    d = os.path.join(OUT, f"mipmap-{name}")
    os.makedirs(d, exist_ok=True)
    legacy(px).save(os.path.join(d, "ic_launcher.png"))
    # adaptive foreground is 108dp
    fg = int(round(px * 108 / 48))
    foreground(fg).save(os.path.join(d, "ic_launcher_foreground.png"))

legacy(512).save(os.path.join(OUT, "store_icon_512.png"))
print("icons written to", OUT)
