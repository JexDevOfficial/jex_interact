JX = {}

JX.dict = 'jex_interaction'

JX.sprite = {
    badge = 'dot',
    badgeFocus = 'ring_key',

    row = 'unselected',
    rowFocus = 'selected',

    rail = 'rail',

    cursor = 'arrow_right',
    back = 'arrow_left',
    leaf = 'ring',
}

JX.points = {}
JX.order = {}
JX.nearby = {}
JX.focus = nil
JX.target = 0
JX.index = 1
JX.offset = 1
JX.alpha = 0
JX.held = false
JX.suppressed = false
JX.ped = PlayerPedId()
JX.aspect = GetAspectRatio()

local seq = 0

function JX.NextId(resource)
    seq = seq + 1
    return ('%s:%d'):format(resource or 'jex', seq)
end

function JX.Coords(v)
    if type(v) == 'vector3' then return v end
    if type(v) == 'table' then
        return vec3(v.x or v[1] or 0.0, v.y or v[2] or 0.0, v.z or v[3] or 0.0)
    end
    return vec3(0.0, 0.0, 0.0)
end

function JX.Scaled(key)
    return Config.Ui[key] * Config.Scale
end

local WIDTH = {
    a = 1.07, b = 0.94, c = 0.93, d = 1.03, e = 0.86, f = 0.85, g = 0.99,
    h = 1.10, i = 0.49, j = 0.93, k = 1.00, l = 0.86, m = 1.36, n = 1.12,
    o = 0.98, p = 1.00, q = 0.99, r = 1.00, s = 0.88, t = 0.89, u = 1.08,
    v = 1.06, w = 1.65, x = 1.01, y = 1.03, z = 0.88,

    ['0'] = 0.98, ['1'] = 0.49, ['2'] = 0.87, ['3'] = 0.90, ['4'] = 0.90,
    ['5'] = 0.88, ['6'] = 0.98, ['7'] = 0.81, ['8'] = 0.90, ['9'] = 0.98,

    [' '] = 0.66, ['.'] = 0.31, [','] = 0.32, ["'"] = 0.32, ['"'] = 0.52,
    ['-'] = 0.64, ['_'] = 0.80, ['('] = 0.45, [')'] = 0.45, ['['] = 0.45,
    [']'] = 0.45, ['{'] = 0.50, ['}'] = 0.50, ['%'] = 1.19, ['$'] = 0.92,
    ['/'] = 0.81, ['\\'] = 0.81, [':'] = 0.31, [';'] = 0.31, ['!'] = 0.31,
    ['?'] = 0.90, ['&'] = 0.98, ['+'] = 0.87, ['='] = 0.87, ['<'] = 0.87,
    ['>'] = 0.87, ['~'] = 0.87, ['*'] = 0.55, ['#'] = 0.90, ['@'] = 1.25,
    ['^'] = 0.60, ['`'] = 0.32, ['|'] = 0.30,
}

local AVERAGE = 1.0

local function step(byte)
    if byte < 0x80 then return 1 end
    if byte < 0xE0 then return 2 end
    if byte < 0xF0 then return 3 end
    return 4
end

local function widthAt(text, i, size)
    if size ~= 1 then return AVERAGE end

    return WIDTH[text:sub(i, i):lower()] or AVERAGE
end

function JX.TextWidth(text)
    local total, i, n = 0.0, 1, #text

    while i <= n do
        local size = step(text:byte(i))

        total = total + widthAt(text, i, size)
        i = i + size
    end

    return total * JX.Scaled('charW')
end

function JX.Fit(text, room)
    if JX.TextWidth(text) <= room then return text end

    local unit = JX.Scaled('charW')
    local total, i, n = 0.0, 1, #text

    while i <= n do
        local size = step(text:byte(i))

        total = total + widthAt(text, i, size) * unit

        if total > room - unit then
            return text:sub(1, i > 1 and i - 1 or size) .. '.'
        end

        i = i + size
    end

    return text
end

function JX.Label(option, entity)
    local label = option.label or option.text

    if type(label) == 'function' then
        local ok, result = pcall(label, option, entity)

        if not ok then
            JX.Warn(('label function errored: %s'):format(result))
            return ''
        end

        if type(result) ~= 'string' then
            JX.Warn(('label function returned %s, expected a string'):format(type(result)))
            return ''
        end

        return result
    end

    return type(label) == 'string' and label or ''
end

function JX.Allowed(option, entity)
    local check = option.canInteract or option.canUse
    if not check then return true end
    local ok, result = pcall(check, option, entity)
    return ok and result and true or false
end

local missing = {}

function JX.Colour(key)
    local value = Config.Colours[key]

    if type(value) == 'table' then return value end

    local found = Config.Palette[value]
    if found then return found end

    if value and not missing[value] then
        missing[value] = true
        JX.Warn(('no colour named "%s" in Config.Palette'):format(tostring(value)))
    end

    return Config.Palette.white
end

function JX.Available(point)
    for _, option in ipairs(point.options or {}) do
        if option.options or JX.Allowed(option, point.entity) then return true end
    end

    return false
end

function JX.Warn(msg)
    print(('^3[jex_interact]^0 %s'):format(msg))
end

local reported = {}

function JX.Try(tag, fn, ...)
    local ok, err = pcall(fn, ...)

    if not ok and not reported[tag] then
        reported[tag] = true
        JX.Warn(('%s failed: %s'):format(tag, err))
    end

    return ok
end

CreateThread(function()
    while true do
        JX.ped = PlayerPedId()
        JX.aspect = GetAspectRatio()
        Wait(500)
    end
end)

CreateThread(function()
    while not HasStreamedTextureDictLoaded(JX.dict) do
        RequestStreamedTextureDict(JX.dict, true)
        Wait(100)
    end
end)
