Registry = {}

JX.models = {}
JX.props = {}
JX.context = {}
JX.globals = { ped = {}, player = {} }

local function owner()
    return GetInvokingResource() or GetCurrentResourceName()
end

local function store(point)
    point.resource = point.resource or owner()
    point.id = point.id or JX.NextId(point.resource)
    point.options = point.options or {}
    point.render = point.render or Config.RenderDistance
    point.distance = point.distance or Config.InteractDistance

    if not JX.points[point.id] then
        JX.order[#JX.order + 1] = point.id
    end

    JX.points[point.id] = point
    return point.id
end

function Registry.AddPoint(data)
    data.coords = JX.Coords(data.coords)
    return store(data)
end

function Registry.AddZone(data)
    data.coords = JX.Coords(data.coords)
    data.zone = true

    if data.size then
        data.size = JX.Coords(data.size)
        data.render = data.render or math.max(data.size.x, data.size.y)
    else
        data.radius = data.radius or 5.0
        data.render = data.render or data.radius + 4.0
    end

    return store(data)
end

function Registry.AddPropsInZone(data)
    local entry = {
        id = data.id or JX.NextId(owner()),
        resource = owner(),
        coords = JX.Coords(data.coords),
        radius = data.radius or 30.0,
        max = data.max,
        models = {},
        options = data.options or {},
        render = data.render or Config.RenderDistance,
        distance = data.distance or Config.InteractDistance,
        offset = data.offset and JX.Coords(data.offset) or vec3(0.0, 0.0, 0.0),
        placed = data.offset ~= nil,
        bone = data.bone,
    }

    for _, model in ipairs(data.models or {}) do
        entry.models[type(model) == 'string' and joaat(model) or model] = true
    end

    JX.props[entry.id] = entry
    return entry.id
end

JX.states = {
    inWater = function() return IsEntityInWater(JX.ped) end,
    swimming = function() return IsPedSwimming(JX.ped) end,
    mounted = function() return IsPedOnMount(JX.ped) end,
    inVehicle = function() return IsPedInAnyVehicle(JX.ped, false) end,
}

function Registry.DefineState(name, check)
    JX.states[name] = check
end

function Registry.AddWhile(state, data)
    local check = JX.states[state]

    if not check then
        JX.Warn(('no state named "%s". Define one with DefineState.'):format(tostring(state)))
        return
    end

    data = data or {}
    data.when = check

    return Registry.AddContext(data)
end

function Registry.AddContext(data)
    local entry = {
        id = data.id or JX.NextId(owner()),
        resource = owner(),
        when = data.when,
        offset = data.offset and JX.Coords(data.offset) or vec3(0.0, 0.0, 0.55),
        options = data.options or {},
        render = math.huge,
        distance = math.huge,
        always = true,
    }

    JX.context[entry.id] = entry
    return entry.id
end

function Registry.Inside(point, pos)
    if not point.zone then
        return point.dist <= point.distance
    end

    local d = pos - point.coords

    if point.size then
        local h = -math.rad(point.heading or 0.0)
        local cx = d.x * math.cos(h) - d.y * math.sin(h)
        local cy = d.x * math.sin(h) + d.y * math.cos(h)

        return math.abs(cx) <= point.size.x / 2
            and math.abs(cy) <= point.size.y / 2
            and math.abs(d.z) <= point.size.z / 2
    end

    return #d <= point.radius
end

function Registry.AddEntity(data)
    data.placed = data.offset ~= nil
    data.offset = data.offset and JX.Coords(data.offset) or vec3(0.0, 0.0, 0.0)

    return store(data)
end

function Registry.AddModel(data)
    local entry = {
        resource = data.resource or owner(),
        models = {},
        options = data.options or {},
        render = data.render or Config.RenderDistance,
        distance = data.distance or Config.InteractDistance,
        offset = data.offset and JX.Coords(data.offset) or vec3(0.0, 0.0, 0.0),
        placed = data.offset ~= nil,
        bone = data.bone,
    }

    for _, model in ipairs(data.models or {}) do
        entry.models[type(model) == 'string' and joaat(model) or model] = true
    end

    entry.id = data.id or JX.NextId(entry.resource)
    JX.models[entry.id] = entry
    return entry.id
end

local function addGlobal(kind, data)
    local entry = {
        id = data.id or JX.NextId(owner()),
        resource = data.resource or owner(),
        options = data.options or {},
        render = data.render or Config.RenderDistance,
        distance = data.distance or Config.InteractDistance,
        offset = data.offset and JX.Coords(data.offset) or vec3(0.0, 0.0, 0.0),
        placed = data.offset ~= nil,
        bone = data.bone,
    }
    JX.globals[kind][entry.id] = entry
    return entry.id
end

function Registry.AddPeds(data) return addGlobal('ped', data) end
function Registry.AddPlayers(data) return addGlobal('player', data) end

function Registry.Remove(id)
    if JX.points[id] then
        JX.points[id] = nil
        for i = #JX.order, 1, -1 do
            if JX.order[i] == id then table.remove(JX.order, i) break end
        end
        if JX.focus == id then JX.focus = nil end
        return true
    end

    if JX.models[id] then JX.models[id] = nil return true end
    if JX.props[id] then JX.props[id] = nil return true end
    if JX.context[id] then JX.context[id] = nil return true end

    for _, set in pairs(JX.globals) do
        if set[id] then set[id] = nil return true end
    end

    return false
end

function Registry.RemoveResource(resource)
    for i = #JX.order, 1, -1 do
        local id = JX.order[i]
        local point = JX.points[id]
        if point and point.resource == resource then
            JX.points[id] = nil
            table.remove(JX.order, i)
            if JX.focus == id then JX.focus = nil end
        end
    end

    for id, entry in pairs(JX.models) do
        if entry.resource == resource then JX.models[id] = nil end
    end

    for id, entry in pairs(JX.props) do
        if entry.resource == resource then JX.props[id] = nil end
    end

    for id, entry in pairs(JX.context) do
        if entry.resource == resource then JX.context[id] = nil end
    end

    for _, set in pairs(JX.globals) do
        for id, entry in pairs(set) do
            if entry.resource == resource then set[id] = nil end
        end
    end
end

function Registry.Live(point)
    if point.always then
        return GetEntityCoords(JX.ped) + point.offset
    end

    if point.entity then
        return Registry.Position(point)
    end

    return point.coords
end

local centres = {}

function Registry.Centre(model)
    local known = centres[model]

    if known ~= nil then return known or nil end

    local mn, mx = GetModelDimensions(model)

    if not mn or not mx then
        centres[model] = false
        return nil
    end

    local centre = vec3((mn.x + mx.x) * 0.5, (mn.y + mx.y) * 0.5, (mn.z + mx.z) * 0.5)
    centres[model] = centre

    return centre
end

local function bounds(entity)
    local centre = Registry.Centre(GetEntityModel(entity))

    if not centre then return nil end

    return GetOffsetFromEntityInWorldCoords(entity, centre.x, centre.y, centre.z)
end

local function placement(entity)
    local root = GetEntityCoords(entity)

    if IsEntityAPed(entity) then
        if not IsEntityDead(entity) then
            return root + vec3(0.0, 0.0, Config.Lift.ped)
        end

        return (Config.BoundsCentre.pedDead and bounds(entity))
            or root + vec3(0.0, 0.0, Config.Lift.pedDead)
    end

    if IsEntityAVehicle(entity) then
        return root + vec3(0.0, 0.0, Config.Lift.vehicle)
    end

    return (Config.BoundsCentre.object and bounds(entity))
        or root + vec3(0.0, 0.0, Config.Lift.object)
end

function Registry.Position(point)
    if not point.entity then return point.coords end
    if not DoesEntityExist(point.entity) then return nil end

    if point.bone then
        local bone = GetPedBoneCoords(point.entity, point.bone, point.offset.x, point.offset.y, point.offset.z)
        local root = GetEntityCoords(point.entity)

        if bone and #(bone - root) < 3.0 then return bone end

        return root + point.offset
    end

    if point.placed then
        return GetEntityCoords(point.entity) + point.offset
    end

    return placement(point.entity)
end

function Registry.Reach(point)
    if not point.entity then return point.coords end
    if not DoesEntityExist(point.entity) then return nil end
    if point.placed then return GetEntityCoords(point.entity) + point.offset end

    return GetEntityCoords(point.entity)
end

AddEventHandler('onClientResourceStop', function(resource)
    Registry.RemoveResource(resource)
end)
