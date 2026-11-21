local windscreenEjectionFlag = 32
local vehicleExitControl = 75
local seatbeltRestartKey = 'DaVehicleHUD:seatbeltRestart'
local seatbelt
local windscreenPed
local previousWindscreenFlag
local lightDebugNight = false
local cruiseControl
local accelerateControl = 71
local brakeControl = 72
local handbrakeControl = 76
local supportedThemes = {
    arcane = true,
    digital = true,
    single_round = true,
    dual_round = true,
    supercar = true,
    supercar2 = true,
    supercar3 = true,
    electric = true,
    touring = true,
    analog = true,
    vintage = true,
    motorcycle = true,
    orbit = true,
    aircraft = true,
    fighter_jet = true,
    bicycle = true
}
local function resolveTheme(theme)
    if theme == 'round' then
        return 'single_round'
    end
    if supportedThemes[theme] then
        return theme
    end
end

local defaultTheme = resolveTheme(Config.Theme) or 'arcane'
local speedUnit = Config.SpeedUnit == 'mph' and 'mph' or 'kmh'
local speedMultiplier = speedUnit == 'mph' and (3600 / 1609.344) or 3.6
local cruiseConfig = Config.CruiseControl or {}
local keybinds = Config.Keybinds or {}
local indicatorSoundVolume = math.max(0, math.min(1, tonumber(Config.IndicatorSoundVolume) or 0.3))
local fuelWarningSoundVolume = math.max(0, math.min(1, tonumber(Config.FuelWarningSoundVolume) or 0.3))
local fuelWarningSoundSeconds = math.max(0, tonumber(Config.FuelWarningSoundSeconds) or 5)
local fuelWarningIntervalSeconds = math.max(0.25, tonumber(Config.FuelWarningIntervalSeconds) or 0.8)
local seatbeltWarningDuration = math.max(0, tonumber(Config.SeatbeltWarningSeconds) or 30) * 1000
local seatbeltWarningVolume = math.max(0, math.min(1, tonumber(Config.SeatbeltWarningVolume) or 0.55))
local seatbeltChimeLengthMs = 950
local seatbeltChimeIntervalMs = 1200
local seatbeltCrashEjection = Config.SeatbeltCrashEjection ~= false
local seatbeltCrashMinSpeed = math.max(1, tonumber(Config.SeatbeltCrashMinSpeedKmh) or 80) / 3.6
local seatbeltCrashMinSpeedLoss = math.max(1, tonumber(Config.SeatbeltCrashMinSpeedLossKmh) or 35) / 3.6
local crashSampleIntervalMs = 100
local crashContactWindowMs = 175
local motorcycleTheme = resolveTheme(Config.MotorcycleTheme)
local aircraftTheme = resolveTheme(Config.AircraftTheme)
local bicycleTheme = resolveTheme(Config.BicycleTheme)
local colorConfig = Config.Colors or {}
local themeColors = {}
for theme in pairs(supportedThemes) do
    local colors = {}
    if theme == 'single_round' or theme == 'dual_round' then
        for key, color in pairs(colorConfig.round or {}) do
            colors[key] = color
        end
    end
    for key, color in pairs(colorConfig.all or {}) do
        colors[key] = color
    end
    for key, color in pairs(colorConfig[theme] or {}) do
        colors[key] = color
    end
    themeColors[theme] = colors
end
local vehicleClassThemes = {}
for class, theme in pairs(Config.VehicleClassThemes or {}) do
    if type(class) == 'number' then
        vehicleClassThemes[class] = resolveTheme(theme)
    end
end

local vehicleThemes = {}
for model, theme in pairs(Config.VehicleThemes or {}) do
    local resolvedTheme = resolveTheme(theme)
    if type(model) == 'string' and resolvedTheme then
        vehicleThemes[joaat(model:lower()) & 0xffffffff] = resolvedTheme
    end
end

local locale = Locales[Config.Locale] and Config.Locale or 'de'
local labels = Locales[locale]

local function registerHudKey(command, label, setting, defaultKey)
    local key = keybinds[setting]
    if key == false then
        return
    end
    if type(key) ~= 'string' or key == '' then
        key = defaultKey
    end
    RegisterKeyMapping(command, 'DaVehicleHUD: ' .. label, 'keyboard', key)
end

local function isNativeFlagOn(state)
    -- The native's BOOL outputs can arrive as integers in Lua. Read only the flag byte.
    local value = math.tointeger(state)
    return state == true or (value ~= nil and (value & 0xff) == 1)
end

local function clearLightDebugNight()
    if lightDebugNight then
        NetworkClearClockTimeOverride()
        lightDebugNight = false
    end
end

local function showNotification(message)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, false)
end

local function setWindscreenEjection(ped, allowed)
    if windscreenPed ~= ped then
        if windscreenPed and DoesEntityExist(windscreenPed) then
            SetPedConfigFlag(windscreenPed, windscreenEjectionFlag, previousWindscreenFlag)
        end

        windscreenPed = ped
        previousWindscreenFlag = nil
        if ped then
            if seatbelt and seatbelt.ped == ped then
                previousWindscreenFlag = seatbelt.previousEjectionFlag
            else
                previousWindscreenFlag = isNativeFlagOn(GetPedConfigFlag(ped, windscreenEjectionFlag, true))
            end
        end
    end

    if ped then
        SetPedConfigFlag(ped, windscreenEjectionFlag, allowed)
    end
end

local function releaseSeatbelt(keepForRestart)
    if not seatbelt then
        return
    end

    if DoesEntityExist(seatbelt.ped) then
        local stillInCar = windscreenPed == seatbelt.ped
            and GetVehiclePedIsIn(seatbelt.ped, false) == seatbelt.vehicle
        SetPedConfigFlag(seatbelt.ped, windscreenEjectionFlag, stillInCar or seatbelt.previousEjectionFlag)
    end
    seatbelt = nil
    if not keepForRestart then
        DeleteResourceKvp(seatbeltRestartKey)
    end
end

local function isSeatbeltVehicleOccupied(ped, vehicle)
    return vehicle ~= 0 and DoesEntityExist(vehicle) and PlayerPedId() == ped
        and not isNativeFlagOn(IsEntityDead(ped)) and GetVehiclePedIsIn(ped, false) == vehicle
end

local function hasSeatbelt(vehicle)
    return isNativeFlagOn(IsThisModelACar(GetEntityModel(vehicle)))
end

local function isBuckledIn(ped, vehicle)
    return seatbelt ~= nil and seatbelt.ped == ped and seatbelt.vehicle == vehicle
end

local function ejectAfterCrash(ped, velocity)
    -- Match ESX's ejection: move the ped out of the seat and carry over the pre-impact velocity.
    local position = GetEntityCoords(ped)
    SetEntityCoords(ped, position.x, position.y, position.z - 0.47, true, true, true, false)
    SetEntityVelocity(ped, velocity.x, velocity.y, velocity.z)

    local deadline = GetGameTimer() + 150
    repeat
        Wait(0)
        if PlayerPedId() ~= ped or isNativeFlagOn(IsEntityDead(ped)) then
            return
        end
        if GetVehiclePedIsIn(ped, false) == 0 then
            SetPedToRagdoll(ped, 1000, 1000, 0, false, false, false)
            SetEntityVelocity(ped, velocity.x, velocity.y, velocity.z)
            return
        end
    until GetGameTimer() >= deadline
end

local function startCrashEjection()
    CreateThread(function()
        local trackedPed, trackedVehicle
        local sampleAt, sampleVelocity, sampleSpeed, sampleBodyHealth
        local lastContactAt

        while true do
            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(ped, false)
            if vehicle ~= 0 and DoesEntityExist(vehicle) and hasSeatbelt(vehicle)
                and not isBuckledIn(ped, vehicle) and not isNativeFlagOn(IsEntityDead(ped)) then
                local now = GetGameTimer()
                local velocity = GetEntityVelocity(vehicle)
                local speed = #velocity
                local bodyHealth = GetVehicleBodyHealth(vehicle)

                if ped ~= trackedPed or vehicle ~= trackedVehicle or now - sampleAt > crashContactWindowMs then
                    trackedPed, trackedVehicle = ped, vehicle
                    lastContactAt = nil
                    sampleAt, sampleVelocity, sampleSpeed, sampleBodyHealth = now, velocity, speed, bodyHealth
                else
                    if isNativeFlagOn(HasEntityCollidedWithAnything(vehicle)) or bodyHealth < sampleBodyHealth then
                        lastContactAt = now
                    end

                    if lastContactAt and now - lastContactAt <= crashContactWindowMs
                        and sampleSpeed >= seatbeltCrashMinSpeed then
                        -- Project onto the old direction so a rebound also counts as a speed loss.
                        local forwardSpeed = (velocity.x * sampleVelocity.x + velocity.y * sampleVelocity.y
                            + velocity.z * sampleVelocity.z) / sampleSpeed
                        if sampleSpeed - forwardSpeed >= seatbeltCrashMinSpeedLoss then
                            trackedVehicle = nil
                            -- Let the game apply its native ejection first, if it can.
                            Wait(50)
                            if isSeatbeltVehicleOccupied(ped, vehicle) and not isBuckledIn(ped, vehicle) then
                                ejectAfterCrash(ped, sampleVelocity)
                            end
                            Wait(600)
                        end
                    end

                    if now - sampleAt >= crashSampleIntervalMs or speed > sampleSpeed then
                        sampleAt, sampleVelocity, sampleSpeed, sampleBodyHealth = now, velocity, speed, bodyHealth
                    end
                end
                Wait(0)
            else
                trackedVehicle = nil
                Wait(100)
            end
        end
    end)
end

local function getSeatbeltVehicleNetworkId(vehicle)
    return isNativeFlagOn(NetworkGetEntityIsNetworked(vehicle)) and NetworkGetNetworkIdFromEntity(vehicle) or 0
end

local function buckleSeatbelt(ped, vehicle, previousEjectionFlag)
    if previousEjectionFlag == nil then
        if windscreenPed == ped then
            previousEjectionFlag = previousWindscreenFlag
        else
            previousEjectionFlag = isNativeFlagOn(GetPedConfigFlag(ped, windscreenEjectionFlag, true))
        end
    end

    local buckle = {
        ped = ped,
        vehicle = vehicle,
        model = GetEntityModel(vehicle),
        networkId = getSeatbeltVehicleNetworkId(vehicle),
        savedAt = GetGameTimer(),
        previousEjectionFlag = previousEjectionFlag
    }
    seatbelt = buckle
    SetPedConfigFlag(ped, windscreenEjectionFlag, false)

    CreateThread(function()
        while seatbelt == buckle do
            if not isSeatbeltVehicleOccupied(ped, vehicle) then
                releaseSeatbelt()
                return
            end

            DisableControlAction(0, vehicleExitControl, true)
            Wait(0)
        end
    end)
    SetResourceKvp(seatbeltRestartKey, json.encode(buckle))
end

RegisterCommand('davehiclehud_seatbelt', function()
    local message
    if seatbelt then
        releaseSeatbelt()
        message = labels.seatbeltOff
    else
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        if not isSeatbeltVehicleOccupied(ped, vehicle) or not hasSeatbelt(vehicle) then
            return
        end
        buckleSeatbelt(ped, vehicle)
        message = labels.seatbeltOn
    end

    showNotification(message)
end, false)
registerHudKey('davehiclehud_seatbelt', labels.seatbelt, 'Seatbelt', 'B')

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        if seatbelt then
            seatbelt.savedAt = GetGameTimer()
            SetResourceKvp(seatbeltRestartKey, json.encode(seatbelt))
        end
        releaseSeatbelt(true)
        setWindscreenEjection(nil)
        clearLightDebugNight()
    end
end)

local function restoreSeatbelt()
    local checkpoint = GetResourceKvpString(seatbeltRestartKey)
    if not checkpoint then
        return
    end

    local decoded, saved = pcall(json.decode, checkpoint)
    if decoded and type(saved) == 'table' and type(saved.savedAt) == 'number' then
        local elapsed = GetGameTimer() - saved.savedAt
        if elapsed >= 0 and elapsed <= 30000 then
            local deadline = GetGameTimer() + 2000
            repeat
                local ped = PlayerPedId()
                local vehicle = GetVehiclePedIsIn(ped, false)
                if seatbelt then
                    return
                end
                if vehicle ~= 0 and DoesEntityExist(vehicle) then
                    local networkId = getSeatbeltVehicleNetworkId(vehicle)
                    if ped == saved.ped and GetEntityModel(vehicle) == saved.model
                        and ((networkId ~= 0 and networkId == saved.networkId)
                            or (networkId == 0 and saved.networkId == 0 and vehicle == saved.vehicle))
                        and isSeatbeltVehicleOccupied(ped, vehicle) then
                        buckleSeatbelt(ped, vehicle, saved.previousEjectionFlag)
                        return
                    end
                end
                Wait(50)
            until GetGameTimer() >= deadline
        end
    end

    DeleteResourceKvp(seatbeltRestartKey)
end

local function readFuel(vehicle, theme)
    if type(Config.GetFuel) ~= 'function' then
        return nil, false, false
    end

    local success, fuel, electric, fuelSystemFailed = pcall(Config.GetFuel, vehicle, theme)
    if not success then
        return nil, false, false
    end

    fuel = tonumber(fuel)
    local level = fuel and fuel == fuel and math.max(0, math.min(100, fuel)) or nil
    return level, electric == true, fuelSystemFailed == true
end

local function toggleIndicators(mode)
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then
        return
    end

    local currentMode = GetVehicleIndicatorLights(vehicle) & 3
    local nextMode = currentMode == mode and 0 or mode
    SetVehicleIndicatorLights(vehicle, 1, (nextMode & 1) ~= 0)
    SetVehicleIndicatorLights(vehicle, 0, (nextMode & 2) ~= 0)
end

local lightDebugRunning = false

RegisterCommand('davehiclehud_lightdebug', function(_, args)
    if lightDebugRunning then
        return
    end

    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then
        print('[DaVehicleHUD] ' .. labels.lightDebugNoVehicle)
        return
    end

    lightDebugRunning = true
    if args[1] == 'night' then
        NetworkOverrideClockTime(23, 0, 0)
        lightDebugNight = true
    end
    print('[DaVehicleHUD] ' .. labels.lightDebugStart)

    CreateThread(function()
        local started = GetGameTimer()
        local lastState
        while GetGameTimer() - started < 12000 and GetVehiclePedIsIn(ped, false) == vehicle do
            local result, lightsOn, highBeamsOn = GetVehicleLightsState(vehicle)
            local beam = isNativeFlagOn(highBeamsOn) and labels.highBeam
                or (isNativeFlagOn(lightsOn) and labels.lowBeam or labels.lightsOff)
            local state = ('HUD=%s | result=%s | lightsOn=%s | highBeamsOn=%s'):format(
                beam, tostring(result), tostring(lightsOn), tostring(highBeamsOn)
            )
            if state ~= lastState or IsControlJustPressed(0, 74) then
                print(('[DaVehicleHUD] %0.1fs | %s'):format((GetGameTimer() - started) / 1000, state))
                lastState = state
            end
            Wait(0)
        end
        clearLightDebugNight()
        lightDebugRunning = false
        print('[DaVehicleHUD] ' .. labels.lightDebugEnd)
    end)
end, false)

RegisterCommand('davehiclehud_left', function()
    toggleIndicators(1)
end, false)
registerHudKey('davehiclehud_left', labels.leftSignal, 'LeftSignal', 'LEFT')

RegisterCommand('davehiclehud_right', function()
    toggleIndicators(2)
end, false)
registerHudKey('davehiclehud_right', labels.rightSignal, 'RightSignal', 'RIGHT')

RegisterCommand('davehiclehud_hazard', function()
    toggleIndicators(3)
end, false)
registerHudKey('davehiclehud_hazard', labels.hazard, 'Hazard', 'UP')

local function canUseCruise(ped, vehicle)
    return isSeatbeltVehicleOccupied(ped, vehicle)
        and GetPedInVehicleSeat(vehicle, -1) == ped
        and isNativeFlagOn(IsVehicleDriveable(vehicle, false))
        and isNativeFlagOn(GetIsVehicleEngineRunning(vehicle))
        and not isNativeFlagOn(IsPauseMenuActive())
end

local function startCruise(ped, vehicle, speed)
    local activeCruise = { ped = ped, vehicle = vehicle, target = speed }
    cruiseControl = activeCruise

    CreateThread(function()
        local lastSpeed = speed
        local lastBodyHealth = GetVehicleBodyHealth(vehicle)
        local throttleTrim = 0.0
        while cruiseControl == activeCruise do
            if not canUseCruise(ped, vehicle)
                or isNativeFlagOn(IsControlPressed(0, brakeControl))
                or isNativeFlagOn(IsControlPressed(0, handbrakeControl)) then
                cruiseControl = nil
                return
            end

            local currentSpeed = GetEntitySpeed(vehicle)
            local bodyHealth = GetVehicleBodyHealth(vehicle)
            if GetEntitySpeedVector(vehicle, true).y <= 0.5 or lastBodyHealth - bodyHealth > 10.0
                or (lastSpeed - currentSpeed > 3.0 and isNativeFlagOn(HasEntityCollidedWithAnything(vehicle))) then
                cruiseControl = nil
                return
            end

            local error = activeCruise.target - currentSpeed
            throttleTrim = math.max(0, math.min(1, throttleTrim + error * math.min(GetFrameTime(), 0.1) * 0.35))
            local throttle = math.max(0, math.min(1, throttleTrim + error * 0.35))
            if throttle > 0 and error >= -0.15 then
                SetControlNormal(0, accelerateControl, throttle)
            end

            lastSpeed, lastBodyHealth = currentSpeed, bodyHealth
            Wait(0)
        end
    end)
end

if cruiseConfig.Enabled ~= false then
    RegisterCommand('davehiclehud_cruise', function()
        if cruiseControl then
            cruiseControl = nil
            showNotification(labels.cruiseOff)
            return
        end

        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        if not canUseCruise(ped, vehicle) then
            return
        end

        local model = GetEntityModel(vehicle)
        local roadVehicle = (isNativeFlagOn(IsThisModelACar(model)) or isNativeFlagOn(IsThisModelABike(model)))
            and not isNativeFlagOn(IsThisModelABicycle(model))
        if not roadVehicle or GetEntitySpeedVector(vehicle, true).y <= 0.5 then
            return
        end

        local speed = GetEntitySpeed(vehicle)
        startCruise(ped, vehicle, speed)
        local unit = speedUnit == 'mph' and 'mph' or 'km/h'
        showNotification(labels.cruiseOn:format(math.floor(speed * speedMultiplier + 0.5), unit))
    end, false)
    registerHudKey('davehiclehud_cruise', labels.cruise, 'CruiseControl', cruiseConfig.Key or 'CAPITAL')
end

CreateThread(function()
    restoreSeatbelt()
    if seatbeltCrashEjection then
        startCrashEjection()
    end
    local wasVisible = false
    local warningVehicle
    local warningStarted
    local nextChime
    local fuelWarningVehicle
    local wasLowFuel = false

    while true do
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        local vehicleExists = vehicle ~= 0 and DoesEntityExist(vehicle)
        local visible = vehicleExists and not IsPauseMenuActive()
        local currentFuelVehicle = vehicleExists and vehicle or nil
        if currentFuelVehicle ~= fuelWarningVehicle then
            fuelWarningVehicle = currentFuelVehicle
            wasLowFuel = false
        end
        local seatbeltAvailable = vehicleExists and hasSeatbelt(vehicle)
        local seatbeltWarning = seatbeltAvailable and not isBuckledIn(ped, vehicle)
        local manageEjection = seatbeltAvailable and not isNativeFlagOn(IsEntityDead(ped))
            and GetConvar('game_enableFlyThroughWindscreen', 'false') == 'true'
        setWindscreenEjection(manageEjection and ped or nil, seatbeltWarning)

        local chimeVolume, chimeMs
        if seatbeltWarning and seatbeltWarningDuration > 0 and seatbeltWarningVolume > 0 then
            local now = GetGameTimer()
            if warningVehicle ~= vehicle then
                warningVehicle = vehicle
                warningStarted = now
                nextChime = now
            end
            local remaining = seatbeltWarningDuration - (now - warningStarted)
            if visible and now >= nextChime and remaining > 0 then
                chimeVolume = seatbeltWarningVolume
                chimeMs = math.min(remaining, seatbeltChimeLengthMs)
                nextChime = now + seatbeltChimeIntervalMs
            end
        else
            warningVehicle = nil
        end

        if visible then
            local indicators = GetVehicleIndicatorLights(vehicle)
            local _, lightsOn, highBeamsOn = GetVehicleLightsState(vehicle)
            local highBeam = isNativeFlagOn(highBeamsOn)
            local sirenActive = isNativeFlagOn(IsVehicleSirenAudioOn(vehicle))
            local vehicleClass = GetVehicleClass(vehicle)
            local hasSiren = sirenActive or GetEntityBoneIndexByName(vehicle, 'siren1') ~= -1
                or vehicleClass == 18
            local model = GetEntityModel(vehicle)
            local bicycle = isNativeFlagOn(IsThisModelABicycle(model))
            local theme = vehicleThemes[model & 0xffffffff]
                or vehicleClassThemes[vehicleClass]
                or (bicycle and (bicycleTheme or defaultTheme))
                or (aircraftTheme
                    and (isNativeFlagOn(IsThisModelAPlane(model)) or isNativeFlagOn(IsThisModelAHeli(model)))
                    and aircraftTheme)
                or (motorcycleTheme and isNativeFlagOn(IsThisModelABike(model)) and motorcycleTheme)
                or defaultTheme
            local fuel, electric, fuelSystemFailed
            if not bicycle then
                fuel, electric, fuelSystemFailed = readFuel(vehicle, theme)
            end
            local fuelWarningChimeVolume
            if fuel ~= nil then
                local lowFuel = fuel < 15
                if lowFuel and not wasLowFuel and fuelWarningSoundVolume > 0 and fuelWarningSoundSeconds > 0 then
                    fuelWarningChimeVolume = fuelWarningSoundVolume
                end
                wasLowFuel = lowFuel
            end
            local flight = theme == 'aircraft' or theme == 'fighter_jet'
            local heading, landingGear
            if flight then
                local forward = GetEntityForwardVector(vehicle)
                heading = math.deg(math.atan(forward.x, forward.y)) % 360
                landingGear = GetLandingGearState(vehicle)
            end
            SendNUIMessage({
                action = 'vehicleHud',
                theme = theme,
                colors = themeColors[theme],
                locale = locale,
                visible = true,
                speed = math.floor(GetEntitySpeed(vehicle) * speedMultiplier + 0.5),
                speedUnit = speedUnit,
                cruiseSpeed = cruiseControl and cruiseControl.ped == ped and cruiseControl.vehicle == vehicle
                    and math.floor(cruiseControl.target * speedMultiplier + 0.5) or nil,
                indicatorSoundVolume = indicatorSoundVolume,
                bicycle = bicycle,
                altitude = flight and math.max(0, GetEntityHeightAboveGround(vehicle)) or nil,
                verticalSpeed = flight and GetEntityVelocity(vehicle).z or nil,
                heading = heading,
                landingGear = landingGear,
                rpm = GetIsVehicleEngineRunning(vehicle) and GetVehicleCurrentRpm(vehicle) or 0,
                gear = GetVehicleCurrentGear(vehicle),
                fuel = fuel,
                fuelWarningChimeVolume = fuelWarningChimeVolume,
                fuelWarningSoundSeconds = fuelWarningChimeVolume and fuelWarningSoundSeconds or nil,
                fuelWarningIntervalSeconds = fuelWarningChimeVolume and fuelWarningIntervalSeconds or nil,
                electric = electric,
                leftSignal = (indicators & 1) ~= 0,
                rightSignal = (indicators & 2) ~= 0,
                seatbeltAvailable = seatbeltAvailable,
                seatbeltWarning = seatbeltWarning,
                seatbeltChimeVolume = chimeVolume,
                seatbeltChimeMs = chimeMs,
                checkEngine = fuelSystemFailed or GetVehicleEngineHealth(vehicle) < 650.0,
                lowBeam = isNativeFlagOn(lightsOn) and not highBeam,
                highBeam = highBeam,
                hasSiren = hasSiren,
                siren = sirenActive
            })
        elseif wasVisible then
            SendNUIMessage({ action = 'vehicleHud', visible = false })
        end

        wasVisible = visible
        Wait(150)
    end
end)
