-- Self-check for No Weapon and Armor Wear. Two real paths:
-- * engine wear (weapon, shield block, lockpick): the test lowers the condition through the global helper, exactly
--   like the engine does, and the mod must put it back (or scale it) within a moment;
-- * armor hits: the test sends OpenMW's own ModifyItemCondition event, exactly like scripts/omw/combat/local.lua.
-- Controls: the same steps at 100% must show the normal wear (proves the checks can fail).
local core = require('openmw.core')
local self = require('openmw.self')
local storage = require('openmw.storage')
local types = require('openmw.types')
local I = require('openmw.interfaces')
local H = require('scripts.OtcSelfCheck.items')

local SLOT = types.Actor.EQUIPMENT_SLOT

return function(ctx, mod)
    local s = storage.playerSection('SettingsOtcNoWear')
    local saved = s:asTable()
    local function set(k, v) s:set(k, v); ctx.sleep(0.8) end   -- the mod sends armor settings every 0.5 s

    ctx.check(mod, 'defaults (weapons 0%, armor 0%, tools 100%, NPC armor off)',
        I.OtcNoWear.wearPercent('weapon') == 0 and I.OtcNoWear.wearPercent('armor') == 0
        and I.OtcNoWear.wearPercent('tool') == 100 and s:get('npcArmor') == false,
        ('weapon %s armor %s tool %s'):format(I.OtcNoWear.wearPercent('weapon'), I.OtcNoWear.wearPercent('armor'),
            I.OtcNoWear.wearPercent('tool')))

    local rec = H.records()
    ctx.info('NoWear test items: ' .. tostring(rec.melee) .. ', ' .. tostring(rec.cuirass) .. ', ' .. tostring(rec.shield)
        .. ', ' .. tostring(rec.lockpick))
    local weapon, cuirass, shield, pick = H.give(ctx, rec.melee), H.give(ctx, rec.cuirass), H.give(ctx, rec.shield),
        H.give(ctx, rec.lockpick)
    if not ctx.check(mod, 'test items created', weapon and cuirass and shield and pick) then return end
    local okEq = H.equip(ctx, SLOT.CarriedRight, weapon) and H.equip(ctx, SLOT.Cuirass, cuirass)
        and H.equip(ctx, SLOT.CarriedLeft, shield)
    if not ctx.check(mod, 'test items equipped', okEq) then return end
    ctx.frames(3)

    -- weapon: engine-style wear is undone
    local wMax = H.cond(weapon)
    H.setCond(ctx, weapon, wMax - 5)
    ctx.check(mod, 'weapon wear undone at 0%', ctx.waitFor(function() return H.cond(weapon) == wMax end, 2),
        ('condition %s, full %s'):format(H.cond(weapon), wMax))

    set('weaponWear', 50)
    H.setCond(ctx, weapon, wMax - 4)
    ctx.check(mod, 'weapon at 50%: 4 points of wear become 2',
        ctx.waitFor(function() return H.cond(weapon) == wMax - 2 end, 2), 'condition ' .. H.cond(weapon))

    set('weaponWear', 300)
    local c0 = H.cond(weapon)
    H.setCond(ctx, weapon, c0 - 2)
    ctx.check(mod, 'weapon at 300%: 2 points of wear become 6',
        ctx.waitFor(function() return H.cond(weapon) == c0 - 6 end, 2), ('condition %s, start %s'):format(H.cond(weapon), c0))

    set('weaponWear', 100)
    c0 = H.cond(weapon)
    H.setCond(ctx, weapon, c0 - 3)
    ctx.sleep(0.5)
    ctx.check(mod, 'control: weapon at 100% keeps the normal wear', H.cond(weapon) == c0 - 3, 'condition ' .. H.cond(weapon))
    set('weaponWear', 0)

    -- repair is accepted (a rise in condition is never undone)
    H.setCond(ctx, weapon, wMax)
    ctx.sleep(0.3)
    ctx.check(mod, 'repair accepted', H.cond(weapon) == wMax, 'condition ' .. H.cond(weapon))

    -- armor: OpenMW's own ModifyItemCondition event
    local aMax = H.cond(cuirass)
    core.sendGlobalEvent('ModifyItemCondition', { actor = self.object, item = cuirass, amount = -7 })
    ctx.sleep(0.5)
    ctx.check(mod, 'armor hit ignored at 0%', H.cond(cuirass) == aMax, ('condition %s, full %s'):format(H.cond(cuirass), aMax))

    set('armorWear', 100)
    core.sendGlobalEvent('ModifyItemCondition', { actor = self.object, item = cuirass, amount = -7 })
    ctx.check(mod, 'control: armor at 100% takes the normal 7 points',
        ctx.waitFor(function() return H.cond(cuirass) == aMax - 7 end, 2), 'condition ' .. H.cond(cuirass))

    set('armorWear', 50)
    c0 = H.cond(cuirass)
    core.sendGlobalEvent('ModifyItemCondition', { actor = self.object, item = cuirass, amount = -8 })
    ctx.check(mod, 'armor at 50%: an 8-point hit costs 4',
        ctx.waitFor(function() return H.cond(cuirass) == c0 - 4 end, 2), 'condition ' .. H.cond(cuirass))
    set('armorWear', 0)

    -- shield: block wear is engine-side, like the weapon
    local sMax = H.cond(shield)
    H.setCond(ctx, shield, sMax - 3)
    ctx.check(mod, 'shield block wear undone at 0%', ctx.waitFor(function() return H.cond(shield) == sMax end, 2),
        'condition ' .. H.cond(shield))

    -- lockpick: game value by default, never runs out at 0%
    if H.equip(ctx, SLOT.CarriedRight, pick) then
        ctx.frames(3)
        local p0 = H.cond(pick)
        H.setCond(ctx, pick, p0 - 1)
        ctx.sleep(0.5)
        ctx.check(mod, 'lockpick at 100% (default) uses up normally', H.cond(pick) == p0 - 1, 'uses ' .. H.cond(pick))
        set('toolWear', 0)
        p0 = H.cond(pick)
        H.setCond(ctx, pick, p0 - 1)
        ctx.check(mod, 'lockpick at 0% keeps its uses', ctx.waitFor(function() return H.cond(pick) == p0 end, 2),
            'uses ' .. H.cond(pick))
        set('toolWear', 100)
    else
        ctx.check(mod, 'lockpick equipped', false)
    end

    -- master switch off = normal wear
    H.equip(ctx, SLOT.CarriedRight, weapon)
    ctx.frames(3)
    set('enabled', false)
    c0 = H.cond(weapon)
    H.setCond(ctx, weapon, c0 - 2)
    ctx.sleep(0.5)
    ctx.check(mod, 'mod off = normal weapon wear', H.cond(weapon) == c0 - 2, 'condition ' .. H.cond(weapon))

    for k, v in pairs(saved) do s:set(k, v) end
    ctx.sleep(0.8)
    ctx.check(mod, 'settings restored', I.OtcNoWear.wearPercent('weapon') == 0 and s:get('enabled') == true)
    H.equip(ctx, SLOT.CarriedRight, nil)
    H.equip(ctx, SLOT.CarriedLeft, nil)
    H.equip(ctx, SLOT.Cuirass, nil)
end
