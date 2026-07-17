-- Love Pillow Hunt (OpenMW port) — local script attached to each pillow
-- (CUSTOM flag, attached by global.lua). Owns this pillow's cleanliness and
-- watches for being dropped into water.

local core = require('openmw.core')
local self = require('openmw.self')
local types = require('openmw.types')

local shared = require('scripts.LovePillowHunt.shared')

local cleanliness = shared.MAX_CLEAN

-- Tell the global script to re-evaluate this pillow's dirt stage / stink
-- effects. Called after anything that changes (or establishes) cleanliness.
local function stageCheck()
  core.sendGlobalEvent('LPH_StageCheck', { pillow = self.object, cleanliness = cleanliness })
end

-- Wash sequence state: staggered splash sounds driven from onUpdate so no
-- timer API is needed. nil when idle.
local wash = nil
local checkTimer = 0

local function isUnderwater()
  local cell = self.cell
  return cell ~= nil and cell.hasWater and cell.waterLevel ~= nil
    and self.position.z < cell.waterLevel
end

local function playSplash(soundId)
  -- 3D at the pillow's position; pcall+log so a silent engine rejection
  -- shows up in openmw.log instead of just... silence.
  local ok, err = pcall(function() core.sound.playSound3d(soundId, self, {}) end)
  if not ok then print('LPH pillow: playSound3d failed: ' .. tostring(err)) end
end

local function onUpdate(dt)
  if wash then
    wash.t = wash.t + dt
    if wash.stage == 1 and wash.t >= 0.7 then
      wash.stage = 2
      playSplash('swim left')
    elseif wash.stage == 2 and wash.t >= 1.2 then
      wash.stage = 3
      playSplash('swim right')
    elseif wash.stage == 3 and wash.t >= 1.8 then
      wash = nil
      core.sendGlobalEvent('LPH_Washed', { pillow = self.object, cleanliness = cleanliness })
    end
    return
  end

  checkTimer = checkTimer + dt
  if checkTimer < 0.25 then return end
  checkTimer = 0

  -- Only a dirty pillow washes (a pristine pillow lying in water is left
  -- alone — this also prevents world-placed pillows from self-collecting).
  if cleanliness < shared.MAX_CLEAN and isUnderwater() then
    cleanliness = shared.MAX_CLEAN
    wash = { t = 0, stage = 1 }
    playSplash('swim left')
  end
end

return {
  engineHandlers = {
    onUpdate = onUpdate,
    -- initData carries cleanliness across stage-swaps. Without it (fresh
    -- attach, e.g. a stage-variant item dropped from inventory), infer a
    -- plausible value from the record's own stage so looks and state agree.
    onInit = function(initData)
      local carried = tonumber(initData and initData.cleanliness)
      if carried then
        cleanliness = carried
      else
        local def = shared.pillows[self.object.recordId]
        cleanliness = shared.seedCleanliness(def and def.stage or 0)
      end
    end,
    onActive = stageCheck,
    onSave = function()
      return { version = 1, cleanliness = cleanliness }
    end,
    onLoad = function(data)
      -- Type-guard persisted data: never trust saved values' types.
      cleanliness = tonumber(data and data.cleanliness) or shared.MAX_CLEAN
    end,
  },
  eventHandlers = {
    LPH_Activated = function(data)
      local rec = types.Miscellaneous.record(self.object)
      data.actor:sendEvent('LPH_ShowMenu', {
        pillow = self.object,
        name = (rec and rec.name) or '?',
        cleanliness = cleanliness,
      })
    end,
    LPH_Dirty = function()
      cleanliness = math.max(0, cleanliness - math.random(shared.DIRTY_MIN, shared.DIRTY_MAX))
      stageCheck()
    end,
  },
}
