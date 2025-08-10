-- COMPLETE FIXED VERSION OF cl_team_vehicle_handler.lua
-- Handles achievement vehicle spawning for teams

local QBCore = exports['qb-core']:GetCoreObject()

-- =====================================
-- FIX: ADD MISSING FUNCTION AT TOP
-- =====================================

-- Helper function to get available convoy spawn point
local function GetConvoySpawnPoint(warehouseId)
    local warehouseConfig = Config.Warehouses[warehouseId or 1]
    if not warehouseConfig then
        print("[CONVOY] ERROR: No warehouse config for ID", warehouseId)
        -- Emergency fallback position
        return vector4(-85.97, 6559.03, 31.23, 223.13)
    end
    
    -- Check if convoy spawn points exist
    if not warehouseConfig.convoySpawnPoints then
        print("[CONVOY] Warning: No convoy spawn points configured, using default")
        if warehouseConfig.vehicle and warehouseConfig.vehicle.position then
            return warehouseConfig.vehicle.position
        else
            -- Emergency fallback
            return vector4(-85.97, 6559.03, 31.23, 223.13)
        end
    end
    
    -- Find first available spawn point
    for _, spawnPoint in ipairs(warehouseConfig.convoySpawnPoints) do
        if not spawnPoint.occupied then
            -- Mark as occupied
            spawnPoint.occupied = true
            
            -- Set timeout to release after 5 minutes
            SetTimeout(300000, function()
                spawnPoint.occupied = false
            end)
            
            return spawnPoint.position
        end
    end
    
    -- All spawn points occupied, use random offset from base position
    print("[CONVOY] Warning: All convoy spawn points occupied, using random offset")
    if warehouseConfig.vehicle and warehouseConfig.vehicle.position then
        local basePos = warehouseConfig.vehicle.position
        local randomOffset = math.random(-15, 15)
        return vector4(
            basePos.x + randomOffset,
            basePos.y + randomOffset,
            basePos.z,
            basePos.w or 0
        )
    else
        -- Emergency fallback with offset
        local randomOffset = math.random(-15, 15)
        return vector4(-85.97 + randomOffset, 6559.03 + randomOffset, 31.23, 223.13)
    end
end

-- =====================================
-- FIXED SPAWN HANDLER
-- =====================================

-- Spawn team vehicle with achievement modifications
RegisterNetEvent("team:spawnAchievementVehicle")
AddEventHandler("team:spawnAchievementVehicle", function(teamData, vehicleConfig)
    if vehicleConfig and vehicleConfig.skipVehicle then
        -- Passenger in duo - just notify
        lib.notify({
            title = "🚐 Duo Delivery",
            description = "You'll ride with your team leader. Stand by for pickup!",
            type = "info",
            duration = 10000,
            position = Config.UI and Config.UI.notificationPosition or "top-right",
            markdown = Config.UI and Config.UI.enableMarkdown or false
        })
        return
    end
    
    local warehouseConfig = Config.Warehouses[1]
    if not warehouseConfig then 
        print("[ERROR] No warehouse config found!")
        lib.notify({
            title = "Error",
            description = "Warehouse configuration missing!",
            type = "error",
            duration = 5000
        })
        return 
    end

    -- NO SCREEN FADE (removed for better experience)
    Citizen.Wait(1000)

    local playerPed = PlayerPedId()
    local vehicleModel = GetHashKey(vehicleConfig and vehicleConfig.model or "speedo")
    
    RequestModel(vehicleModel)
    local timeout = 0
    while not HasModelLoaded(vehicleModel) and timeout < 100 do
        Citizen.Wait(100)
        timeout = timeout + 1
    end
    
    if not HasModelLoaded(vehicleModel) then
        print("[ERROR] Failed to load vehicle model!")
        lib.notify({
            title = "Vehicle Error",
            description = "Failed to load vehicle model. Try again.",
            type = "error",
            duration = 5000
        })
        return
    end

    -- Get safe spawn position
    local spawnPos = GetConvoySpawnPoint(1) -- Use warehouse 1
    
    -- Validate spawn position
    if not spawnPos then
        print("[ERROR] No valid spawn position!")
        spawnPos = vector4(-85.97, 6559.03, 31.23, 223.13) -- Emergency fallback
    end
    
    -- Spawn vehicle at convoy position
    local van = CreateVehicle(vehicleModel, 
        spawnPos.x, 
        spawnPos.y, 
        spawnPos.z, 
        spawnPos.w or 0, 
        true, false)
    
    if not DoesEntityExist(van) then
        print("[ERROR] Failed to spawn vehicle!")
        lib.notify({
            title = "Spawn Failed",
            description = "Failed to spawn vehicle. Please try again.",
            type = "error",
            duration = 5000
        })
        return
    end
    
    -- Basic vehicle setup
    SetEntityAsMissionEntity(van, true, true)
    SetVehicleHasBeenOwnedByPlayer(van, true)
    SetVehicleNeedsToBeHotwired(van, false)
    SetVehRadioStation(van, "OFF")
    SetVehicleEngineOn(van, true, true, false)
    
    -- Apply achievement tier modifications (with nil checks)
    if vehicleConfig and vehicleConfig.applyMods and vehicleConfig.tier then
        if Config.AchievementVehicles and Config.AchievementVehicles.performanceTiers then
            local tierConfig = Config.AchievementVehicles.performanceTiers[vehicleConfig.tier]
            
            if tierConfig then
                -- Apply performance mods
                if tierConfig.performanceMods then
                    for modType, modLevel in pairs(tierConfig.performanceMods) do
                        SetVehicleMod(van, modType, modLevel, false)
                    end
                end
                
                -- Apply team colors
                if vehicleConfig.teamVisuals and vehicleConfig.teamVisuals.primaryColor then
                    local color = vehicleConfig.teamVisuals.primaryColor
                    SetVehicleCustomPrimaryColour(van, color[1], color[2], color[3])
                    SetVehicleCustomSecondaryColour(van, color[1], color[2], color[3])
                end
                
                -- Special effects for elite/legendary (with nil checks)
                if vehicleConfig.teamVisuals and vehicleConfig.teamVisuals.specialEffects then
                    -- Add underglow for elite/legendary teams
                    if Config.AchievementVehicles.visualEffects and 
                       Config.AchievementVehicles.visualEffects.underglow and
                       Config.AchievementVehicles.visualEffects.underglow.enabled then
                        local underglowColor = Config.AchievementVehicles.visualEffects.underglow.colors[vehicleConfig.tier]
                        if underglowColor then
                            -- Enable neon lights
                            for i = 0, 3 do
                                SetVehicleNeonLightEnabled(van, i, true)
                            end
                            SetVehicleNeonLightsColour(van, underglowColor.r, underglowColor.g, underglowColor.b)
                        end
                    end
                end
            end
        end
    end
    
    -- Give vehicle keys
    local vanPlate = GetVehicleNumberPlateText(van)
    TriggerEvent("vehiclekeys:client:SetOwner", vanPlate)

    -- Show achievement tier notification (with nil checks)
    if vehicleConfig and vehicleConfig.tier then
        local tierInfo = Config.AchievementVehicles and 
                        Config.AchievementVehicles.performanceTiers and
                        Config.AchievementVehicles.performanceTiers[vehicleConfig.tier]
        
        if tierInfo then
            lib.notify({
                title = string.format("🏆 %s Vehicle", tierInfo.name or "Team"),
                description = string.format(
                    "🚛 Team %s Vehicle\n⚡ Speed: +%.0f%% | 🚀 Acceleration: +%.0f%%\n%s",
                    teamData and teamData.memberRole == "leader" and "Leader" or "Member",
                    ((tierInfo.speedMultiplier or 1) - 1) * 100,
                    (tierInfo.accelerationBonus or 0) * 100,
                    tierInfo.description or "Ready for delivery"
                ),
                type = "success",
                duration = 12000,
                position = Config.UI and Config.UI.notificationPosition or "top-right",
                markdown = Config.UI and Config.UI.enableMarkdown or false
            })
        end
    end

    -- Move player near vehicle (not inside to avoid conflicts)
    if warehouseConfig.vehicle and warehouseConfig.vehicle.position then
        SetEntityCoords(playerPed, 
            warehouseConfig.vehicle.position.x + 2.0, 
            warehouseConfig.vehicle.position.y, 
            warehouseConfig.vehicle.position.z, 
            false, false, false, true)
    end
    
    -- Track vehicle for damage monitoring
    if teamData and teamData.teamId then
        Citizen.CreateThread(function()
            local lastHealth = GetEntityHealth(van)
            while DoesEntityExist(van) do
                local currentHealth = GetEntityHealth(van)
                if currentHealth < lastHealth then
                    -- Vehicle took damage
                    TriggerServerEvent("team:reportVehicleDamage", teamData.teamId, true)
                    break
                end
                Citizen.Wait(1000)
            end
        end)
    end
    
    -- Signal spawn complete for queue system
    if teamData and teamData.teamId then
        TriggerServerEvent("team:vehicleSpawnComplete", teamData.teamId)
    end
    
    -- Use team-specific loading system
    if teamData then
        TriggerEvent("team:loadTeamBoxesPallet", warehouseConfig, van, teamData)
    end
end)

-- Update the original spawn handler to use new system
RegisterNetEvent("team:spawnDeliveryVehicle")
AddEventHandler("team:spawnDeliveryVehicle", function(teamData)
    -- Request vehicle with achievement data
    TriggerServerEvent("team:requestVehicleSpawn", teamData)
end)