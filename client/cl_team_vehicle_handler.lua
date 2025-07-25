-- Handles achievement vehicle spawning for teams

-- Spawn team vehicle with achievement modifications
RegisterNetEvent("team:spawnAchievementVehicle")
AddEventHandler("team:spawnAchievementVehicle", function(teamData, vehicleConfig)
    if vehicleConfig.skipVehicle then
        -- Passenger in duo - just notify
        lib.notify({
            title = "🚐 Duo Delivery",
            description = "You'll ride with your team leader. Stand by for pickup!",
            type = "info",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    local warehouseConfig = Config.Warehouses[1]
    if not warehouseConfig then return end

    DoScreenFadeOut(2500)
    Citizen.Wait(2500)

    local playerPed = PlayerPedId()
    local vehicleModel = GetHashKey(vehicleConfig.model)
    
    RequestModel(vehicleModel)
    while not HasModelLoaded(vehicleModel) do
        Citizen.Wait(100)
    end

    -- Spawn vehicle with queue offset to prevent collisions
    local spawnOffset = teamData.memberRole == "leader" and 0 or (GetPlayerServerId(PlayerId()) % 5) * 3
    local van = CreateVehicle(vehicleModel, 
        warehouseConfig.vehicle.position.x + spawnOffset, 
        warehouseConfig.vehicle.position.y, 
        warehouseConfig.vehicle.position.z, 
        warehouseConfig.vehicle.position.w, 
        true, false)
    
    SetEntityAsMissionEntity(van, true, true)
    SetVehicleHasBeenOwnedByPlayer(van, true)
    SetVehicleNeedsToBeHotwired(van, false)
    SetVehRadioStation(van, "OFF")
    SetVehicleEngineOn(van, true, true, false)
    
    -- Apply achievement tier modifications
    if vehicleConfig.applyMods and Config.AchievementVehicles.performanceTiers[vehicleConfig.tier] then
        local tierConfig = Config.AchievementVehicles.performanceTiers[vehicleConfig.tier]
        
        -- Apply performance mods
        for modType, modLevel in pairs(tierConfig.performanceMods) do
            SetVehicleMod(van, modType, modLevel, false)
        end
        
        -- Apply team colors
        if vehicleConfig.teamVisuals then
            local color = vehicleConfig.teamVisuals.primaryColor
            SetVehicleCustomPrimaryColour(van, color[1], color[2], color[3])
            SetVehicleCustomSecondaryColour(van, color[1], color[2], color[3])
        end
        
        -- Special effects for elite/legendary
        if vehicleConfig.teamVisuals.specialEffects then
            -- Add underglow for elite/legendary teams
            if Config.AchievementVehicles.visualEffects.underglow.enabled then
                local underglowColor = Config.AchievementVehicles.visualEffects.underglow.colors[vehicleConfig.tier]
                if underglowColor then
                    -- This would need actual underglow implementation
                    -- Placeholder for visual effect
                end
            end
            
            -- Custom horn
            if Config.AchievementVehicles.visualEffects.hornSounds[vehicleConfig.tier] then
                -- Set custom horn (requires game build 1365 or higher)
            end
        end
    end
    
    local vanPlate = GetVehicleNumberPlateText(van)
    TriggerEvent("vehiclekeys:client:SetOwner", vanPlate)

    DoScreenFadeIn(2500)

    -- Show achievement tier notification
    local tierInfo = Config.AchievementVehicles.performanceTiers[vehicleConfig.tier]
    lib.notify({
        title = string.format("🏆 %s Vehicle", tierInfo.name),
        description = string.format(
            "🚛 Team %s Vehicle\n⚡ Speed: +%.0f%% | 🚀 Acceleration: +%.0f%%\n%s",
            teamData.memberRole == "leader" and "Leader" or "Member",
            (tierInfo.speedMultiplier - 1) * 100,
            tierInfo.accelerationBonus * 100,
            tierInfo.description
        ),
        type = "success",
        duration = 12000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })

    SetEntityCoords(playerPed, warehouseConfig.vehicle.position.x + 2.0, warehouseConfig.vehicle.position.y, warehouseConfig.vehicle.position.z, false, false, false, true)
    
    -- Track vehicle for damage monitoring
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
    
    -- Signal spawn complete for queue system
    TriggerServerEvent("team:vehicleSpawnComplete", teamData.teamId)
    
    -- Use team-specific loading system
    TriggerEvent("team:loadTeamBoxes", warehouseConfig, van, teamData)
end)

-- Update the original spawn handler to use new system
RegisterNetEvent("team:spawnDeliveryVehicle")
AddEventHandler("team:spawnDeliveryVehicle", function(teamData)
    -- Request vehicle with achievement data
    TriggerServerEvent("team:requestVehicleSpawn", teamData)
end)