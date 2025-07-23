-- Validate vehicle ownership access
local function hasVehicleOwnershipAccess(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    
    local playerJob = Player.PlayerData.job.name
    return playerJob == "hurst"
end

-- Purchase vehicle with validation
RegisterNetEvent('vehicles:purchasePersonalVehicle')
AddEventHandler('vehicles:purchasePersonalVehicle', function(vehicleData)
    local src = source
    
    if not hasVehicleOwnershipAccess(src) then
        local Player = QBCore.Functions.GetPlayer(src)
        local currentJob = Player and Player.PlayerData.job.name or "unemployed"
        
        TriggerClientEvent('ox_lib:notify', src, {
            title = '🚫 Vehicle Purchase Denied',
            description = 'Personal vehicle ownership restricted to Hurst Industries employees. Current job: ' .. currentJob,
            type = 'error',
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    -- Continue with vehicle purchase logic...
end)

-- Manage personal fleet with validation
RegisterNetEvent('vehicles:getPersonalFleet')
AddEventHandler('vehicles:getPersonalFleet', function()
    local src = source
    
    if not hasVehicleOwnershipAccess(src) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = '🚫 Fleet Access Denied',
            description = 'Personal fleet management restricted to Hurst Industries employees',
            type = 'error',
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    -- Continue with fleet management logic...
end)

-- Vehicle modification with validation
RegisterNetEvent('vehicles:modifyPersonalVehicle')
AddEventHandler('vehicles:modifyPersonalVehicle', function(vehicleId, modifications)
    local src = source
    
    if not hasVehicleOwnershipAccess(src) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = '🚫 Vehicle Modification Denied',
            description = 'Personal vehicle modifications restricted to Hurst Industries employees',
            type = 'error',
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    -- Continue with modification logic...
end)