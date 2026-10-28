Config = {}

--- Keys -----------------------------------------------------------------

Config.Key = 0x8AAA0AD4
Config.Select = 0x17BEC168
Config.Up = 0x81457A1A
Config.Down = 0x9DA42644

--- Behaviour ------------------------------------------------------------

-- menu or inline
Config.SubMenu = 'menu'

Config.BackLabel = 'Back'
Config.ShowUnavailable = false

-- Answer on these scripts' exports, if they are not running.
Config.Takeover = {
    ox_target = true,
}

--- Distance -------------------------------------------------------------

Config.ScanDistance = 12.0
Config.RenderDistance = 8.0
Config.InteractDistance = 2.5

-- How far above an entity's origin its marker sits, when a script gives no
-- offset of its own.
Config.Lift = {
    ped = 0.40,
    pedDead = 0.10,
    object = 0.30,
    vehicle = 0.80,
}

-- Use the model's bounding box instead, for things whose origin is not their
-- middle. A prop's pivot is at its base; a carcass lies flat.
Config.BoundsCentre = {
    pedDead = true,
    object = true,
}

-- Hide anything behind a wall. Opt out per point with ignoreLos.
Config.LineOfSight = true
Config.SightLift = 0.5

-- How near the middle of the screen before a menu opens, and how much
-- more forgiving that gets once you are in range.
Config.FocusThreshold = 0.10
Config.FocusNear = 2.5

--- Colour ---------------------------------------------------------------

Config.Palette = {
    white = { 255, 255, 255 },
    bone = { 236, 226, 205 },
    grey = { 150, 150, 150 },
    darkgrey = { 78, 78, 78 },
    black = { 24, 24, 24 },

    red = { 168, 46, 40 },
    blue = { 68, 108, 164 },
    green = { 84, 138, 78 },
    gold = { 206, 166, 74 },
    orange = { 198, 110, 44 },
    purple = { 118, 80, 148 },
    tan = { 176, 146, 106 },
}

-- A name above, or { r, g, b }.
Config.Colours = {
    badge = 'white',
    badgeFocus = 'white',

    row = 'grey',
    rowSelected = 'white',

    marker = 'white',

    text = 'white',
    textSelected = 'white',
}

-- How far the rows you are not on fade back.
Config.DimAlpha = 0.70

--- Size -----------------------------------------------------------------

-- Raise on 1440p and up.
Config.Scale = 1.0

Config.Ui = {
    badge = 0.020,
    icon = 0.012,

    -- Narrowest and widest a plate gets.
    rowW = 0.095,
    rowMaxW = 0.320,

    -- Width of an average character. Plates are sized by their label.
    charW = 0.0050,

    rowH = 0.015,

    -- Gap between plates. 0 makes them one strip.
    rowSpace = 0.0,

    -- Where the column starts. Plates grow right from here.
    rowX = 0.032,
    pop = 0.0,

    -- The rule beside the rows, and the gap it leaves for the marker.
    railW = 0.003,
    railGap = 0.010,
    railBreak = 0.004,
    railMin = 0.012,

    textPad = 0.006,
    textY = -0.011,
    text = 0.30,
}

-- How much narrower and shorter each level gets, in inline mode.
Config.SubWidth = 0.90
Config.SubHeight = 1.0

--- Motion ---------------------------------------------------------------

Config.FadeSpeed = 12

-- 1.0 snaps, 0.1 glides.
Config.Ease = 0.22

-- Damping on a menu attached to something moving.
Config.Follow = 0.18

--- Performance ----------------------------------------------------------

-- How often option checks run again, in ms.
Config.RefreshRate = 120

-- The engine draws 32 world-space origins a frame. Stay under it.
Config.MaxDrawn = 24

--- When it stays shut ---------------------------------------------------

Config.Disable = {
    dead = true,
    nuiFocused = true,
    pauseMenu = true,
    mounted = false,
    inVehicle = true,
    cuffed = true,
}

-- Anything else already owning the screen. Keeps the menu off the top of an
-- open inventory or a running progress bar.
Config.BlockWhile = {
    -- Player statebags that mean a menu is up.
    states = {
        'invOpen',
    },

    -- { resource, export }, asked only while that resource is running, so
    -- nothing here becomes a dependency.
    probes = {
        { 'ox_lib', 'progressActive' },
    },
}

Config.DisabledControls = {
    0xFD0F0C2C, -- next weapon
    0xCC1075A7, -- previous weapon
    0x018C47CF, -- aim
    0x17D3BFF5, -- sprint
    0x2277FAE9, -- grapple
    0x91C9A817, -- weapon wheel
}

-- Only while options are on screen, or you cannot mount a horse stood on a point.
Config.DisabledWhenOpen = {
    0x2EAB0795, -- dynamic scenario
    0xCEFD9220, -- enter
    0xCBDB82A8, -- horse exit
    0xFEFAB9B4, -- vehicle exit
}

--- Peds -----------------------------------------------------------------

Config.Peds = {
    enabled = false,
    humansOnly = false,
    skipDead = true,
    skipMounted = true,
    networkedOnly = true,
    options = {},
}
