-- No Weapon and Armor Wear: logic + the real player/global/menu scripts against the stub API.
return function(T)
    local MOD = 'NoWeaponArmorWear'
    local env = T.fresh(MOD)
    local L = require('scripts.OtcNoWear.logic')

    -- logic: afterWear(last, now, pct, debt, max)
    local c, d = L.afterWear(100, 95, 0, 0, 100)
    T.check('0%: wear undone', c == 100 and d == 0, c)
    c, d = L.afterWear(100, 96, 50, 0, 100)
    T.check('50%: 4 -> 2', c == 98, c)
    c, d = L.afterWear(100, 99, 50, 0, 100)
    T.check('50%: 1 -> 0 now, half carried', c == 100 and T.near(d, 0.5), c .. ' ' .. d)
    c, d = L.afterWear(100, 99, 50, d, 100)
    T.check('50%: next 1 -> 1 (carried half used)', c == 99 and T.near(d, 0), c .. ' ' .. d)
    c = L.afterWear(100, 98, 300, 0, 100)
    T.check('300%: 2 -> 6', c == 94, c)
    c = L.afterWear(3, 2, 1000, 0, 100)
    T.check('faster wear stops at 1 (never breaks by itself)', c == 1, c)
    c = L.afterWear(3, 0, 0, 0, 100)
    T.check('the game broke it: left at 0', c == 0, c)
    c = L.afterWear(50, 80, 0, 0, 100)
    T.check('repair accepted', c == 80, c)
    c = L.afterWear(100, 90, 100, 0, 100)
    T.check('100% = game value', c == 90, c)

    -- logic: armorHit(cond, amount, pct, debt, max)
    c = L.armorHit(300, -7, 0, 0, 300)
    T.check('armor 0%: no loss', c == 300, c)
    c = L.armorHit(300, -8, 50, 0, 300)
    T.check('armor 50%: 8 -> 4', c == 296, c)
    c = L.armorHit(5, -7, 100, 0, 300)
    T.check('armor 100% breaking hit = 0 (game rule)', c == 0, c)
    c = L.armorHit(5, -3, 1000, 0, 300)
    T.check('armor 1000% stops at 1', c == 1, c)
    c = L.armorHit(5, -7, 50, 0, 300)
    T.check('armor 50% on a breaking hit keeps 1+', c == 2, c)
    T.check('pct defaults: weapon 0, armor 0, tool 100', L.pctFor('weapon', function() end) == 0
        and L.pctFor('armor', function() end) == 0 and L.pctFor('tool', function() end) == 100)
    T.check('pct off = 100', L.pctFor('weapon', function(k) if k == 'enabled' then return false end end) == 100)
    T.check('pct clamp 0..1000', L.clampPct(5000) == 1000 and L.clampPct(-1) == 0 and L.clampPct('x', 7) == 7)

    -- menu defaults
    T.load(MOD, 'scripts/OtcNoWear/menu.lua')
    local g
    for _, r in ipairs(env.registered) do if r.group then g = r.group end end
    local def = {}
    for _, s in ipairs(g.settings) do def[s.key] = s.default end
    T.check('menu defaults', def.enabled == true and def.weaponWear == 0 and def.armorWear == 0 and def.toolWear == 100
        and def.npcArmor == false and g.permanentStorage == true)

    -- player + global scripts
    local SLOT = env.types.Actor.EQUIPMENT_SLOT
    local player = T.load(MOD, 'scripts/OtcNoWear/player.lua')
    local global = T.load(MOD, 'scripts/OtcNoWear/global.lua')
    player.engineHandlers.onInit()
    local cfgEv = env.globalEvents[#env.globalEvents]
    T.check('player pushes settings to global at start', cfgEv and cfgEv.name == 'OtcNoWear_Config' and cfgEv.data.armorPct == 0)
    -- deliver it (the game's own handler table first, then ours: ours runs first)
    local gameCalls = 0
    local gameHandler = { eventHandlers = { ModifyItemCondition = function(d)
        gameCalls = gameCalls + 1
        d.item.data.condition = d.item.data.condition + d.amount
    end } }
    local tables = { gameHandler, global }
    env.stub = T.stub
    T.stub.dispatchGlobal(tables, cfgEv.name, cfgEv.data)

    local sword = env.weapon('LongBladeOneHand', 900)
    env.player.equipment[SLOT.CarriedRight] = sword
    player.engineHandlers.onUpdate(0.016)
    env.globalEvents = {}
    sword.data.condition = 895                       -- the engine wears the sword
    player.engineHandlers.onUpdate(0.016)
    local ev = env.globalEvents[1]
    T.check('weapon wear: asks the global script to restore', ev and ev.name == 'OtcNoWear_SetCondition' and ev.data.condition == 900)
    T.stub.dispatchGlobal(tables, ev.name, ev.data)
    T.check('weapon wear: restored to 900', sword.data.condition == 900, sword.data.condition)

    -- armor via ModifyItemCondition: ours handles it and stops the game's handler
    local cuirass = env.armor(300)
    env.player.equipment[SLOT.Cuirass] = cuirass
    local r = T.stub.dispatchGlobal(tables, 'ModifyItemCondition', { actor = env.player, item = cuirass, amount = -7 })
    T.check('armor hit at 0%: stopped, no loss', r == 'stopped' and gameCalls == 0 and cuirass.data.condition == 300)
    -- an NPC's armor: not ours unless npcArmor
    local npc = env.obj({ kind = 'npc' })
    local npcArmor = env.armor(100)
    r = T.stub.dispatchGlobal(tables, 'ModifyItemCondition', { actor = npc, item = npcArmor, amount = -5 })
    T.check('NPC armor: game value by default', r == 'done' and gameCalls == 1 and npcArmor.data.condition == 95)
    -- weapons through ModifyItemCondition are left to the game (the player poll handles weapons)
    r = T.stub.dispatchGlobal(tables, 'ModifyItemCondition', { actor = env.player, item = sword, amount = -5 })
    T.check('weapon via the armor event: left to the game', r == 'done' and gameCalls == 2)
    sword.data.condition = 900

    -- settings change -> pushed within 0.5 s
    local sec = env.storage.playerSection(L.GROUP)
    sec:set('armorWear', 100)
    env.globalEvents = {}
    player.engineHandlers.onUpdate(0.6)
    ev = nil
    for _, e in ipairs(env.globalEvents) do if e.name == 'OtcNoWear_Config' then ev = e end end
    T.check('settings change pushed', ev and ev.data.armorPct == 100)
    T.stub.dispatchGlobal(tables, ev.name, ev.data)
    r = T.stub.dispatchGlobal(tables, 'ModifyItemCondition', { actor = env.player, item = cuirass, amount = -7 })
    T.check('armor 100%: the game applies the normal 7', r == 'done' and cuirass.data.condition == 293)

    -- breaking hit at 50%: unequip event like the game
    sec:set('armorWear', 50)
    player.engineHandlers.onUpdate(0.6)
    for _, e in ipairs(env.globalEvents) do if e.name == 'OtcNoWear_Config' then T.stub.dispatchGlobal(tables, e.name, e.data) end end
    cuirass.data.condition = 3
    env.localEvents = {}
    r = T.stub.dispatchGlobal(tables, 'ModifyItemCondition', { actor = env.player, item = cuirass, amount = -4 })
    T.check('armor 50%: 4-point hit on 3 leaves 1', r == 'stopped' and cuirass.data.condition == 1, cuirass.data.condition)
    local handled = env.localEvents[#env.localEvents]
    T.check('player told about the handled armor hit', handled and handled.name == 'OtcNoWear_Handled' and handled.data.condition == 1)

    -- lockpick: game value by default, kept at 0%
    local pick = env.lockpick(25)
    env.player.equipment[SLOT.CarriedRight] = pick
    player.engineHandlers.onUpdate(0.016)
    env.globalEvents = {}
    pick.data.condition = 24
    player.engineHandlers.onUpdate(0.016)
    local asked = false
    for _, e in ipairs(env.globalEvents) do if e.name == 'OtcNoWear_SetCondition' then asked = true end end
    T.check('lockpick 100% (default): used up normally', not asked)
    sec:set('toolWear', 0)
    pick.data.condition = 23
    player.engineHandlers.onUpdate(0.016)
    ev = nil
    for _, e in ipairs(env.globalEvents) do if e.name == 'OtcNoWear_SetCondition' then ev = e end end
    T.check('lockpick 0%: use given back', ev and ev.data.condition == 24, ev and ev.data.condition)

    -- arrows/thrown/torches are never touched
    local arrows = env.weapon('Arrow', 0, 'iron arrow', 20)
    env.player.equipment[SLOT.CarriedRight] = env.weapon('MarksmanThrown', 0, 'star', 10)
    env.globalEvents = {}
    player.engineHandlers.onUpdate(0.016)
    player.engineHandlers.onUpdate(0.016)
    T.check('thrown weapons ignored', #env.globalEvents == 0)
    T.check('arrows have no condition rule', arrows.data.condition == 0)

    -- mod off: nothing restored
    sec:set('enabled', false)
    env.player.equipment[SLOT.CarriedRight] = sword
    player.engineHandlers.onUpdate(0.016)
    sword.data.condition = 890
    env.globalEvents = {}
    player.engineHandlers.onUpdate(0.016)
    asked = false
    for _, e in ipairs(env.globalEvents) do if e.name == 'OtcNoWear_SetCondition' then asked = true end end
    T.check('mod off: no restore', not asked)

    -- global SetCondition clamps to the item's full condition
    T.stub.dispatchGlobal(tables, 'OtcNoWear_SetCondition', { item = sword, condition = 5000 })
    T.check('SetCondition clamps to max', sword.data.condition == 900, sword.data.condition)
end
