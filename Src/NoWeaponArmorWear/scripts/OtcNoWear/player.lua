-- No Weapon and Armor Wear (OpenMW) by Off the Clock - player script.
-- 1. Weapons, shields (blocking), lockpicks and probes: OpenMW's engine lowers their condition directly, so this
--    script watches the items in your hands every frame and asks the global script to put the condition back
--    (only global scripts may change an item's condition).
-- 2. Armor hits go through OpenMW's own Lua event (ModifyItemCondition); the global script scales those before the
--    game applies them. This script sends it your settings (they live in your player settings, not in the save).
local core = require('openmw.core')
local self = require('openmw.self')
local storage = require('openmw.storage')
local types = require('openmw.types')
local L = require('scripts.OtcNoWear.logic')

local Actor = types.Actor
local SLOT = Actor.EQUIPMENT_SLOT
local section = storage.playerSection(L.GROUP)
local function get(key) return section:get(key) end

local tracked = {}   -- slot -> { id, last, debt }

local function kindOf(item)
    if types.Weapon.objectIsInstance(item) then
        local rec = types.Weapon.record(item)
        if rec.type == types.Weapon.TYPE.Arrow or rec.type == types.Weapon.TYPE.Bolt
            or rec.type == types.Weapon.TYPE.MarksmanThrown then return nil end
        return 'weapon', rec.health
    elseif types.Armor.objectIsInstance(item) then
        return 'armor', types.Armor.record(item).health
    elseif types.Lockpick.objectIsInstance(item) then
        return 'tool', types.Lockpick.record(item).maxCondition
    elseif types.Probe.objectIsInstance(item) then
        return 'tool', types.Probe.record(item).maxCondition
    end
    return nil
end

local function watchSlot(slot)
    local item = Actor.getEquipment(self, slot)
    if item == nil or not item:isValid() then tracked[slot] = nil return end
    local kind, max = kindOf(item)
    if kind == nil or max == nil or max <= 0 then tracked[slot] = nil return end
    local now = types.Item.itemData(item).condition
    if now == nil then tracked[slot] = nil return end
    local t = tracked[slot]
    if t == nil or t.id ~= item.id then
        tracked[slot] = { id = item.id, last = now, debt = 0 }
        return
    end
    if now < t.last then
        local target, debt = L.afterWear(t.last, now, L.pctFor(kind, get), t.debt, max)
        t.debt = debt
        if target ~= now then
            core.sendGlobalEvent('OtcNoWear_SetCondition', { item = item, condition = target })
        end
        t.last = target
    else
        t.last = now   -- repaired, or unchanged
    end
end

-- Settings for the global script (armor hits): sent at start and whenever they change.
local pushed, sinceCheck = nil, 0
local function pushConfig(force)
    local cfg = {
        player = self.object,
        enabled = L.setting(get, 'enabled') ~= false,
        armorPct = L.pctFor('armor', get),
        npcArmor = L.setting(get, 'npcArmor') == true,
    }
    if force or pushed == nil or pushed.enabled ~= cfg.enabled or pushed.armorPct ~= cfg.armorPct
        or pushed.npcArmor ~= cfg.npcArmor then
        core.sendGlobalEvent('OtcNoWear_Config', cfg)
        pushed = cfg
    end
end

local function hello()
    tracked = {}
    pushConfig(true)
    print(('[OtcNoWear] No Weapon and Armor Wear %s loaded (OpenMW Lua API %s)'):format(L.VERSION,
        tostring(core.API_REVISION)))
end

return {
    interfaceName = 'OtcNoWear',
    interface = {
        version = L.VERSION,
        --- Current wear percent for 'weapon' | 'armor' | 'tool' (for other mods and our self-check).
        wearPercent = function(kind) return L.pctFor(kind, get) end,
    },
    engineHandlers = {
        onInit = hello,
        onLoad = hello,
        onUpdate = function(dt)
            if L.setting(get, 'enabled') ~= false then
                watchSlot(SLOT.CarriedRight)   -- weapon, lockpick or probe
                watchSlot(SLOT.CarriedLeft)    -- shield
            end
            sinceCheck = sinceCheck + (dt or 0)
            if sinceCheck >= 0.5 then sinceCheck = 0; pushConfig(false) end
        end,
    },
    eventHandlers = {
        -- the global script already scaled an armor hit on this item: don't scale the same wear twice
        OtcNoWear_Handled = function(d)
            for _, t in pairs(tracked) do
                if d and t.id == d.itemId then t.last = d.condition end
            end
        end,
    },
}
