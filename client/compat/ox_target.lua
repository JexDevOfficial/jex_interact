
if not Config.Takeover or not Config.Takeover.ox_target then return end

local claimed = false

local function claim(name, fn)
    AddEventHandler(('__cfx_export_ox_target_%s'):format(name), function(setCB)
        setCB(function(...)
            local ok, err = pcall(fn, ...)

            if not ok then
                JX.Warn(('ox_target:%s failed: %s'):format(name, tostring(err)))
            end

            return ok and err or nil
        end)
    end)
end

local owned = {}

local function track(key, name, id)
    owned[key] = owned[key] or {}

    if name and owned[key][name] then Registry.Remove(owned[key][name]) end

    owned[key][name or id] = id
end

local function untrack(key, names)
    local held = owned[key]
    if not held then return end

    if not names then
        for _, id in pairs(held) do Registry.Remove(id) end
        owned[key] = nil
        return
    end

    if type(names) ~= 'table' then names = { names } end

    for _, name in ipairs(names) do
        if held[name] then
            Registry.Remove(held[name])
            held[name] = nil
        end
    end

    if next(held) == nil then owned[key] = nil end
end

local function asList(options)
    if type(options) ~= 'table' then return {} end
    if options.label or options.name then return { options } end
    return options
end

local function asArray(v)
    if type(v) == 'table' then return v end
    return { v }
end

JX.checks = { groups = nil, items = nil }

local warned = {}

local function gated(kind, value, extra)
    local check = JX.checks[kind]

    if not check then
        if not warned[kind] then
            warned[kind] = true
            JX.Warn(('an ox_target option uses "%s" and nothing answers it, so it stays hidden. Set a check with Set%sCheck.')
                :format(kind, kind == 'groups' and 'Group' or 'Item'))
        end

        return false
    end

    local ok, allowed = pcall(check, value, extra)
    return ok and allowed and true or false
end

local function respond(option, entity)
    local out = {}

    for key, value in pairs(option) do out[key] = value end

    out.entity = entity or 0
    out.coords = (entity and entity ~= 0 and DoesEntityExist(entity)) and GetEntityCoords(entity) or nil
    out.distance = out.coords and #(GetEntityCoords(JX.ped) - out.coords) or 0.0

    out.icon, out.groups, out.items = nil, nil, nil
    out.canInteract, out.onSelect = nil, nil
    out.export, out.event, out.serverEvent, out.command = nil, nil, nil, nil

    return out
end

local function convert(option)
    return {
        label = option.label,
        distance = option.distance,

        canInteract = function(_, entity)
            if option.groups and not gated('groups', option.groups) then return false end
            if option.items and not gated('items', option.items, option.anyItem) then return false end
            if not option.canInteract then return true end

            local coords = (entity and entity ~= 0 and DoesEntityExist(entity)) and GetEntityCoords(entity) or nil
            local distance = coords and #(GetEntityCoords(JX.ped) - coords) or 0.0

            local ok, allowed = pcall(option.canInteract, entity, distance, coords, option.name, nil)
            return ok and allowed and true or false
        end,

        onSelect = function(_, entity)
            local payload = respond(option, entity)

            if option.onSelect then
                option.onSelect(payload)
            elseif option.export then
                exports[option.resource][option.export](nil, payload)
            elseif option.event then
                TriggerEvent(option.event, payload)
            elseif option.serverEvent then
                TriggerServerEvent(option.serverEvent, payload)
            elseif option.command then
                ExecuteCommand(option.command)
            end
        end,
    }
end

local function attach(key, options, add)
    local from = GetInvokingResource()

    for _, option in ipairs(asList(options)) do
        option.resource = option.resource or from
        local id = add(convert(option), option.distance, from)
        track(key, option.name, id)
    end
end

local function addLocalEntity(arr, options)
    for _, entity in ipairs(asArray(arr)) do
        if DoesEntityExist(entity) then
            attach('e:' .. entity, options, function(built, distance, from)
                return Registry.AddEntity { entity = entity, distance = distance, resource = from, options = { built } }
            end)
        end
    end
end

local function removeLocalEntity(arr, names)
    for _, entity in ipairs(asArray(arr)) do untrack('e:' .. entity, names) end
end

local function resolve(value)
    if DoesEntityExist(value) then return value end
    if NetworkDoesNetworkIdExist(value) then return NetworkGetEntityFromNetworkId(value) end
    return nil
end

local function addEntity(arr, options)
    for _, value in ipairs(asArray(arr)) do
        local entity = resolve(value)
        if entity then addLocalEntity(entity, options) end
    end
end

local function removeEntity(arr, names)
    for _, value in ipairs(asArray(arr)) do
        local entity = resolve(value)
        if entity then removeLocalEntity(entity, names) end
    end
end

local function addModel(arr, options)
    for _, model in ipairs(asArray(arr)) do
        local hash = tonumber(model) or joaat(model)

        attach('m:' .. hash, options, function(built, distance, from)
            return Registry.AddModel { models = { hash }, distance = distance, resource = from, options = { built } }
        end)
    end
end

local function removeModel(arr, names)
    for _, model in ipairs(asArray(arr)) do
        untrack('m:' .. (tonumber(model) or joaat(model)), names)
    end
end

local function addGlobalPed(options)
    attach('g:ped', options, function(built, distance, from)
        return Registry.AddPeds { distance = distance, resource = from, options = { built } }
    end)
end

local function addGlobalPlayer(options)
    attach('g:player', options, function(built, distance, from)
        return Registry.AddPlayers { distance = distance, resource = from, options = { built } }
    end)
end

local function addSphereZone(data)
    local id = Registry.AddZone {
        coords = data.coords,
        radius = data.radius or 2.0,
        options = {},
    }

    attach('z:' .. id, data.options, function(built)
        local point = JX.points[id]
        point.options[#point.options + 1] = built
        return id
    end)

    return id
end

local function addBoxZone(data)
    local id = Registry.AddZone {
        coords = data.coords,
        size = data.size,
        heading = data.rotation or data.heading,
        options = {},
    }

    attach('z:' .. id, data.options, function(built)
        local point = JX.points[id]
        point.options[#point.options + 1] = built
        return id
    end)

    return id
end

local function unsupported(name)
    return function()
        if warned[name] then return end
        warned[name] = true
        JX.Warn(('%s is not supported. Anything registered through it will not appear.'):format(name))
    end
end

local function claimAll()
    if claimed then return end

    claim('addLocalEntity', addLocalEntity)
    claim('removeLocalEntity', removeLocalEntity)
    claim('addEntity', addEntity)
    claim('removeEntity', removeEntity)
    claim('addModel', addModel)
    claim('removeModel', removeModel)
    claim('addGlobalPed', addGlobalPed)
    claim('removeGlobalPed', function(names) untrack('g:ped', names) end)
    claim('addGlobalPlayer', addGlobalPlayer)
    claim('removeGlobalPlayer', function(names) untrack('g:player', names) end)
    claim('addSphereZone', addSphereZone)
    claim('addBoxZone', addBoxZone)
    claim('removeZone', function(id) Registry.Remove(id) end)
    claim('disableTargeting', function(state) JX.suppressed = state and true or false end)
    claim('isActive', function() return JX.focus ~= nil end)

    claim('addPolyZone', unsupported('addPolyZone'))
    claim('addGlobalVehicle', unsupported('addGlobalVehicle'))
    claim('addGlobalObject', unsupported('addGlobalObject'))
    claim('removeGlobalVehicle', function() end)
    claim('removeGlobalObject', function() end)

    claimed = true
    print('^2[jex_interact]^0 answering on ox_target')
end

if GetResourceState('ox_target') == 'started' then
    JX.Warn('ox_target is running, so its exports were left alone. Stop it and jex_interact picks them up.')
else
    claimAll()
end

AddEventHandler('onClientResourceStop', function(resource)
    if resource == 'ox_target' then claimAll() end
end)

exports('SetGroupCheck', function(fn) JX.checks.groups = fn end)
exports('SetItemCheck', function(fn) JX.checks.items = fn end)
exports('IsAnsweringOxTarget', function() return claimed end)

exports('IsAnsweringOxTarget', function() return claimed end)
