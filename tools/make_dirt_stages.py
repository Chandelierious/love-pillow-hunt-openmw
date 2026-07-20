"""Generate dirt-stage textures for all 18 pillows.

Stage recipe (v2 + warmth pass): discrete brown stain blobs filled from the
vanilla dirt patch texture, density/size/opacity ramp per stage, plus overall
desaturation+darkening on the filthy stage.

Output names are byte-length-identical to the originals so the stage NIFs can
be produced by substring patching:
  lovepillow_<n>.dds -> lovepillod_<n>.png  (dirty)
  lovepillow_<n>.dds -> lovepillof_<n>.png  (filthy)
"""
import random
from PIL import Image, ImageEnhance, ImageChops, ImageDraw, ImageFilter, ImageOps

MOD = r"P:\Morrowind Modding CoWork\love-pillow-hunt-openmw"
DIRT = r"C:\Users\AJ\AppData\Local\Temp\claude\P--Morrowind-Modding-CoWork\a8343a8d-df3f-4487-ad26-3f55cd60568e\scratchpad\dirtsample\tx_ai_dirtpatch_01.dds"

NAMES = [
    'almalexia', 'anhaedra', 'azura', 'caius', 'crassius', 'dagothur',
    'divayth', 'dratha', 'eydis', 'fargoth', 'gaenor', 'galbedir',
    'habasi', 'jiub', 'maiq', 'mehramilo', 'tarhiel', 'vivec',
]

dirt = Image.open(DIRT).convert("RGB")

def build_stage(base, seed, count, rmin, rmax, opacity, desat, darken):
    w, h = base.size
    tiled = Image.new("RGB", (w, h))
    for x in range(0, w, dirt.width):
        for y in range(0, h, dirt.height):
            tiled.paste(dirt, (x, y))
    gray = tiled.convert("L")
    # warm stain-brown fill, keeps the dirt texture's variation
    brown = ImageOps.colorize(gray, black=(48, 30, 14), white=(168, 118, 66))
    stained = ImageChops.multiply(base, brown)

    rng = random.Random(seed)
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    for _ in range(count):
        cx, cy = rng.randint(0, w), rng.randint(0, h)
        # cluster of overlapping ellipses = irregular splotch
        for _ in range(rng.randint(2, 4)):
            ox, oy = rng.randint(-30, 30), rng.randint(-30, 30)
            rx, ry = rng.randint(rmin, rmax), rng.randint(rmin, rmax)
            d.ellipse((cx + ox - rx, cy + oy - ry, cx + ox + rx, cy + oy + ry), fill=opacity)
    m = ImageChops.multiply(m, ImageOps.autocontrast(gray).point(lambda v: 110 + v // 2))
    m = m.filter(ImageFilter.GaussianBlur(5))

    out = Image.composite(stained, base, m)
    out = ImageEnhance.Color(out).enhance(desat)
    out = ImageEnhance.Brightness(out).enhance(darken)
    return out

def build_double_stage(base, seed, **kw):
    # two independent stain passes: overlapping pools multiply darker,
    # giving the "overlaps the other pools" look for the filthy stage
    once = build_stage(base, seed=seed, **kw)
    return build_stage(once, seed=seed + 500, **kw)

made = 0
for i, n in enumerate(NAMES):
    base = Image.open(rf"{MOD}\textures\lovepillow_{n}.dds").convert("RGB")
    # stage 1 "speckled": many small light spots, appears early
    s1 = build_stage(base, seed=3000 + i, count=42, rmin=8,  rmax=26,  opacity=150, desat=0.97, darken=1.00)
    # stage 2 "dirty": medium blobs
    s2 = build_stage(base, seed=1000 + i, count=14, rmin=30, rmax=95,  opacity=205, desat=0.85, darken=0.94)
    # stage 3 "filthy": big dark overlapping pools (double pass)
    s3 = build_double_stage(base, seed=2000 + i, count=15, rmin=45, rmax=150, opacity=235, desat=0.62, darken=0.88)
    for tag, img in (('s', s1), ('d', s2), ('f', s3)):
        out = f"lovepillo{tag}_{n}.png"
        img.save(rf"{MOD}\textures\{out}")
        # receipts: output names must match source byte-length exactly
        assert len(out) == len(f"lovepillow_{n}.dds"), out
        made += 1
print(f"OK: {made} stage textures written")
