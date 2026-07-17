-- Love Pillow Hunt — LOAD-context script.
-- Creates the dirt-stage record variants and the fly-swarm activator (mesh
-- by R-Zero, from "Flies"). The stink light uses a vanilla record instead
-- (custom modelless lights fail engine validation).
--
-- Stage records copy every field from the base record EXPLICITLY and derive
-- the stage model path from the base record's own model string — template
-- with a model override kept the template's model in-game (round-5 test:
-- "the pillow texture never changes"). Readback receipts log any mismatch.

local content = require('openmw.content')

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
  local sampleLogged = false
  for _, name in ipairs(shared.NAMES) do
    local base = content.miscs.records['lovepillow_' .. name]
    if not base then
      print('LPH load: base record missing: lovepillow_' .. name)
      failed = failed + 2
    else
      for stage = 1, 2 do
        local sid = shared.stageRecordId(base.id, stage)
        local tag = (stage == 1) and 'd' or 'f'
        -- derive from the base model path so slashes/prefix conventions match
        local stageModel, replaced = tostring(base.model):gsub('lovepillow_' .. name, 'lovepillo' .. tag .. '_' .. name)
        local ok = attempt('stage record ' .. sid, function()
          if replaced ~= 1 then
            error(string.format('model derive failed: %q (%d replacements)', tostring(base.model), replaced))
          end
          content.miscs.records[sid] = {
            name = base.name,
            model = stageModel,
            icon = base.icon,
            weight = base.weight,
            value = base.value,
          }
        end)
        local rec = ok and content.miscs.records[sid] or nil
        if rec and tostring(rec.model) == stageModel then
          made = made + 1
          if not sampleLogged then
            sampleLogged = true
            print(string.format('LPH load: sample stage model %s -> %s', sid, tostring(rec.model)))
          end
        else
          failed = failed + 1
          if rec then
            print(string.format('LPH load: MODEL MISMATCH on %s: wanted %q got %q', sid, stageModel, tostring(rec.model)))
          end
        end
      end
    end
  end

  attempt('flies activator', function()
    content.activators.records[shared.FLIES_RECORD] = {
      name = '',
      model = 'meshes\\r0\\f\\flies.nif',
    }
  end)
  attempt('stink cloud activator', function()
    content.activators.records[shared.CLOUD_RECORD] = {
      name = '',
      -- the thin chimney wisp; the plain smoke_green column engulfed the
      -- whole pillow (round-8 screenshot: "a little much")
      model = 'meshes\\chimney_smoke_green.nif',
    }
  end)

  print(string.format('LPH load: %d stage records verified, %d failed; flies=%s cloud=%s',
    made, failed,
    tostring(content.activators.records[shared.FLIES_RECORD] ~= nil),
    tostring(content.activators.records[shared.CLOUD_RECORD] ~= nil)))
end

return {
  engineHandlers = {
    onContentFilesLoaded = onContentFilesLoaded,
  },
}
