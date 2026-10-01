-- Skill Gain Multiplier (OpenMW) by Off the Clock - pure logic (no OpenMW modules, unit-tested offline).
-- OpenMW runs LuaJIT (Lua 5.1 rules): keep this file 5.1-compatible.

local M = {}

M.VERSION = '1.0.0'
M.PAGE = 'OtcSkillGain'
M.L10N = 'OtcSkillGain'
M.GROUP = 'SettingsOtcSkillGain'            -- master switch, all skills, the three specializations
M.GROUP_SKILLS = 'SettingsOtcSkillGainSkills' -- one multiplier per skill
M.MIN, M.MAX = 0, 100                       -- x100 already gives about one skill point per use (the game never
                                            -- gives more than one point per use), so more would change nothing

-- The 27 Morrowind skills by specialization (the game's own grouping; used if a skill record can't be read).
M.SPECIALIZATION = {
    armorer = 'combat', athletics = 'combat', axe = 'combat', block = 'combat', bluntweapon = 'combat',
    heavyarmor = 'combat', longblade = 'combat', mediumarmor = 'combat', spear = 'combat',
    alchemy = 'magic', alteration = 'magic', conjuration = 'magic', destruction = 'magic', enchant = 'magic',
    illusion = 'magic', mysticism = 'magic', restoration = 'magic', unarmored = 'magic',
    acrobatics = 'stealth', handtohand = 'stealth', lightarmor = 'stealth', marksman = 'stealth',
    mercantile = 'stealth', security = 'stealth', shortblade = 'stealth', sneak = 'stealth', speechcraft = 'stealth',
}

-- Settings page order: combat, magic, stealth skills (alphabetical inside each).
M.SKILLS = {
    'armorer', 'athletics', 'axe', 'block', 'bluntweapon', 'heavyarmor', 'longblade', 'mediumarmor', 'spear',
    'alchemy', 'alteration', 'conjuration', 'destruction', 'enchant', 'illusion', 'mysticism', 'restoration',
    'unarmored',
    'acrobatics', 'handtohand', 'lightarmor', 'marksman', 'mercantile', 'security', 'shortblade', 'sneak',
    'speechcraft',
}

--- A setting value as a safe multiplier: numbers only, clamped to 0..100; anything else counts as x1.
function M.clampMultiplier(v)
    v = tonumber(v)
    if v == nil or v ~= v then return 1 end   -- nil or NaN
    if v < M.MIN then return M.MIN end
    if v > M.MAX then return M.MAX end
    return v
end

--- Final multiplier for one skill use = all skills x its specialization x the skill itself.
-- get(key) reads the main group, getSkill(key) the per-skill group (both may return nil = default x1).
function M.multiplier(skillId, specialization, get, getSkill)
    if get('enabled') == false then return 1 end
    local spec = specialization or M.SPECIALIZATION[skillId]
    local m = M.clampMultiplier(get('allSkills'))
    if spec == 'combat' or spec == 'magic' or spec == 'stealth' then
        m = m * M.clampMultiplier(get(spec))
    end
    if getSkill then m = m * M.clampMultiplier(getSkill(skillId)) end
    return m
end

--- Skill-used handler body: scales params.skillGain in place. Returns the multiplier it used.
function M.apply(skillId, params, specialization, get, getSkill)
    if type(params) ~= 'table' or type(params.skillGain) ~= 'number' then return 1 end
    local m = M.multiplier(skillId, specialization, get, getSkill)
    if m ~= 1 then params.skillGain = params.skillGain * m end
    return m
end

return M
