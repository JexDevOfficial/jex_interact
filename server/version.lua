-- Checks for updates when jex_lib isn't here to do it, and only speaks when
-- there is one. With jex_lib running, jex_lib's version checker lists
-- jex_interact instead.
-- Turn it off with: set jex:versionCheck false

local REPO = 'JexDevOfficial/jex_interact'
local RAW = ('https://raw.githubusercontent.com/%s/main/fxmanifest.lua'):format(REPO)
local URL = 'https://github.com/' .. REPO

local resource = GetCurrentResourceName()

local function parts(v)
    local t = {}
    for n in tostring(v):gmatch('%d+') do t[#t + 1] = tonumber(n) end
    return t
end

local function older(a, b)
    local x, y = parts(a), parts(b)
    for i = 1, math.max(#x, #y) do
        local p, q = x[i] or 0, y[i] or 0
        if p ~= q then return p < q end
    end
    return false
end

-- The jex-dev.com palette, matching jex_lib's checker.
local function rgb(r, g, b) return ('\27[38;2;%d;%d;%dm'):format(r, g, b) end

local LIME, TEXT, FAINT, AMBER, RED = rgb(183, 255, 60), rgb(232, 229, 222), rgb(92, 95, 99), rgb(255, 196, 61), rgb(255, 99, 88)
local RESET = '\27[0m'

CreateThread(function()
    if GetConvar('jex:versionCheck', 'true') == 'false' then return end

    -- Give jex_lib the same chance to start that its own checker waits for.
    Wait(2000)

    local lib = GetResourceState('jex_lib')
    if lib == 'started' or lib == 'starting' then return end

    local have = GetResourceMetadata(resource, 'version', 0) or '0.0.0'

    PerformHttpRequest(RAW, function(code, body)
        -- Line anchored, so fx_version never matches.
        local latest = code == 200 and body
            and ('\n' .. body):match("\n%s*version%s*%(?%s*['\"]([^'\"]+)['\"]")

        if latest and older(have, latest) then
            print(('%s  ▌ %s▲ %s%s %s%s %s→ %s  %supdate available  %s%s%s'):format(
                LIME, AMBER, TEXT, resource, RED, have, LIME, latest, AMBER, FAINT, URL, RESET))
        end
    end, 'GET')
end)
