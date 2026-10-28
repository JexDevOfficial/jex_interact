local spawned = {}

local function say(msg)
    print(('^2[jex_interact]^0 %s'):format(msg))
end

RegisterCommand('jexdemo', function()
    local ped = PlayerPedId()
    local at = GetEntityCoords(ped) + GetEntityForwardVector(ped) * 2.0

    local id = exports.jex_interact:AddPoint {
        coords = at,
        options = {
            {
                label = 'Say hello',
                onSelect = function() say('hello') end,
            },
            {
                label = 'Stable',
                options = {
                    { label = 'Stable your horse', onSelect = function() say('stabled') end },
                    { label = 'Retrieve a horse', onSelect = function() say('retrieved') end },
                    {
                        label = 'Sell',
                        options = {
                            { label = 'Sell the bay', onSelect = function() say('sold the bay') end },
                            { label = 'Sell the grey', onSelect = function() say('sold the grey') end },
                        },
                    },
                },
            },
            {
                label = function() return ('The hour is %d'):format(GetClockHours()) end,
                onSelect = function() say('checked the time') end,
            },
            {
                label = 'Locked',
                canInteract = function() return false end,
                onSelect = function() say('should never happen') end,
            },
            {
                label = 'Buy feed',
                onSelect = function() say('bought feed') end,
            },
        },
    }

    spawned[#spawned + 1] = id
    say(('point %s at %.2f %.2f %.2f - hold ALT and look at it'):format(id, at.x, at.y, at.z))
end, false)

RegisterCommand('jexzone', function(_, args)
    local radius = tonumber(args[1]) or 10.0
    local at = GetEntityCoords(PlayerPedId())

    local id = exports.jex_interact:AddZone {
        coords = at,
        radius = radius,
        options = {
            { label = 'Rent a room', onSelect = function() say('rented') end },
            { label = 'Buy a drink', onSelect = function() say('poured') end },
        },
    }

    spawned[#spawned + 1] = id
    say(('zone %s, radius %.1f - walk anywhere inside it'):format(id, radius))
end, false)

RegisterCommand('jexprops', function(_, args)
    local model = args[1] or 'p_barrel02x'
    local max = tonumber(args[2])
    local at = GetEntityCoords(PlayerPedId())

    local id = exports.jex_interact:AddPropsInZone {
        coords = at,
        radius = tonumber(args[3]) or 40.0,
        max = max,
        models = { model },
        options = {
            { label = 'Search it', onSelect = function() say('searched') end },
        },
    }

    spawned[#spawned + 1] = id
    say(('props %s, model %s, max %s'):format(id, model, max and tostring(max) or 'all'))
end, false)

RegisterCommand('jexwater', function()
    local id = exports.jex_interact:AddWhileInWater {
        options = {
            { label = 'Cast a line', onSelect = function() say('fishing') end },
            { label = 'Fill canteen', onSelect = function() say('filled') end },
            { label = 'Wash up', onSelect = function() say('washed') end },
        },
    }

    spawned[#spawned + 1] = id
    say(('water context %s - get in a river and hold the key'):format(id))
end, false)

RegisterCommand('jexclear', function()
    for _, id in ipairs(spawned) do
        exports.jex_interact:Remove(id)
    end

    say(('removed %d'):format(#spawned))
    spawned = {}
end, false)

local debugOn = false

RegisterCommand('jexdebug', function()
    debugOn = not debugOn
    say('debug ' .. (debugOn and 'on' or 'off'))
end, false)

CreateThread(function()
    while true do
        if debugOn then
            local pos = GetEntityCoords(PlayerPedId())

            for _, id in ipairs(JX.order) do
                local point = JX.points[id]
                local c = point and Registry.Position(point)

                if c and #(pos - c) < 40.0 then
                    JX.Try('debugSprite', function()
                        SetDrawOrigin(c.x, c.y, c.z, 0)
                        DrawSprite(JX.dict, JX.sprite.badge, 0.0, 0.0,
                            0.02, 0.02 * JX.aspect, 0.0, 255, 255, 255, 255)
                        ClearDrawOrigin()
                    end)

                    JX.Try('debugText', function()
                        SetDrawOrigin(c.x, c.y, c.z, 0)
                        SetTextScale(0.35, 0.35)
                        SetTextColor(255, 255, 255, 255)
                        SetTextCentre(false)
                        SetTextFontForCurrentCommand(9)
                        DisplayText(CreateVarString(10, 'LITERAL_STRING', tostring(id)), -0.02, 0.02)
                        ClearDrawOrigin()
                    end)
                end
            end

            Wait(0)
        else
            Wait(500)
        end
    end
end)

CreateThread(function()
    while true do
        if debugOn then
            local best = JX.nearby[1]

            print(('^5[jex]^0 dict=%s blocked=%s held=%s points=%d nearby=%d focus=%s screen=%s target=%s'):format(
                tostring(HasStreamedTextureDictLoaded(JX.dict)),
                tostring(Scan.Blocked()),
                tostring(JX.held),
                #JX.order,
                #JX.nearby,
                tostring(JX.focus),
                best and ('%.3f'):format(best.screen) or '-',
                tostring(JX.target)))

            Wait(1000)
        else
            Wait(1000)
        end
    end
end)

RegisterCommand('jexcol', function(_, args)
    local name = args[1]

    if not name or Config.Colours[name] == nil then
        for key in pairs(Config.Colours) do
            local c = JX.Colour(key)
            say(('%-13s %-9s %d %d %d'):format(key, tostring(Config.Colours[key]), c[1], c[2], c[3]))
        end

        local names = {}
        for key in pairs(Config.Palette) do names[#names + 1] = key end
        table.sort(names)
        say('palette: ' .. table.concat(names, ' '))
        return
    end

    local value = args[2]
    local r, g, b = tonumber(args[2]), tonumber(args[3]), tonumber(args[4])

    if r and g and b then
        Config.Colours[name] = { r, g, b }
        say(('%s set to %d %d %d'):format(name, r, g, b))
    elseif value and Config.Palette[value] then
        Config.Colours[name] = value
        say(('%s set to %s'):format(name, value))
    else
        local c = JX.Colour(name)
        say(('%s is %d %d %d'):format(name, c[1], c[2], c[3]))
    end
end, false)

RegisterCommand('jexsub', function(_, args)
    local mode = args[1]

    local value = tonumber(args[2])

    if mode == 'menu' or mode == 'inline' then
        Config.SubMenu = mode
    elseif mode == 'w' and value then
        Config.SubWidth = math.max(0.4, math.min(1.0, value))
    elseif mode == 'h' and value then
        Config.SubHeight = math.max(0.4, math.min(1.0, value))
    else
        Config.SubMenu = Config.SubMenu == 'inline' and 'menu' or 'inline'
    end

    say(('sub menus %s, w %.2f h %.2f'):format(Config.SubMenu, Config.SubWidth, Config.SubHeight))
end, false)

RegisterCommand('jexdim', function(_, args)
    local value = tonumber(args[1])

    if not value then
        say(('dim is %.2f'):format(Config.DimAlpha))
        return
    end

    Config.DimAlpha = math.max(0.0, math.min(1.0, value))
    say(('dim set to %.2f'):format(Config.DimAlpha))
end, false)

RegisterCommand('jexlift', function(_, args)
    local kind, value = args[1], tonumber(args[2])

    if not kind or Config.Lift[kind] == nil then
        for _, name in ipairs({ 'ped', 'pedDead', 'object', 'vehicle' }) do
            say(('%-8s %.2f'):format(name, Config.Lift[name]))
        end
        say(('bounds centre: pedDead %s, object %s'):format(
            tostring(Config.BoundsCentre.pedDead), tostring(Config.BoundsCentre.object)))
        return
    end

    if not value then
        say(('%s lift is %.2f'):format(kind, Config.Lift[kind]))
        return
    end

    Config.Lift[kind] = value
    say(('%s lift set to %.2f'):format(kind, value))
end, false)

RegisterCommand('jexbounds', function(_, args)
    local kind = args[1]

    if kind ~= 'pedDead' and kind ~= 'object' then
        say('usage: jexbounds pedDead|object')
        return
    end

    Config.BoundsCentre[kind] = not Config.BoundsCentre[kind]
    say(('bounds centre for %s %s'):format(kind, Config.BoundsCentre[kind] and 'on' or 'off'))
end, false)

RegisterCommand('jexwidth', function(_, args)
    local text = table.concat(args, ' ')

    if text == '' then
        say('usage: jexwidth some label')
        return
    end

    local room = Config.Ui.rowMaxW * Config.Scale - Config.Ui.textPad * Config.Scale * 2

    say(('"%s"  estimated %.4f  room %.4f  fits %s  drawn as "%s"'):format(
        text, JX.TextWidth(text), room,
        tostring(JX.TextWidth(text) <= room), JX.Fit(text, room)))
end, false)

RegisterCommand('jexfollow', function(_, args)
    local value = tonumber(args[1])

    if not value then
        say(('follow is %.2f'):format(Config.Follow))
        return
    end

    Config.Follow = math.max(0.02, math.min(1.0, value))
    say(('follow set to %.2f'):format(Config.Follow))
end, false)

RegisterCommand('jexease', function(_, args)
    local value = tonumber(args[1])

    if not value then
        say(('ease is %.2f'):format(Config.Ease))
        return
    end

    Config.Ease = math.max(0.02, math.min(1.0, value))
    say(('ease set to %.2f'):format(Config.Ease))
end, false)

RegisterCommand('jexui', function(_, args)
    local key, value = args[1], tonumber(args[2])

    if not key then
        for _, name in ipairs({ 'badge', 'icon', 'rowW', 'rowMaxW', 'charW', 'rowH', 'rowSpace', 'rowX', 'pop', 'railW', 'railGap', 'railBreak', 'railMin', 'textPad', 'textY', 'text' }) do
            say(('%-8s %.4f'):format(name, Config.Ui[name]))
        end
        say(('%-8s %.4f  (row height on screen is rowH x %.2f = %.4f)'):format(
            'scale', Config.Scale, JX.aspect, Config.Ui.rowH * JX.aspect))
        return
    end

    if Config.Ui[key] == nil then
        say(('no such value: %s'):format(key))
        return
    end

    if not value then
        say(('%s is %.4f'):format(key, Config.Ui[key]))
        return
    end

    Config.Ui[key] = value
    say(('%s set to %.4f'):format(key, value))
end, false)

RegisterCommand('jexscale', function(_, args)
    local value = tonumber(args[1])
    if not value then
        say(('scale is %.2f'):format(Config.Scale))
        return
    end

    Config.Scale = value
    say(('scale set to %.2f'):format(value))
end, false)
