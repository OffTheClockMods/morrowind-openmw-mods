-- OTC self-check (TEST ONLY, never shipped): player-side runner for our test tooling.
-- Runs the test file of every OTC mod whose player interface is present, prints
--   [OTC-SC] PASS|FAIL <Mod>: <check> - <detail>, [OTC-SC] SUMMARY <Mod> pass=n fail=m, [OTC-SC] DONE pass=N fail=M
-- into openmw.log, then asks the global helper to quit the game. It never saves.
-- Load order: this content file is listed BEFORE the mods, so its skill-used probe runs AFTER the mods' handlers
-- (OpenMW calls the newest handler first) and can read the gain a mod produced, then stop it (no real progress).
local core = require('openmw.core')
local self = require('openmw.self')
local types = require('openmw.types')
local I = require('openmw.interfaces')

local TAG = '[OTC-SC] '
local function out(s) print(TAG .. s) end

-- mod name (as in the profile) -> player interface name + test file
local TESTS = {
    { mod = 'SkillGainMultiplier', iface = 'OtcSkillGain', file = 'scripts.OtcSelfCheck.t_skillgain' },
    { mod = 'NoWeaponArmorWear', iface = 'OtcNoWear', file = 'scripts.OtcSelfCheck.t_nowear' },
    { mod = 'InfiniteArrowsBolts', iface = 'OtcInfiniteAmmo', file = 'scripts.OtcSelfCheck.t_infiniteammo' },
}

local ctx = { self = self, skillProbe = nil }
local results, totalPass, totalFail = {}, 0, 0
local pending, nextId = {}, 0

function ctx.check(mod, name, ok, detail)
    local r = results[mod] or { pass = 0, fail = 0 }
    results[mod] = r
    if ok then r.pass = r.pass + 1; totalPass = totalPass + 1 else r.fail = r.fail + 1; totalFail = totalFail + 1 end
    out((ok and 'PASS ' or 'FAIL ') .. mod .. ': ' .. name .. (detail and (' - ' .. tostring(detail)) or ''))
    return ok
end

function ctx.info(s) out('INFO ' .. s) end

function ctx.sleep(seconds)
    local t = core.getRealTime() + seconds
    while core.getRealTime() < t do coroutine.yield() end
end

function ctx.frames(n)
    for _ = 1, n do coroutine.yield() end
end

function ctx.waitFor(fn, timeout)
    local t0 = core.getRealTime()
    repeat
        local ok, v = pcall(fn)
        if ok and v then return true end
        coroutine.yield()
    until core.getRealTime() - t0 > (timeout or 3)
    local ok, v = pcall(fn)
    return ok and v and true or false
end

--- Ask the global helper to do something (give/setCondition/remove/quit); waits for its reply (5 s max).
function ctx.global(op, args)
    args = args or {}
    nextId = nextId + 1
    local id = nextId
    args.op, args.id, args.player = op, id, self.object
    core.sendGlobalEvent('OtcSC_Do', args)
    local t0 = core.getRealTime()
    while pending[id] == nil do
        if core.getRealTime() - t0 > 5 then return { ok = false, err = 'timeout waiting for global ' .. op } end
        coroutine.yield()
    end
    local r = pending[id]
    pending[id] = nil
    return r
end

-- Skill-used probe (see the header): records the gain the mods produced and stops the event (no progress).
I.SkillProgression.addSkillUsedHandler(function(skillId, params)
    local p = ctx.skillProbe
    if p then
        p.gain, p.skill, p.calls = params.skillGain, skillId, (p.calls or 0) + 1
        return false
    end
end)

local function safe(f) local ok, v = pcall(f) if ok then return v end return '?' end

local function main()
    ctx.sleep(3)   -- let every script finish its first frames
    out('INFO env: OpenMW Lua API ' .. tostring(core.API_REVISION) .. ', cell ' .. tostring(safe(function() return self.cell.name end))
        .. ', UI mode ' .. tostring(safe(function() return I.UI.getMode() end))
        .. ', stance ' .. tostring(safe(function() return types.Actor.getStance(self) end))
        .. ', coroutine ' .. type(coroutine))
    for _, t in ipairs(TESTS) do
        if I[t.iface] then
            out('MOD ' .. t.mod .. ' present (interface ' .. t.iface .. ' version ' .. tostring(I[t.iface].version) .. ')')
            local okLoad, testFn = pcall(require, t.file)
            if not okLoad then
                ctx.check(t.mod, 'test file loads', false, testFn)
            else
                -- each test runs in its own coroutine, so a crash in one test is a FAIL, not the end of the run
                local co = coroutine.create(testFn)
                local ok, err = coroutine.resume(co, ctx, t.mod)
                while ok and coroutine.status(co) ~= 'dead' do
                    coroutine.yield()
                    ok, err = coroutine.resume(co)
                end
                if not ok then ctx.check(t.mod, 'test ran to the end', false, err) end
            end
            local r = results[t.mod] or { pass = 0, fail = 0 }
            out(('SUMMARY %s pass=%d fail=%d'):format(t.mod, r.pass, r.fail))
        end
    end
    out(('DONE pass=%d fail=%d'):format(totalPass, totalFail))
    ctx.global('quit', { delay = 1 })
end

local runner = nil
local started = core.getRealTime()
local finished = false

return {
    eventHandlers = {
        OtcSC_Reply = function(d) if d and d.id then pending[d.id] = d end end,
    },
    engineHandlers = {
        onInit = function() runner = coroutine.create(main) end,
        onLoad = function() runner = coroutine.create(main) end,
        onFrame = function()   -- every frame, also while a menu pauses the game
            if finished or runner == nil then return end
            if core.getRealTime() - started > 240 then
                finished = true
                out('FAIL runner: overall time limit (240 s) reached')
                out(('DONE pass=%d fail=%d'):format(totalPass, totalFail + 1))
                core.sendGlobalEvent('OtcSC_Do', { op = 'quit', id = -1, player = self.object })
                return
            end
            local ok, err = coroutine.resume(runner)
            if not ok then
                finished = true
                out('FAIL runner: crashed - ' .. tostring(err))
                out(('DONE pass=%d fail=%d'):format(totalPass, totalFail + 1))
                core.sendGlobalEvent('OtcSC_Do', { op = 'quit', id = -1, player = self.object })
            elseif coroutine.status(runner) == 'dead' then
                finished = true
            end
        end,
    },
}
