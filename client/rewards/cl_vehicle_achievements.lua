-- ============================================
-- ACHIEVEMENT-BASED VEHICLE PERFORMANCE SYSTEM
-- Dynamic performance mods applied per spawn
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()
local lib = exports['ox_lib']

-- ============================================
-- MISSING FUNCTION DEFINITIONS
-- ============================================

-- Calculate total boxes needed for orders
local function calculateTotalBoxes(orders, containers)
    local totalItems = 0
    
    if orders then
        for _, order in ipairs(orders) do
            totalItems = totalItems + (order.quantity or 0)
        end
    end
    
    if containers then
        for _, container in ipairs(containers) do
            totalItems = totalItems + (container.contents_amount or 0)
        end
    end
    
    -- Calculate boxes needed (12 items per box)
    local boxesNeeded = math.ceil(totalItems / 12)
    return boxesNeeded, totalItems
end

-- Determine appropriate vehicle model based on load
local function determineVehicleModel(totalBoxes, containers, achievementTier)
    local vehicleModel = "speedo" -- Default vehicle
    
    -- Base vehicle selection on load size
    if totalBoxes <= 2 then
        vehicleModel = "pony" -- Small deliveries
    elseif totalBoxes <= 5 then
        vehicleModel = "speedo" -- Medium deliveries
    elseif totalBoxes <= 10 then
        vehicleModel = "mule" -- Large deliveries
    else
        vehicleModel = "mule3" -- Extra large deliveries
    end
    
    -- Achievement tier can upgrade vehicle
    if achievementTier == "elite" or achievementTier == "legendary" then
        if vehicleModel == "pony" then
            vehicleModel = "speedo" -- Upgrade small to medium
        elseif vehicleModel == "speedo" then
            vehicleModel = "mule" -- Upgrade medium to large
        elseif vehicleModel == "mule" then
            vehicleModel = "mule3" -- Upgrade large to extra large
        end
    end
    
    return vehicleModel
end

-- Find optimal spawn location for vehicle
local function findOptimalSpawnLocation(playerCoords)
    -- Try to find a clear spawn location near player
    local spawnOffset = 5.0
    local testCoords = {
        vector4(playerCoords.x + spawnOffset, playerCoords.y, playerCoords.z, 0.0),
        vector4(playerCoords.x - spawnOffset, playerCoords.y, playerCoords.z, 0.0),
        vector4(playerCoords.x, playerCoords.y + spawnOffset, playerCoords.z, 0.0),
        vector4(playerCoords.x, playerCoords.y - spawnOffset, playerCoords.z, 0.0)
    }
    
    -- Test each location for clearance
    for _, coords in ipairs(testCoords) do
        local groundZ = coords.z
        local foundGround, groundCoords = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 5.0, false)
        
        if foundGround then
            return vector4(coords.x, coords.y, groundCoords, 0.0)
        end
    end
    
    -- Fallback to player position with offset
    return vector4(playerCoords.x + spawnOffset, playerCoords.y, playerCoords.z, 0.0)
end

-- Setup delivery vehicle with standard configurations
local function setupDeliveryVehicle(vehicle, vehicleModel)
    if not DoesEntityExist(vehicle) then return end
    
    -- Standard vehicle setup
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    SetVehicleNeedsToBeHotwired(vehicle, false)
    SetVehRadioStation(vehicle, "OFF")
    SetVehicleEngineOn(vehicle, true, true, false)
    
    -- Set fuel to full
    if exports['LegacyFuel'] then
        exports['LegacyFuel']:SetFuel(vehicle, 100.0)
    end
    
    -- Add vehicle keys if using a key system
    if exports['qb-vehiclekeys'] then
        exports['qb-vehiclekeys']:GiveKeys(GetVehicleNumberPlateText(vehicle))
    end
    
    print("[ACHIEVEMENTS] Vehicle setup complete: " .. vehicleModel)
end

-- ============================================
-- CLIENT-SIDE VEHICLE MODIFICATION
-- ============================================

-- Apply achievement-based modifications to vehicle
local function applyAchievementMods(vehicle, achievementTier)
    if not DoesEntityExist(vehicle) then return end
    
    local tierData = Config.AchievementVehicles and Config.AchievementVehicles.performanceTiers and 
                     Config.AchievementVehicles.performanceTiers[achievementTier]
    
    if not tierData then
        print("[ACHIEVEMENTS] No tier data found for: " .. tostring(achievementTier))
        return
    end
    
    -- Apply performance modifications
    if tierData.performanceMods then
        for modType, level in pairs(tierData.performanceMods) do
            SetVehicleMod(vehicle, modType, level, false)
        end
    end
    
    -- Apply visual modifications
    if tierData.colorTint then
        local colorTint = tierData.colorTint
        SetVehicleCustomPrimaryColour(vehicle, colorTint.r, colorTint.g, colorTint.b)
    end
    
    -- Apply special effects for higher tiers
    if tierData.specialEffects then
        if tierData.specialEffects.underglow then
            -- Add underglow effect
            SetVehicleNeonLightEnabled(vehicle, 0, true)
            SetVehicleNeonLightEnabled(vehicle, 1, true) 
            SetVehicleNeonLightEnabled(vehicle, 2, true)
            SetVehicleNeonLightEnabled(vehicle, 3, true)
            
            if tierData.colorTint then
                SetVehicleNeonLightsColour(vehicle, tierData.colorTint.r, tierData.colorTint.g, tierData.colorTint.b)
            end
        end
        
        if tierData.specialEffects.customLivery and Config.AchievementVehicles.visualEffects then
            local liveryIndex = Config.AchievementVehicles.visualEffects.liveries and 
                              Config.AchievementVehicles.visualEffects.liveries[achievementTier]
            if liveryIndex then
                SetVehicleLivery(vehicle, liveryIndex)
            end
        end
    end
    
    -- Apply engine modifications for performance
    if tierData.speedMultiplier then
        SetVehicleEnginePowerMultiplier(vehicle, tierData.speedMultiplier)
    end
    
    SetVehicleEngineOn(vehicle, true, true, false)
    
    -- Show achievement notification
    lib.notify({
        title = '🏆 ' .. tierData.name .. ' Vehicle',
        description = tierData.description,
        type = 'success',
        duration = 8000,
        position = Config.UI and Config.UI.notificationPosition or "top",
        markdown = Config.UI and Config.UI.enableMarkdown or false
    })
end

-- ============================================
-- INTEGRATION WITH EXISTING VEHICLE SPAWNING
-- ============================================

-- Enhanced warehouse vehicle spawning with achievements
RegisterNetEvent("warehouse:spawnVehiclesWithAchievements")
AddEventHandler("warehouse:spawnVehiclesWithAchievements", function(restaurantId, orders, containers, achievementTier)
    -- Use existing spawn logic but add achievement mods
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    -- Determine vehicle based on order size and achievement tier
    local totalBoxes = calculateTotalBoxes(orders, containers)
    local vehicleModel = determineVehicleModel(totalBoxes, containers, achievementTier)
    
    -- Ensure vehicleModel is always a string
    if type(vehicleModel) ~= "string" then
        vehicleModel = "speedo" -- Fallback
    end
    
    -- Spawn vehicle using existing logic
    lib.requestModel(vehicleModel, 10000)
    
    local spawnCoords = findOptimalSpawnLocation(playerCoords)
    local vehicle = CreateVehicle(GetHashKey(vehicleModel), spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnCoords.w, true, false)
    
    if DoesEntityExist(vehicle) then
        -- Apply standard vehicle setup
        setupDeliveryVehicle(vehicle, vehicleModel)
        
        -- Apply achievement-based modifications
        applyAchievementMods(vehicle, achievementTier)
        
        -- Continue with existing delivery setup
        TriggerEvent("warehouse:startDelivery", restaurantId, vehicle, orders)
    end
end)

-- Enhanced team delivery vehicle spawning
RegisterNetEvent("team:spawnAchievementVehicle")
AddEventHandler("team:spawnAchievementVehicle", function(teamData, achievementTier)
    -- Use existing team spawn logic with achievement mods
    local warehouseConfig = Config.Warehouses and Config.Warehouses[1]
    if not warehouseConfig then
        print("[ACHIEVEMENTS] No warehouse config found")
        return
    end
    
    local playerPed = PlayerPedId()
    
    -- Determine vehicle based on team size and achievement tier
    local vehicleModel = "speedo"
    if teamData.memberRole == "leader" and teamData.boxesAssigned and teamData.boxesAssigned > 5 then
        if achievementTier == "elite" or achievementTier == "legendary" then
            vehicleModel = "mule3"
        else
            vehicleModel = "mule"
        end
    end
    
    -- Ensure vehicleModel is a string
    if type(vehicleModel) ~= "string" then
        vehicleModel = "speedo"
    end
    
    RequestModel(GetHashKey(vehicleModel))
    while not HasModelLoaded(GetHashKey(vehicleModel)) do
        Citizen.Wait(100)
    end
    
    local spawnOffset = (teamData.memberRole == "leader") and 0 or math.random(-5, 5)
    local spawnPos = warehouseConfig.vehicle and warehouseConfig.vehicle.position
    
    if not spawnPos then
        print("[ACHIEVEMENTS] No spawn position in warehouse config")
        return
    end
    
    local van = CreateVehicle(GetHashKey(vehicleModel),
        spawnPos.x + spawnOffset,
        spawnPos.y + spawnOffset,
        spawnPos.z,
        spawnPos.w or 0.0,
        true, false)
    
    if DoesEntityExist(van) then
        -- Standard vehicle setup
        setupDeliveryVehicle(van, vehicleModel)
        
        -- Apply achievement modifications
        applyAchievementMods(van, achievementTier)
        
        -- Achievement tier bonus notification for teams
        if achievementTier ~= "rookie" then
            local tierInfo = Config.AchievementVehicles and Config.AchievementVehicles.performanceTiers and
                           Config.AchievementVehicles.performanceTiers[achievementTier]
            local tierName = tierInfo and tierInfo.name or achievementTier
            
            lib.notify({
                title = '🎉 Team Achievement Bonus!',
                description = string.format('Team leader has %s tier - enhanced vehicle performance!', tierName),
                type = 'success',
                duration = 10000,
                position = Config.UI and Config.UI.notificationPosition or "top",
                markdown = Config.UI and Config.UI.enableMarkdown or false
            })
        end
        
        -- Continue with team loading
        TriggerEvent("team:loadTeamBoxes", warehouseConfig, van, teamData)
    end
end)

-- Achievement status command for players
RegisterCommand('mystats', function()
    TriggerServerEvent('achievements:getPlayerTier')
end)

RegisterNetEvent('achievements:showPlayerTier')
AddEventHandler('achievements:showPlayerTier', function(tierData, stats)
    local tier = tierData.tier
    local tierInfo = Config.AchievementVehicles and Config.AchievementVehicles.performanceTiers and
                     Config.AchievementVehicles.performanceTiers[tier]
    
    if not tierInfo then
        lib.notify({
            title = 'No Achievement Data',
            description = 'Achievement system not properly configured',
            type = 'error',
            duration = 5000,
            position = Config.UI and Config.UI.notificationPosition or "top",
            markdown = Config.UI and Config.UI.enableMarkdown or false
        })
        return
    end
    
    lib.alertDialog({
        header = '🏆 Your Achievement Status',
        content = string.format(
            '**Current Tier:** %s\n\n**Vehicle Benefits:**\n%s\n\n**Your Stats:**\n• Deliveries: %d\n• Average Rating: %.1f%%\n• Team Deliveries: %d\n\n**Next Tier:** %s',
            tierInfo.name,
            tierInfo.description,
            stats.totalDeliveries,
            stats.avgRating,
            stats.teamDeliveries,
            tierData.nextTier or "Maximum tier reached!"
        ),
        centered = true,
        cancel = true
    })
end)

-- Export for other scripts
exports('applyAchievementMods', applyAchievementMods)

print("[ACHIEVEMENTS] Vehicle performance system loaded")