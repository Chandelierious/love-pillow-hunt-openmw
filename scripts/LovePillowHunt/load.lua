-- Love Pillow Hunt — LOAD-context script.
-- Creates the dirt-stage record variants (restained models, everything else
-- from the base record via template) plus the stink-effect records: the fly
-- swarm activator (mesh by R-Zero, from "Flies") and the sickly green light.
-- Everything pcall-wrapped and logged with an "LPH load:" prefix.

local content = require('openmw.content')
local util = require('openmw.util')

local shared = require('scripts.LovePillowHunt.shared')

local function attempt(label, fn)
  local ok, err = pcall(fn)
  if not ok then
    print(string.format('LPH load: %s FAILED: %s', label, tostring(err)))
  end
  return ok
end

local function onContentFilesLoaded()
  local made, failed = 0, 0
  for _, name in ipairs(shared.NAMES) do
    local base = 'lovepillow_' .. name
    for stage = 1, 2 do
      local sid = shared.stageRecordId(base, stage)
      local tag = (stage == 1) and 'd' or 'f'
      local ok = attempt('stage record ' .. sid, function()
        content.miscs.records[sid] = {
          template = content.miscs.records[base],
          model = string.format('meshes/lp/lovepillo%s_%s.nif', tag, name),
        }
      end)
      if ok and content.miscs.records[sid] then made = made + 1 else failed = failed + 1 end
    end
  end

  attempt('flies activator', function()
    content.activators.records[shared.FLIES_RECORD] = {
      name = '',
      model = 'meshes/r0/f/flies.nif',
    }
  end)
  attempt('stink light', function()
    content.lights.records[shared.LIGHT_RECORD] = {
      name = '',
      model = '',
      radius = 128,
      color = util.color.rgb(0.35, 0.9, 0.3),
      duration = 999999,
      isCarriable = false,
      isDynamic = true,
      isFlicker = true,
      isOffByDefault = false,
    }
  end)

  print(string.format('LPH load: %d stage records created, %d failed; effects: flies=%s light=%s',
    made, failed,
    tostring(content.activators.records[shared.FLIES_RECORD] ~= nil),
    tostring(content.lights.records[shared.LIGHT_RECORD] ~= nil)))
end

return {
  engineHandlers = {
    onContentFilesLoaded = onContentFilesLoaded,
  },
}
