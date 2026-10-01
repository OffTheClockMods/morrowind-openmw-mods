-- Skill Gain Multiplier (OpenMW) by Off the Clock - player script.
-- Scales the skill progress you get from USING a skill (hits, spells, jumps, lockpicking...). Books, trainers and
-- jail are untouched. Uses OpenMW's own SkillProgression interface (0.49+): nothing is written to your save.
local core = require('openmw.core')
local storage = require('openmw.storage')
local I = require('openmw.interfaces')
local L = require('scripts.OtcSkillGain.logic')

local main = storage.playerSection(L.GROUP)
local skills = storage.playerSection(L.GROUP_SKILLS)

local function get(key) return main:get(key) end
local function getSkill(key) return skills:get(key) end

local specCache = {}
local function specialization(skillId)
    local s = specCache[skillId]
    if s == nil then
        local ok, rec = pcall(function() return core.stats.Skill.record(skillId) end)
        s = (ok and rec and rec.specialization) or L.SPECIALIZATION[skillId] or false
        specCache[skillId] = s
    end
    return s or nil
end

local function onSkillUsed(skillId, params)
    local ok, err = pcall(L.apply, skillId, params, specialization(skillId), get, getSkill)
    if not ok then print('[OtcSkillGain] error: ' .. tostring(err)) end
    -- never return false: the game's own handler must still add the progress
end

-- Registered in the script body (OpenMW's advice for load order). Handlers run newest first, so ours scales the
-- gain before the game's own progress handler (and before mods loaded earlier) uses it.
I.SkillProgression.addSkillUsedHandler(onSkillUsed)

local function hello()
    print(('[OtcSkillGain] Skill Gain Multiplier %s loaded (OpenMW Lua API %s)'):format(L.VERSION,
        tostring(core.API_REVISION)))
end

return {
    interfaceName = 'OtcSkillGain',
    interface = {
        version = L.VERSION,
        --- Current multiplier for a skill (for other mods and our self-check).
        multiplier = function(skillId) return L.multiplier(skillId, specialization(skillId), get, getSkill) end,
    },
    engineHandlers = { onInit = hello, onLoad = hello },
}
