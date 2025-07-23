-- ENHANCED LEADERBOARD SYSTEM

local QBCore = exports['qb-core']:GetCoreObject()
local checkAchievements

-- Enhanced leaderboard data structure
local leaderboardCache = {
    topDrivers = {},
    weeklyStats = {},
    monthlyStats = {},
    achievements = {},
    lastUpdate = 0
}

-- Calculate driver performance rating
local function calculatePerformanceRating(stats)
    local baseRating = 0
    
    -- Delivery efficiency (40% of rating)
    local deliveryEfficiency = (stats.completed_deliveries / math.max(stats.total_deliveries, 1)) * 100
    baseRating = baseRating + (deliveryEfficiency * 0.4)
    
    -- Speed bonus (30% of rating) - faster deliveries get higher rating
    local avgDeliveryTime = stats.total_delivery_time / math.max(stats.completed_deliveries, 1)
    local speedRating = math.max(0, 100 - (avgDeliveryTime / 60)) -- Penalty for slow deliveries
    baseRating = baseRating + (speedRating * 0.3)
    
    -- Volume bonus (20% of rating)
    local volumeRating = math.min(100, stats.total_boxes_delivered * 2) -- 2 points per box, max 100
    baseRating = baseRating + (volumeRating * 0.2)
    
    -- Consistency bonus (10% of rating)
    local consistencyRating = math.min(100, stats.consecutive_days * 10) -- 10 points per consecutive day
    baseRating = baseRating + (consistencyRating * 0.1)
    
    return math.floor(baseRating)
end

-- Update driver statistics
local function updateDriverStats(citizenid, deliveryData)
    local currentTime = os.time()
    local today = os.date("%Y-%m-%d", currentTime)
    
    MySQL.Async.execute([[
        INSERT INTO supply_driver_stats (
            citizenid, 
            delivery_date,
            completed_deliveries,
            total_deliveries,
            total_boxes_delivered,
            total_delivery_time,
            total_earnings,
            perfect_deliveries,
            last_delivery
        ) VALUES (?, ?, 1, 1, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            completed_deliveries = completed_deliveries + 1,
            total_deliveries = total_deliveries + 1,
            total_boxes_delivered = total_boxes_delivered + ?,
            total_delivery_time = total_delivery_time + ?,
            total_earnings = total_earnings + ?,
            perfect_deliveries = perfect_deliveries + ?,
            last_delivery = ?
    ]], {
        citizenid,
        today,
        deliveryData.boxes,
        deliveryData.deliveryTime,
        deliveryData.earnings,
        deliveryData.isPerfect and 1 or 0,
        currentTime,
        -- Duplicate key update values
        deliveryData.boxes,
        deliveryData.deliveryTime,
        deliveryData.earnings,
        deliveryData.isPerfect and 1 or 0,
        currentTime
    })
    
    -- Update performance rating
    MySQL.Async.fetchAll('SELECT * FROM supply_driver_stats WHERE citizenid = ?', {citizenid}, function(result)
        if not result or not result[1] then 
            print("[DEBUG] No driver stats found for:", citizenid)
            return 
        end
        
        local stats = result[1]
            local performanceRating = calculatePerformanceRating(stats)
            
            MySQL.Async.execute([[
                UPDATE supply_driver_stats 
                SET performance_rating = ? 
                WHERE citizenid = ?
            ]], {performanceRating, citizenid})
        end)
    
    -- Check for achievements
    checkAchievements(citizenid, deliveryData)
end

-- Achievement system
local achievements = {
    {
        id = "first_delivery",
        name = "First Steps", 
        description = "Complete your first delivery",
        icon = "🚚",
        reward = 500,
        condition = function(stats, deliveryData) return stats.completed_deliveries >= 1 end
    },
    {
        id = "speed_demon",
        name = "Speed Demon",
        description = "Complete a delivery in under 5 minutes",
        icon = "⚡",
        reward = 1000,
        condition = function(stats, delivery) return delivery.deliveryTime < 300 end
    },
    {
        id = "big_hauler",
        name = "Big Hauler",
        description = "Deliver 10+ boxes in a single run",
        icon = "📦",
        reward = 1500,
        condition = function(stats, delivery) return delivery.boxes >= 10 end
    },
    {
        id = "perfect_week",
        name = "Perfect Week",
        description = "Complete 7 consecutive days of deliveries",
        icon = "👑", 
        reward = 5000,
        condition = function(stats, deliveryData) return stats.consecutive_days >= 7 end
    },
    {
        id = "century_club", 
        name = "Century Club",
        description = "Complete 100 deliveries",
        icon = "💯",
        reward = 10000,
        condition = function(stats, deliveryData) return stats.completed_deliveries >= 100 end
    }
}

-- Check and award achievements
checkAchievements = function(citizenid, deliveryData)
    MySQL.Async.fetchAll('SELECT * FROM supply_driver_stats WHERE citizenid = ?', {citizenid}, function(result)
        if not result or not result[1] then return end
        
        local stats = result[1]
        
        for _, achievement in ipairs(achievements) do
            -- Check if player already has this achievement
            MySQL.Async.fetchAll('SELECT * FROM supply_achievements WHERE citizenid = ? AND achievement_id = ?', 
                {citizenid, achievement.id}, function(existing)
                
                if not existing or #existing == 0 then
                    -- Check if condition is met
                    if achievement.condition(stats, deliveryData) then
                        -- Award achievement
                        MySQL.Async.execute([[
                            INSERT INTO supply_achievements (citizenid, achievement_id, earned_date)
                            VALUES (?, ?, ?)
                        ]], {citizenid, achievement.id, os.time()})
                        
                        -- Give reward
                        local xPlayer = QBCore.Functions.GetPlayer(QBCore.Functions.GetPlayerByCitizenId(citizenid))
                        if xPlayer then
                            xPlayer.Functions.AddMoney('bank', achievement.reward, "Achievement: " .. achievement.name)
                            
                            TriggerClientEvent('ox_lib:notify', xPlayer.PlayerData.source, {
                                title = '🏆 Achievement Unlocked!',
                                description = achievement.icon .. ' **' .. achievement.name .. '**\n' .. achievement.description .. '\n💰 Reward: $' .. achievement.reward,
                                type = 'success',
                                duration = 15000,
                                position = Config.UI.notificationPosition,
                                markdown = Config.UI.enableMarkdown
                            })
                        end
                    end
                end
            end)
        end
    end)
end

-- Get leaderboard data
RegisterNetEvent('leaderboard:getDriverStats')
AddEventHandler('leaderboard:getDriverStats', function(filter)
    local src = source
    filter = filter or "all_time"
    
    local dateFilter = ""
    if filter == "daily" then
        dateFilter = "AND delivery_date = CURDATE()"
    elseif filter == "weekly" then
        dateFilter = "AND YEARWEEK(delivery_date, 1) = YEARWEEK(CURDATE(), 1)"
    elseif filter == "monthly" then
        dateFilter = "AND YEAR(delivery_date) = YEAR(CURDATE()) AND MONTH(delivery_date) = MONTH(CURDATE())"
    end
    
    MySQL.Async.fetchAll([[
        SELECT 
            ds.citizenid,
            ds.name,
            SUM(ds.completed_deliveries) as total_deliveries,
            SUM(ds.total_boxes_delivered) as total_boxes,
            SUM(ds.total_earnings) as total_earnings,
            AVG(ds.performance_rating) as avg_rating,
            COUNT(DISTINCT ds.delivery_date) as active_days,
            MAX(ds.last_delivery) as last_active
        FROM supply_driver_stats ds
        WHERE ds.completed_deliveries > 0 ]] .. dateFilter .. [[
        GROUP BY ds.citizenid
        ORDER BY total_earnings DESC, total_deliveries DESC
        LIMIT 20
    ]], {}, function(results)
        
        -- Get achievements for each driver
        local driversWithAchievements = {}
        local completedQueries = 0
        
        for i, driver in ipairs(results) do
            MySQL.Async.fetchAll([[
                SELECT sa.achievement_id, sa.earned_date
                FROM supply_achievements sa
                WHERE sa.citizenid = ?
                ORDER BY sa.earned_date DESC
            ]], {driver.citizenid}, function(achievements)
                
                driver.achievements = achievements or {}
                driver.rank = i
                table.insert(driversWithAchievements, driver)
                
                completedQueries = completedQueries + 1
                if completedQueries >= #results then
                    TriggerClientEvent('leaderboard:showDriverStats', src, driversWithAchievements, filter)
                end
            end)
        end
        
        if #results == 0 then
            TriggerClientEvent('leaderboard:showDriverStats', src, {}, filter)
        end
    end)
end)

-- Track delivery completion (called from update:stock)
RegisterNetEvent('leaderboard:trackDelivery')
AddEventHandler('leaderboard:trackDelivery', function(deliveryData)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    
    if xPlayer then
        updateDriverStats(xPlayer.PlayerData.citizenid, deliveryData)
    end
end)

-- Get player's personal stats
RegisterNetEvent("leaderboard:getPersonalStats")
AddEventHandler("leaderboard:getPersonalStats", function()
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    local citizenid = xPlayer.PlayerData.citizenid
    
    -- Get aggregated lifetime stats
    MySQL.Async.fetchAll([[
        SELECT 
            SUM(total_deliveries) as lifetime_deliveries,
            SUM(total_earnings) as lifetime_earnings,
            SUM(total_boxes_delivered) as lifetime_boxes,
            SUM(perfect_deliveries) as lifetime_perfect,
            AVG(total_delivery_time / NULLIF(total_deliveries, 0)) as avg_delivery_time,
            MIN(total_delivery_time / NULLIF(total_deliveries, 0)) as fastest_avg_time,
            MAX(total_deliveries) as best_daily_deliveries,
            COUNT(DISTINCT delivery_date) as active_days
        FROM supply_driver_stats 
        WHERE citizenid = ?
    ]], {citizenid}, function(stats)
        -- Get current streak data
        MySQL.Async.fetchAll('SELECT * FROM supply_driver_streaks WHERE citizenid = ?', {citizenid}, function(streaks)
            -- Get today's stats
            MySQL.Async.fetchAll([[
                SELECT * FROM supply_driver_stats 
                WHERE citizenid = ? AND delivery_date = CURDATE()
            ]], {citizenid}, function(todayStats)
                
                local playerStats = {}
                
                if stats and #stats > 0 and stats[1].lifetime_deliveries then
                    local s = stats[1]
                    playerStats = {
                        total_deliveries = s.lifetime_deliveries,
                        total_earnings = s.lifetime_earnings,
                        total_boxes = s.lifetime_boxes,
                        perfect_deliveries = s.lifetime_perfect,
                        average_time = s.avg_delivery_time,
                        fastest_time = s.fastest_avg_time,
                        largest_delivery = s.best_daily_deliveries,
                        active_days = s.active_days
                    }
                end
                
                if streaks and #streaks > 0 then
                    playerStats.current_streak = streaks[1].perfect_streak
                    playerStats.best_streak = streaks[1].best_streak
                    playerStats.streak_broken_count = streaks[1].streak_broken_count
                end
                
                if todayStats and #todayStats > 0 then
                    playerStats.daily_deliveries = todayStats[1].completed_deliveries
                    playerStats.daily_earnings = todayStats[1].total_earnings
                end
                
                TriggerClientEvent("rewards:showDriverStatus", src, playerStats)
            end)
        end)
    end)
end)

-- Handle driver status request
RegisterNetEvent("rewards:getPlayerStatus")
AddEventHandler("rewards:getPlayerStatus", function()
    local src = source
    TriggerEvent("leaderboard:getPersonalStats", src) -- Reuse existing logic
end)

-- Handle leaderboard menu request  
RegisterNetEvent("leaderboard:requestData")
AddEventHandler("leaderboard:requestData", function()
    local src = source
    TriggerEvent("leaderboard:getDriverStats", "all_time", src) -- Default to all-time
end)