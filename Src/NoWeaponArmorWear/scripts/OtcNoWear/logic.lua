-- No Weapon and Armor Wear (OpenMW) by Off the Clock - pure logic (no OpenMW modules, unit-tested offline).
-- OpenMW runs LuaJIT (Lua 5.1 rules): keep this file 5.1-compatible.
--
-- Wear is a percent of the game's own wear: 0 = never wears, 100 = normal, 1000 = ten times faster.
-- Fractions are carried over per item ("debt"), so 50% really is half the wear over many hits.
-- Faster wear (over 100%) never breaks an item by itself: our extra wear stops at 1 point; the game's own wear can
-- still break it as usual (so a broken item is always the game's decision).

local M = {}

M.VERSION = '1.0.0'
M.PAGE = 'OtcNoWear'
M.L10N = 'OtcNoWear'
M.GROUP = 'SettingsOtcNoWear'
M.MIN_PCT, M.MAX_PCT = 0, 1000

M.DEFAULTS = {
    enabled = true,
    weaponWear = 0,    -- the point of the mod: weapons never wear
    armorWear = 0,     -- armor and shields never wear
    toolWear = 100,    -- lockpicks and probes: game value unless the player opts in
    npcArmor = false,  -- other actors' armor: game value
}

function M.clampPct(v, default)
    v = tonumber(v)
    if v == nil or v ~= v then return default or 100 end
    if v < M.MIN_PCT then return M.MIN_PCT end
    if v > M.MAX_PCT then return M.MAX_PCT end
    return v
end

--- Setting value with the mod default when unset.
function M.setting(get, key)
    local v = get(key)
    if v == nil then return M.DEFAULTS[key] end
    return v
end

--- The game lowered an item's condition from `last` to `now`. Returns the condition the item should have at
-- `pct` percent wear, and the new carried fraction. `max` = the item's full condition.
function M.afterWear(last, now, pct, debt, max)
    debt = debt or 0
    if now >= last then return now, debt end            -- no wear (or a repair): accept the game's value
    if now <= 0 then return now, 0 end                  -- the game broke it: its decision
    local scaled = (last - now) * pct / 100 + debt
    local whole = math.floor(scaled + 1e-9)
    debt = scaled - whole
    local target = last - whole
    if target < now and target < 1 then target = 1 end  -- extra wear never breaks the item
    if max and max > 0 and target > max then target = max end
    if target < 0 then target = 0 end
    return target, debt
end

--- A hit on armor (OpenMW's ModifyItemCondition event, amount < 0). Returns the new condition and fraction.
function M.armorHit(cond, amount, pct, debt, max)
    debt = debt or 0
    if amount >= 0 then
        local c = cond + amount
        if max and max > 0 and c > max then c = max end
        return c, debt
    end
    if cond + amount <= 0 and pct >= 100 then return 0, 0 end   -- the game itself would break it
    local scaled = -amount * pct / 100 + debt
    local whole = math.floor(scaled + 1e-9)
    debt = scaled - whole
    local new = cond - whole
    if new < 1 and cond >= 1 then new = 1 end                   -- our share never breaks it
    if new < 0 then new = 0 end
    return new, debt
end

--- Which wear setting applies to an item kind ('weapon' | 'armor' | 'tool').
function M.pctFor(kind, get)
    if M.setting(get, 'enabled') == false then return 100 end
    if kind == 'weapon' then return M.clampPct(M.setting(get, 'weaponWear'), 0) end
    if kind == 'armor' then return M.clampPct(M.setting(get, 'armorWear'), 0) end
    if kind == 'tool' then return M.clampPct(M.setting(get, 'toolWear'), 100) end
    return 100
end

return M
