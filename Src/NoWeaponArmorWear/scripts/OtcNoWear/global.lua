-- No Weapon and Armor Wear (OpenMW) by Off the Clock - global script.
-- * OtcNoWear_SetCondition: puts an item's condition back (only global scripts may change item condition).
-- * ModifyItemCondition (OpenMW 0.50's own armor-hit event, scripts/omw/combat/local.lua): our handler runs before the
--   game's (newest script first), applies the scaled wear itself, unequips at 0 like the game does, and stops the
--   event (returns false). With 100% wear, or before the player's settings arrived, the game handles it unchanged.
-- Nothing is stored in your save.
local types = require('openmw.types')
local L = require('scripts.OtcNoWear.logic')

local cfg = nil      -- last settings from the player script
local debts = {}     -- item id -> carried fraction (session only)

local function maxCondition(item)
    local ok, rec = pcall(function() return item.type.record(item) end)
    if ok and rec then return rec.health or rec.maxCondition end
    return nil
end

local function onSetCondition(d)
    if d == nil or d.item == nil or not d.item:isValid() or type(d.condition) ~= 'number' then return end
    local max = maxCondition(d.item)
    local c = d.condition
    if max and c > max then c = max end
    if c < 0 then c = 0 end
    types.Item.itemData(d.item).condition = c
end

local function onModifyItemCondition(d)
    if cfg == nil or not cfg.enabled or d == nil or d.item == nil or type(d.amount) ~= 'number' then return end
    if d.amount >= 0 or not d.item:isValid() or not types.Armor.objectIsInstance(d.item) then return end
    local isPlayer = d.actor ~= nil and types.Player.objectIsInstance(d.actor)
    if not isPlayer and not cfg.npcArmor then return end
    local pct = cfg.armorPct                        -- "also NPCs": the same armor wear for everyone
    if pct == 100 then return end                   -- game value: let the game do it
    local data = types.Item.itemData(d.item)
    local new, debt = L.armorHit(data.condition, d.amount, pct, debts[d.item.id], maxCondition(d.item))
    debts[d.item.id] = debt
    data.condition = new
    if d.actor and new <= 0 then d.actor:sendEvent('Unequip', { item = d.item }) end   -- same as the game
    if isPlayer then d.actor:sendEvent('OtcNoWear_Handled', { itemId = d.item.id, condition = new }) end
    return false   -- handled: the game's own handler must not apply the full wear again
end

return {
    interfaceName = 'OtcNoWearGlobal',
    interface = {
        version = L.VERSION,
        config = function() return cfg end,
    },
    eventHandlers = {
        OtcNoWear_Config = function(d) cfg = d end,
        OtcNoWear_SetCondition = onSetCondition,
        ModifyItemCondition = onModifyItemCondition,
    },
}
