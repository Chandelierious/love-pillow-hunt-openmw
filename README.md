# The Great Love Pillow Hunt (OpenMW)

Stuporstar and Merlord's body pillow mod, rebuilt for OpenMW — no MWSE
required. Eighteen body pillows are hidden across Vvardenfell. Cuddle them
for buffs. Flip them over like a shameless perv. Wash them when they get
gross (they will get gross).

## Install

1. Add this folder as a data path in the launcher.
2. Enable **both** `Love_Pillow_Hunt.esp` and `LovePillowHunt.omwscripts`.
3. OpenMW 0.51+. Remove the MWSE version if you have it.

Settings live in Options → Scripts → The Great Love Pillow Hunt.

## Changed from the original

- Cleanliness shows in the pillow menu instead of the hover tooltip
  (OpenMW scripts can't touch engine tooltips).
- The fade-to-black is homemade and a bit quicker than the original nap.
- **Pillows get visibly gross.** Dirt shows up in stages as the clean %
  drops — first splotches at 80%, bigger ones at 65%, full grease at 50%.
  At 35% flies move in (buzzing included), at 20% the rot clouds start
  rising off it. Washing walks it all back.
- **Voice lines** — your character reacts to a good cuddle in their own
  race and voice.
- **Restyled menu** — tight black box, thin outline, outlined text, and
  an opacity setting.
- **Custom pillow support** — a registry plus a bake script that builds a
  new pillow from two images: mesh, dirt stages, inventory icon, and a
  buff spell. Bring your own art.
- `tools/` holds the bake scripts that generate the dirt-stage textures,
  the stage meshes, and the stink cloud, if you want to re-tune anything.
  Paths in them are from our machine — point them at yours.

---

<sub>All credit to Stuporstar (pillows), Merlord (original scripts), and
Aleist3r (Vivec pose). Fly swarm mesh by R-Zero (Flies,
nexusmods.com/morrowind/mods/43481). Assets and ESP ship unchanged; the
scripts are an OpenMW rewrite, made with AI assistance and playtested by me.
Original mod: nexusmods.com/morrowind/mods/46852.</sub>
