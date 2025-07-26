local QBCore = exports['qb-core']:GetCoreObject()

-- Apply achievement-based vehicle modifications
RegisterNetEvent("achievements:applyVehicleModsClient")
AddEventHandler("achievements:applyVehicleModsClient", function(vehicleNetId, tierData)
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not DoesEntityExist(vehicle) then return end
    
    -- Wait for vehicle to be fully loaded
    while not IsEntityAVehicle(vehicle) do
        Wait(100)
    end
    
    -- SESSION 36 FIX: Add nil check for tierData
    if not tierData then
        print("[VEHICLE_ACHIEVEMENTS] Warning: No tier data received")
        return
    end
    
    -- Apply performance mods based on tier
    if tierData.performanceMods then
        SetVehicleModKit(vehicle, 0)
        
        for modType, modLevel in pairs(tierData.performanceMods) do
            if type(modType) == "number" then
                SetVehicleMod(vehicle, modType, modLevel, false)
            end
        end
    end
    
    -- Apply color tint
    if tierData.colorTint then
        SetVehicleCustomPrimaryColour(vehicle, tierData.colorTint.r, tierData.colorTint.g, tierData.colorTint.b)
        SetVehicleCustomSecondaryColour(vehicle, tierData.colorTint.r, tierData.colorTint.g, tierData.colorTint.b)
    end
    
    -- Apply special effects
    if tierData.specialEffects then
        -- Underglow/Neon
        if tierData.specialEffects.underglow and Config.AchievementVehicles.visualEffects.underglow.enabled then
            local color = Config.AchievementVehicles.visualEffects.underglow.colors[tierData.tier]
            if color then
                -- Enable all neon lights
                for i = 0, 3 do
                    SetVehicleNeonLightEnabled(vehicle, i, true)
                end
                SetVehicleNeonLightsColour(vehicle, color.r, color.g, color.b)
            end
        end
        
        -- Custom horn
        if tierData.specialEffects.hornUpgrade then
            local hornSound = Config.AchievementVehicles.visualEffects.hornSounds[tierData.tier]
            if hornSound then
                -- Note: Horn modification requires specific mod IDs, this is a placeholder
                SetVehicleMod(vehicle, 14, 1, false) -- Horn mod
            end
        end
        
        -- Custom livery
        if tierData.specialEffects.customLivery then
            local liveryIndex = Config.AchievementVehicles.visualEffects.liveries[tierData.tier]
            if liveryIndex then
                SetVehicleLivery(vehicle, liveryIndex)
            end
        end
    end
    
    -- Apply handling modifications (speed/acceleration)
    if tierData.speedMultiplier and tierData.speedMultiplier > 1.0 then
        -- Note: Actual handling modifications would require more complex implementation
        -- This is a visual/notification placeholder
        local speedBonus = math.floor((tierData.speedMultiplier - 1) * 100)
        local accelBonus = math.floor(tierData.accelerationBonus * 100)
        
        lib.notify({
            title = "🏆 Achievement Vehicle",
            description = string.format("%s Vehicle Spawned\n+%d%% Speed | +%d%% Acceleration", 
                tierData.name, speedBonus, accelBonus),
            type = "success",
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
    end
    
    -- Ensure vehicle is in good condition
    SetVehicleFixed(vehicle)
    SetVehicleDirtLevel(vehicle, 0.0)
    SetVehicleEngineHealth(vehicle, 1000.0)
    SetVehicleBodyHealth(vehicle, 1000.0)
    SetVehiclePetrolTankHealth(vehicle, 1000.0)
    
    -- Add a slight particle effect on spawn for higher tiers
    if tierData.tier == "elite" or tierData.tier == "legendary" then
        local coords = GetEntityCoords(vehicle)
        RequestNamedPtfxAsset("scr_rcbarry2")
        while not HasNamedPtfxAssetLoaded("scr_rcbarry2") do
            Wait(100)
        end
        UseParticleFxAssetNextCall("scr_rcbarry2")
        StartParticleFxNonLoopedAtCoord("scr_clown_appears", coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 1.5, false, false, false)
    end
end)