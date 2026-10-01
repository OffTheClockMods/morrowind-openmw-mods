-- A tiny stand-in for the OpenMW 0.50 Lua API, just enough for our mods' scripts (offline tests, no game).
-- Mirrors the real behaviour our mods rely on (checked against resources\lua_api and resources\vfs\scripts\omw):
--   * storage sections: get / set / asTable;
--   * SkillProgression handlers run newest first, a handler returning false stops the chain;
--   * global event handlers run newest script first, returning false stops the chain;
--   * Actor.getEquipment(actor) -> table, (actor, slot) -> item; setEquipment only on self.
-- Lua 5.1-5.4 compatible.
local S = {}

function S.new()
    local env = { sections = {}, globalEvents = {}, localEvents = {}, printed = {}, registered = {} }

    -- storage
    local function section(name)
        local s = env.sections[name]
        if s then return s end
        local data = {}
        s = { data = data }
        function s:get(k) return data[k] end
        function s:set(k, v) data[k] = v end
        function s:asTable() local t = {} for k, v in pairs(data) do t[k] = v end return t end
        env.sections[name] = s
        return s
    end
    env.storage = { playerSection = section, globalSection = section }

    -- core
    local skills = {}
    local SPEC = {
        longblade = 'combat', axe = 'combat', destruction = 'magic', alchemy = 'magic', sneak = 'stealth',
        marksman = 'stealth', athletics = 'combat',
    }
    env.core = {
        API_REVISION = 97,
        sendGlobalEvent = function(name, data) env.globalEvents[#env.globalEvents + 1] = { name = name, data = data } end,
        stats = { Skill = { record = function(id)
            local spec = SPEC[id]
            if not spec then error('no skill ' .. tostring(id)) end
            return { id = id, specialization = spec, skillGain = { 1, 2, 3, 4 } }
        end } },
    }

    -- interfaces
    env.skillHandlers = {}
    env.I = {
        SkillProgression = {
            addSkillUsedHandler = function(fn) env.skillHandlers[#env.skillHandlers + 1] = fn end,
        },
        Settings = {
            registerPage = function(o) env.registered[#env.registered + 1] = { page = o } end,
            registerGroup = function(o) env.registered[#env.registered + 1] = { group = o } end,
        },
        UI = { getMode = function() return env.uiMode end },
    }
    --- Runs the skill-used chain like scripts/omw/skillhandlers.lua (newest first, false stops). Returns params.
    function env.skillUsed(skillId, gain)
        local params = { skillGain = gain, useType = 0 }
        for i = #env.skillHandlers, 1, -1 do
            if env.skillHandlers[i](skillId, params) == false then break end
        end
        return params
    end

    -- objects
    env.nextId = 0
    local function obj(fields)
        env.nextId = env.nextId + 1
        fields.id = fields.id or ('@' .. env.nextId)
        fields.count = fields.count or 1
        fields.valid = true
        function fields:isValid() return self.valid end
        function fields:sendEvent(name, data) env.localEvents[#env.localEvents + 1] = { target = self, name = name, data = data } end
        function fields:remove(n)
            -- like OpenMW 0.50 (seen in game): a used-up stack keeps its object and slot, with count 0
            n = n or self.count
            self.count = math.max(0, self.count - n)
        end
        function fields:moveInto(inv) inv.add(self) end
        return fields
    end
    env.obj = obj

    local SLOT = { Helmet = 0, Cuirass = 1, CarriedRight = 16, CarriedLeft = 17, Ammunition = 18 }
    local STANCE = { Nothing = 0, Weapon = 1, Spell = 2 }
    env.player = obj({ kind = 'player', equipment = {}, stance = 0, inv = {} })
    env.self = env.player
    env.self.object = env.player
    env.self.cell = { name = 'Test cell' }

    function env.unequip(item)
        for slot, it in pairs(env.player.equipment) do if it == item then env.player.equipment[slot] = nil end end
    end

    local WTYPE = { ShortBladeOneHand = 0, LongBladeOneHand = 1, MarksmanBow = 9, MarksmanCrossbow = 10,
                    MarksmanThrown = 11, Arrow = 12, Bolt = 13 }
    local function isKind(k) return function(o) return o ~= nil and o.kind == k end end
    local weaponRecords = {}
    env.types = {
        Actor = {
            EQUIPMENT_SLOT = SLOT, STANCE = STANCE,
            getEquipment = function(actor, slot)
                if slot == nil then local t = {} for k, v in pairs(actor.equipment) do t[k] = v end return t end
                return actor.equipment[slot]
            end,
            setEquipment = function(actor, eq)
                if actor ~= env.self then error('setEquipment only on self') end
                actor.equipment = {}
                for k, v in pairs(eq) do actor.equipment[k] = v end
            end,
            getStance = function(actor) return actor.stance end,
            inventory = function(actor)
                return {
                    add = function(item) actor.inv[#actor.inv + 1] = item; env.added = item end,
                    find = function(_, recordId)
                        for _, it in ipairs(actor.inv) do if it.valid and it.recordId == recordId then return it end end
                    end,
                    findAll = function(_, recordId)
                        local out = {}
                        for _, it in ipairs(actor.inv) do
                            if it.valid and it.count > 0 and it.recordId == recordId then out[#out + 1] = it end
                        end
                        return out
                    end,
                }
            end,
        },
        Weapon = {
            TYPE = WTYPE, objectIsInstance = isKind('weapon'),
            record = function(o)
                if type(o) == 'string' then
                    local r = weaponRecords[o]
                    if not r then error('no weapon record ' .. o) end
                    return r
                end
                return o.rec
            end,
        },
        Armor = { objectIsInstance = isKind('armor'), record = function(o) return o.rec end },
        Lockpick = { objectIsInstance = isKind('lockpick'), record = function(o) return o.rec end },
        Probe = { objectIsInstance = isKind('probe'), record = function(o) return o.rec end },
        Player = { objectIsInstance = isKind('player') },
        Item = { itemData = function(o) return o.data end },
    }
    env.weaponRecords = weaponRecords

    env.world = {
        createObject = function(recordId, count)
            local rec = weaponRecords[recordId]
            return obj({ kind = 'weapon', recordId = recordId, count = count or 1, rec = rec, data = {} })
        end,
    }

    -- item helpers
    function env.weapon(t, health, recordId, count)
        local rec = { type = WTYPE[t], health = health or 0 }
        if recordId then weaponRecords[recordId] = rec end
        local o = obj({ kind = 'weapon', rec = rec, recordId = recordId or 'w', count = count or 1,
                        data = { condition = health } })
        o.type = env.types.Weapon
        return o
    end
    function env.armor(health)
        local o = obj({ kind = 'armor', rec = { health = health }, recordId = 'a', data = { condition = health } })
        o.type = env.types.Armor
        return o
    end
    function env.lockpick(uses)
        local o = obj({ kind = 'lockpick', rec = { maxCondition = uses }, recordId = 'pick', data = { condition = uses } })
        o.type = env.types.Lockpick
        return o
    end

    -- install as the openmw.* modules
    package.preload['openmw.core'] = function() return env.core end
    package.preload['openmw.self'] = function() return env.self end
    package.preload['openmw.storage'] = function() return env.storage end
    package.preload['openmw.types'] = function() return env.types end
    package.preload['openmw.interfaces'] = function() return env.I end
    package.preload['openmw.world'] = function() return env.world end
    for k in pairs(package.loaded) do
        if k:find('^openmw') or k:find('^scripts%.') then package.loaded[k] = nil end
    end
    local realPrint = print
    env.realPrint = realPrint
    print = function(...)
        local parts = {}
        for i = 1, select('#', ...) do parts[#parts + 1] = tostring((select(i, ...))) end
        env.printed[#env.printed + 1] = table.concat(parts, '\t')
    end
    return env
end

--- Global event dispatch like OpenMW: handler tables in load order; newest first; false stops.
function S.dispatchGlobal(handlerTables, name, data)
    for i = #handlerTables, 1, -1 do
        local h = handlerTables[i].eventHandlers and handlerTables[i].eventHandlers[name]
        if h and h(data) == false then return 'stopped' end
    end
    return 'done'
end

return S
