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

  -- Custom pillows first: base misc record (donor fields + our mesh) and
  -- the buff spell (constant ability, mirrors the ESP pillow spells).
  for _, c in ipairs(shared.CUSTOM) do
    local donor = content.miscs.records['lovepillow_' .. c.donor]
    if donor then
      attempt('custom pillow ' .. c.key, function()
        content.miscs.records['lovepillow_' .. c.key] = {
          name = c.name,
          model = string.format('meshes\\lp\\lovepillow_%s.nif', c.key),
          icon = c.icon or donor.icon,
          weight = donor.weight,
          value = donor.value,
        }
      end)
      attempt('custom spell ' .. c.spell, function()
        content.spells.records[c.spell] = {
          name = c.name,
          type = content.spells.TYPE.Ability,
          cost = 0,
          effects = { {
            id = c.effect.id,
            affectedAttribute = c.effect.attribute,
            duration = 0,
            magnitudeMin = c.effect.magnitude,
            magnitudeMax = c.effect.magnitude,
          } },
        }
      end)
    else
      print('LPH load: donor missing for custom pillow ' .. c.key)
    end
  end

  local allNames = {}
  for _, name in ipairs(shared.NAMES) do allNames[#allNames + 1] = name end
  for _, c in ipairs(shared.CUSTOM) do allNames[#allNames + 1] = c.key end

  for _, name in ipairs(allNames) do
    local base = content.miscs.records['lovepillow_' .. name]
    if not base then
      print('LPH load: base record missing: lovepillow_' .. name)
      failed = failed + 3
    else
      for stage = 1, 3 do
        -- id from the known name, not base.id (don't depend on the engine
        -- populating .id on records created via content assignment)
        local sid = shared.stageRecordId('lovepillow_' .. name, stage)
        local tag = shared.STAGE_TAGS[stage]
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
      -- Quarter-opacity copy of the vanilla column (the only smoke that
      -- renders in-game; full-alpha particles read as a glowing core —
      -- tools/make_slow_smoke.py). Spawned as THREE small offset clouds.
      model = 'meshes\\lph\\stinkcloud.nif',
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
