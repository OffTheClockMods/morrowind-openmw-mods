-- Infinite Arrows and Bolts (OpenMW) by Off the Clock - pure logic (no OpenMW modules, unit-tested offline).
-- OpenMW runs LuaJIT (Lua 5.1 rules): keep this file 5.1-compatible.
--
-- A shot = the equipped stack got smaller while your weapon is drawn and no menu is open. Only then the fired
-- ammo comes back. Selling, dropping, giving or moving ammo always happens in a menu, so it is never refilled.

local M = {}

M.VERSION = '1.0.0'
M.PAGE = 'OtcInfiniteAmmo'
M.L10N = 'OtcInfiniteAmmo'
M.GROUP = 'SettingsOtcInfiniteAmmo'
M.DEFAULTS = { enabled = true, arrowsBolts = true, thrown = true }

function M.setting(get, key)
    local v = get(key)
    if v == nil then return M.DEFAULTS[key] end
    return v
end

--- Decide what to do for one slot this frame.
-- prev: { id, recordId, count } from the last frame or nil; cur: the same for the item now in the slot, or nil.
-- ready: weapon drawn and no menu open; allowed: this kind of ammo is switched on.
-- Returns refill (number of items to give back, 0 = none), reequip (true when the stack ran out), next state.
function M.step(prev, cur, ready, allowed)
    if not allowed then return 0, false, cur end
    if cur ~= nil then
        if prev ~= nil and ready and prev.id == cur.id and cur.count < prev.count then
            return prev.count - cur.count, false, cur
        end
        return 0, false, cur
    end
    -- the slot is empty now
    if prev ~= nil and ready and prev.count == 1 then
        return 1, true, nil   -- the last arrow was fired: give it back and equip it again
    end
    return 0, false, nil
end

return M
