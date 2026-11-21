Config = {
    -- 'de' = German, 'en' = English
    Locale = 'de',

    -- 'kmh' = km/h, 'mph' = miles per hour
    SpeedUnit = 'kmh',

    -- Default DaVehicleHUD keys. Use false to skip registering a key binding for that action.
    Keybinds = {
        LeftSignal = 'LEFT',
        RightSignal = 'RIGHT',
        Hazard = 'UP',
        Seatbelt = 'B',
        CruiseControl = 'CAPITAL' -- Caps Lock
    },

    -- Turn signal click volume from 0 (muted) to 1 (full volume).
    IndicatorSoundVolume = 0.3,

    -- Low fuel warning volume from 0 to 1. Duration and interval are in seconds.
    FuelWarningSoundVolume = 0.3,
    FuelWarningSoundSeconds = 5,
    FuelWarningIntervalSeconds = 0.8,

    -- Seat belt warning duration in seconds and volume from 0 to 1. Set either to 0 to mute it.
    SeatbeltWarningSeconds = 30,
    SeatbeltWarningVolume = 0.55,

    -- Additional crash detection for unbuckled occupants. Speed thresholds are always in km/h.
    SeatbeltCrashEjection = true,
    SeatbeltCrashMinSpeedKmh = 80,
    SeatbeltCrashMinSpeedLossKmh = 35,

    -- Cruise control for cars and motorcycles.
    CruiseControl = {
        Enabled = true
    },

    -- Fallback theme for vehicles without a model, class, or vehicle type override.
    -- 'arcane', 'digital', 'single_round', 'dual_round', 'supercar', 'supercar2', 'supercar3', 'electric', 'touring', 'analog', 'vintage', 'motorcycle', 'orbit', 'aircraft', 'fighter_jet', 'bicycle'
    Theme = 'orbit',

    -- Default themes by vehicle type. Use false to fall back to Theme.
    MotorcycleTheme = 'motorcycle',
    AircraftTheme = 'aircraft', -- Airplanes and helicopters
    BicycleTheme = 'bicycle'
}

-- Client-side fuel provider. Return the fuel percentage and, optionally, whether the vehicle is electric and whether the fuel system has failed.
-- Replace this function to use another fuel provider.
Config.GetFuel = function(vehicle, theme)
    if GetResourceState('myFuel') ~= 'started' then
        return nil
    end

    local fuel = exports['myFuel']:GetFuel(vehicle)
    local isElectric = false
    if theme == 'electric' then
        local available, unit = pcall(function()
            return exports['myFuel']:GetFuelUnit(vehicle)
        end)
        isElectric = available and unit == 'KW'
    end

    return fuel, isElectric, Entity(vehicle).state.myFuelTankStatus == 'broken'
end
