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

local function assignVehicleIndices(teamId)
    local team = activeTeamDeliveries[teamId]
    if not team then return end
    
    local memberCount = 0
    local memberList = {}
    for citizenid, member in pairs(team.members) do
        memberCount = memberCount + 1
        table.insert(memberList, {citizenid = citizenid, member = member})
    end
    
    -- Sort to ensure consistent assignment (leader first)
    table.sort(memberList, function(a, b)
        if a.citizenid == team.leaderId then return true end
        if b.citizenid == team.leaderId then return false end
        return a.citizenid < b.citizenid
    end)
    
    -- HYBRID DISTRIBUTION LOGIC
    local vehicleAssignments = {}
    
    if memberCount == 2 then
        -- DUO MODE: Both in vehicle 1
        vehicleAssignments[1] = {memberList[1], memberList[2]}
        team.isDuo = true
        team.vehicleCount = 1
        
        print("[HYBRID] DUO MODE - 1 vehicle for 2 players")
        
    elseif memberCount <= 4 then
        -- SQUAD MODE: Split into 2 vehicles
        local vehiclesNeeded = math.min(2, math.ceil(memberCount / 2))
        team.vehicleCount = vehiclesNeeded
        
        if memberCount == 3 then
            vehicleAssignments[1] = {memberList[1], memberList[2]}  -- Leader + 1
            vehicleAssignments[2] = {memberList[3]}                 -- Solo driver
        else -- memberCount == 4
            vehicleAssignments[1] = {memberList[1], memberList[2]}  -- Leader + 1
            vehicleAssignments[2] = {memberList[3], memberList[4]}  -- 2 members
        end
        
        print("[HYBRID] SQUAD MODE - " .. vehiclesNeeded .. " vehicles for " .. memberCount .. " players")
        
    else
        -- LARGE MODE: Maximum 3 vehicles
        local vehiclesNeeded = math.min(3, math.ceil(memberCount / 3))
        team.vehicleCount = vehiclesNeeded
        
        local playersPerVehicle = math.ceil(memberCount / vehiclesNeeded)
        local currentVehicle = 1
        local currentCount = 0
        
        vehicleAssignments[currentVehicle] = {}
        
        for i, memberData in ipairs(memberList) do
            table.insert(vehicleAssignments[currentVehicle], memberData)
            currentCount = currentCount + 1
            
            if currentCount >= playersPerVehicle and currentVehicle < vehiclesNeeded then
                currentVehicle = currentVehicle + 1
                currentCount = 0
                vehicleAssignments[currentVehicle] = {}
            end
        end
        
        print("[HYBRID] LARGE MODE - " .. vehiclesNeeded .. " vehicles for " .. memberCount .. " players")
    end
    
    -- Apply assignments to team members
    for vehicleIndex, vehicleMembers in pairs(vehicleAssignments) do
        for _, memberData in ipairs(vehicleMembers) do
            local member = team.members[memberData.citizenid]
            if member then
                member.vehicleIndex = vehicleIndex
                member.vehicleGroup = vehicleAssignments[vehicleIndex]
                
                -- Notify player of their vehicle assignment
                if member.source then
                    TriggerClientEvent('ox_lib:notify', member.source, {
                        title = '🚛 Vehicle Assignment',
                        description = string.format(
                            'You are assigned to **Vehicle %d**\n%s',
                            vehicleIndex,
                            team.isDuo and "Riding together with your partner!" or 
                            string.format("Vehicle has %d team member(s)", #vehicleMembers)
                        ),
                        type = 'info',
                        duration = 8000,
                        position = Config.UI.notificationPosition,
                        markdown = Config.UI.enableMarkdown
                    })
                end
            end
        end
    end
    
    return vehicleAssignments
end

-- MAIN SPAWN HANDLER - SIMPLIFIED
RegisterNetEvent('team:startVehicleSpawning')
AddEventHandler('team:startVehicleSpawning', function(teamId)
    local team = activeTeamDeliveries[teamId]
    if not team then return end
    
    -- Assign vehicle indices first
    local vehicleAssignments = assignVehicleIndices(teamId)
    if not vehicleAssignments then return end
    
    -- Spawn vehicles based on assignments
    local spawnDelay = 0
    local warehouseConfig = Config.Warehouses[1]  -- Default warehouse
    
    for vehicleIndex, vehicleMembers in pairs(vehicleAssignments) do
        Citizen.SetTimeout(spawnDelay, function()
            -- Calculate boxes for this vehicle
            local totalBoxesForVehicle = 0
            for _, memberData in ipairs(vehicleMembers) do
                local member = team.members[memberData.citizenid]
                if member then
                    totalBoxesForVehicle = totalBoxesForVehicle + member.boxesAssigned
                end
            end
            
            -- Select appropriate vehicle model
            local vehicleModel = "speedo"  -- Default
            if totalBoxesForVehicle > 20 then
                vehicleModel = "pounder"
            elseif totalBoxesForVehicle > 10 then
                vehicleModel = "mule"
            end
            
            -- Determine spawn position with smart offsets
            local baseSpawn = warehouseConfig.vehicle.position
            local spawnOffset = {x = 0, y = 0}
            
            if team.vehicleCount > 1 then
                -- Use fallback offsets if convoy points not available
                local offsets = Config.HybridSpawnSystem.spawning.fallbackOffsets
                if offsets[vehicleIndex] then
                    spawnOffset = offsets[vehicleIndex]
                end
            end
            
            local spawnPos = {
                x = baseSpawn.x + spawnOffset.x,
                y = baseSpawn.y + spawnOffset.y,
                z = baseSpawn.z,
                w = baseSpawn.w
            }
            
            -- Spawn vehicle for each member in this vehicle group
            for _, memberData in ipairs(vehicleMembers) do
                local member = team.members[memberData.citizenid]
                if member and member.source then
                    -- Prepare team data for client
                    local teamDataForClient = {
                        teamId = teamId,
                        memberRole = (memberData.citizenid == team.leaderId) and "leader" or "member",
                        boxesAssigned = member.boxesAssigned,
                        restaurantId = team.restaurantId,
                        isDuo = team.isDuo,
                        vehicleIndex = vehicleIndex,
                        vehicleCount = team.vehicleCount,
                        members = team.members  -- Include for duo key sharing
                    }
                    
                    -- Only the first member of each vehicle spawns it
                    if memberData == vehicleMembers[1] then
                        -- This member spawns the vehicle
                        teamDataForClient.spawnVehicle = true
                        teamDataForClient.vehicleModel = vehicleModel
                        teamDataForClient.spawnPos = spawnPos
                        
                        print("[HYBRID] Spawning vehicle " .. vehicleIndex .. " for " .. member.name)
                    else
                        -- Other members just get notified
                        teamDataForClient.spawnVehicle = false
                        teamDataForClient.waitForVehicle = true
                        
                        print("[HYBRID] " .. member.name .. " will share vehicle " .. vehicleIndex)
                    end
                    
                    -- Send spawn instruction to client
                    TriggerClientEvent('team:spawnDeliveryVehicle', member.source, teamDataForClient)
                end
            end
        end)
        
        -- Stagger spawns to prevent collisions
        spawnDelay = spawnDelay + Config.HybridSpawnSystem.spawning.spawnDelay
    end
    
    -- Summary notification to all members
    Citizen.SetTimeout(spawnDelay + 1000, function()
        for _, member in pairs(team.members) do
            if member.source then
                TriggerClientEvent('ox_lib:notify', member.source, {
                    title = '🚛 Hybrid Fleet Ready!',
                    description = string.format(
                        '**Fleet Status:**\n👥 %d drivers\n🚛 %d vehicles\n📦 %d total boxes\n\n%s',
                        memberCount,
                        team.vehicleCount,
                        team.totalBoxes,
                        team.isDuo and "DUO MODE: Share vehicle and coordinate!" or
                        team.vehicleCount == 2 and "SQUAD MODE: 2-vehicle operation!" or
                        "CONVOY MODE: Maximum efficiency!"
                    ),
                    type = 'success',
                    duration = 12000,
                    position = Config.UI.notificationPosition,
                    markdown = Config.UI.enableMarkdown
                })
            end
        end
    end)
end)

-- Key sharing handler for duo vehicles
RegisterNetEvent('team:shareVehicleKeys')
AddEventHandler('team:shareVehicleKeys', function(teamId, plate)
    local src = source
    local team = activeTeamDeliveries[teamId]
    if not team or not team.isDuo then return end
    
    -- Share keys with all team members in duo mode
    for citizenid, member in pairs(team.members) do
        if member.source and member.source ~= src then
            TriggerClientEvent('team:receiveVehicleKeys', member.source, plate)
            
            print("[HYBRID] Shared vehicle keys for plate " .. plate .. " with " .. member.name)
        end
    end
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