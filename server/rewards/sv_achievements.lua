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
        WHERE citizenid = ? 
            AND (delivery_status IS NULL OR delivery_status = 'completed')
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
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    local citizenid = xPlayer.PlayerData.citizenid
    
    -- Get player stats from database
    MySQL.Async.fetchAll([[
        SELECT 
            COALESCE(total_deliveries, 0) as totalDeliveries,
            COALESCE(perfect_deliveries, 0) as perfectDeliveries,
            COALESCE(average_rating, 0) as averageRating,
            COALESCE(total_earnings, 0) as totalEarnings,
            COALESCE(level, 1) as level
        FROM supply_player_stats
        WHERE citizenid = ?
    ]], {citizenid}, function(stats)
        
        local playerStats = stats[1] or {
            totalDeliveries = 0,
            perfectDeliveries = 0,
            averageRating = 0,
            totalEarnings = 0,
            level = 1
        }
        
        -- Determine current tier based on stats
        local currentTier = "rookie"
        if playerStats.totalDeliveries >= 500 and playerStats.averageRating >= 95 then
            currentTier = "legendary"
        elseif playerStats.totalDeliveries >= 300 and playerStats.averageRating >= 90 then
            currentTier = "elite"
        elseif playerStats.totalDeliveries >= 150 and playerStats.averageRating >= 85 then
            currentTier = "professional"
        elseif playerStats.totalDeliveries >= 50 and playerStats.averageRating >= 80 then
            currentTier = "experienced"
        elseif playerStats.totalDeliveries >= 10 then
            currentTier = "rookie"
        end
        
        -- Get progress data
        MySQL.Async.fetchAll([[
            SELECT 
                COUNT(CASE WHEN delivery_time < 300 THEN 1 END) as lightningDeliveries,
                COUNT(CASE WHEN boxes_delivered >= 10 THEN 1 END) as largeDeliveries,
                COUNT(DISTINCT delivery_date) as perfectDays
            FROM supply_delivery_logs
            WHERE citizenid = ? AND is_perfect_delivery = 1
        ]], {citizenid}, function(progress)
            
            local progressData = progress[1] or {
                lightningDeliveries = 0,
                largeDeliveries = 0,
                perfectDays = 0
            }
            
            -- Build the achievement data structure CORRECTLY
            local achievementData = {
                currentTier = currentTier,        -- STRING not table
                vehicleTier = currentTier,        -- STRING not table
                stats = {
                    totalDeliveries = playerStats.totalDeliveries,
                    perfectDeliveries = playerStats.perfectDeliveries,
                    averageRating = playerStats.averageRating,
                    totalEarnings = playerStats.totalEarnings,
                    level = playerStats.level
                },
                progress = {
                    lightningDeliveries = progressData.lightningDeliveries,
                    largeDeliveries = progressData.largeDeliveries,
                    perfectDays = progressData.perfectDays
                }
            }
            
            -- Send to client
            TriggerClientEvent("achievements:showProgress", src, achievementData)
        end)
    end)
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

-- Apply vehicle mods with correct tier
RegisterNetEvent("achievements:applyVehicleMods")
AddEventHandler("achievements:applyVehicleMods", function(vehicleNetId)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    local citizenid = xPlayer.PlayerData.citizenid
    
    -- Get player stats to determine tier
    MySQL.Async.fetchAll([[
        SELECT 
            COALESCE(total_deliveries, 0) as totalDeliveries,
            COALESCE(average_rating, 0) as averageRating,
            COALESCE(team_deliveries, 0) as teamDeliveries
        FROM supply_player_stats
        WHERE citizenid = ?
    ]], {citizenid}, function(stats)
        
        local playerStats = stats[1] or {
            totalDeliveries = 0,
            averageRating = 0,
            teamDeliveries = 0
        }
        
        -- Determine tier (STRING)
        local tier = "rookie"
        if playerStats.totalDeliveries >= 500 and playerStats.averageRating >= 95 and playerStats.teamDeliveries >= 50 then
            tier = "legendary"
        elseif playerStats.totalDeliveries >= 300 and playerStats.averageRating >= 90 then
            tier = "elite"
        elseif playerStats.totalDeliveries >= 150 and playerStats.averageRating >= 85 then
            tier = "professional"
        elseif playerStats.totalDeliveries >= 50 and playerStats.averageRating >= 80 then
            tier = "experienced"
        end
        
        -- Get tier data from config
        local tierData = nil
        if Config.AchievementVehicles and Config.AchievementVehicles.performanceTiers then
            tierData = Config.AchievementVehicles.performanceTiers[tier]
        end
        
        -- Fallback to rookie if needed
        if not tierData then
            tierData = Config.AchievementVehicles.performanceTiers["rookie"]
        end
        
        -- Add tier identifier as STRING
        if tierData then
            tierData.tier = tier  -- STRING not table!
        end
        
        -- Send to client with correct structure
        TriggerClientEvent("achievements:applyVehicleModsClient", -1, vehicleNetId, tierData)
    end)
end)

-- Export achievement tier for vehicle spawning
exports('getPlayerAchievementTier', getPlayerAchievementTier)