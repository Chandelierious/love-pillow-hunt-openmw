-- Love Pillow Hunt (OpenMW port) — GLOBAL script.
-- Intercepts pillow activation, attaches the pillow local script, and performs
-- the world mutations only global scripts may do (advanceTime, teleport/flip,
-- activateBy).

local core = require('openmw.core')
local world = require('openmw.world')
local types = require('openmw.types')
local util = require('openmw.util')
local I = require('openmw.interfaces')

local shared = require('scripts.LovePillowHunt.shared')

local enabled = true
local visibleDirt = true
local stinkEffects = true

-- Stink effects (flies + green light + buzz) per filthy pillow.
-- Keyed by the pillow object's id: { flies = obj, light = obj, pillow = obj }
local stink = {}

local function clearStink(pillowId)
  local s = stink[pillowId]
  if not s then return end
  stink[pillowId] = nil
  pcall(function()
    if s.pillow and s.pillow:isValid() then
      core.sound.stopSound3d('flies', s.pillow)
    end
  end)
  for _, key in ipairs({ 'flies', 'light' }) do
    pcall(function()
      if s[key] and s[key]:isValid() then s[key]:remove() end
    end)
  end
end

local function ensureStink(pillow)
  if stink[pillow.id] then return end
  local ok, err = pcall(function()
    local flies = world.createObject(shared.FLIES_RECORD, 1)
    flies:teleport(pillow.cell, pillow.position)
    local light = world.createObject(shared.LIGHT_RECORD, 1)
    light:teleport(pillow.cell, pillow.position)
    stink[pillow.id] = { flies = flies, light = light, pillow = pillow }
    -- Vanilla Flies sound record, same volume the vanilla emitter script uses
    core.sound.playSound3d('flies', pillow, { loop = true, volume = 0.5 })
  end)
  if not ok then print('LPH global: ensureStink failed: ' .. tostring(err)) end
end

-- Re-evaluate a pillow's visible stage + stink effects. May REPLACE the
-- object (record swap); returns the current (possibly new) pillow object.
local function applyStage(pillow, cleanliness)
  local def = shared.pillows[pillow.recordId]
  if not def then return pillow end
  local stage = shared.stageFor(cleanliness)
  local targetStage = visibleDirt and stage or 0
  local targetId = shared.stageRecordId(def.base, targetStage)

  if pillow.recordId ~= targetId and pillow.cell ~= nil then
    local ok, err = pcall(function()
      clearStink(pillow.id)
      local fresh = world.createObject(targetId, 1)
      fresh:teleport(pillow.cell, pillow.position, { rotation = pillow.rotation })
      -- Attach with carried state BEFORE the engine's onObjectActive can
      -- attach it stateless (hasScript guard there skips ours).
      fresh:addScript(shared.PILLOW_SCRIPT, { cleanliness = cleanliness })
      pillow:remove()
      pillow = fresh
    end)
    if not ok then print('LPH global: stage swap failed: ' .. tostring(err)) end
  end

  if stage == 2 and stinkEffects and pillow.cell ~= nil then
    ensureStink(pillow)
  else
    clearStink(pillow.id)
  end
  return pillow
end
-- object.id -> simulation timestamp of a deliberate fall-through. Other mods
-- (e.g. Animated Pickup) intercept the activation we passed on, animate, and
-- finish with their own activateBy() — which re-enters this handler. Within
-- this window we keep passing the object through so their deferred pickup
-- completes instead of being re-intercepted by our menu.
local PASS_WINDOW_SECONDS = 5
local passThrough = {}

local function pillowName(pillow)
  local rec = types.Miscellaneous.record(pillow)
  return (rec and rec.name) or '?'
end

local function isUnderwater(obj)
  local cell = obj.cell
  return cell ~= nil and cell.hasWater and cell.waterLevel ~= nil
    and obj.position.z < cell.waterLevel
end

-- Returning false suppresses the engine's standard activation action
-- (verified against scripts/omw/activationhandlers.lua on the openmw-0.51.0
-- tag: a handled activation returns before world._runStandardActivationAction).
I.Activation.addHandlerForType(types.Miscellaneous, function(obj, actor)
  if not shared.pillows[obj.recordId] then return end
  local passed = passThrough[obj.id]
  if passed and core.getSimulationTime() - passed < PASS_WINDOW_SECONDS then
    return
  end
  passThrough[obj.id] = nil
  -- Underwater pillows fall through to vanilla pickup on purpose: activating
  -- one in the water simply takes it.
  if not enabled or isUnderwater(obj) then
    passThrough[obj.id] = core.getSimulationTime()
    return
  end
  obj:sendEvent('LPH_Activated', { actor = actor })
  return false
end)

local function onObjectActive(object)
  if shared.pillows[object.recordId] and not object:hasScript(shared.PILLOW_SCRIPT) then
    object:addScript(shared.PILLOW_SCRIPT)
  end
end

-- Direct pickup: no activation replay. Replayed activateBy() calls interact
-- badly with other activation-intercepting mods (Animated Pickup re-enters
-- the handler chain and our menu "blocks" its deferred pickup).
local function pickUp(pillow, actor)
  if not actor then return end
  clearStink(pillow.id)
  pillow:moveInto(types.Actor.inventory(actor))
  -- 2D feedback sound via the player script (openmw.ambient) — playSound3d
  -- from here was silent in-game (round-2 test).
  actor:sendEvent('LPH_Sound', { sound = 'item misc up' })
end

return {
  engineHandlers = {
    onObjectActive = onObjectActive,
    onSave = function()
      return { enabled = enabled, visibleDirt = visibleDirt, stinkEffects = stinkEffects, stink = stink }
    end,
    onLoad = function(data)
      enabled = not (data and data.enabled == false)
      visibleDirt = not (data and data.visibleDirt == false)
      stinkEffects = not (data and data.stinkEffects == false)
      -- Revalidate persisted stink effects; drop anything dangling.
      stink = {}
      local saved = data and data.stink
      if type(saved) == 'table' or type(saved) == 'userdata' then
        pcall(function()
          for id, s in pairs(saved) do
            if s.pillow and s.pillow:isValid() and s.pillow.cell ~= nil then
              stink[id] = { flies = s.flies, light = s.light, pillow = s.pillow }
            else
              for _, key in ipairs({ 'flies', 'light' }) do
                pcall(function() if s[key] and s[key]:isValid() then s[key]:remove() end end)
              end
            end
          end
        end)
      end
    end,
  },
  eventHandlers = {
    LPH_SetEnabled = function(data)
      enabled = not (data and data.enabled == false)
      visibleDirt = not (data and data.visibleDirt == false)
      stinkEffects = not (data and data.stinkEffects == false)
      if not stinkEffects then
        for id in pairs(stink) do clearStink(id) end
      end
    end,
    LPH_StageCheck = function(data)
      if data and data.pillow then
        applyStage(data.pillow, tonumber(data.cleanliness) or shared.MAX_CLEAN)
      end
    end,
    LPH_Cuddled = function(data)
      world.advanceTime(shared.DIRTY_HOURS)
      data.pillow:sendEvent('LPH_Dirty', {})
    end,
    LPH_Flip = function(data)
      local pillow = data.pillow
      if not pillow.cell then return end
      pillow:teleport(pillow.cell, pillow.position, {
        -- Right-to-left composition: rotateY applies first, i.e. in the
        -- pillow's local frame — same flip as the original's post-multiply.
        rotation = pillow.rotation * util.transform.rotateY(math.pi),
      })
      -- Keep stink effects glued to the pillow.
      local s = stink[pillow.id]
      if s then
        pcall(function()
          if s.flies and s.flies:isValid() then s.flies:teleport(pillow.cell, pillow.position) end
          if s.light and s.light:isValid() then s.light:teleport(pillow.cell, pillow.position) end
        end)
      end
      local player = world.players[1]
      if player then player:sendEvent('LPH_Sound', { sound = 'item misc down' }) end
    end,
    LPH_PickUp = function(data)
      pickUp(data.pillow, data.actor)
    end,
    LPH_Washed = function(data)
      local pillow = data.pillow
      local player = world.players[1]
      if not player then return end
      world.advanceTime(shared.CLEAN_HOURS)
      player:sendEvent('LPH_Fade', {
        text = string.format('You clean the filth from %s', shared.displayName(pillowName(pillow))),
      })
      -- Restore the clean look (and clear stink) BEFORE pocketing it, so the
      -- inventory receives the base record.
      pillow = applyStage(pillow, tonumber(data.cleanliness) or shared.MAX_CLEAN)
      pickUp(pillow, player)
    end,
  },
}
