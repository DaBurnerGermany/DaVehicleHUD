-- Default HUD themes by GTA vehicle class ID. Use false to skip a class override.
Config.VehicleClassThemes = {
    [0] = 'arcane',              -- Compacts
    [1] = 'touring',             -- Sedans
    [2] = 'digital',             -- SUVs
    [3] = 'single_round',        -- Coupes
    [4] = 'analog',              -- Muscle
    [5] = 'vintage',             -- Sports classics
    [6] = 'orbit',               -- Sports
    [7] = 'supercar',            -- Super
    [8] = Config.MotorcycleTheme, -- Motorcycles
    [9] = 'dual_round',          -- Off-road
    [10] = 'digital',            -- Industrial
    [11] = 'digital',            -- Utility
    [12] = 'touring',            -- Vans
    [13] = Config.BicycleTheme,   -- Cycles
    [14] = 'digital',            -- Boats
    [15] = Config.AircraftTheme,  -- Helicopters
    [16] = Config.AircraftTheme,  -- Planes
    [17] = 'digital',            -- Service
    [18] = 'digital',            -- Emergency
    [19] = 'digital',            -- Military
    [20] = 'touring',            -- Commercial
    [21] = 'digital',            -- Trains
    [22] = 'supercar2'           -- Open wheel
}

-- Optional model overrides. Use the vehicle spawn name as the key.
Config.VehicleThemes = {
    -- Electric vehicles
    neon = 'electric',
    raiden = 'electric',
    voltic = 'electric',

    -- Everyday vehicles
    dilettante = 'touring',
    tailgater = 'touring',

    -- Supercars
    adder = 'supercar',
    zentorno = 'supercar2',
    tempesta = 'supercar3',

    -- Sports cars and tuners
    banshee = 'single_round',
    comet2 = 'dual_round',
    futo = 'arcane',
    sultan = 'analog',

    -- Classics
    peyote = 'vintage',
    tornado = 'vintage',

    -- Emergency vehicles
    ambulance = 'digital',
    police = 'digital',

    -- Fighter jets
    hydra = 'fighter_jet',
    lazer = 'fighter_jet',
    molotok = 'fighter_jet',
    raiju = 'fighter_jet',
    strikeforce = 'fighter_jet',

    -- ['my-addon-car'] = 'dual_round',
}
