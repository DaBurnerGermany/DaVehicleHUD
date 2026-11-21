-- Use hex colors. #RRGGBBAA adds transparency to #RRGGBB.
-- Colors are applied in order: theme defaults, round (round gauges only), all, then per-theme overrides.
-- Available options depend on the instruments in the theme.
--   accent, speed, rpm, fuel, redline, reserve, needle, gear
--   text, muted, track, ticks, border, background, backgroundEdge, dialCenter, dialEdge, panel
Config.Colors = {
    all = {
        -- reserve = '#ffae62',
    },
    round = {
        accent = '#79e4bb',
        redline = '#ff786f',
        reserve = '#ffae62',
        text = '#ebfff8',
        muted = '#aad0c4',
        track = '#324d49',
        ticks = '#81a39c',
        border = '#44625f',
        dialCenter = '#1e3433d6',
        dialEdge = '#111a1bc7',
        panel = '#101b1bcf',
        -- Optional speed, rpm, and fuel values override the accent color for those instruments.
    },
    arcane = {
        -- rpm = '#ffb84f',
        -- background = '#161210cf',
    },
    digital = {
        -- accent = '#79d9fd',
    },
    single_round = {
        -- speed = '#7bbcff',
    },
    dual_round = {
        -- rpm = '#d3a4ff',
        -- fuel = '#72e7c9',
    },
    supercar = {
        -- rpm = '#f8c943',
        -- background = '#262a2d9e',
        -- backgroundEdge = '#0f11138a',
    },
    supercar2 = {
        -- rpm = '#f2f5fa',
        -- redline = '#fa605b',
    },
    supercar3 = {
        -- rpm = '#57e5ff',
        -- needle = '#ff626b',
    },
    electric = {
        -- accent = '#65b4ff',
        -- fuel = '#5faaff',
    },
    touring = {
        -- speed = '#72e7c9',
        -- rpm = '#59d1cd',
    },
    analog = {
        -- needle = '#ff6152',
        -- ticks = '#d9c9b0',
    },
    vintage = {
        -- needle = '#ff974a',
        -- dialCenter = '#304b289c',
    },
    motorcycle = {
        -- rpm = '#83e7c3',
        -- gear = '#a1f6d6',
    },
    orbit = {
        -- speed = '#68bbff',
        -- rpm = '#d9f1ff',
        -- fuel = '#d9f1ff',
    },
    aircraft = {
        -- accent = '#74c7ef',
        -- background = '#102436d9',
    },
    fighter_jet = {
        -- accent = '#95ffad',
        -- text = '#c8ffce',
    },
    bicycle = {
        -- text = '#19271c',
        -- dialCenter = '#b7c5a4',
    }
}
