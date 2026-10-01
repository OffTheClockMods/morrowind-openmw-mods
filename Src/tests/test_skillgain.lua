-- Skill Gain Multiplier: logic + the real player/menu scripts against the stub API.
return function(T)
    local MOD = 'SkillGainMultiplier'
    local env = T.fresh(MOD)
    local L = require('scripts.OtcSkillGain.logic')

    -- logic
    local vals = {}
    local function get(k) return vals[k] end
    local skillVals = {}
    local function getSkill(k) return skillVals[k] end
    T.check('defaults (nothing set) = x1', L.multiplier('longblade', 'combat', get, getSkill) == 1)
    vals.allSkills = 3
    T.check('all skills x3', L.multiplier('longblade', 'combat', get, getSkill) == 3)
    vals.combat = 2
    T.check('combat stacks (x6)', L.multiplier('longblade', 'combat', get, getSkill) == 6)
    T.check('magic skill ignores combat (x3)', L.multiplier('destruction', 'magic', get, getSkill) == 3)
    skillVals.longblade = 0.5
    T.check('single skill stacks (x3)', L.multiplier('longblade', 'combat', get, getSkill) == 3)
    T.check('fallback specialization table', L.multiplier('longblade', nil, get, getSkill) == 3)
    vals.enabled = false
    T.check('off = x1', L.multiplier('longblade', 'combat', get, getSkill) == 1)
    T.check('clamp: above max', L.clampMultiplier(1e9) == L.MAX)
    T.check('clamp: negative', L.clampMultiplier(-5) == 0)
    T.check('clamp: text/nil/NaN = x1', L.clampMultiplier('abc') == 1 and L.clampMultiplier(nil) == 1 and L.clampMultiplier(0 / 0) == 1)
    T.check('27 skills, each with a specialization', #L.SKILLS == 27 and (function()
        for _, id in ipairs(L.SKILLS) do if not L.SPECIALIZATION[id] then return false end end
        return true end)())
    local p = { skillGain = 2 }
    vals = { allSkills = 5 }
    T.check('apply scales params.skillGain', L.apply('sneak', p, 'stealth', get, nil) == 5 and p.skillGain == 10)
    T.check('apply ignores bad params', L.apply('sneak', nil, 'stealth', get, nil) == 1)

    -- menu registers a page + two groups whose defaults are the game values
    T.load(MOD, 'scripts/OtcSkillGain/menu.lua')
    local groups, page = {}, nil
    for _, r in ipairs(env.registered) do
        if r.page then page = r.page end
        if r.group then groups[r.group.key] = r.group end
    end
    T.check('menu: page registered', page and page.key == L.PAGE)
    local g, gs = groups[L.GROUP], groups[L.GROUP_SKILLS]
    T.check('menu: both groups, permanent storage', g and gs and g.permanentStorage and gs.permanentStorage)
    local allDefault = true
    for _, s in ipairs(g.settings) do
        if s.key ~= 'enabled' and s.default ~= 1 then allDefault = false end
        if s.renderer == 'number' and (s.argument.min ~= 0 or s.argument.max ~= 100) then allDefault = false end
    end
    for _, s in ipairs(gs.settings) do if s.default ~= 1 then allDefault = false end end
    T.check('menu: every multiplier defaults to x1 with range 0-100', allDefault and #gs.settings == 27)

    -- l10n has a text for every key the menu uses
    local f = io.open(T.src .. '/' .. MOD .. '/l10n/OtcSkillGain/en.yaml', 'r')
    local yaml = f and f:read('*a') or ''
    if f then f:close() end
    local missing = {}
    local function need(k) if not yaml:find('\n' .. k .. ':', 1, true) and not yaml:find('^' .. k .. ':') then missing[#missing + 1] = k end end
    need(page.name); need(page.description); need(g.name); need(g.description); need(gs.name); need(gs.description)
    for _, s in ipairs(g.settings) do need(s.name); need(s.description) end
    for _, s in ipairs(gs.settings) do need(s.name); need(s.description) end
    T.check('l10n: every page/group/setting text exists', #missing == 0, table.concat(missing, ', '))

    -- player script: registers a skill handler in its body; the game's own handler (registered first) sees the
    -- scaled gain because ours runs first
    local seenByGame = nil
    env.I.SkillProgression.addSkillUsedHandler(function(_, params) seenByGame = params.skillGain end)
    local handlers = T.load(MOD, 'scripts/OtcSkillGain/player.lua')
    T.check('player: one handler added', #env.skillHandlers == 2)
    T.check('player: interface', handlers.interfaceName == 'OtcSkillGain' and handlers.interface.version == L.VERSION)
    handlers.engineHandlers.onInit()
    T.check('player: hello line', env.printed[#env.printed]:find('Skill Gain Multiplier', 1, true) ~= nil)
    local sec = env.storage.playerSection(L.GROUP)
    env.skillUsed('longblade', 1)
    T.check('player: unset settings = game gain', seenByGame == 1, seenByGame)
    sec:set('allSkills', 4); sec:set('combat', 2)
    env.skillUsed('longblade', 1)
    T.check('player: x4 all, x2 combat = x8 for Long Blade', seenByGame == 8, seenByGame)
    env.skillUsed('destruction', 1)
    T.check('player: magic skill only x4', seenByGame == 4, seenByGame)
    env.storage.playerSection(L.GROUP_SKILLS):set('destruction', 0)
    env.skillUsed('destruction', 1)
    T.check('player: single skill x0', seenByGame == 0, seenByGame)
    T.check('player: interface multiplier', handlers.interface.multiplier('longblade') == 8)
    env.skillUsed('nonsense_skill', 1)
    T.check('player: unknown skill falls back safely (x4)', seenByGame == 4, seenByGame)
end
