Render = {}

local drawing = false

JX.stack = {}
JX.expanded = {}

local function inline()
    return Config.SubMenu == 'inline'
end

local function wide(depth)
    return Config.SubWidth ^ depth
end

local function tall(depth)
    return Config.SubHeight ^ depth
end

local function row(option, entity, depth, key, open)
    return {
        option = option,
        label = JX.Label(option, entity),
        nested = option.options and #option.options > 0,
        dim = not JX.Allowed(option, entity),
        depth = depth,
        key = key,
        open = open,
    }
end

local function ordered(options)
    local plain, deeper = {}, {}

    for i, option in ipairs(options) do
        local entry = { at = i, option = option }

        if option.options and #option.options > 0 then
            deeper[#deeper + 1] = entry
        else
            plain[#plain + 1] = entry
        end
    end

    for _, entry in ipairs(deeper) do plain[#plain + 1] = entry end

    return plain
end

local function tree(options, depth, path, out, entity)
    for _, item in ipairs(ordered(options)) do
        local key = path == '' and tostring(item.at) or (path .. '.' .. item.at)
        local entry = row(item.option, entity, depth, key, JX.expanded[key] or false)

        if entry.label ~= '' and (not entry.dim or Config.ShowUnavailable) then
            out[#out + 1] = entry

            if entry.nested and entry.open then
                tree(item.option.options, depth + 1, key, out, entity)
            end
        end
    end

    return out
end

local function stacked(point)
    local top = JX.stack[#JX.stack]
    local options = top and top.options or point.options
    local rows = {}

    if #JX.stack > 0 then
        rows[1] = { back = true, label = Config.BackLabel, depth = 0 }
    end

    for _, item in ipairs(ordered(options)) do
        local entry = row(item.option, point.entity, 0, tostring(item.at), false)

        if entry.label ~= '' and (not entry.dim or Config.ShowUnavailable) then
            rows[#rows + 1] = entry
        end
    end

    return rows
end

local function build(point)
    if inline() then
        return tree(point.options, 0, '', {}, point.entity)
    end

    return stacked(point)
end

local cache, cachedFor, cachedAt = {}, nil, 0
local dirty = true

local function rowsFor(point)
    local now = GetGameTimer()

    if dirty or cachedFor ~= point.id or now - cachedAt >= Config.RefreshRate then
        cache = build(point)
        cachedFor = point.id
        cachedAt = now
        dirty = false
    end

    return cache
end

local function resetMenu()
    JX.stack = {}
    JX.expanded = {}
    JX.index = 1
    JX.offset = 1
    dirty = true
end

local function drawBadge(point, alpha, focused)
    local c = point.coordsNow
    local size = JX.Scaled('badge')
    local col = JX.Colour(focused and 'badgeFocus' or 'badge')

    SetDrawOrigin(c.x, c.y, c.z, 0)
    DrawSprite(JX.dict, focused and JX.sprite.badgeFocus or JX.sprite.badge,
        0.0, 0.0, size, size * JX.aspect, 0.0, col[1], col[2], col[3], alpha)
    ClearDrawOrigin()
end

local function drawText(text, size, x, y, col, alpha, room)
    text = tostring(text or '')
    if text == '' then return end

    if room then text = JX.Fit(text, room) end

    SetTextScale(size, size)
    SetTextColor(col[1], col[2], col[3], math.floor(alpha))
    SetTextCentre(false)
    SetTextDropshadow(3, 0, 0, 0, 255)
    SetTextFontForCurrentCommand(9)
    DisplayText(CreateVarString(10, 'LITERAL_STRING', text), x, y)
end

local function drawMenu(point, alpha, rows)
    local c = point.coordsNow
    local badge = JX.Scaled('badge')
    local widest = 0.0

    for _, entry in ipairs(rows) do
        widest = math.max(widest, JX.TextWidth(entry.label))
    end

    local rowW = math.min(
        math.max(JX.Scaled('rowW'), widest + JX.Scaled('textPad') * 2),
        JX.Scaled('rowMaxW'))

    local rowH = JX.Scaled('rowH')
    local space = JX.Scaled('rowSpace')
    local pop = JX.Scaled('pop')
    local right = JX.Scaled('rowX') + rowW
    local textY = JX.Scaled('textY')

    local pos, acc = {}, 0.0

    for i = 1, #rows do
        pos[i] = acc
        acc = acc + rowH * JX.aspect * tall(rows[i].depth) + space
    end

    local lo = math.max(1, math.min(#rows, math.floor(JX.offset)))
    local hi = math.min(#rows, lo + 1)
    local anchor = pos[lo] + (pos[hi] - pos[lo]) * (JX.offset - lo)

    SetDrawOrigin(c.x, c.y, c.z, 0)

    local lit = JX.Colour('badgeFocus')

    DrawSprite(JX.dict, JX.sprite.badgeFocus, 0.0, 0.0, badge, badge * JX.aspect,
        0.0, lit[1], lit[2], lit[3], alpha)

    local rule = JX.Colour('marker')
    local railX = right - rowW - JX.Scaled('railGap')

    local picked = rows[JX.index]
    local selH = rowH * JX.aspect * tall(picked and picked.depth or 0)
    local half = selH / 2 + JX.Scaled('railBreak')

    local top = pos[1] - anchor - (rowH * JX.aspect * tall(rows[1].depth)) / 2
    local bottom = pos[#rows] - anchor + (rowH * JX.aspect * tall(rows[#rows].depth)) / 2

    local function segment(from, to)
        local height = to - from
        if height <= 0.0 then return end

        DrawSprite(JX.dict, JX.sprite.rail,
            railX, from + height / 2, JX.Scaled('railW'), height,
            0.0, rule[1], rule[2], rule[3], alpha)
    end

    if #rows > 1 then
        local run = JX.Scaled('railMin')

        segment(math.min(top, -half - run), -half)
        segment(half, math.max(bottom, half + run))
    end

    local icon = JX.Scaled('icon')

    local mark = picked and picked.back and JX.sprite.back
        or (picked and picked.nested and JX.sprite.cursor or JX.sprite.leaf)

    DrawSprite(JX.dict, mark,
        railX, 0.0, icon, icon * JX.aspect,
        0.0, rule[1], rule[2], rule[3], alpha)

    for i, entry in ipairs(rows) do
        local selected = i == JX.index
        local sw, s = wide(entry.depth), tall(entry.depth)
        local w, h = rowW * sw, rowH * s
        local y = pos[i] - anchor

        local edge = right - w
        local x = edge + w / 2 - (selected and pop or 0.0)
        local fade = selected and alpha or math.floor(alpha * Config.DimAlpha)

        if entry.dim then fade = math.floor(fade * 0.5) end

        local plate = JX.Colour(selected and 'rowSelected' or 'row')
        local ink = JX.Colour(selected and 'textSelected' or 'text')

        DrawSprite(JX.dict, selected and JX.sprite.rowFocus or JX.sprite.row,
            x, y, w, h * JX.aspect, 0.0, plate[1], plate[2], plate[3], fade)

        drawText(entry.label, JX.Scaled('text') * s, edge + JX.Scaled('textPad'), y + textY * s, ink, fade,
            w - JX.Scaled('textPad') * 2)
    end

    ClearDrawOrigin()
end

local function openBranch(key)
    if JX.expanded[key] then
        local prefix = key .. '.'

        for k in pairs(JX.expanded) do
            if k == key or k:sub(1, #prefix) == prefix then JX.expanded[k] = nil end
        end

        return
    end

    local open, path = {}, nil

    for part in key:gmatch('[^.]+') do
        path = path and (path .. '.' .. part) or part
        open[path] = true
    end

    JX.expanded = open
end

local function dispatch(point, entry)
    if entry.back then
        local top = table.remove(JX.stack)
        JX.index = top and top.from or 1
        dirty = true
        return
    end

    if entry.dim then return end

    local option = entry.option

    if entry.nested then
        if inline() then
            openBranch(entry.key)
        else
            JX.stack[#JX.stack + 1] = { options = option.options, from = JX.index }
            JX.index = 2
        end

        dirty = true
        return
    end

    CreateThread(function()
        if option.onSelect then
            pcall(option.onSelect, option, point.entity)
        elseif option.event then
            TriggerEvent(option.event, option, point.entity)
        elseif option.serverEvent then
            TriggerServerEvent(option.serverEvent, option.args)
        end
    end)
end

local function tapped(control)
    return IsControlJustPressed(0, control) or IsDisabledControlJustPressed(0, control)
end

local function handleInput(point, rows)
    if #rows == 0 then return end

    if tapped(Config.Up) then
        JX.index = JX.index > 1 and JX.index - 1 or #rows
    elseif tapped(Config.Down) then
        JX.index = JX.index < #rows and JX.index + 1 or 1
    end

    if JX.index > #rows then JX.index = #rows end

    if tapped(Config.Select) and Registry.Inside(point, GetEntityCoords(JX.ped)) then
        dispatch(point, rows[JX.index])
    end
end

local function disable(list)
    for _, control in ipairs(list) do
        DisableControlAction(0, control, true)
    end
end

local function close()
    JX.held = false
    JX.dynamic = {}
    JX.nearby = {}
    JX.focus = nil
    resetMenu()
    TriggerEvent('jex_interact:closed')
end

CreateThread(function()
    while true do
        local wait = 250

        if not Scan.Blocked() then
            local held = IsControlPressed(0, Config.Key)

            if held and not JX.held then
                JX.held = true
                Scan.BuildDynamic()
                resetMenu()
                TriggerEvent('jex_interact:opened')
            elseif not held and JX.held then
                close()
            end

            if JX.held then
                Scan.Nearby()
                JX.target = Scan.Target(Config.ScanDistance)
                wait = 200
            end
        elseif JX.held then
            close()
        end

        Wait(wait)
    end
end)

CreateThread(function()
    while true do
        if JX.held and #JX.nearby > 0 then
            drawing = true

            local best = JX.nearby[1]

            local reach = Config.FocusThreshold
            if best.dist and best.dist <= (best.distance or 0) then
                reach = reach * Config.FocusNear
            end

            local open = best.always or best.screen <= reach

            if open and not best.always and best.entity and best.entity ~= JX.target and not best.ignoreLos then
                open = false
            end

            if open and not Registry.Inside(best, GetEntityCoords(JX.ped)) then
                open = false
            end

            if open and JX.focus ~= best.id then
                JX.focus = best.id
                resetMenu()
            elseif not open then
                JX.focus = nil
            end

            JX.alpha = math.min(255, JX.alpha + Config.FadeSpeed)

            local slide = JX.index - JX.offset
            JX.offset = math.abs(slide) < 0.002 and JX.index or JX.offset + slide * Config.Ease

            disable(Config.DisabledControls)

            local budget = math.min(#JX.nearby, Config.MaxDrawn)

            for i = 1, budget do
                local point = JX.nearby[i]

                local live = Registry.Live(point)

                if live then
                    if point.always or point.entity then
                        if not point.smooth or #(live - point.smooth) > 3.0 then
                            point.smooth = live
                        else
                            point.smooth = point.smooth + (live - point.smooth) * Config.Follow
                        end

                        point.coordsNow = point.smooth
                    else
                        point.coordsNow = live
                    end
                end

                if point.id == JX.focus then
                    local rows = rowsFor(point)

                    if #rows > 0 then
                        JX.Try('drawMenu', drawMenu, point, JX.alpha, rows)
                        disable(Config.DisabledWhenOpen)
                        handleInput(point, rows)
                    else
                        JX.Try('drawBadge', drawBadge, point, JX.alpha, true)
                    end
                else
                    JX.Try('drawBadge', drawBadge, point, JX.alpha, false)
                end
            end

            Wait(0)
        else
            if drawing then
                drawing = false
                JX.alpha = 0
            end
            Wait(120)
        end
    end
end)
