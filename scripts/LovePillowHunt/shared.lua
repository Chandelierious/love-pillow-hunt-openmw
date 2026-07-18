-- Shared data for The Great Love Pillow Hunt (OpenMW port).
-- Pure Lua, no openmw.* requires — loadable from any context.

local shared = {}

shared.MAX_CLEAN = 100
-- Fixed dirt per cuddle (was random 10-20 like the MWSE original): the
-- visible-stage progression must be deterministic — clean, speckle on the
-- 2nd cuddle, filthy on the 3rd — and random rolls kept undershooting the
-- thresholds (rounds 11-12 feedback).
shared.DIRTY_MIN = 15
shared.DIRTY_MAX = 15
shared.DIRTY_HOURS = 0.5   -- game hours passed per cuddle
shared.CLEAN_HOURS = 0.15  -- game hours passed per wash
shared.DEFAULT_BUFF_HOURS = 2

shared.PILLOW_SCRIPT = 'scripts/LovePillowHunt/pillow.lua'

shared.NAMES = {
  'almalexia', 'anhaedra', 'azura', 'caius', 'crassius', 'dagothur',
  'divayth', 'dratha', 'eydis', 'fargoth', 'gaenor', 'galbedir',
  'habasi', 'jiub', 'maiq', 'mehramilo', 'tarhiel', 'vivec',
}

-- Visible dirt ladder (round-24, AJ's spec): 80% first splotches, 65%
-- bigger splotches on top, 50% very greasy; the effects trail behind —
-- flies+buzz at 35%, rot clouds at 20%. At 15 dirt per cuddle:
-- 100 -> 85 clean -> 70 splotch -> 55 bigger -> 40 greasy -> 25 +flies
-- -> 10 +clouds.
shared.FLIES_AT = 35
shared.CLOUDS_AT = 20

function shared.stageFor(cleanliness)
  local c = tonumber(cleanliness) or shared.MAX_CLEAN
  if c <= 50 then return 3 end
  if c <= 65 then return 2 end
  if c <= 80 then return 1 end
  return 0
end

function shared.stageRecordId(baseId, stage)
  if stage >= 1 and stage <= 3 then return baseId .. '_d' .. stage end
  return baseId
end

-- Model filename tag per stage (s = speckled, d = dirty, f = filthy)
shared.STAGE_TAGS = { [1] = 's', [2] = 'd', [3] = 'f' }

-- A pillow object spawned without script state (e.g. dropped from inventory)
-- infers a plausible cleanliness from its own record's stage. Seeds sit at
-- each stage's top (no effects yet) so the map stays self-consistent.
function shared.seedCleanliness(stage)
  if stage == 3 then return 45 end
  if stage == 2 then return 58 end
  if stage == 1 then return 72 end
  return shared.MAX_CLEAN
end

-- Custom pillows: not in the ESP; base record + spell + stage records are
-- all created by load.lua. donor = ESP pillow whose record fields (weight,
-- icon) seed the base; the mesh/texture come from tools/make_custom_pillow.py
-- (donor name must be the same LENGTH for the NIF byte patch).
-- PERSONAL USE: custom art textures are gitignored (real-person likeness /
-- SKZOO IP — do not publish).
shared.CUSTOM = {
  {
    key = 'bangchan',
    name = 'Bang Chan Body Pillow',
    donor = 'galbedir',
    icon = 'icons\\lp\\lvpillow_bangchan.tga',
    spell = 'lovepillow_sp_bangchan',
    -- Leader-of-the-pack charisma.
    effect = { id = 'fortifyattribute', attribute = 'personality', magnitude = 10 },
  },
}

-- record id -> { spell, base, stage } for base records AND stage variants
-- (ESP-backed pillows confirmed against Love_Pillow_Hunt.esp, plus customs)
shared.pillows = {}
local function registerPillow(name, spell)
  local base = 'lovepillow_' .. name
  shared.pillows[base] = { id = base, spell = spell, base = base, stage = 0 }
  for stage = 1, 3 do
    local sid = shared.stageRecordId(base, stage)
    shared.pillows[sid] = { id = sid, spell = spell, base = base, stage = stage }
  end
end
for _, name in ipairs(shared.NAMES) do
  registerPillow(name, 'lovepillow_sp_' .. name)
end
for _, c in ipairs(shared.CUSTOM) do
  registerPillow(c.key, c.spell)
end

-- Stink effect records, both created by load.lua as nameless activators:
-- the fly swarm (mesh by R-Zero) and the cartoonish rising stink cloud
-- (vanilla green smoke column mesh). A spawned vanilla light was tried for
-- a glow and never visibly rendered (round-7, tested at night).
shared.FLIES_RECORD = 'lph_flies'
shared.CLOUD_RECORD = 'lph_stink_cloud'

-- Display-name transform: ESP records are named "Body Pillow of X"; AJ's
-- preferred scheme is "X Body Pillow". Names that don't match pass through.
function shared.displayName(name)
  local who = tostring(name or ''):match('^Body Pillow of (.+)$')
  if who then return who .. ' Body Pillow' end
  return tostring(name or '?')
end

return shared
