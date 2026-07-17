-- Love Pillow Hunt (OpenMW port) — PLAYER script.
-- Activation menu UI, buff bookkeeping and expiry, settings page.

local core = require('openmw.core')
local self = require('openmw.self')
local types = require('openmw.types')
local ui = require('openmw.ui')
local util = require('openmw.util')
local async = require('openmw.async')
local storage = require('openmw.storage')
local ambient = require('openmw.ambient')
local I = require('openmw.interfaces')

local shared = require('scripts.LovePillowHunt.shared')
local vocals = require('scripts.LovePillowHunt.vocals')

local col = util.color.rgb
local V2 = util.vector2

-- ---------------------------------------------------------------- settings

I.Settings.registerPage {
  key = 'LovePillowHunt',
  l10n = 'LovePillowHunt',
  name = 'The Great Love Pillow Hunt',
  description = 'Cuddle, flip, and wash your love pillows. '
    .. 'Assets by Stuporstar, original MWSE scripts by Merlord, '
    .. 'Vivec pose by Aleist3r. OpenMW port made with AI assistance.',
}

I.Settings.registerGroup {
  key = 'SettingsPlayerLovePillowHunt',
  page = 'LovePillowHunt',
  l10n = 'LovePillowHunt',
  name = 'Options',
  permanentStorage = true,
  settings = {
    {
      key = 'enabled',
      renderer = 'checkbox',
      name = 'Enable Pillow Menu',
      description = 'Enable the menu that allows you to cuddle, wash and flip over your love pillow.',
      default = true,
    },
    {
      key = 'buffDuration',
      renderer = 'number',
      argument = { integer = true, min = 1, max = 24 },
      name = 'Buff duration (hours)',
      description = 'How long (in game time) the buff gained from making out with a pillow lasts.',
      default = shared.DEFAULT_BUFF_HOURS,
    },
    {
      key = 'menuOpacity',
      renderer = 'number',
      argument = { integer = true, min = 10, max = 100 },
      name = 'Menu background opacity (%)',
      description = 'Opacity of the black box behind the pillow menu.',
      default = 60,
    },
  },
}

local settings = storage.playerSection('SettingsPlayerLovePillowHunt')

local function getEnabled()
  return settings:get('enabled') ~= false
end

local function getBuffHours()
  -- Type-guard: persisted values can come back with unexpected types.
  return tonumber(settings:get('buffDuration')) or shared.DEFAULT_BUFF_HOURS
end

local function getMenuOpacity()
  local pct = tonumber(settings:get('menuOpacity')) or 60
  return math.max(0.1, math.min(pct / 100, 1))
end

local function syncEnabled()
  core.sendGlobalEvent('LPH_SetEnabled', { enabled = getEnabled() })
end

settings:subscribe(async:callback(syncEnabled))

-- ------------------------------------------------------------------- buffs

local buffTime = nil -- game-time seconds of the last cuddle, nil when no buff
local expiryTimer = 0

local function removeAllPillowSpells()
  local spells = types.Actor.spells(self)
  for _, def in pairs(shared.pillows) do
    if spells[def.spell] then
      spells:remove(def.spell)
    end
  end
end

local function effectLine(spellId)
  local rec = core.magic.spells.records[spellId]
  local eff = rec and rec.effects and rec.effects[1]
  if not eff then
    return (rec and rec.name) or spellId
  end
  local name = (eff.effect and eff.effect.name) or 'Effect'
  local param = eff.affectedSkill or eff.affectedAttribute
  if param then
    name = string.format('%s (%s)', name, param)
  end
  local mag = tonumber(eff.magnitudeMax) or tonumber(eff.magnitudeMin)
  if mag then
    name = string.format('%s %d pts', name, mag)
  end
  return name
end

-- -------------------------------------------------------------------- fade

-- Engine screen fade is not exposed to Lua (verified 0.51); this is a
-- fullscreen black Image whose alpha we animate from onUpdate.
local FADE_OUT, FADE_HOLD, FADE_IN = 0.5, 0.5, 1.0
local fadeEl = nil
local fade = nil -- { t, atBlack, atEnd, ranAtBlack }

local function setControls(allowed)
  -- Pass `self`, NOT self.object: like say(), the engine validates the
  -- caller's identity via the openmw.self userdata ("Only player and global
  -- scripts can toggle control switches" when handed the plain GameObject).
  -- pcall so a future engine quirk degrades to an unlocked fade, not a
  -- wedged one.
  local ok, err = pcall(function()
    types.Player.setControlSwitch(self, types.Player.CONTROL_SWITCH.Controls, allowed)
  end)
  if not ok then print('LPH: setControlSwitch failed: ' .. tostring(err)) end
end

local function setFadeAlpha(a)
  if not fadeEl then
    fadeEl = ui.create {
      layer = 'Notification',
      type = ui.TYPE.Image,
      props = {
        resource = ui.texture { path = 'white' },
        color = col(0, 0, 0),
        relativeSize = V2(1, 1),
        alpha = a,
        visible = true,
      },
    }
  else
    fadeEl.layout.props.alpha = a
    fadeEl:update()
  end
end

local function startFade(opts)
  if fade then return end -- one fade at a time; drop the request's visuals
  fade = { t = 0, atBlack = opts.atBlack, atEnd = opts.atEnd, ranAtBlack = false }
  setControls(false)
  setFadeAlpha(0)
end

local function updateFade(dt)
  if not fade then return end
  fade.t = fade.t + dt
  local t = fade.t
  if t < FADE_OUT then
    setFadeAlpha(t / FADE_OUT)
  elseif t < FADE_OUT + FADE_HOLD then
    setFadeAlpha(1)
    if not fade.ranAtBlack then
      fade.ranAtBlack = true
      if fade.atBlack then fade.atBlack() end
    end
  elseif t < FADE_OUT + FADE_HOLD + FADE_IN then
    setFadeAlpha(1 - (t - FADE_OUT - FADE_HOLD) / FADE_IN)
  else
    -- Clear the state FIRST: if any teardown call throws, the fade must not
    -- stay wedged (a stuck non-nil `fade` silently blocks every later
    -- cuddle — that was the round-4 "can't cuddle again" bug).
    local atEnd = fade.atEnd
    fade = nil
    if fadeEl then fadeEl:destroy(); fadeEl = nil end
    setControls(true)
    if atEnd then atEnd() end
  end
end

-- ------------------------------------------------------------------- voice

local function playVoiceLine()
  local rec = types.NPC.record(self.object)
  if not rec then return end
  local byRace = vocals[tostring(rec.race or ''):lower()]
  if not byRace then return end
  local list = rec.isMale and byRace.male or byRace.female
  if not list or #list == 0 then return end
  local line = list[math.random(#list)]
  -- Must pass `self` (not self.object): local-script sound functions verify
  -- the argument IS the attached script's self, or throw "Local scripts can
  -- only modify object they are attached to".
  -- Voice mp3s are loose files under Data Files\Sound\Vo\ — the VFS path
  -- therefore needs the sound/ prefix (vocals.lua keeps the original's
  -- Sound-relative paths as data).
  local ok, err = pcall(function() core.sound.say('sound/' .. line.path, self, line.text) end)
  if not ok then print('LPH: say failed: ' .. tostring(err)) end
end

-- -------------------------------------------------------------------- menu

local menu = nil
-- Our own setMode/removeMode also fire the engine's UiModeChanged event;
-- this flag suppresses reacting to the change we caused ourselves.
local suppressModeEvent = false

-- Tear down the menu widget only — for when the UI mode was already changed
-- out from under us (player opened inventory, hit Escape, etc.).
local function destroyMenu()
  if menu then
    menu:destroy()
    menu = nil
  end
end

local function closeMenu()
  if menu then
    destroyMenu()
    suppressModeEvent = true
    I.UI.removeMode('Interface')
  end
end

local function onCuddle(data)
  closeMenu()
  if (tonumber(data.cleanliness) or 0) <= 0 then
    ui.showMessage(string.format('%s is too filthy!', data.name))
    return
  end
  local def = shared.pillows[data.pillow.recordId]
  if not def then return end
  playVoiceLine()
  startFade {
    atBlack = function()
      removeAllPillowSpells()
      types.Actor.spells(self):add(def.spell)
      buffTime = core.getGameTime()
      core.sendGlobalEvent('LPH_Cuddled', { pillow = data.pillow })
    end,
    atEnd = function()
      ui.showMessage(string.format('You feel completely satisfied.\n(%s for %s hours)',
        effectLine(def.spell), getBuffHours()))
    end,
  }
end

local function textButton(label, onClick)
  return {
    type = ui.TYPE.Text,
    props = {
      text = label,
      textSize = 18,
      textColor = col(0.87, 0.79, 0.58), -- Morrowind-ish parchment yellow
    },
    events = {
      mouseClick = async:callback(onClick),
    },
  }
end

local function spacer(h)
  return { props = { size = V2(1, h) } }
end

local function openMenu(data)
  closeMenu()
  local title = string.format('%s (%d%% clean)', data.name, tonumber(data.cleanliness) or shared.MAX_CLEAN)
  local rows = {
    {
      type = ui.TYPE.Text,
      props = {
        text = title,
        textSize = 20,
        textColor = col(0.92, 0.90, 0.83),
      },
    },
    spacer(14),
    textButton('Cuddle', function() onCuddle(data) end),
    spacer(8),
    textButton('Pick Up', function()
      closeMenu()
      core.sendGlobalEvent('LPH_PickUp', { pillow = data.pillow, actor = self.object })
    end),
    spacer(8),
    textButton('Flip Over', function()
      closeMenu()
      core.sendGlobalEvent('LPH_Flip', { pillow = data.pillow })
    end),
    spacer(8),
    textButton('Cancel', function() closeMenu() end),
  }
  -- Size the box to its content plus a little padding (no measure API for
  -- Flex content — estimate from string lengths, same idiom the highlight
  -- mod uses for label widths).
  local widest = #title * 9
  for _, label in ipairs({ 'Cuddle', 'Pick Up', 'Flip Over', 'Cancel' }) do
    widest = math.max(widest, #label * 8)
  end
  local boxW = math.max(220, widest + 32)
  -- title 26 + gap 14 + 4 buttons at 24 + 3 gaps at 8 + vertical padding
  local boxH = 26 + 14 + 4 * 24 + 3 * 8 + 28
  suppressModeEvent = true
  menu = ui.create {
    layer = 'Windows',
    -- Image, not Container: empty/shape Containers render at 0x0 (#7848).
    type = ui.TYPE.Image,
    props = {
      resource = ui.texture { path = 'white' },
      color = col(0, 0, 0),
      alpha = getMenuOpacity(),
      size = V2(boxW, boxH),
      relativePosition = V2(0.5, 0.5),
      anchor = V2(0.5, 0.5),
    },
    content = ui.content {
      {
        type = ui.TYPE.Flex,
        props = {
          horizontal = false,
          arrange = ui.ALIGNMENT.Center,
          relativeSize = V2(1, 1),
          -- Text must stay fully opaque while the box behind it is
          -- translucent; children inherit parent alpha by default.
          inheritAlpha = false,
        },
        content = ui.content(rows),
      },
    },
  }
  I.UI.setMode('Interface', { windows = {} })
end

-- ------------------------------------------------------------------ engine

local function onUpdate(dt)
  updateFade(dt)
  if not buffTime then return end
  expiryTimer = expiryTimer + dt
  if expiryTimer < 1 then return end
  expiryTimer = 0
  if core.getGameTime() > buffTime + getBuffHours() * 3600 then
    buffTime = nil
    removeAllPillowSpells()
  end
end

return {
  engineHandlers = {
    onUpdate = onUpdate,
    onActive = syncEnabled,
    onSave = function()
      return { version = 1, buffTime = buffTime }
    end,
    onLoad = function(data)
      buffTime = tonumber(data and data.buffTime) or nil
    end,
  },
  eventHandlers = {
    LPH_ShowMenu = function(data)
      if not getEnabled() then return end
      if I.UI.getMode() then return end -- some other UI is open
      openMenu(data)
    end,
    LPH_Message = function(data)
      ui.showMessage(tostring(data.text))
    end,
    LPH_Fade = function(data)
      local text = data and data.text
      startFade {
        atEnd = function()
          if text then ui.showMessage(tostring(text)) end
        end,
      }
    end,
    -- 2D feedback sounds (pickup, flip) — the MWSE original used the 2D
    -- tes3.playSound; openmw.ambient is the player-context equivalent.
    LPH_Sound = function(data)
      local ok, err = pcall(function() ambient.playSound(tostring(data.sound)) end)
      if not ok then print('LPH: ambient.playSound failed: ' .. tostring(err)) end
    end,
    -- Fired by the engine's built-in UI script on every mode-stack change.
    -- If someone else changed the mode while our menu is up (inventory,
    -- Escape, journal...), tear the menu down instead of floating stuck.
    UiModeChanged = function(data)
      if suppressModeEvent then
        suppressModeEvent = false
        return
      end
      destroyMenu()
    end,
  },
}
