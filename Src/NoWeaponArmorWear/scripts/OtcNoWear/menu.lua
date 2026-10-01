-- No Weapon and Armor Wear (OpenMW) by Off the Clock - settings page (Options > Scripts > No Weapon and Armor Wear).
-- A MENU script, so the page works from the main menu too. Values live in the player storage (all saves).
local I = require('openmw.interfaces')
local L = require('scripts.OtcNoWear.logic')

local function pct(key)
    return {
        key = key, renderer = 'number', name = key, description = key .. 'Desc', default = L.DEFAULTS[key],
        argument = { min = L.MIN_PCT, max = L.MAX_PCT },
    }
end

I.Settings.registerPage({ key = L.PAGE, l10n = L.L10N, name = 'pageName', description = 'pageDesc' })

I.Settings.registerGroup({
    key = L.GROUP, page = L.PAGE, l10n = L.L10N, name = 'groupMain', description = 'groupMainDesc',
    permanentStorage = true, order = 0,
    settings = {
        { key = 'enabled', renderer = 'checkbox', name = 'enabled', description = 'enabledDesc', default = L.DEFAULTS.enabled },
        pct('weaponWear'),
        pct('armorWear'),
        pct('toolWear'),
        { key = 'npcArmor', renderer = 'checkbox', name = 'npcArmor', description = 'npcArmorDesc', default = L.DEFAULTS.npcArmor },
    },
})
