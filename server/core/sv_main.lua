local QBCore = exports['qb-core']:GetCoreObject()

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        if not Config.Restaurants then
            print("[ERROR] Config.Restaurants not loaded in sv_main.lua")
            return
        end
        for id, restaurant in pairs(Config.Restaurants) do
            exports.ox_inventory:RegisterStash("restaurant_stock_" .. tostring(id), "Restaurant Stock " .. (restaurant.name or "Unknown"), 50, 100000, false, { [restaurant.job] = 0 })
            print("[DEBUG] Registered stash: restaurant_stock_" .. tostring(id))
        end
        MySQL.Async.execute('UPDATE supply_orders SET status = @newStatus WHERE status = @oldStatus', {
            ['@newStatus'] = 'pending',
            ['@oldStatus'] = 'accepted'
        }, function(rowsAffected)
            print("[DEBUG] Reset " .. rowsAffected .. " accepted orders to pending")
        end)
    end
end)

-- Universal validation helper
local function validatePlayerAccess(source, feature)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return false, "Player not found"
    end
    
    local playerJob = Player.PlayerData.job.name
    local currentJob = playerJob or "unemployed"
    
    -- Use config validation functions
    local hasAccess = false
    if feature == "achievement" then
        hasAccess = Config.JobValidation.validateAchievementAccess(playerJob)
    elseif feature == "npc" then
        hasAccess = Config.JobValidation.validateNPCAccess(playerJob)
    elseif feature == "vehicle" then
        hasAccess = Config.JobValidation.validateVehicleOwnership(playerJob)
    elseif feature == "manufacturing" then
        hasAccess = Config.JobValidation.validateManufacturingAccess(playerJob)
    elseif feature == "warehouse" then
        hasAccess = Config.JobValidation.validateWarehouseAccess(playerJob)
    end
    
    if not hasAccess then
        local errorMessage = Config.JobValidation.getAccessDeniedMessage(feature, currentJob)
        return false, errorMessage
    end
    
    return true, "Access granted"
end

-- Export validation helper
exports('validatePlayerAccess', validatePlayerAccess)

-- Universal validation event
RegisterNetEvent('system:validateAccess')
AddEventHandler('system:validateAccess', function(feature)
    local src = source
    local hasAccess, message = validatePlayerAccess(src, feature)
    
    TriggerClientEvent('system:accessValidationResult', src, feature, hasAccess, message)
end)