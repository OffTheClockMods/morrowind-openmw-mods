-- Skill Gain Multiplier (OpenMW) by Off the Clock - settings page (Options > Scripts > Skill Gain Multiplier).
-- A MENU script, so the page works from the main menu too. Values live in the player storage (all saves).
local I = require('openmw.interfaces')
local L = require('scripts.OtcSkillGain.logic')

local function number(key, default)
    return {
        key = key, renderer = 'number', name = key, description = key .. 'Desc', default = default,
        argument = { min = L.MIN, max = L.MAX },
    }
end

I.Settings.registerPage({ key = L.PAGE, l10n = L.L10N, name = 'pageName', description = 'pageDesc' })

I.Settings.registerGroup({
    key = L.GROUP, page = L.PAGE, l10n = L.L10N, name = 'groupMain', description = 'groupMainDesc',
    permanentStorage = true, order = 0,
    settings = {
        { key = 'enabled', renderer = 'checkbox', name = 'enabled', description = 'enabledDesc', default = true },
        number('allSkills', 1),
        number('combat', 1),
        number('magic', 1),
        number('stealth', 1),
    },
})

local perSkill = {}
for _, id in ipairs(L.SKILLS) do
    perSkill[#perSkill + 1] = {
        key = id, renderer = 'number', name = 'skill_' .. id, description = 'skillDesc', default = 1,
        argument = { min = L.MIN, max = L.MAX },
    }
end
I.Settings.registerGroup({
    key = L.GROUP_SKILLS, page = L.PAGE, l10n = L.L10N, name = 'groupSkills', description = 'groupSkillsDesc',
    permanentStorage = true, order = 1, settings = perSkill,
})
