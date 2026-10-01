-- Infinite Arrows and Bolts: logic + the real player/global/menu scripts against the stub API.
-- The stub inventory (like OpenMW's ContainerStore::addImp) never stacks new items onto the equipped stack.
return function(T)
    local MOD = 'InfiniteArrowsBolts'
    local env = T.fresh(MOD)
    local L = require('scripts.OtcInfiniteAmmo.logic')

    -- logic: step(prev, cur, ready, allowed)
    local a = { id = 'x', recordId = 'iron arrow', count = 20 }
    local n, re = L.step(a, { id = 'x', recordId = 'iron arrow', count = 19 }, true, true)
    T.check('shot while ready: refill 1', n == 1 and re == false)
    n = L.step(a, { id = 'x', recordId = 'iron arrow', count = 19 }, false, true)
    T.check('not ready (sheathed / menu): no refill', n == 0)
    n = L.step(a, { id = 'y', recordId = 'iron arrow', count = 19 }, true, true)
    T.check('different stack: no refill', n == 0)
    n = L.step(a, { id = 'x', recordId = 'iron arrow', count = 25 }, true, true)
    T.check('more arrows (picked up): no refill', n == 0)
    n, re = L.step({ id = 'x', recordId = 'iron arrow', count = 1 }, nil, true, true)
    T.check('last arrow fired: refill 1 + equip again', n == 1 and re == true)
    n = L.step({ id = 'x', recordId = 'iron arrow', count = 5 }, nil, true, true)
    T.check('stack of 5 vanished (unequipped): no refill', n == 0)
    n = L.step(a, { id = 'x', recordId = 'iron arrow', count = 19 }, true, false)
    T.check('kind switched off: no refill', n == 0)

    -- menu
    T.load(MOD, 'scripts/OtcInfiniteAmmo/menu.lua')
    local g
    for _, r in ipairs(env.registered) do if r.group then g = r.group end end
    local def = {}
    for _, s in ipairs(g.settings) do def[s.key] = s.default end
    T.check('menu defaults all on', def.enabled == true and def.arrowsBolts == true and def.thrown == true)

    -- player + global
    local SLOT, STANCE = env.types.Actor.EQUIPMENT_SLOT, env.types.Actor.STANCE
    local player = T.load(MOD, 'scripts/OtcInfiniteAmmo/player.lua')
    local global = T.load(MOD, 'scripts/OtcInfiniteAmmo/global.lua')
    T.check('player watches on onFrame (also while menus pause the game)', player.engineHandlers.onFrame ~= nil
        and player.engineHandlers.onUpdate == nil)
    local tick = player.engineHandlers.onFrame
    local function deliver()
        local evs = env.globalEvents
        env.globalEvents = {}
        for _, e in ipairs(evs) do T.stub.dispatchGlobal({ global }, e.name, e.data) end
        return #evs
    end
    local function total(recordId)
        local t = 0
        for _, it in ipairs(env.types.Actor.inventory(env.player):findAll(recordId)) do t = t + it.count end
        return t
    end
    player.engineHandlers.onInit()
    local arrows = env.weapon('Arrow', 0, 'iron arrow', 20)
    env.player.inv[#env.player.inv + 1] = arrows
    env.player.equipment[SLOT.CarriedRight] = env.weapon('MarksmanBow', 500, 'long bow')
    env.player.equipment[SLOT.Ammunition] = arrows
    env.player.stance = STANCE.Weapon
    tick(0.016)
    T.check('interface lastReady true while drawn', player.interface.lastReady() == true)
    arrows.count = 19
    tick(0.016)
    local ev = env.globalEvents[1]
    T.check('shot: refill event for 1 iron arrow', ev and ev.name == 'OtcInfiniteAmmo_Refill' and ev.data.count == 1
        and ev.data.recordId == 'iron arrow')
    deliver()
    T.check('global gives 1 arrow back (total stays 20)', env.added and env.added.count == 1 and total('iron arrow') == 20)

    -- menu open: no refill, also not after the menu closes
    env.uiMode = 'Interface'
    arrows.count = 15
    tick(0)
    T.check('interface lastReady false in a menu', player.interface.lastReady() == false)
    env.uiMode = nil
    tick(0.016)
    T.check('ammo removed in a menu: never refilled', deliver() == 0)

    -- sheathed: no refill, and no equip changes (the stacks stay as they are)
    arrows.count = 19
    tick(0.016)
    env.player.stance = STANCE.Nothing
    arrows.count = 18
    tick(0.016)
    T.check('sheathed: no refill', deliver() == 0)
    T.check('sheathed: arrows stay equipped', env.player.equipment[SLOT.Ammunition] == arrows)

    -- the last arrow with a reserve stack: the reserve is equipped at once
    local reserve = env.added
    env.player.stance = STANCE.Weapon
    arrows.count = 1
    env.player.stance = STANCE.Nothing
    tick(0.016)
    env.player.stance = STANCE.Weapon
    tick(0.016)
    arrows:remove(1)
    tick(0.016)
    tick(0.016)
    T.check('last arrow with a reserve: the reserve is equipped', env.player.equipment[SLOT.Ammunition] == reserve)
    deliver()
    -- the last arrow, no reserve: the given-back arrow is equipped
    for _, it in ipairs(env.player.inv) do it.valid = false end   -- empty the inventory
    arrows = env.weapon('Arrow', 0, 'iron arrow', 1)
    env.player.inv[#env.player.inv + 1] = arrows
    env.player.equipment[SLOT.Ammunition] = arrows
    arrows.count = 1
    tick(0.016)                    -- sheathed: the new count is just noted
    env.player.stance = STANCE.Weapon
    tick(0.016)
    arrows:remove(1)
    tick(0.016)
    ev = env.globalEvents[1]
    T.check('last arrow: refill 1', ev and ev.data.count == 1)
    deliver()
    tick(0.016)
    eq = env.player.equipment[SLOT.Ammunition]
    T.check('the given-back arrow is equipped again', eq and eq.recordId == 'iron arrow' and eq.count == 1, eq and eq.count)

    -- thrown weapons + their switch
    local stars = env.weapon('MarksmanThrown', 0, 'steel star', 10)
    env.player.inv[#env.player.inv + 1] = stars
    env.player.equipment[SLOT.CarriedRight] = stars
    tick(0.016)
    stars.count = 9
    tick(0.016)
    T.check('thrown: refill', env.globalEvents[1] and env.globalEvents[1].data.recordId == 'steel star')
    deliver()
    env.storage.playerSection(L.GROUP):set('thrown', false)
    stars.count = 8
    tick(0.016)
    T.check('thrown off: no refill', #env.globalEvents == 0)

    -- global safety
    env.added = nil
    T.stub.dispatchGlobal({ global }, 'OtcInfiniteAmmo_Refill', { player = env.player, recordId = 'not a weapon', count = 1 })
    T.check('global: unknown record ignored', env.added == nil)
    T.stub.dispatchGlobal({ global }, 'OtcInfiniteAmmo_Refill', { player = env.player, recordId = 'iron arrow', count = 999 })
    T.check('global: capped at 50 per event', env.added and env.added.count == 50)
    env.added = nil
    T.stub.dispatchGlobal({ global }, 'OtcInfiniteAmmo_Refill', { player = env.player, recordId = 'iron arrow', count = 0 })
    T.check('global: 0 ignored', env.added == nil)

    -- whole mod off
    env.storage.playerSection(L.GROUP):set('enabled', false)
    arrows = env.weapon('Arrow', 0, 'iron arrow', 20)
    env.player.equipment[SLOT.Ammunition] = arrows
    tick(0.016)
    arrows.count = 19
    env.globalEvents = {}
    tick(0.016)
    T.check('mod off: no refill', #env.globalEvents == 0)
end
