local QBCore = exports['qb-core']:GetCoreObject()
local activeSpawns = {} -- Track active spawns to prevent collisions

-- Smart vehicle distribution based on team size
local function getVehicleDistribution(teamSize, totalBoxes)
    local distribution = {}
    
    if teamSize == 2 then
        -- DUO: One vehicle, both players share
        distribution = {
            vehicles = 1,
            arrangement = "shared",
            boxDistribution = {totalBoxes} -- All boxes in one vehicle
        }
    elseif teamSize <= 4 then
        -- SQUAD: Two vehicles maximum
        local vehicleCount = math.min(2, teamSize)
        local boxesPerVehicle = math.ceil(totalBoxes / vehicleCount)
        distribution = {
            vehicles = vehicleCount,
            arrangement = "paired",
            boxDistribution = {}
        }
        for i = 1, vehicleCount do
            local boxes = i == vehicleCount and (totalBoxes - (boxesPerVehicle * (vehicleCount - 1))) or boxesPerVehicle
            table.insert(distribution.boxDistribution, boxes)
        end
    else
        -- LARGE: Three vehicles maximum
        local vehicleCount = math.min(3, math.ceil(teamSize / 2))
        local boxesPerVehicle = math.ceil(totalBoxes / vehicleCount)
        distribution = {
            vehicles = vehicleCount,
            arrangement = "convoy",
            boxDistribution = {}
        }
        for i = 1, vehicleCount do
            local boxes = i == vehicleCount and (totalBoxes - (boxesPerVehicle * (vehicleCount - 1))) or boxesPerVehicle
            table.insert(distribution.boxDistribution, boxes)
        end
    end
    
    return distribution
end

-- Get safe spawn position with collision check
local function getSafeSpawnPosition(warehouseId, vehicleIndex)
    local warehouse = Config.Warehouses[warehouseId or 1]
    if not warehouse then
        print("[SPAWN ERROR] No warehouse config for ID:", warehouseId)
        return vector4(-85.97, 6559.03, 31.23, 223.13) -- Emergency fallback
    end
    
    -- Use smart spawn points if available
    if Config.HybridSpawnSystem and Config.HybridSpawnSystem.enabled then
        local spawnPoints = warehouse.smartSpawnPoints or warehouse.convoySpawnPoints
        
        if spawnPoints then
            -- Find first available spawn point (max 3 vehicles)
            local maxVehicles = Config.HybridSpawnSystem.spawning.maxActiveSpawns or 3
            local targetIndex = math.min(vehicleIndex, maxVehicles)
            
            for i = 1, #spawnPoints do
                local point = spawnPoints[i]
                if i == targetIndex and not point.occupied then
                    -- Mark as occupied
                    point.occupied = true
                    
                    -- Auto-clear after timeout
                    SetTimeout(Config.HybridSpawnSystem.spawning.clearAfter or 30000, function()
                        point.occupied = false
                    end)
                    
                    return point.position
                end
            end
        end
    end
    
    -- Fallback to offset system
    local basePos = warehouse.vehicle.position
    local offsets = Config.HybridSpawnSystem.spawning.fallbackOffsets or {
        {x = 0, y = 0},
        {x = 5, y = 0},
        {x = -5, y = 0}
    }
    
    local offset = offsets[math.min(vehicleIndex, #offsets)] or offsets[1]
    return vector4(
        basePos.x + offset.x,
        basePos.y + offset.y,
        basePos.z,
        basePos.w or 223.13
    )
end

-- MAIN SPAWN HANDLER - SIMPLIFIED
RegisterNetEvent('team:startVehicleSpawning')
AddEventHandler('team:startVehicleSpawning', function(teamId)
    local team = activeTeamDeliveries[teamId]
    if not team then return end
    
    -- Count members
    local members = {}
    for citizenid, member in pairs(team.members) do
        table.insert(members, {
            citizenid = citizenid,
            source = member.source,
            isLeader = (citizenid == team.leaderId),
            member = member
        })
    end
    
    -- Sort so leader is first
    table.sort(members, function(a, b)
        if a.isLeader then return true end
        if b.isLeader then return false end
        return false
    end)
    
    local teamSize = #members
    local distribution = getVehicleDistribution(teamSize, team.totalBoxes)
    
    print(string.format("[TEAM SPAWN] Team %s: %d members, %d vehicles needed", 
        teamId, teamSize, distribution.vehicles))
    
    -- Assign vehicles and spawn
    local vehicleIndex = 1
    local assignedMembers = 0
    
    if distribution.arrangement == "shared" then
        -- DUO MODE: One vehicle, both players
        local spawnPos = getSafeSpawnPosition(1, 1)
        local driverMember = members[1] -- Leader drives
        local passengerMember = members[2]
        
        -- Spawn vehicle for driver
        local spawnData = {
            teamId = teamId,
            memberRole = "leader",
            boxesAssigned = team.totalBoxes,
            restaurantId = team.restaurantId,
            deliveryType = team.deliveryType,
            isDuo = true,
            spawnPosition = spawnPos,
            vehicleIndex = 1,
            totalVehicles = 1
        }
        
        TriggerClientEvent('team:spawnSmartVehicle', driverMember.source, spawnData)
        
        -- Notify passenger
        TriggerClientEvent('ox_lib:notify', passengerMember.source, {
            title = '🚐 Duo Delivery',
            description = string.format('You\'ll ride with %s. Vehicle spawning...', driverMember.member.name),
            type = 'info',
            duration = 8000,
            position = Config.UI.notificationPosition
        })
        
        -- Share keys after spawn
        SetTimeout(3000, function()
            local plate = "TEAM" .. string.sub(teamId, -4) -- Generate predictable plate
            TriggerClientEvent('team:receiveVehicleKeys', passengerMember.source, plate)
        end)
        
    else
        -- SQUAD/LARGE MODE: Multiple vehicles
        local playersPerVehicle = math.ceil(teamSize / distribution.vehicles)
        
        for i = 1, distribution.vehicles do
            local spawnPos = getSafeSpawnPosition(1, i)
            local vehicleMembers = {}
            
            -- Assign members to this vehicle
            for j = 1, playersPerVehicle do
                assignedMembers = assignedMembers + 1
                if assignedMembers <= teamSize then
                    table.insert(vehicleMembers, members[assignedMembers])
                end
            end
            
            -- Spawn vehicle for first member of this group
            if vehicleMembers[1] then
                local spawnData = {
                    teamId = teamId,
                    memberRole = vehicleMembers[1].isLeader and "leader" or "member",
                    boxesAssigned = distribution.boxDistribution[i],
                    restaurantId = team.restaurantId,
                    deliveryType = team.deliveryType,
                    isDuo = false,
                    spawnPosition = spawnPos,
                    vehicleIndex = i,
                    totalVehicles = distribution.vehicles,
                    vehicleMembers = vehicleMembers -- Who's in this vehicle
                }
                
                -- Spawn for primary driver
                TriggerClientEvent('team:spawnSmartVehicle', vehicleMembers[1].source, spawnData)
                
                -- Notify other members in this vehicle group
                for j = 2, #vehicleMembers do
                    TriggerClientEvent('ox_lib:notify', vehicleMembers[j].source, {
                        title = '🚛 Vehicle Group ' .. i,
                        description = string.format('Your vehicle is spawning (Driver: %s)', vehicleMembers[1].member.name),
                        type = 'info',
                        duration = 5000,
                        position = Config.UI.notificationPosition
                    })
                    
                    -- Share keys
                    SetTimeout(3000, function()
                        local plate = "TEAM" .. i .. string.sub(teamId, -3)
                        TriggerClientEvent('team:receiveVehicleKeys', vehicleMembers[j].source, plate)
                    end)
                end
            end
            
            -- Small delay between spawns to prevent collisions
            Citizen.Wait(2000)
        end
    end
    
    -- Summary notification to all team members
    SetTimeout(5000, function()
        for _, member in ipairs(members) do
            TriggerClientEvent('ox_lib:notify', member.source, {
                title = '✅ Vehicles Ready!',
                description = string.format('Team: %d vehicles spawned\nArrangement: %s\nLet\'s deliver!', 
                    distribution.vehicles, distribution.arrangement),
                type = 'success',
                duration = 8000,
                position = Config.UI.notificationPosition
            })
        end
    end)
end)

-- CLIENT SIDE: cl_team_vehicle_spawn_fixed.lua
-- Simplified client-side spawning

RegisterNetEvent('team:spawnSmartVehicle')
AddEventHandler('team:spawnSmartVehicle', function(spawnData)
    local playerPed = PlayerPedId()
    
    -- Determine vehicle model based on boxes
    local vehicleModel = "speedo" -- Default
    if spawnData.boxesAssigned > 10 then
        vehicleModel = "mule"
    elseif spawnData.boxesAssigned > 15 then
        vehicleModel = "pounder"
    end
    
    -- Request model
    local modelHash = GetHashKey(vehicleModel)
    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 100 do
        Citizen.Wait(100)
        timeout = timeout + 1
    end
    
    if not HasModelLoaded(modelHash) then
        print("[ERROR] Failed to load vehicle model:", vehicleModel)
        lib.notify({
            title = 'Spawn Error',
            description = 'Failed to load vehicle. Please try again.',
            type = 'error',
            duration = 5000
        })
        return
    end
    
    -- Spawn at provided position
    local spawnPos = spawnData.spawnPosition
    local vehicle = CreateVehicle(modelHash, spawnPos.x, spawnPos.y, spawnPos.z, spawnPos.w, true, false)
    
    if not DoesEntityExist(vehicle) then
        print("[ERROR] Failed to create vehicle")
        lib.notify({
            title = 'Spawn Error',
            description = 'Failed to spawn vehicle. Please try again.',
            type = 'error',
            duration = 5000
        })
        return
    end
    
    -- Basic setup
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    SetVehicleNeedsToBeHotwired(vehicle, false)
    SetVehRadioStation(vehicle, "OFF")
    SetVehicleEngineOn(vehicle, true, true, false)
    
    -- Set predictable plate for key sharing
    local plate = nil
    if spawnData.isDuo then
        plate = "TEAM" .. string.sub(spawnData.teamId, -4)
    else
        plate = "TEAM" .. spawnData.vehicleIndex .. string.sub(spawnData.teamId, -3)
    end
    SetVehicleNumberPlateText(vehicle, plate)
    
    -- Give keys
    TriggerEvent("vehiclekeys:client:SetOwner", plate)
    
    -- Visual distinction
    if spawnData.memberRole == "leader" then
        SetVehicleCustomPrimaryColour(vehicle, 0, 255, 0) -- Green for leader
        SetVehicleCustomSecondaryColour(vehicle, 0, 200, 0)
    else
        SetVehicleCustomPrimaryColour(vehicle, 0, 150, 255) -- Blue for members
        SetVehicleCustomSecondaryColour(vehicle, 0, 100, 200)
    end
    
    -- Apply achievement mods if available
    local playerData = QBCore.Functions.GetPlayerData()
    if playerData and Config.AchievementVehicles and Config.AchievementVehicles.enabled then
        TriggerServerEvent("achievements:applyVehicleMods", NetworkGetNetworkIdFromEntity(vehicle))
    end
    
    -- Success notification
    lib.notify({
        title = spawnData.isDuo and '🚐 Duo Vehicle Ready!' or '🚛 Team Vehicle Ready!',
        description = string.format(
            'Vehicle %d of %d\n📦 %d boxes to deliver\nRole: %s',
            spawnData.vehicleIndex,
            spawnData.totalVehicles,
            spawnData.boxesAssigned,
            spawnData.memberRole
        ),
        type = 'success',
        duration = 8000,
        position = Config.UI.notificationPosition
    })
    
    -- Start loading process
    local warehouseConfig = Config.Warehouses[1] -- Default warehouse
    if warehouseConfig then
        local teamData = {
            teamId = spawnData.teamId,
            memberRole = spawnData.memberRole,
            boxesAssigned = spawnData.boxesAssigned,
            restaurantId = spawnData.restaurantId,
            isDuo = spawnData.isDuo
        }
        
        -- Use existing pallet loading system
        TriggerEvent("team:loadTeamBoxesPallet", warehouseConfig, vehicle, teamData)
    end
end)