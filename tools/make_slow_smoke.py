"""Bake the stink-cloud assets from vanilla smoke_green.nif.

v4 (round-14 direction: "dark green brown", "still too bright"):
- Recolor the smoke's texture (vanilla tx_greenglow.dds, bright pale cyan)
  by luminance onto a black -> dark green-brown ramp, keeping its alpha.
  Ships as textures/lph_stinksmk.tga (same byte-length as the NIF's
  'Tx_greenglow.tga' reference -> safe string patch).
- Material alpha 1.0 -> 0.25 (additive particles stack to white otherwise).
Size/count/spread handled at spawn time in global.lua.
"""
import struct, os
from PIL import Image

SCRATCH = r"C:\Users\AJ\AppData\Local\Temp\claude\P--Morrowind-Modding-CoWork\a8343a8d-df3f-4487-ad26-3f55cd60568e\scratchpad\smoke"
MOD = r"P:\Morrowind Modding CoWork\love-pillow-hunt-openmw"

# --- texture: luminance -> dark green-brown ramp, alpha preserved
im = Image.open(rf"{SCRATCH}\tx_greenglow.dds").convert("RGBA")
px = im.load()
TARGET = (38, 42, 17)  # foul murk ceiling (round-24: "still need to be darker")
for y in range(im.height):
    for x in range(im.width):
        r, g, b, a = px[x, y]
        lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
        px[x, y] = (int(TARGET[0] * lum), int(TARGET[1] * lum), int(TARGET[2] * lum), a)
im.save(rf"{MOD}\textures\lph_stinksmk.tga")

# --- NIF: texture path swap + material alpha
data = bytearray(open(rf"{SCRATCH}\smoke_green.nif", 'rb').read())

needle, repl = b'Tx_greenglow.tga', b'lph_stinksmk.tga'
assert len(needle) == len(repl)
count = data.count(needle)
assert count == 1, f'expected 1 texture ref, found {count}'
data = bytearray(bytes(data).replace(needle, repl))

i = data.find(b'NiMaterialProperty')
base = i + len(b'NiMaterialProperty')
nameLen, = struct.unpack_from('<I', data, base)
alphaOff = base + 4 + nameLen + 10 + 13 * 4
old, = struct.unpack_from('<f', data, alphaOff)
assert abs(old - 1.0) < 0.001, f'expected material alpha 1.0, found {old}'
struct.pack_into('<f', data, alphaOff, 0.13)

# Wider clouds (round-16: "stretched about double the width"): the vanilla
# emitter is a POINT (StartRandom 0,0,0) and girth comes from particle size.
# Double-ish the particle size and give the emitter a real horizontal area.
pb = data.find(b'NiParticleSystemController') + len(b'NiParticleSystemController')
size, = struct.unpack_from('<f', data, pb + 78)
assert abs(size - 58.8) < 0.1, f'expected particle size ~58.8, found {size}'
struct.pack_into('<f', data, pb + 78, 100.0)
sx, sy, sz = struct.unpack_from('<3f', data, pb + 105)
assert sx == 0.0 and sy == 0.0 and sz == 0.0, f'expected StartRandom zeros, found {(sx, sy, sz)}'
struct.pack_into('<3f', data, pb + 105, 28.0, 28.0, 0.0)

os.makedirs(rf"{MOD}\meshes\lph", exist_ok=True)
open(rf"{MOD}\meshes\lph\stinkcloud.nif", 'wb').write(bytes(data))
print('OK: recolored texture + patched cloud NIF written')
