# Love Pillow Hunt — OpenMW port, minimal first pass

Port of The Great Love Pillow Hunt (nexusmods.com/morrowind/mods/46852) by
Stuporstar (assets) and Merlord (MWSE scripts) to OpenMW 0.51 Lua.
Scope per AJ 2026-07-17: **core loop only** — activation menu, buffs,
cleanliness, underwater cleaning, flip. No voice lines. Instant time-skip (no
4-second control lock / fade). Polish in round two.

## Facts extracted from the MWSE source (read, not guessed)

- 18 pillows, MISC id `lovepillow_<name>`, spell id `lovepillow_sp_<name>`:
  divayth, dratha, fargoth, gaenor, galbedir, jiub, maiq, mehramilo, vivec,
  almalexia, anhaedra, azura, caius, crassius, dagothur, tarhiel, habasi, eydis.
- Constants: maxCleanliness=100, dirty amount per cuddle = random(10,20),
  cuddle advances GameHour +0.5, wash advances +0.15 and resets cleanliness
  to 100. Buff timestamp/now = `daysPassed * 24 + hour` (game-time hours).
- Config: `enabled` (default true), `buffDuration` hours (default 2, slider
  1–24). Buff expiry checked per-frame: `buffTime + buffDuration < now` →
  remove all 18 pillow spells and clear the timestamp.
- Activation menu (world activation, NOT in menu mode, NOT underwater):
  title `"<name> (N% clean)"`, buttons Cuddle / Pick Up / Flip Over / Cancel.
  Menu suppresses vanilla pickup; Pick Up button performs vanilla pickup.
  **Underwater activation deliberately falls through to vanilla pickup** —
  that's how a washed pillow returns to inventory.
- Cuddle: if cleanliness <= 0 → "<name> is too filthy!" message, nothing else.
  Else: remove all 18 spells → advance time → add this pillow's spell →
  dirty the pillow → stamp buffTime → message
  "You feel completely satisfied.\n(<effect> for <N> hours)".
- Wash: when a dropped pillow is underwater (`cell.hasWater` and
  `position.z < waterLevel`) and cleanliness < 100: Swim Left ×2 + Swim Right
  sounds, advance time, cleanliness=100, message "You clean the filth from
  <name>", then re-activate → vanilla pickup (returns to inventory).
- Flip Over: rotate the reference 180° about its local Y axis, play
  "Item Misc Down".
- Cleanliness was per-instance MWSE `itemData.data.bodypillow.cleanliness`;
  tooltip injection of "(N% clean)" is NOT portable (OpenMW Lua can't modify
  built-in menus) — info survives in the activation-menu title.

## ESP verification (parsed 2026-07-17, tools/esp_dump)

Record counts match the handoff plan exactly: MISC ×18, SPEL ×18, CELL ×17,
BOOK ×1, CREA ×1, DIAL ×1, INFO ×1. All 18 spells are single-effect,
magnitude 10, duration 0 (constant abilities). Spell FNAMs are all
"Body Pillow of <char>" — same as the pillow names — so the buff message must
render the EFFECT (effect name + skill/attribute + magnitude), not the spell
name. Effects range from Fortify Skill (11 pillows) to Fortify Magicka,
Fortify Luck, Resist Magicka, Resist Blight, Jump (Tarhiel, naturally).
Known original-data quirk shipped unchanged: MISC `lovepillow_crassius` FNAM
is misspelled "Crassuis Curio".

## Deliberately dropped/simplified in this pass

- Voice lines (vocals.lua) — cuddle is silent.
- Fade-out + 4s control lock — time advances instantly (if the verified API
  allows writing game time at all; otherwise time-skip is dropped too and the
  buff message stands alone).
- Hover-tooltip cleanliness (engine gap, permanent).
- `util.hourToString` — dead code with a pre-existing bug; not ported.

## Architecture (.omwscripts)

```
GLOBAL:        scripts/LovePillowHunt/global.lua
PLAYER:        scripts/LovePillowHunt/player.lua
CUSTOM, MISC:  scripts/LovePillowHunt/pillow.lua
```

- **global.lua** — attaches pillow.lua to pillow refs (onObjectActive +
  record-id match); owns world mutations: flip rotation, time advance, spell
  add/remove on the player (context permitting), global storage writes.
- **pillow.lua** (local, per-pillow) — owns per-instance cleanliness
  (onSave/onLoad), watches its own position vs cell water level while active,
  reports state / receives dirty+clean commands via events.
- **player.lua** — activation menu UI (Image-backed window, Text buttons,
  proper util.vector2/color types), buff bookkeeping + expiry check in
  onUpdate, settings via I.Settings registerPage/registerGroup.
- ESP + meshes/icons/textures ship unchanged. `mwse/` folder not shipped.

## API verification results (all confirmed against 0.51 docs/source 2026-07-17)

- Activation: `I.Activation.addHandlerForType(types.Miscellaneous, fn)`
  (global). Handler returning **false** marks the activation handled; verified
  in `scripts/omw/activationhandlers.lua` (openmw-0.51.0 tag) that handled
  activations return before `world._runStandardActivationAction` — vanilla
  pickup suppressed. Inventory activations never reach handlers
  (`obj.parentContainer` check).
- Time: NO absolute setter; `world.advanceTime(hours)` (global only).
  Read: `core.getGameTime()` in SECONDS (any context).
- Spells: `types.Actor.spells(self):add/remove('id')` — allowed on self from
  the player script. Membership: `spells['id']`. activeSpells is WRONG for
  abilities (expire instantly / can't remove).
- Attach: `obj:addScript(path)` global-only, script needs CUSTOM flag,
  guard with `obj:hasScript`. Discovery via global `onObjectActive`.
- Water: `cell.hasWater` / `cell.waterLevel` (nil-able) fields, not methods.
- Rotate: only via `obj:teleport(cell, pos, {rotation=Transform})` (global).
  `t1*t2` applies right-to-left → `obj.rotation * rotateY(pi)` = local-frame
  flip, matching the MWSE post-multiply.
- Sound: `core.sound.playSound3d(id, obj, {})` — global, or local on self.
  Screen fade confirmed NOT exposed.
- UI: `I.UI.setMode('Interface', {windows={}})` / `removeMode` / `getMode`.
  Cursor behavior at setMode is NOT documented — first thing to check in-game.
- Effect names: `core.magic.spells.records[id].effects[1]` →
  `.effect.name`, `.affectedSkill/.affectedAttribute`, `.magnitudeMax`.

## Implementation status (2026-07-17)

Built: shared.lua, global.lua, pillow.lua, player.lua + LovePillowHunt.omwscripts.
Event flow: activation → global handler → pillow `LPH_Activated` → player
`LPH_ShowMenu`; player → global: `LPH_Cuddled` / `LPH_PickUp` / `LPH_Flip` /
`LPH_SetEnabled`; pillow → global: `LPH_Washed`; global → player: `LPH_Message`.
Vanilla pickup replay via per-object skip flag + `activateBy`.
All scripts pass `luac -p`. Desktop harness
(`harnesses/pillow-harness.lua`, run from the mod root) drives the real
three-script event flow, 40/40 checks pass.

## Round 2 (2026-07-17, after AJ's first in-game test)

In-game round 1: menu/cuddle/buff/flip/settings/filth all worked. Pick Up
failed: **Animated Pickup** (AJ's manually-added mod, in Downloads\alt mods)
also intercepts Miscellaneous activation, animates the item, then finishes
with its own `activateBy()` — which re-entered our handler, our menu
"blocked" its deferred pickup, and it restored the item with its
msg_pickupblock message (confirmed in its global.lua and in openmw.log).

Changes:
- Pick Up and wash-return now use `pillow:moveInto(types.Actor.inventory(actor))`
  directly + 'item misc up' sound — NO activation replay, no skip flag.
  Lesson recorded: never re-fire activateBy to trigger vanilla behavior when
  other activation-intercepting mods may be installed.
- Pass-through window (5s of simulation time, per object id): when our handler
  deliberately declines a pillow activation (underwater/disabled), subsequent
  re-activations of that object pass through too, so Animated Pickup's
  deferred completion isn't re-intercepted.
- Fade-to-black added: fullscreen black Image ('Notification' layer), alpha
  ramp 0.5s out / 0.5s hold / 1.0s in, driven from onUpdate; controls locked
  via types.Player.setControlSwitch(..., CONTROL_SWITCH.Controls, ...)
  (verified in engine lua_api stubs: usable from player scripts). Buff work
  runs at black; message at fade end. Wash uses the same fade via LPH_Fade.
- Voice lines ported (vocals.lua, lowercase race keys, VFS paths) via
  `core.sound.say(path, self.object, subtitle)`; race/sex from
  types.NPC.record: `.race` (lowercased defensively) + `.isMale`.
- l10n/LovePillowHunt/en.yaml added to silence the missing-language warning.

## Credits to carry into settings sidebar

Scripts: Merlord. Models: Stuporstar. Vivec pose: Aleist3r
(nexusmods.com/morrowind/mods/46745). Fork/port made with AI assistance
(Anthropic's Claude); Nexus AI-content flag applies if published.
