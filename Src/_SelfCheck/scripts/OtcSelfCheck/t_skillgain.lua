-- Self-check for Skill Gain Multiplier: real skill-use events through OpenMW's SkillProgression chain.
-- Our probe handler (runner) sits after the mod's handler, records the gain and stops the event (no progress).
-- Then one unblocked use proves the game's own handler still adds progress. Settings are restored at the end.
local core = require('openmw.core')
local storage = require('openmw.storage')
local types = require('openmw.types')
local I = require('openmw.interfaces')

local USE = 0   -- Weapon_SuccessfulHit / Spellcast_Success (use type 0 of every skill)

return function(ctx, mod)
    local main = storage.playerSection('SettingsOtcSkillGain')
    local skills = storage.playerSection('SettingsOtcSkillGainSkills')
    local saved = { main = main:asTable(), skills = skills:asTable() }

    local function gainOf(skill)
        ctx.skillProbe = {}
        I.SkillProgression.skillUsed(skill, { useType = USE })
        local p = ctx.skillProbe
        ctx.skillProbe = nil
        return p.gain, p.calls
    end
    local function near(a, b) return a and b and math.abs(a - b) < 1e-6 * math.max(1, math.abs(b)) end

    ctx.check(mod, 'defaults are the game values (x1, on)',
        main:get('enabled') == true and main:get('allSkills') == 1 and main:get('combat') == 1
        and skills:get('longblade') == 1, ('enabled=%s all=%s combat=%s longblade=%s'):format(
            tostring(main:get('enabled')), tostring(main:get('allSkills')), tostring(main:get('combat')),
            tostring(skills:get('longblade'))))

    local recLB = core.stats.Skill.record('longblade').skillGain[USE + 1]
    local recDS = core.stats.Skill.record('destruction').skillGain[USE + 1]
    local g1, calls = gainOf('longblade')
    ctx.check(mod, 'x1 leaves the game gain unchanged', calls == 1 and near(g1, recLB),
        ('gain %s, record %s'):format(tostring(g1), tostring(recLB)))

    main:set('allSkills', 10)
    local g10 = gainOf('longblade')
    ctx.check(mod, 'All skills x10 gives 10x the gain', near(g10, 10 * recLB), ('%s vs %s'):format(tostring(g10), tostring(10 * recLB)))

    main:set('combat', 2)
    local gc = gainOf('longblade')
    local gm = gainOf('destruction')
    ctx.check(mod, 'Combat x2 stacks on a combat skill (x20)', near(gc, 20 * recLB), tostring(gc))
    ctx.check(mod, 'Combat x2 leaves a magic skill alone (x10)', near(gm, 10 * recDS), tostring(gm))

    skills:set('longblade', 0)
    local g0 = gainOf('longblade')
    ctx.check(mod, 'Single skill x0 stops that skill', near(g0, 0), tostring(g0))

    main:set('enabled', false)
    local goff = gainOf('longblade')
    ctx.check(mod, 'Mod off = game gain', near(goff, recLB), tostring(goff))

    -- restore the defaults, then one REAL use: the game's own handler must still add progress
    for k, v in pairs(saved.main) do main:set(k, v) end
    for k, v in pairs(saved.skills) do skills:set(k, v) end
    main:set('allSkills', 2)
    local stat = types.NPC.stats.skills.longblade(ctx.self)
    local before, baseBefore = stat.progress, stat.base
    stat.progress = 0
    I.SkillProgression.skillUsed('longblade', { useType = USE })
    local req = I.SkillProgression.getSkillProgressRequirement('longblade')
    local got = stat.progress
    local want = 2 * recLB / req
    ctx.check(mod, 'real skill use at x2 adds 2x progress (game handler still runs)',
        stat.base == baseBefore and near(got, want), ('progress %s, expected %s'):format(tostring(got), tostring(want)))
    stat.progress = before
    main:set('allSkills', saved.main.allSkills or 1)
    ctx.check(mod, 'settings restored', main:get('allSkills') == (saved.main.allSkills or 1) and skills:get('longblade') == 1)
end
