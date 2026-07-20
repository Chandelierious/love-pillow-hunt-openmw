"""Build a CUSTOM body pillow: texture (front/back art), dirt stages, NIFs.

Usage:
  python make_custom_pillow.py bangchan galbedir [front.png] [back.png]

- key: custom pillow key (records: lovepillow_<key>; donor name must be the
  SAME LENGTH as key for the NIF byte patch, e.g. galbedir/bangchan = 8).
- front/back images optional: any aspect, fitted into each half of the
  1024x1024 pillow layout (front art = left panel, back art = right panel).
  Without them, an original-art placeholder is generated (no likenesses).
- PERSONAL USE: supplied art is likely third-party IP (likeness/SKZOO) —
  the output textures/meshes are gitignored; do not publish them.

Outputs into the mod: textures/lovepillow_<key>.png + 3 stage textures,
meshes/LP/lovepillow_<key>.nif + 3 stage NIFs (filthy stage gets the green
emissive like the ESP pillows).
"""
import os
import random
import struct
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageEnhance, ImageOps, ImageFont

MOD = r"P:\Morrowind Modding CoWork\love-pillow-hunt-openmw"
DIRT = r"C:\Users\AJ\AppData\Local\Temp\claude\P--Morrowind-Modding-CoWork\a8343a8d-df3f-4487-ad26-3f55cd60568e\scratchpad\dirtsample\tx_ai_dirtpatch_01.dds"

FABRIC = (126, 126, 126)


def placeholder_panel(label, back=False):
    im = Image.new("RGB", (512, 1024), FABRIC)
    d = ImageDraw.Draw(im)
    cx = 256
    if not back:
        # front: big heart + music notes (original shapes, no likeness)
        d.polygon([(cx, 700), (96, 420), (150, 260), (256, 320),
                   (362, 260), (416, 420)], fill=(196, 84, 110))
        for nx, ny in ((150, 150), (330, 120), (240, 200)):
            d.ellipse((nx - 18, ny + 30, nx + 18, ny + 62), fill=(60, 60, 70))
            d.rectangle((nx + 12, ny - 40, nx + 20, ny + 46), fill=(60, 60, 70))
    else:
        # back: wolf silhouette howling at a moon
        d.ellipse((330, 90, 470, 230), fill=(214, 214, 200))
        d.polygon([(140, 860), (180, 640), (160, 600), (200, 480),
                   (250, 420), (245, 360), (285, 300), (300, 360),
                   (340, 400), (330, 500), (370, 640), (360, 860)],
                  fill=(52, 52, 60))
    try:
        font = ImageFont.truetype("arialbd.ttf", 44)
    except OSError:
        font = ImageFont.load_default()
    d.text((cx, 940), label, fill=(60, 60, 70), font=font, anchor="mm")
    return im


def fit_into(img, w, h):
    img = ImageOps.exif_transpose(img.convert("RGB"))
    img.thumbnail((w, h), Image.LANCZOS)
    canvas = Image.new("RGB", (w, h), FABRIC)
    canvas.paste(img, ((w - img.width) // 2, (h - img.height) // 2))
    return canvas


def build_base(front, back):
    canvas = Image.new("RGB", (1024, 1024), FABRIC)
    canvas.paste(fit_into(front, 500, 1000), (6, 12))
    canvas.paste(fit_into(back, 500, 1000), (518, 12))
    return canvas


# --- stain recipe (mirrors tools/make_dirt_stages.py) ---
dirt = Image.open(DIRT).convert("RGB")

def build_stage(base, seed, count, rmin, rmax, opacity, desat, darken):
    w, h = base.size
    tiled = Image.new("RGB", (w, h))
    for x in range(0, w, dirt.width):
        for y in range(0, h, dirt.height):
            tiled.paste(dirt, (x, y))
    gray = tiled.convert("L")
    brown = ImageOps.colorize(gray, black=(48, 30, 14), white=(168, 118, 66))
    stained = ImageChops.multiply(base, brown)
    rng = random.Random(seed)
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    for _ in range(count):
        cx, cy = rng.randint(0, w), rng.randint(0, h)
        for _ in range(rng.randint(2, 4)):
            ox, oy = rng.randint(-30, 30), rng.randint(-30, 30)
            rx, ry = rng.randint(rmin, rmax), rng.randint(rmin, rmax)
            d.ellipse((cx + ox - rx, cy + oy - ry, cx + ox + rx, cy + oy + ry), fill=opacity)
    m = ImageChops.multiply(m, ImageOps.autocontrast(gray).point(lambda v: 110 + v // 2))
    m = m.filter(ImageFilter.GaussianBlur(5))
    out = Image.composite(stained, base, m)
    out = ImageEnhance.Color(out).enhance(desat)
    return ImageEnhance.Brightness(out).enhance(darken)


def main():
    key, donor = sys.argv[1], sys.argv[2]
    assert len(key) == len(donor), 'key and donor must be the same length (NIF byte patch)'
    front = Image.open(sys.argv[3]) if len(sys.argv) > 3 else placeholder_panel('BANG CHAN')
    back = Image.open(sys.argv[4]) if len(sys.argv) > 4 else placeholder_panel('WOLF', back=True)

    base = build_base(front, back)
    base.save(rf"{MOD}\textures\lovepillow_{key}.png")
    s1 = build_stage(base, 5000, 42, 8, 26, 150, 0.97, 1.00)
    s2 = build_stage(base, 5100, 14, 30, 95, 205, 0.85, 0.94)
    s3 = build_stage(build_stage(base, 5200, 15, 45, 150, 235, 1.0, 1.0),
                     5700, 15, 45, 150, 235, 0.62, 0.88)
    for tag, img in (('s', s1), ('d', s2), ('f', s3)):
        img.save(rf"{MOD}\textures\lovepillo{tag}_{key}.png")

    donorNif = open(rf"{MOD}\meshes\LP\lovepillow_{donor}.nif", 'rb').read()
    needle = f"lovepillow_{donor}.dds".encode()
    assert donorNif.count(needle) == 1
    baseNif = donorNif.replace(needle, f"lovepillow_{key}.png".encode())
    open(rf"{MOD}\meshes\LP\lovepillow_{key}.nif", 'wb').write(baseNif)
    for tag in ('s', 'd', 'f'):
        n2 = bytearray(baseNif.replace(f"lovepillow_{key}.png".encode(),
                                       f"lovepillo{tag}_{key}.png".encode()))
        if tag == 'f':
            i = n2.find(b'NiMaterialProperty')
            b2 = i + len(b'NiMaterialProperty')
            nl, = struct.unpack('<I', n2[b2:b2 + 4])
            emisOff = b2 + 4 + nl + 10 + 9 * 4
            struct.pack_into('<3f', n2, emisOff, 0.04, 0.09, 0.03)
        open(rf"{MOD}\meshes\LP\lovepillo{tag}_{key}.nif", 'wb').write(bytes(n2))
    print(f'OK: custom pillow {key} — base + 3 stages (textures + NIFs)')


if __name__ == '__main__':
    main()
