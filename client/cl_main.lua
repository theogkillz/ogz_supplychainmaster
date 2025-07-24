local QBCore = exports['qb-core']:GetCoreObject()
local currentOrder = {}
local currentOrderRestaurantId = nil
local boxCount = 0
local lastDeliveryTime = 0
local DELIVERY_COOLDOWN = 300000 -- 5 minutes in milliseconds
local REQUIRED_BOXES = 3 -- Fixed number of boxes to deliver

-- Show Leaderboard Event
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

-- Simple job check helper
local function hasWarehouseAccess()
    local PlayerData = QBCore.Functions.GetPlayerData()
    if not PlayerData or not PlayerData.job then
        return false
    end
    
    local playerJob = PlayerData.job.name
    for _, authorizedJob in ipairs(Config.Jobs.warehouse) do
        if playerJob == authorizedJob then
            return true
        end
    end
    
    return false
end

-- Export for other scripts if needed
exports('hasWarehouseAccess', hasWarehouseAccess)