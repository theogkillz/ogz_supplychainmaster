-- ============================================
-- SERVER-SIDE ACHIEVEMENT TRACKING
-- ============================================
local QBCore = exports['qb-core']:GetCoreObject()

-- Validate job access for achievement functions
local function hasAchievementAccess(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    
    local playerJob = Player.PlayerData.job.name
    return playerJob == "hurst"
end

-- Get player's highest achievement tier
local function getPlayerAchievementTier(citizenid)
    -- Get player's delivery stats
    local deliveryCount = 0
    local avgRating = 0
    local teamAchievements = 0
    
    -- Query delivery statistics
    MySQL.Async.fetchAll([[
        SELECT 
            COUNT(*) as total_deliveries,
            AVG(delivery_rating) as avg_rating,
            SUM(CASE WHEN team_delivery = 1 THEN 1 ELSE 0 END) as team_deliveries
        FROM supply_delivery_logs 
        WHERE citizenid = ? AND delivery_status = 'completed'
    ]], {citizenid}, function(results)
        if results and results[1] then
            deliveryCount = results[1].total_deliveries or 0
            avgRating = results[1].avg_rating or 0
            teamAchievements = results[1].team_deliveries or 0
        end
    end)
    
    -- Determine achievement tier based on stats
    if deliveryCount >= 500 and avgRating >= 95 and teamAchievements >= 50 then
        return "legendary"
    elseif deliveryCount >= 300 and avgRating >= 90 then
        return "elite"
    elseif deliveryCount >= 150 and avgRating >= 85 then
        return "professional"  
    elseif deliveryCount >= 50 and avgRating >= 80 then
        return "experienced"
    else
        return "rookie"
    end
end

-- Get player achievement tier with validation
RegisterNetEvent('achievements:getPlayerTier')
AddEventHandler('achievements:getPlayerTier', function()
    local src = source
    
    -- Validate job access
    if not hasAchievementAccess(src) then
        local Player = QBCore.Functions.GetPlayer(src)
        local currentJob = Player and Player.PlayerData.job.name or "unemployed"
        
        TriggerClientEvent('ox_lib:notify', src, {
            title = '🚫 Access Denied',
            description = 'Achievement system restricted to Hurst Industries employees. Current job: ' .. currentJob,
            type = 'error',
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    -- Continue with achievement logic...
end)

RegisterNetEvent("achievements:getProgress")
AddEventHandler("achievements:getProgress", function()
    -- Get player's achievement data
    TriggerClientEvent("achievements:showProgress", source, data)
end)

-- Vehicle modification validation
RegisterNetEvent('achievements:requestVehicleMods')
AddEventHandler('achievements:requestVehicleMods', function(vehicleNetId)
    local src = source
    
    if not hasAchievementAccess(src) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = '🚫 Vehicle Access Denied',
            description = 'Achievement vehicle modifications restricted to Hurst Industries employees',
            type = 'error',
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    -- Continue with vehicle modification logic...
end)

-- SESSION 36 FIX: Fixed tierData being nil
RegisterNetEvent("achievements:applyVehicleMods")
AddEventHandler("achievements:applyVehicleMods", function(vehicleNetId)
    local src = source
    
    -- Validate access
    if not hasAchievementAccess(src) then
        return
    end
    
    -- Get player data
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    
    -- Get player's achievement tier
    local tier = getPlayerAchievementTier(citizenid)
    
    -- Build tierData from config
    local tierData = nil
    if Config.AchievementVehicles and Config.AchievementVehicles.performanceTiers then
        tierData = Config.AchievementVehicles.performanceTiers[tier]
    end
    
    -- Fallback to rookie if something goes wrong
    if not tierData then
        tierData = Config.AchievementVehicles.performanceTiers["rookie"]
    end
    
    -- Add the tier identifier
    if tierData then
        tierData.tier = tier
    end
    
    -- Send to all clients
    TriggerClientEvent("achievements:applyVehicleModsClient", -1, vehicleNetId, tierData)
end)

-- Export achievement tier for vehicle spawning
exports('getPlayerAchievementTier', getPlayerAchievementTier)