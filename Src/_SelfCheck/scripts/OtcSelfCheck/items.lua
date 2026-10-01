-- OTC self-check helpers: pick vanilla test items from the loaded records, give and equip them.
local self = require('openmw.self')
local types = require('openmw.types')

local Actor = types.Actor
local H = {}

local function first(records, pred)
    for _, r in ipairs(records) do
        local ok, hit = pcall(pred, r)
        if ok and hit then return r.id end
    end
    return nil
end

-- a normal shop item: has a name, value and weight, no enchantment, not an effect-only record
local function real(r)
    return r.name ~= nil and r.name ~= '' and r.value > 0 and r.weight > 0 and (r.enchant == nil or r.enchant == '')
        and not r.id:find('^vfx')
end

function H.records()
    local W, A = types.Weapon, types.Armor
    return {
        melee = first(W.records, function(r) return r.type == W.TYPE.LongBladeOneHand and r.health >= 100 and r.enchant == nil end)
            or first(W.records, function(r) return r.type ~= W.TYPE.Arrow and r.type ~= W.TYPE.Bolt and r.health >= 50 end),
        bow = first(W.records, function(r) return r.type == W.TYPE.MarksmanBow and r.health >= 50 end),
        arrow = first(W.records, function(r) return r.id == 'iron arrow' end)
            or first(W.records, function(r) return r.type == W.TYPE.Arrow and real(r) end),
        thrown = first(W.records, function(r) return r.type == W.TYPE.MarksmanThrown and real(r) end),
        cuirass = first(A.records, function(r) return r.type == A.TYPE.Cuirass and r.health >= 100 end),
        shield = first(A.records, function(r) return r.type == A.TYPE.Shield and r.health >= 100 end),
        lockpick = first(types.Lockpick.records, function(r) return r.maxCondition >= 5 end),
    }
end

function H.give(ctx, recordId, count)
    local r = ctx.global('give', { record = recordId, count = count or 1 })
    return r.ok and r.item or nil, r.err
end

function H.equip(ctx, slot, item)
    local eq = Actor.getEquipment(self)
    eq[slot] = item
    Actor.setEquipment(self, eq)
    return ctx.waitFor(function()
        local now = Actor.getEquipment(self, slot)
        if item == nil then return now == nil end
        return now ~= nil and now.id == item.id
    end, 3)
end

function H.cond(item) return types.Item.itemData(item).condition end

function H.setCond(ctx, item, value)
    local r = ctx.global('setCondition', { item = item, value = value })
    return r.ok
end

return H
