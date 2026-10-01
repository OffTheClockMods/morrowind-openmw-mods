-- Offline tests for our OpenMW Lua mods (no game). Run from anywhere:
--   lua Src\tests\run_tests.lua            (all)
--   lua Src\tests\run_tests.lua nowear     (test files whose name contains "nowear")
-- Exit code 0 = all pass. Last line: "RESULT: n/n passed". The scripts run against openmw_stub.lua.
-- Uses the real script files (logic, player, global, menu), so a typo there fails here.
local here = (arg and arg[0] and arg[0]:match('^(.*)[/\\][^/\\]*$')) or '.'
local src = here .. '/..'
package.path = here .. '/?.lua;' .. package.path
local S = require('openmw_stub')

local T = { run = 0, failed = 0, stub = S, src = src }
local realPrint = print
function T.check(name, ok, detail)
    T.run = T.run + 1
    if not ok then
        T.failed = T.failed + 1
        realPrint('FAIL ' .. T.current .. ': ' .. name .. (detail ~= nil and (' - ' .. tostring(detail)) or ''))
    end
    return ok
end
function T.near(a, b) return type(a) == 'number' and type(b) == 'number' and math.abs(a - b) < 1e-9 end

--- Fresh fake world + load a mod script (returns env and the script's return value).
function T.fresh(modFolder)
    local env = S.new()
    T.basePath = T.basePath or package.path
    package.path = src .. '/' .. modFolder .. '/?.lua;' .. T.basePath
    return env
end
function T.load(modFolder, rel)
    return dofile(src .. '/' .. modFolder .. '/' .. rel)
end

local files = { 'test_skillgain', 'test_nowear', 'test_infiniteammo' }
local filter = arg and arg[1]
for _, f in ipairs(files) do
    if not filter or f:find(filter, 1, true) then
        T.current = f
        local ok, err = pcall(function() require(f)(T) end)
        print = realPrint
        if not ok then T.check('test file ran to the end', false, err) end
    end
end
print = realPrint
print(('RESULT: %d/%d passed'):format(T.run - T.failed, T.run))
os.exit(T.failed == 0 and 0 or 1)
