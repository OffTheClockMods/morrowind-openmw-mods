-- Infinite Arrows and Bolts (OpenMW) by Off the Clock - player script.
-- Watches your equipped arrows/bolts and thrown weapons. When you shoot (weapon drawn, no menu open) and the stack
-- gets smaller, the global script puts the same number back into your inventory.
-- OpenMW never stacks new items onto an EQUIPPED stack (engine: ContainerStore::addImp "Don't stack with equipped
-- items"), so the returned ammo waits in a second stack of the same arrows. Your total never goes down:
-- if the equipped stack runs out, the biggest stack of the same ammo is equipped again at once. (Joining the stacks
-- by script would need extra equip calls, which in tests re-drew the weapon, so the mod leaves them as they are.)
-- Nothing is stored in your save.
local core = require('openmw.core')
local self = require('openmw.self')
local storage = require('openmw.storage')
local types = require('openmw.types')
local I = require('openmw.interfaces')
local L = require('scripts.OtcInfiniteAmmo.logic')

local Actor, Weapon = types.Actor, types.Weapon
local SLOT = Actor.EQUIPMENT_SLOT
local section = storage.playerSection(L.GROUP)
local function get(key) return section:get(key) end

local state = {}       -- slot -> { id, recordId, count }
local pending = {}     -- slot -> recordId to equip again (after the last shot)
local lastReady = false

local function ammoIn(slot)
    local item = Actor.getEquipment(self, slot)
    if item == nil or not item:isValid() or not Weapon.objectIsInstance(item) then return nil end
    if item.count <= 0 then return nil end   -- seen in 0.50: a used-up stack stays in the slot with count 0
    local t = Weapon.record(item).type
    if slot == SLOT.Ammunition and (t == Weapon.TYPE.Arrow or t == Weapon.TYPE.Bolt) then
        return { id = item.id, recordId = item.recordId, count = item.count }
    end
    if slot == SLOT.CarriedRight and t == Weapon.TYPE.MarksmanThrown then
        return { id = item.id, recordId = item.recordId, count = item.count }
    end
    return nil
end

local function menuOpen()
    local ok, mode = pcall(function() return I.UI.getMode() end)
    return not ok or mode ~= nil
end

--- The biggest stack of this ammo in the inventory (the reserve that collected the returned ammo).
local function biggestStack(recordId)
    local best = nil
    local ok, list = pcall(function() return Actor.inventory(self):findAll(recordId) end)
    if not ok or list == nil then return nil end
    for _, it in ipairs(list) do
        if it:isValid() and (best == nil or it.count > best.count) then best = it end
    end
    return best
end

local function equipNow(slot, item)
    local eq = Actor.getEquipment(self)
    eq[slot] = item
    local ok, err = pcall(Actor.setEquipment, self, eq)
    print(('[OtcInfiniteAmmo] stack ran out: equipping %s x%d (%s)'):format(item.recordId, item.count,
        ok and 'ok' or tostring(err)))
end

local function watch(slot, allowed, ready)
    local prev = state[slot]
    local cur = ammoIn(slot)
    local refill, reequip, nextState = L.step(prev, cur, ready, allowed)
    if refill > 0 then
        core.sendGlobalEvent('OtcInfiniteAmmo_Refill', {
            player = self.object, recordId = (cur or prev).recordId, count = refill,
        })
        if reequip then pending[slot] = prev.recordId end
    end
    state[slot] = nextState
end

local function onFrame()
    if L.setting(get, 'enabled') == false then state, pending = {}, {} return end
    -- equip again what is waiting (once the given-back last arrow, or the reserve stack, is in the inventory)
    for slot, recordId in pairs(pending) do
        local now = Actor.getEquipment(self, slot)   -- right after the last shot this can still be the used-up stack
        if now ~= nil and now:isValid() and now.count > 0 then
            pending[slot] = nil
        else
            local item = biggestStack(recordId)
            if item then equipNow(slot, item); pending[slot] = nil end
        end
    end
    local drawn = Actor.getStance(self) == Actor.STANCE.Weapon
    local menu = menuOpen()
    local ready = drawn and not menu
    lastReady = ready
    local arrowsOn, thrownOn = L.setting(get, 'arrowsBolts') ~= false, L.setting(get, 'thrown') ~= false
    watch(SLOT.Ammunition, arrowsOn, ready)
    watch(SLOT.CarriedRight, thrownOn, ready)
end

local function hello()
    state, pending = {}, {}
    print(('[OtcInfiniteAmmo] Infinite Arrows and Bolts %s loaded (OpenMW Lua API %s)'):format(L.VERSION,
        tostring(core.API_REVISION)))
end

return {
    interfaceName = 'OtcInfiniteAmmo',
    interface = {
        version = L.VERSION,
        --- Whether the last frame counted as "can shoot" (weapon drawn, no menu). For our self-check.
        lastReady = function() return lastReady end,
    },
    -- onFrame runs every frame even while a menu has the game paused, so ammo dropped or sold in a menu is seen
    -- (and never refilled) before the menu closes.
    engineHandlers = { onInit = hello, onLoad = hello, onFrame = onFrame },
}
