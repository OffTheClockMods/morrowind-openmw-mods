-- Self-check for Infinite Arrows and Bolts. A "shot" is simulated the way the engine does it: the equipped stack
-- gets smaller (global helper remove) while the weapon is drawn and no menu is open.
-- OpenMW never stacks new items onto an equipped stack, so the check counts ALL stacks of the ammo (the total must
-- stay the same), and checks that the reserve stack is equipped when the equipped stack runs out.
-- Controls: with the option off, or the weapon sheathed, the ammo must NOT come back.
-- Order matters: the weapon is drawn once and kept drawn until the sheathed control at the very end (in tests,
-- equip changes right after a stance change could undo the stance).
local self = require('openmw.self')
local storage = require('openmw.storage')
local types = require('openmw.types')
local I = require('openmw.interfaces')
local H = require('scripts.OtcSelfCheck.items')

local Actor = types.Actor
local SLOT = Actor.EQUIPMENT_SLOT

return function(ctx, mod)
    local s = storage.playerSection('SettingsOtcInfiniteAmmo')
    local saved = s:asTable()
    ctx.check(mod, 'defaults (on, arrows and bolts on, thrown on)',
        s:get('enabled') == true and s:get('arrowsBolts') == true and s:get('thrown') == true)

    local rec = H.records()
    ctx.info('Ammo test items: ' .. tostring(rec.bow) .. ', ' .. tostring(rec.arrow) .. ', ' .. tostring(rec.thrown))
    local bow, arrows, thrown = H.give(ctx, rec.bow), H.give(ctx, rec.arrow, 20), H.give(ctx, rec.thrown, 10)
    if not ctx.check(mod, 'test items created', bow and arrows and thrown) then return end
    if not ctx.check(mod, 'bow and arrows equipped',
        H.equip(ctx, SLOT.CarriedRight, bow) and H.equip(ctx, SLOT.Ammunition, arrows)) then return end

    local function stance(v)
        Actor.setStance(self, v)
        return ctx.waitFor(function() return Actor.getStance(self) == v end, 3)
    end
    local function equipped(slot) return Actor.getEquipment(self, slot) end
    local function countIn(slot) local it = equipped(slot) return it and it.count or 0 end
    local function total(recordId)
        local t = 0
        for _, it in ipairs(Actor.inventory(self):findAll(recordId)) do t = t + it.count end
        return t
    end
    local function stacks(recordId)
        local out = {}
        for _, it in ipairs(Actor.inventory(self):findAll(recordId)) do out[#out + 1] = it.count end
        return table.concat(out, '+')
    end
    local function shoot(slot, n) ctx.global('remove', { item = equipped(slot), count = n or 1 }) end

    if not ctx.check(mod, 'weapon drawn', stance(Actor.STANCE.Weapon), 'stance ' .. tostring(Actor.getStance(self))) then return end
    ctx.frames(3)

    shoot(SLOT.Ammunition, 1)
    ctx.check(mod, 'fired arrow comes back (total stays 20)', ctx.waitFor(function() return total(rec.arrow) == 20 end, 2),
        'stacks ' .. stacks(rec.arrow))
    shoot(SLOT.Ammunition, 3)
    ctx.check(mod, 'three shots in one frame come back (total 20)', ctx.waitFor(function() return total(rec.arrow) == 20 end, 2),
        'stacks ' .. stacks(rec.arrow))

    -- shoot the equipped stack down to its last arrow, then the last one: the reserve must be equipped
    shoot(SLOT.Ammunition, countIn(SLOT.Ammunition) - 1)
    ctx.waitFor(function() return countIn(SLOT.Ammunition) == 1 and total(rec.arrow) == 20 end, 2)
    ctx.info('before the last arrow: stacks ' .. stacks(rec.arrow) .. ', equipped ' .. countIn(SLOT.Ammunition))
    shoot(SLOT.Ammunition, 1)
    ctx.check(mod, 'last arrow fired: the full reserve stack is equipped (20)',
        ctx.waitFor(function() return countIn(SLOT.Ammunition) == 20 end, 3),
        'stacks ' .. stacks(rec.arrow) .. ', equipped ' .. countIn(SLOT.Ammunition) .. ', stance ' .. Actor.getStance(self))

    -- menus: the mod's own per-frame check must see "not ready" while a menu pauses the game
    local before = I.OtcInfiniteAmmo.lastReady()
    I.UI.setMode('Interface')
    ctx.frames(5)
    local during = I.OtcInfiniteAmmo.lastReady()
    I.UI.setMode()
    ctx.frames(5)
    ctx.check(mod, 'menu open = not ready (the mod keeps watching while the game is paused)',
        before == true and during == false and I.OtcInfiniteAmmo.lastReady() == true,
        ('before %s, in menu %s, after %s'):format(tostring(before), tostring(during), tostring(I.OtcInfiniteAmmo.lastReady())))

    -- control: arrows option off = used up
    s:set('arrowsBolts', false)
    ctx.frames(2)
    shoot(SLOT.Ammunition, 1)
    ctx.sleep(0.5)
    ctx.check(mod, 'control: arrows option off = used up (19)', total(rec.arrow) == 19, 'stacks ' .. stacks(rec.arrow))
    s:set('arrowsBolts', true)
    ctx.frames(2)

    -- thrown weapons
    if ctx.check(mod, 'thrown weapon equipped', H.equip(ctx, SLOT.CarriedRight, thrown)) then
        if Actor.getStance(self) ~= Actor.STANCE.Weapon then stance(Actor.STANCE.Weapon) end
        ctx.frames(3)
        ctx.info('thrown: stance ' .. Actor.getStance(self))
        shoot(SLOT.CarriedRight, 1)
        ctx.check(mod, 'thrown weapon comes back (total 10)', ctx.waitFor(function() return total(rec.thrown) == 10 end, 2),
            'stacks ' .. stacks(rec.thrown))
        s:set('thrown', false)
        ctx.frames(2)
        shoot(SLOT.CarriedRight, 1)
        ctx.sleep(0.5)
        ctx.check(mod, 'control: thrown option off = used up (9)', total(rec.thrown) == 9, 'stacks ' .. stacks(rec.thrown))
        s:set('thrown', true)
        ctx.frames(2)
    end

    -- control: weapon sheathed (selling, dropping and giving happen with the weapon away or in a menu)
    local sheathed = stance(Actor.STANCE.Nothing)
    ctx.frames(5)
    local t0 = total(rec.thrown)
    shoot(SLOT.CarriedRight, 1)
    ctx.sleep(0.5)
    ctx.check(mod, 'control: weapon sheathed = no refill', sheathed and total(rec.thrown) == t0 - 1,
        ('sheathed %s (stance %s), total %s -> %s'):format(tostring(sheathed), Actor.getStance(self), t0, total(rec.thrown)))

    for k, v in pairs(saved) do s:set(k, v) end
    ctx.check(mod, 'settings restored', s:get('thrown') == true and s:get('enabled') == true and s:get('arrowsBolts') == true)
end
