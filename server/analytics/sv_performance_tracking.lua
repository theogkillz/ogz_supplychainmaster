local QBCore = exports['qb-core']:GetCoreObject()

-- Wait for QBCore to be ready
local function waitForQBCore()
    while not QBCore do
        QBCore = exports['qb-core']:GetCoreObject()
        Citizen.Wait(100)
    end
end

-- Initialize
Citizen.CreateThread(function()
    waitForQBCore()
end)

-- Performance Tracking System
RegisterNetEvent('leaderboard:trackDelivery')
AddEventHandler('leaderboard:trackDelivery', function(playerId, deliveryData)
    if not QBCore then
        print("[ERROR] QBCore not initialized in performance tracking")
        return
    end
    
    local xPlayer = QBCore.Functions.GetPlayer(playerId)
    if not xPlayer then return end
    
    local citizenid = xPlayer.PlayerData.citizenid
    local playerName = xPlayer.PlayerData.charinfo.firstname .. ' ' .. xPlayer.PlayerData.charinfo.lastname
    local today = os.date("%Y-%m-%d")
    local currentTime = os.time()
    
    -- Insert or update TODAY's stats
    MySQL.Async.execute([[
        INSERT INTO supply_driver_stats (
            citizenid, name, delivery_date, completed_deliveries, total_deliveries,
            total_boxes_delivered, total_delivery_time, total_earnings, 
            perfect_deliveries, last_delivery
        ) VALUES (?, ?, ?, 1, 1, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            completed_deliveries = completed_deliveries + 1,
            total_deliveries = total_deliveries + 1,
            total_boxes_delivered = total_boxes_delivered + ?,
            total_delivery_time = total_delivery_time + ?,
            total_earnings = total_earnings + ?,
            perfect_deliveries = perfect_deliveries + ?,
            last_delivery = ?,
            updated_at = CURRENT_TIMESTAMP
    ]], {
        citizenid, playerName, today, 
        deliveryData.boxes, deliveryData.deliveryTime, deliveryData.earnings,
        deliveryData.isPerfect and 1 or 0, currentTime,
        -- ON DUPLICATE KEY UPDATE values:
        deliveryData.boxes, deliveryData.deliveryTime, deliveryData.earnings,
        deliveryData.isPerfect and 1 or 0, currentTime
    })
    
    -- Update streak tracking
    if deliveryData.isPerfect then
        MySQL.Async.execute([[
            INSERT INTO supply_driver_streaks (citizenid, perfect_streak, best_streak, last_delivery)
            VALUES (?, 1, 1, ?)
            ON DUPLICATE KEY UPDATE
                perfect_streak = perfect_streak + 1,
                best_streak = GREATEST(best_streak, perfect_streak + 1),
                last_delivery = ?,
                updated_at = CURRENT_TIMESTAMP
        ]], {citizenid, currentTime, currentTime})
    else
        -- Streak broken
        MySQL.Async.execute([[
            INSERT INTO supply_driver_streaks (citizenid, perfect_streak, best_streak, last_delivery, streak_broken_count)
            VALUES (?, 0, 0, ?, 1)
            ON DUPLICATE KEY UPDATE
                perfect_streak = 0,
                streak_broken_count = streak_broken_count + 1,
                last_delivery = ?,
                updated_at = CURRENT_TIMESTAMP
        ]], {citizenid, currentTime, currentTime})
    end
end)