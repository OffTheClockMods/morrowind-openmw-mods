-- OTC self-check (TEST ONLY, never shipped): global helper. Does what only global scripts may do (create, remove
-- and change items) for the player-side test runner, and quits the game at the end (core.quit, testing only).
local core = require('openmw.core')
local types = require('openmw.types')
local world = require('openmw.world')

local TAG = '[OTC-SC] '
local quitAt = nil

local function reply(player, id, data)
    data = data or {}
    data.id = id
    player:sendEvent('OtcSC_Reply', data)
end

local ops = {}

function ops.give(d)
    local obj = world.createObject(d.record, d.count or 1)
    obj:moveInto(types.Actor.inventory(d.player))
    return { item = obj }
end

function ops.setCondition(d)
    types.Item.itemData(d.item).condition = d.value
    return { value = types.Item.itemData(d.item).condition }
end

function ops.remove(d)
    if d.item:isValid() and d.item.count > 0 then d.item:remove(math.min(d.count or 1, d.item.count)) end
    return {}
end

function ops.quit(d)
    quitAt = core.getRealTime() + (d.delay or 1)
    return {}
end

return {
    eventHandlers = {
        OtcSC_Do = function(d)
            local f = ops[d.op]
            if not f then reply(d.player, d.id, { ok = false, err = 'unknown op ' .. tostring(d.op) }) return end
            local ok, res = pcall(f, d)
            if ok then
                res.ok = true
                reply(d.player, d.id, res)
            else
                print(TAG .. 'INFO global op ' .. tostring(d.op) .. ' failed: ' .. tostring(res))
                reply(d.player, d.id, { ok = false, err = tostring(res) })
            end
        end,
    },
    engineHandlers = {
        onUpdate = function()
            if quitAt and core.getRealTime() >= quitAt then
                quitAt = nil
                print(TAG .. 'INFO quitting (core.quit)')
                core.quit()
            end
        end,
    },
}
