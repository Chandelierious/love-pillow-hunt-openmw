"""Generate dirt-stage NIFs by patching the texture path inside each pillow
mesh. Same-length substring swap (lovepillow_<n>.dds -> lovepillod_<n>.png),
with hard receipts: exactly one replacement per NIF or the script fails.
"""
import os
import struct

MOD = r"P:\Morrowind Modding CoWork\love-pillow-hunt-openmw"

NAMES = [
    'almalexia', 'anhaedra', 'azura', 'caius', 'crassius', 'dagothur',
    'divayth', 'dratha', 'eydis', 'fargoth', 'gaenor', 'galbedir',
    'habasi', 'jiub', 'maiq', 'mehramilo', 'tarhiel', 'vivec',
]

made = 0
for n in NAMES:
    src_path = rf"{MOD}\meshes\LP\lovepillow_{n}.nif"
    data = open(src_path, 'rb').read()
    needle = f"lovepillow_{n}.dds".encode('ascii')
    count = data.count(needle)
    assert count == 1, f"{n}: expected exactly 1 texture ref, found {count}"
    for tag in ('s', 'd', 'f'):
        repl = f"lovepillo{tag}_{n}.png".encode('ascii')
        assert len(repl) == len(needle)
        patched = bytearray(data.replace(needle, repl))
        assert patched.count(repl) == 1 and needle not in patched
        if tag == 'f':
            # Filthy stage: whisper of sickly green EMISSIVE (round-24:
            # "very greasy looking ... they still need to be darker" —
            # was 0.13,0.30,0.09 and read as glow; now barely-there).
            i = patched.find(b'NiMaterialProperty')
            assert i != -1, f'{n}: no material'
            base = i + len(b'NiMaterialProperty')
            nameLen, = struct.unpack('<I', patched[base:base+4])
            emisOff = base + 4 + nameLen + 10 + 9 * 4
            er, eg, eb = struct.unpack('<3f', patched[emisOff:emisOff+12])
            assert er == 0.0 and eg == 0.0 and eb == 0.0, f'{n}: emissive not zero'
            struct.pack_into('<3f', patched, emisOff, 0.04, 0.09, 0.03)
        out = rf"{MOD}\meshes\LP\lovepillo{tag}_{n}.nif"
        open(out, 'wb').write(bytes(patched))
        made += 1
print(f"OK: {made} stage NIFs written")
