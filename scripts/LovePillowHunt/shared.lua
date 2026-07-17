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

-- record id -> spell id (both confirmed against Love_Pillow_Hunt.esp)
shared.pillows = {}
for _, name in ipairs({
  'almalexia', 'anhaedra', 'azura', 'caius', 'crassius', 'dagothur',
  'divayth', 'dratha', 'eydis', 'fargoth', 'gaenor', 'galbedir',
  'habasi', 'jiub', 'maiq', 'mehramilo', 'tarhiel', 'vivec',
}) do
  shared.pillows['lovepillow_' .. name] = {
    id = 'lovepillow_' .. name,
    spell = 'lovepillow_sp_' .. name,
  }
end

return shared
