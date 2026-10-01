-- Infinite Arrows and Bolts (OpenMW) by Off the Clock - settings page (Options > Scripts > Infinite Arrows and Bolts).
local I = require('openmw.interfaces')
local L = require('scripts.OtcInfiniteAmmo.logic')

local function box(key)
    return { key = key, renderer = 'checkbox', name = key, description = key .. 'Desc', default = L.DEFAULTS[key] }
end

I.Settings.registerPage({ key = L.PAGE, l10n = L.L10N, name = 'pageName', description = 'pageDesc' })
I.Settings.registerGroup({
    key = L.GROUP, page = L.PAGE, l10n = L.L10N, name = 'groupMain', description = 'groupMainDesc',
    permanentStorage = true, order = 0,
    settings = { box('enabled'), box('arrowsBolts'), box('thrown') },
})
