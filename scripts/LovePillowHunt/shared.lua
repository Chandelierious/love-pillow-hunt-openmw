-- Shared data for The Great Love Pillow Hunt (OpenMW port).
-- Pure Lua, no openmw.* requires — loadable from any context.

local shared = {}

shared.MAX_CLEAN = 100
shared.DIRTY_MIN = 10
shared.DIRTY_MAX = 20
shared.DIRTY_HOURS = 0.5   -- game hours passed per cuddle
shared.CLEAN_HOURS = 0.15  -- game hours passed per wash
shared.DEFAULT_BUFF_HOURS = 2

shared.PILLOW_SCRIPT = 'scripts/LovePillowHunt/pillow.lua'

shared.NAMES = {
  'almalexia', 'anhaedra', 'azura', 'caius', 'crassius', 'dagothur',
  'divayth', 'dratha', 'eydis', 'fargoth', 'gaenor', 'galbedir',
  'habasi', 'jiub', 'maiq', 'mehramilo', 'tarhiel', 'vivec',
}

-- Visible dirt stages: 0 = clean look, 1 = dirty (<= 66), 2 = filthy (<= 33).
-- Stage 1/2 use load-context record variants with restained models.
function shared.stageFor(cleanliness)
  local c = tonumber(cleanliness) or shared.MAX_CLEAN
  if c <= 33 then return 2 end
  if c <= 66 then return 1 end
  return 0
end

function shared.stageRecordId(baseId, stage)
  if stage == 1 then return baseId .. '_d1' end
  if stage == 2 then return baseId .. '_d2' end
  return baseId
end

-- A pillow object spawned without script state (e.g. dropped from inventory)
-- infers a plausible cleanliness from its own record's stage.
function shared.seedCleanliness(stage)
  if stage == 2 then return 20 end
  if stage == 1 then return 55 end
  return shared.MAX_CLEAN
end

-- record id -> { spell, base, stage } for base records AND stage variants
-- (spell ids confirmed against Love_Pillow_Hunt.esp)
shared.pillows = {}
for _, name in ipairs(shared.NAMES) do
  local base = 'lovepillow_' .. name
  local spell = 'lovepillow_sp_' .. name
  shared.pillows[base] = { id = base, spell = spell, base = base, stage = 0 }
  for stage = 1, 2 do
    local sid = shared.stageRecordId(base, stage)
    shared.pillows[sid] = { id = sid, spell = spell, base = base, stage = stage }
  end
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
