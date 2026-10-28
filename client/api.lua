local api = {}

function api.AddPoint(data) return Registry.AddPoint(data) end
function api.AddEntity(data) return Registry.AddEntity(data) end
function api.AddModel(data) return Registry.AddModel(data) end
function api.AddPeds(data) return Registry.AddPeds(data) end
function api.AddPlayers(data) return Registry.AddPlayers(data) end
function api.AddZone(data) return Registry.AddZone(data) end
function api.AddPropsInZone(data) return Registry.AddPropsInZone(data) end
function api.AddContext(data) return Registry.AddContext(data) end
function api.AddWhile(state, data) return Registry.AddWhile(state, data) end
function api.AddWhileInWater(data) return Registry.AddWhile('inWater', data) end
function api.DefineState(name, check) return Registry.DefineState(name, check) end

function api.Remove(id) return Registry.Remove(id) end

function api.RemoveAll()
    Registry.RemoveResource(GetInvokingResource() or GetCurrentResourceName())
end

function api.Disable(state)
    JX.suppressed = state and true or false
end

function api.IsOpen()
    return JX.focus ~= nil
end

function api.Focused()
    return JX.focus
end

function api.Reload()
    local chunk = LoadResourceFile(GetCurrentResourceName(), 'config.lua')

    if not chunk then
        JX.Warn('could not read config.lua')
        return false
    end

    local fn, err = load(chunk, '@config.lua')

    if not fn then
        JX.Warn(('config.lua did not parse: %s'):format(err))
        return false
    end

    local ok, why = pcall(fn)

    if not ok then
        JX.Warn(('config.lua errored: %s'):format(why))
        return false
    end

    return true
end

RegisterCommand('jexreload', function()
    local was = ('scale %.3f  pedLift %.3f  objLift %.3f  rowX %.4f  dim %.2f')
        :format(Config.Scale, Config.Lift.ped, Config.Lift.object, Config.Ui.rowX, Config.DimAlpha)

    if api.Reload() then
        local now = ('scale %.3f  pedLift %.3f  objLift %.3f  rowX %.4f  dim %.2f')
            :format(Config.Scale, Config.Lift.ped, Config.Lift.object, Config.Ui.rowX, Config.DimAlpha)

        print('^2[jex_interact]^0 before  ' .. was)
        print('^2[jex_interact]^0 after   ' .. now)

        if was == now then
            print('^3[jex_interact]^0 nothing changed - either the file is the same, or the value you edited is read once at start rather than every frame')
        end
    end
end, false)

for name, fn in pairs(api) do
    exports(name, fn)
end

local compat = {}

function compat.CreateInteraction(id, coords, options, render, distance)
    return Registry.AddPoint {
        id = id,
        coords = coords,
        options = options,
        render = render,
        distance = distance,
    }
end

function compat.CreateEntityInteraction(id, entity, options, render, distance, offset, bone)
    return Registry.AddEntity {
        id = id,
        entity = entity,
        options = options,
        render = render,
        distance = distance,
        offset = offset,
        bone = bone,
    }
end

function compat.RegisterPedOptions(resource, options)
    Registry.AddPeds { id = 'compat:' .. tostring(resource), options = options }
    return true
end

function compat.UnregisterPedOptions(resource)
    return Registry.Remove('compat:' .. tostring(resource))
end

function compat.DeleteInteraction(id)
    return Registry.Remove(id)
end

function compat.ChangeOptionText(id, index, text)
    local point = JX.points[id]
    if point and point.options[index] then
        point.options[index].label = text
        return true
    end
    return false
end

exports('GetApi', function() return compat end)
