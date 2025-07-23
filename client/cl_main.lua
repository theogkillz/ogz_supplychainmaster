local QBCore = exports['qb-core']:GetCoreObject()
local currentOrder = {}
local currentOrderRestaurantId = nil
local boxCount = 0
local lastDeliveryTime = 0
local DELIVERY_COOLDOWN = 300000 -- 5 minutes in milliseconds
local REQUIRED_BOXES = 3 -- Fixed number of boxes to deliver

-- Show Leaderboard Event (MISSING IN GROK VERSION)
RegisterNetEvent("warehouse:showLeaderboard")
AddEventHandler("warehouse:showLeaderboard", function(leaderboard)
    local options = {}
    for i, entry in ipairs(leaderboard) do
        table.insert(options, {
            title = string.format("#%d: %s", i, entry.name),
            description = string.format("**Deliveries**: %d\n**Earnings**: $%d", entry.deliveries, entry.earnings),
            metadata = {
                Deliveries = tostring(entry.deliveries),
                Earnings = "$" .. tostring(entry.earnings)
            }
        })
    end
    
    if #options == 0 then
        table.insert(options, {
            title = "No Drivers Yet",
            description = "Complete deliveries to appear on the leaderboard!",
            disabled = true
        })
    end
    
    lib.registerContext({
        id = "leaderboard_menu",
        title = "Top Delivery Drivers",
        options = options
    })
    lib.showContext("leaderboard_menu")
end)

-- Universal client validation
local function validatePlayerAccess(feature)
    local PlayerData = QBCore.Functions.GetPlayerData()
    if not PlayerData or not PlayerData.job then
        return false, "No job data available"
    end
    
    local playerJob = PlayerData.job.name
    local currentJob = playerJob or "unemployed"
    
    -- Use config validation
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

-- Universal access denied notification
local function showAccessDenied(feature, customMessage)
    local PlayerData = QBCore.Functions.GetPlayerData()
    local currentJob = PlayerData and PlayerData.job and PlayerData.job.name or "unemployed"
    
    local message = customMessage or Config.JobValidation.getAccessDeniedMessage(feature, currentJob)
    
    lib.notify({
        title = "🚫 Access Denied",
        description = message,
        type = "error",
        duration = 8000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })
end

-- Export notification helper
exports('showAccessDenied', showAccessDenied)