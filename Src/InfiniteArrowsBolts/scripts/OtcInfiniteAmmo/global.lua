-- Infinite Arrows and Bolts (OpenMW) by Off the Clock - global script: gives fired ammo back
-- (only global scripts may create items). Nothing is stored in your save.
local types = require('openmw.types')
local world = require('openmw.world')

local MAX_PER_EVENT = 50   -- a safety cap: one frame never fires more than a handful

local function onRefill(d)
    if d == nil or d.player == nil or not d.player:isValid() or type(d.recordId) ~= 'string' then return end
    local n = math.floor(tonumber(d.count) or 0)
    if n < 1 then return end
    if n > MAX_PER_EVENT then n = MAX_PER_EVENT end
    local ok, rec = pcall(types.Weapon.record, d.recordId)
    if not ok or rec == nil then return end   -- only weapons (arrows, bolts, thrown) are ever given back
    world.createObject(d.recordId, n):moveInto(types.Actor.inventory(d.player))
end

return {
    eventHandlers = { OtcInfiniteAmmo_Refill = onRefill },
}
