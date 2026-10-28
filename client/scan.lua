Scan = {}

JX.dynamic = {}

local function forward(rot)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local flat = math.abs(math.cos(rx))
    return vec3(-math.sin(rz) * flat, math.cos(rz) * flat, math.sin(rx))
end

local function eye()
    local pos = GetEntityCoords(JX.ped)
    local head = GetPedBoneCoords(JX.ped, 21030, 0.0, 0.0, 0.0)

    if not head or #(head - pos) > 3.0 then
        return pos + vec3(0.0, 0.0, 0.6)
    end

    return head
end

function Scan.Target(distance)
    local from = eye()
    local dest = from + forward(GetGameplayCamRot(2)) * (distance or 12.0)

    local handle = StartShapeTestSweptSphere(from.x, from.y, from.z, dest.x, dest.y, dest.z, 0.4, -1, JX.ped, 0)
    Wait(0)

    local _, hit, _, _, entity = GetShapeTestResult(handle)

    return hit == 1 and entity or 0
end

local warned = {}

local function busy(resource, name)
    if GetResourceState(resource) ~= 'started' then return false end

    local proxy = exports[resource]
    local ok, active = pcall(function() return proxy[name](proxy) end)

    if not ok and not warned[resource .. name] then
        warned[resource .. name] = true
        JX.Warn(('%s has no export named %s - remove it from Config.BlockWhile.probes'):format(resource, name))
    end

    return ok and active and true or false
end

function Scan.Blocked()
    if JX.suppressed then return true end
    if LocalPlayer.state.interactionsDisabled then return true end

    local d = Config.Disable
    local ped = JX.ped

    if d.dead and IsPedDeadOrDying(ped, true) then return true end
    if d.nuiFocused and IsNuiFocused() then return true end
    if d.pauseMenu and IsPauseMenuActive() then return true end
    if d.cuffed and IsPedCuffed(ped) then return true end
    if d.mounted and IsPedOnMount(ped) then return true end
    if d.inVehicle and IsPedInAnyVehicle(ped, false) then return true end

    local block = Config.BlockWhile

    if block then
        for _, name in ipairs(block.states or {}) do
            if LocalPlayer.state[name] then return true end
        end

        for _, probe in ipairs(block.probes or {}) do
            if busy(probe[1], probe[2]) then return true end
        end
    end

    return false
end

local function eligible(ped)
    local p = Config.Peds
    if ped == JX.ped then return false end
    if p.humansOnly and not IsPedHuman(ped) then return false end
    if p.skipDead and IsEntityDead(ped) then return false end
    if p.skipMounted and IsPedOnMount(ped) then return false end
    if p.networkedOnly and not NetworkGetEntityIsNetworked(ped) then return false end
    return true
end

local function spread(handle)
    return (handle * 2654435761) % 1000003
end

local function propsInZone(pos)
    for _, entry in pairs(JX.props) do
        if #(pos - entry.coords) <= entry.radius + Config.ScanDistance then
            local found = {}

            for _, pool in ipairs({ 'CObject', 'CPed' }) do
                for _, entity in ipairs(GetGamePool(pool)) do
                    if entry.models[GetEntityModel(entity)]
                        and #(entry.coords - GetEntityCoords(entity)) <= entry.radius then
                        found[#found + 1] = entity
                    end
                end
            end

            if entry.max and #found > entry.max then
                table.sort(found, function(a, b) return spread(a) < spread(b) end)
                for i = #found, entry.max + 1, -1 do found[i] = nil end
            end

            for _, entity in ipairs(found) do
                JX.dynamic[#JX.dynamic + 1] = {
                    id = entry.id .. ':' .. entity,
                    entity = entity,
                    offset = entry.offset,
                    placed = entry.placed,
                    bone = entry.bone,
                    options = entry.options,
                    render = entry.render,
                    distance = entry.distance,
                }
            end
        end
    end
end

function Scan.BuildDynamic()
    JX.dynamic = {}

    local pos = GetEntityCoords(JX.ped)
    local reach = Config.ScanDistance

    if next(JX.props) then propsInZone(pos) end
    local wantPeds = Config.Peds.enabled and #Config.Peds.options > 0
    local wantGlobals = next(JX.globals.ped) ~= nil or next(JX.globals.player) ~= nil
    local wantModels = next(JX.models) ~= nil

    if wantPeds or wantGlobals then
        for _, ped in ipairs(GetGamePool('CPed')) do
            if eligible(ped) and #(pos - GetEntityCoords(ped)) <= reach then
                local isPlayer = IsPedAPlayer(ped)
                local options = {}
                local offset, placed

                if wantPeds and not isPlayer then
                    for _, opt in ipairs(Config.Peds.options) do options[#options + 1] = opt end
                end

                for _, entry in pairs(JX.globals[isPlayer and 'player' or 'ped']) do
                    for _, opt in ipairs(entry.options) do options[#options + 1] = opt end

                    if entry.placed and not placed then
                        offset, placed = entry.offset, true
                    end
                end

                if #options > 0 then
                    JX.dynamic[#JX.dynamic + 1] = {
                        id = 'ped:' .. ped,
                        entity = ped,
                        offset = offset or vec3(0.0, 0.0, 0.0),
                        placed = placed,
                        options = options,
                        render = Config.RenderDistance,
                        distance = Config.InteractDistance,
                    }
                end
            end
        end
    end

    if wantModels then
        for _, pool in ipairs({ 'CObject', 'CPed' }) do
            for _, entity in ipairs(GetGamePool(pool)) do
                if #(pos - GetEntityCoords(entity)) <= reach then
                    local model = GetEntityModel(entity)

                    for _, entry in pairs(JX.models) do
                        if entry.models[model] then
                            JX.dynamic[#JX.dynamic + 1] = {
                                id = entry.id .. ':' .. entity,
                                entity = entity,
                                offset = entry.offset,
                                placed = entry.placed,
                                bone = entry.bone,
                                options = entry.options,
                                render = entry.render,
                                distance = entry.distance,
                            }
                        end
                    end
                end
            end
        end
    end
end

function Scan.Nearby()
    local pos = GetEntityCoords(JX.ped)
    local list = {}

    local function consider(point)
        local coords = Registry.Position(point)
        if not coords then return end

        local dist = #(pos - (Registry.Reach(point) or coords))
        if dist > point.render then return end

        local onScreen, x, y = GetScreenCoordFromWorldCoord(coords.x, coords.y, coords.z)
        if not onScreen then return end

        if not JX.Available(point) then return end

        point.coordsNow = coords
        point.dist = dist
        point.screen = #(vec2(x, y) - vec2(0.5, 0.5))

        list[#list + 1] = point
    end

    for _, id in ipairs(JX.order) do
        local point = JX.points[id]
        if point then consider(point) end
    end

    for _, point in ipairs(JX.dynamic) do
        consider(point)
    end

    for _, entry in pairs(JX.context) do
        local ok = true

        if entry.when then
            local fine, result = pcall(entry.when, entry)
            ok = fine and result and true or false
        end

        if ok then
            entry.coordsNow = pos + entry.offset
            entry.dist = 0.0
            entry.screen = -1.0
            list[#list + 1] = entry
        end
    end

    table.sort(list, function(a, b) return a.screen < b.screen end)

    JX.nearby = Scan.Visible(list)
    return JX.nearby
end

function Scan.Visible(list)
    if not Config.LineOfSight or #list == 0 then return list end

    local from = eye()
    local lift = vec3(0.0, 0.0, Config.SightLift)
    local tests = {}

    for i = 1, math.min(#list, Config.MaxDrawn) do
        local point = list[i]

        if not point.ignoreLos and not point.always then
            local to = point.coordsNow + lift
            tests[i] = StartShapeTestRay(from.x, from.y, from.z, to.x, to.y, to.z, 1 + 16, JX.ped, 4)
        end
    end

    if next(tests) == nil then return list end

    Wait(0)

    local seen = {}

    for i = 1, #list do
        local handle = tests[i]

        if not handle then
            seen[#seen + 1] = list[i]
        else
            local _, hit, _, _, entity = GetShapeTestResult(handle)

            if hit ~= 1 or entity == list[i].entity then
                seen[#seen + 1] = list[i]
            end
        end
    end

    return seen
end
