-- VEHICLE SPAWN COLLISION PREVENTION SYSTEM
-- Prevents vehicles from spawning on top of each other for both solo and team deliveries

local QBCore = exports['qb-core']:GetCoreObject()

-- Active spawn zones tracking
local activeSpawnZones = {}
local spawnCooldowns = {}

-- Check if spawn area is clear
local function isSpawnAreaClear(position, radius)
    radius = radius or 5.0
    
    -- Check active spawn zones
    for _, zone in pairs(activeSpawnZones) do
        local distance = #(vector3(position.x, position.y, position.z) - vector3(zone.x, zone.y, zone.z))
        if distance < radius then
            return false
        end
    end
    
    return true
end

-- Reserve spawn area
local function reserveSpawnArea(position, duration)
    local zoneId = tostring(position.x) .. "_" .. tostring(position.y)
    activeSpawnZones[zoneId] = position
    
    -- Auto-clear after duration
    SetTimeout(duration or 10000, function()
        activeSpawnZones[zoneId] = nil
    end)
    
    return zoneId
end

-- Find clear spawn position
local function findClearSpawnPosition(basePosition, maxAttempts)
    maxAttempts = maxAttempts or 10
    local attempts = 0
    local offset = 0
    
    while attempts < maxAttempts do
        local checkPos = vector3(
            basePosition.x + (offset * math.cos(math.rad(basePosition.w or 0))),
            basePosition.y + (offset * math.sin(math.rad(basePosition.w or 0))),
            basePosition.z
        )
        
        if isSpawnAreaClear(checkPos, 6.0) then
            return vector4(checkPos.x, checkPos.y, checkPos.z, basePosition.w or 0)
        end
        
        offset = offset + 8  -- Move back 8 units each attempt
        attempts = attempts + 1
        Wait(100)
    end
    
    return nil  -- No clear position found
end

-- Enhanced warehouse accept order with spawn check
RegisterNetEvent('warehouse:acceptOrderEnhanced')
AddEventHandler('warehouse:acceptOrderEnhanced', function(orderGroupId, restaurantId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    -- Find clear spawn position
    local warehouseConfig = Config.Warehouses[1]
    if not warehouseConfig then return end
    
    local spawnPos = findClearSpawnPosition(warehouseConfig.vehicle.position)
    
    if not spawnPos then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Spawn Blocked',
            description = 'Vehicle spawn area is congested. Please wait a moment.',
            type = 'error',
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    -- Reserve the spawn area
    local zoneId = reserveSpawnArea(spawnPos, 15000)
    
    -- Continue with normal order acceptance
    TriggerEvent('warehouse:acceptOrder', orderGroupId, restaurantId)
    
    -- Pass spawn position to client
    TriggerClientEvent('warehouse:setSpawnPosition', src, spawnPos)
end)

-- Share vehicle keys for duo teams
RegisterNetEvent('team:shareVehicleKeys')
AddEventHandler('team:shareVehicleKeys', function(teamId, plate)
    local src = source
    local team = exports['ogz_supplychainmaster']:getActiveTeamDelivery(teamId)
    
    if not team then return end
    
    -- Give keys to all team members
    for _, member in pairs(team.members) do
        if member.source ~= src then  -- Don't give keys to the sender
            TriggerClientEvent('team:receiveVehicleKeys', member.source, plate)
        end
    end
end)

-- Export functions for other scripts
exports('isSpawnAreaClear', isSpawnAreaClear)
exports('findClearSpawnPosition', findClearSpawnPosition)
exports('reserveSpawnArea', reserveSpawnArea)