"""Generates the Shrinkly launcher icons into tool/icons/ (run once locally; output is committed)."""
import os
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "icons")
os.makedirs(OUT, exist_ok=True)

AMBER = (11, 122, 107)   # deep teal
ORANGE = (15, 157, 138)
DEEP = (22, 190, 160)    # bright teal


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
    # play triangle (the video)
    d.polygon([P(0.38, 0.30), P(0.38, 0.70), P(0.66, 0.50)], fill=w)
    # two arrows squeezing in from the sides (the compression)
    d.polygon([P(0.04, 0.50), P(0.20, 0.34), P(0.20, 0.44), P(0.30, 0.44), P(0.30, 0.56), P(0.20, 0.56), P(0.20, 0.66)], fill=w)
    d.polygon([P(0.96, 0.50), P(0.80, 0.34), P(0.80, 0.44), P(0.70, 0.44), P(0.70, 0.56), P(0.80, 0.56), P(0.80, 0.66)], fill=w)
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
