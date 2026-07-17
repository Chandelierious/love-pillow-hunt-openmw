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
  pillow:moveInto(types.Actor.inventory(actor))
  -- 2D feedback sound via the player script (openmw.ambient) — playSound3d
  -- from here was silent in-game (round-2 test).
  actor:sendEvent('LPH_Sound', { sound = 'item misc up' })
end

return {
  engineHandlers = {
    onObjectActive = onObjectActive,
    onSave = function() return { enabled = enabled } end,
    onLoad = function(data)
      enabled = not (data and data.enabled == false)
    end,
  },
  eventHandlers = {
    LPH_SetEnabled = function(data)
      enabled = not (data and data.enabled == false)
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
      pickUp(pillow, player)
    end,
  },
}
