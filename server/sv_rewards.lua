-- EPIC DRIVER REWARDS SYSTEM
-- Add this to sv_leaderboard.lua or create new sv_rewards.lua

local QBCore = exports['qb-core']:GetCoreObject()
local showRewardNotification
local getNextStreakBonus
local getNextDailyBonus

-- Reward Configuration
Config.DriverRewards = {
    -- Speed Bonuses (based on delivery time)
    speedBonuses = {
        lightning = { maxTime = 300, multiplier = 2.5, name = "⚡ Lightning Fast", icon = "⚡" },    -- Under 5 min = 2.5x
        express = { maxTime = 600, multiplier = 2.0, name = "🚀 Express Delivery", icon = "🚀" },   -- Under 10 min = 2x
        fast = { maxTime = 900, multiplier = 1.5, name = "⏰ Fast Delivery", icon = "⏰" },         -- Under 15 min = 1.5x
        standard = { maxTime = 1800, multiplier = 1.0, name = "Standard", icon = "📦" }            -- Under 30 min = 1x
    },
    
    -- Volume Bonuses (based on boxes delivered)
    volumeBonuses = {
        mega = { minBoxes = 15, bonus = 5000, name = "🏗️ Mega Haul", icon = "🏗️" },
        large = { minBoxes = 10, bonus = 2500, name = "📦 Large Haul", icon = "📦" },
        medium = { minBoxes = 5, bonus = 1000, name = "📋 Medium Haul", icon = "📋" },
        small = { minBoxes = 1, bonus = 0, name = "📦 Standard", icon = "📦" }
    },
    
    -- Streak Bonuses (consecutive perfect deliveries)
    streakBonuses = {
        legendary = { streak = 20, multiplier = 3.0, name = "👑 Legendary Streak", icon = "👑" },
        master = { streak = 15, multiplier = 2.5, name = "🔥 Master Streak", icon = "🔥" },
        expert = { streak = 10, multiplier = 2.0, name = "⭐ Expert Streak", icon = "⭐" },
        skilled = { streak = 5, multiplier = 1.5, name = "💎 Skilled Streak", icon = "💎" },
        basic = { streak = 0, multiplier = 1.0, name = "Standard", icon = "📦" }
    },
    
    -- Daily Multipliers (escalating throughout the day)
    dailyMultipliers = {
        { deliveries = 1, multiplier = 1.0, name = "Getting Started" },
        { deliveries = 3, multiplier = 1.1, name = "Warming Up" },
        { deliveries = 5, multiplier = 1.2, name = "In the Zone" },
        { deliveries = 8, multiplier = 1.3, name = "On Fire" },
        { deliveries = 12, multiplier = 1.5, name = "Unstoppable" },
        { deliveries = 20, multiplier = 2.0, name = "LEGENDARY" }
    },
    
    -- Perfect Delivery Criteria
    perfectDelivery = {
        maxTime = 1200,           -- Under 20 minutes
        noVehicleDamage = true,   -- Van must be in good condition
        onTimeBonus = 500         -- Bonus for perfect deliveries
    }
}

-- BALANCED REWARD CALCULATION SYSTEM
    local function calculateDeliveryRewards(playerId, deliveryData)
    if not playerId or not deliveryData then
        print("[ERROR] Invalid parameters passed to calculateDeliveryRewards")
        return 0, {}
    end
    
    local xPlayer = QBCore.Functions.GetPlayer(playerId)
    if not xPlayer then
        print("[ERROR] Failed to get player object for ID:", playerId)
        return 0, {}
    end
    
    local citizenid = xPlayer.PlayerData.citizenid
    
    -- CALCULATE BASE PAY using new economy system
    local boxes = deliveryData.boxes or 1
    local basePay = math.max(
        Config.EconomyBalance.minimumDeliveryPay,
        boxes * Config.EconomyBalance.basePayPerBox
    )
    
    -- Ensure we don't exceed maximum pay (anti-exploit)
    basePay = math.min(basePay, Config.EconomyBalance.maximumDeliveryPay)
    
    local totalBonusFlat = 0
    local bonusBreakdown = {}
    local finalMultiplier = 1.0
    
    -- 1. SPEED BONUS (multiplicative)
    local speedBonus = nil
    for tier, bonus in pairs(Config.DriverRewards.speedBonuses) do
        if deliveryData.deliveryTime <= bonus.maxTime then
            speedBonus = bonus
            break
        end
    end
    
    if speedBonus and speedBonus.multiplier > 1.0 then
        finalMultiplier = finalMultiplier * speedBonus.multiplier
        table.insert(bonusBreakdown, {
            type = "speed",
            name = speedBonus.name,
            icon = speedBonus.icon,
            multiplier = speedBonus.multiplier,
            description = string.format("%.1fx speed bonus", speedBonus.multiplier)
        })
    end
    
    -- 2. VOLUME BONUS (flat amount)
    local volumeBonus = nil
    for tier, bonus in pairs(Config.DriverRewards.volumeBonuses) do
        if boxes >= bonus.minBoxes then
            volumeBonus = bonus
            break
        end
    end
    
    if volumeBonus and volumeBonus.bonus > 0 then
        totalBonusFlat = totalBonusFlat + volumeBonus.bonus
        table.insert(bonusBreakdown, {
            type = "volume",
            name = volumeBonus.name,
            icon = volumeBonus.icon,
            amount = volumeBonus.bonus,
            description = string.format("+$%d volume bonus", volumeBonus.bonus)
        })
    end
    
    -- 3. GET CURRENT STREAK AND CALCULATE BONUSES
    MySQL.Async.fetchAll('SELECT perfect_streak FROM supply_driver_streaks WHERE citizenid = ?', 
        {citizenid}, function(result)
        
        local currentStreak = (result and result[1]) and result[1].perfect_streak or 0
        
        -- Check if this delivery maintains the streak
        local isPerfectDelivery = deliveryData.deliveryTime <= Config.DriverRewards.perfectDelivery.maxTime
        
        if isPerfectDelivery then
            currentStreak = currentStreak + 1
            
            -- Update streak in database
            MySQL.Async.execute([[
                INSERT INTO supply_driver_streaks (citizenid, perfect_streak, best_streak, last_delivery)
                VALUES (?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE 
                    perfect_streak = ?,
                    best_streak = GREATEST(best_streak, ?),
                    last_delivery = ?
            ]], {citizenid, currentStreak, currentStreak, os.time(), currentStreak, currentStreak, os.time()})
        else
            -- Reset streak
            currentStreak = 0
            MySQL.Async.execute([[
                INSERT INTO supply_driver_streaks (citizenid, perfect_streak, last_delivery, streak_broken_count)
                VALUES (?, 0, ?, 1)
                ON DUPLICATE KEY UPDATE 
                    perfect_streak = 0,
                    last_delivery = ?,
                    streak_broken_count = streak_broken_count + 1
            ]], {citizenid, os.time(), os.time()})
        end
        
        -- 4. STREAK MULTIPLIER (multiplicative)
        local streakMultiplier = 1.0
        for tier, bonus in pairs(Config.DriverRewards.streakBonuses) do
            if currentStreak >= bonus.streak then
                streakMultiplier = bonus.multiplier
                if bonus.multiplier > 1.0 then
                    table.insert(bonusBreakdown, {
                        type = "streak",
                        name = bonus.name .. " (" .. currentStreak .. " streak)",
                        icon = bonus.icon,
                        multiplier = bonus.multiplier,
                        description = string.format("%.1fx streak bonus", bonus.multiplier)
                    })
                end
                break
            end
        end
        
        finalMultiplier = finalMultiplier * streakMultiplier
        
        -- 5. DAILY MULTIPLIER
        MySQL.Async.fetchAll([[
            SELECT SUM(completed_deliveries) as daily_deliveries 
            FROM supply_driver_stats 
            WHERE citizenid = ? AND delivery_date = CURDATE()
        ]], {citizenid}, function(dailyResult)
            
            local dailyDeliveries = (dailyResult and dailyResult[1]) and dailyResult[1].daily_deliveries or 0
            dailyDeliveries = dailyDeliveries + 1 -- Include this delivery
            
            local dailyMultiplier = 1.0
            local dailyTier = nil
            for _, tier in ipairs(Config.DriverRewards.dailyMultipliers) do
                if dailyDeliveries >= tier.deliveries then
                    dailyMultiplier = tier.multiplier
                    dailyTier = tier
                end
            end
            
            if dailyTier and dailyMultiplier > 1.0 then
                finalMultiplier = finalMultiplier * dailyMultiplier
                table.insert(bonusBreakdown, {
                    type = "daily",
                    name = "🔥 Daily Multiplier (" .. dailyTier.name .. ")",
                    icon = "🔥",
                    multiplier = dailyMultiplier,
                    description = string.format("%.1fx daily bonus", dailyMultiplier)
                })
            end
            
            -- 6. PERFECT DELIVERY BONUS (flat amount)
            if isPerfectDelivery then
                totalBonusFlat = totalBonusFlat + Config.DriverRewards.perfectDelivery.onTimeBonus
                table.insert(bonusBreakdown, {
                    type = "perfect",
                    name = "🎯 Perfect Delivery",
                    icon = "🎯",
                    amount = Config.DriverRewards.perfectDelivery.onTimeBonus,
                    description = string.format("+$%d perfect delivery", Config.DriverRewards.perfectDelivery.onTimeBonus)
                })
            end
            
            -- Calculate final payment
            local multipliedPay = math.floor(basePay * finalMultiplier)
            local finalPayout = multipliedPay + totalBonusFlat
            
            -- ENFORCE MAXIMUM PAY CAP (anti-exploit protection)
            finalPayout = math.min(finalPayout, Config.EconomyBalance.maximumDeliveryPay)
            
            -- Award the money
            xPlayer.Functions.AddMoney('cash', finalPayout, "Delivery payment with bonuses")
            
            -- Show reward notification
            showRewardNotification(playerId, {
                basePay = basePay,
                finalPayout = finalPayout,
                bonusBreakdown = bonusBreakdown,
                finalMultiplier = finalMultiplier,
                currentStreak = currentStreak,
                isPerfectDelivery = isPerfectDelivery,
                boxes = boxes
            })
            
            -- Log the delivery for analytics
            MySQL.Async.execute([[
                INSERT INTO supply_delivery_logs (
                    citizenid, order_group_id, restaurant_id, boxes_delivered, 
                    delivery_time, base_pay, bonus_pay, total_pay, 
                    is_perfect_delivery, speed_multiplier, streak_multiplier, 
                    daily_multiplier
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ]], {
                citizenid,
                deliveryData.orderGroupId or "unknown",
                deliveryData.restaurantId or 1,
                boxes,
                deliveryData.deliveryTime,
                basePay,
                totalBonusFlat,
                finalPayout,
                isPerfectDelivery and 1 or 0,
                speedBonus and speedBonus.multiplier or 1.0,
                streakMultiplier,
                dailyMultiplier
            })
            
            -- Also update reward logs (if table exists)
            MySQL.Async.execute([[
                INSERT INTO supply_reward_logs (
                    citizenid, order_group_id, base_pay, bonus_amount, 
                    final_payout, speed_multiplier, streak_multiplier, 
                    daily_multiplier, perfect_delivery, delivery_time
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ]], {
                citizenid,
                deliveryData.orderGroupId or "unknown",
                basePay,
                totalBonusFlat,
                finalPayout,
                speedBonus and speedBonus.multiplier or 1.0,
                streakMultiplier,
                dailyMultiplier,
                isPerfectDelivery and 1 or 0,
                deliveryData.deliveryTime
            })
        end)
    end)
end

-- Enhanced reward notification with better formatting
showRewardNotification = function(playerId, rewardData)
    local bonusText = ""
    local totalBonusAmount = 0
    
    if #rewardData.bonusBreakdown > 0 then
        bonusText = "\n\n🎉 **BONUSES EARNED:**\n"
        for _, bonus in ipairs(rewardData.bonusBreakdown) do
            if bonus.amount then
                bonusText = bonusText .. bonus.icon .. " " .. bonus.description .. "\n"
                totalBonusAmount = totalBonusAmount + bonus.amount
            elseif bonus.multiplier then
                bonusText = bonusText .. bonus.icon .. " " .. bonus.description .. "\n"
            end
        end
    end
    
    local streakText = ""
    if rewardData.currentStreak > 0 then
        streakText = "\n🔥 **PERFECT STREAK: " .. rewardData.currentStreak .. "**"
    end
    
    local multiplierText = ""
    if rewardData.finalMultiplier > 1.0 then
        multiplierText = "\n⚡ **TOTAL MULTIPLIER: " .. string.format("%.2f", rewardData.finalMultiplier) .. "x**"
    end
    
    TriggerClientEvent('ox_lib:notify', playerId, {
        title = '💰 DELIVERY COMPLETED!',
        description = string.format(
            "📦 **%d boxes delivered**\n💵 Base Pay: $%d\n💎 Bonus: +$%d\n💰 **TOTAL: $%d**%s%s%s",
            rewardData.boxes,
            rewardData.basePay,
            totalBonusAmount,
            rewardData.finalPayout,
            bonusText,
            multiplierText,
            streakText
        ),
        type = 'success',
        duration = 15000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })
    
    -- Achievement-style notifications for major milestones
    if rewardData.currentStreak > 0 and rewardData.currentStreak % 5 == 0 then
        TriggerClientEvent('ox_lib:notify', playerId, {
            title = '🔥 STREAK MILESTONE!',
            description = string.format("🎯 **%d PERFECT DELIVERIES IN A ROW!**\n⚡ Your multiplier is now %.1fx!", rewardData.currentStreak, rewardData.finalMultiplier),
            type = 'success',
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
    end
    
    -- Warn about pay cap if reached
    if rewardData.finalPayout >= Config.EconomyBalance.maximumDeliveryPay then
        TriggerClientEvent('ox_lib:notify', playerId, {
            title = '💎 MAXIMUM PAYOUT REACHED',
            description = string.format("You've hit the delivery pay cap of $%d!\nThis prevents economy exploits.", Config.EconomyBalance.maximumDeliveryPay),
            type = 'info',
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
    end
end

-- Main reward calculation event (called from delivery completion)
RegisterNetEvent('rewards:calculateDeliveryReward')
AddEventHandler('rewards:calculateDeliveryReward', function(playerId, deliveryData)
    calculateDeliveryRewards(playerId, deliveryData)
end)

-- Get player's current bonuses/status
RegisterNetEvent('rewards:getPlayerStatus')
AddEventHandler('rewards:getPlayerStatus', function()
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    local citizenid = xPlayer.PlayerData.citizenid
    
    -- Get current streak
    MySQL.Async.fetchAll('SELECT perfect_streak FROM supply_driver_streaks WHERE citizenid = ?', 
        {citizenid}, function(streakResult)
        
        -- Get today's deliveries
        MySQL.Async.fetchAll([[
            SELECT SUM(completed_deliveries) as daily_deliveries 
            FROM supply_driver_stats 
            WHERE citizenid = ? AND delivery_date = CURDATE()
        ]], {citizenid}, function(dailyResult)
            
            local currentStreak = (streakResult and streakResult[1]) and streakResult[1].perfect_streak or 0
            local dailyDeliveries = (dailyResult and dailyResult[1]) and dailyResult[1].daily_deliveries or 0
            
            -- Calculate next bonuses
            local nextStreak = currentStreak + 1
            local nextDaily = dailyDeliveries + 1
            
            TriggerClientEvent('rewards:showPlayerStatus', src, {
                currentStreak = currentStreak,
                dailyDeliveries = dailyDeliveries,
                nextStreakBonus = getNextStreakBonus(nextStreak),
                nextDailyBonus = getNextDailyBonus(nextDaily)
            })
        end)
    end)
end)

-- Helper functions
getNextStreakBonus = function(streak)
    for tier, bonus in pairs(Config.DriverRewards.streakBonuses) do
        if streak >= bonus.streak and bonus.multiplier > 1.0 then
            return bonus
        end
    end
    return nil
end

getNextDailyBonus = function(deliveries)
    for _, tier in ipairs(Config.DriverRewards.dailyMultipliers) do
        if deliveries >= tier.deliveries and tier.multiplier > 1.0 then
            return tier
        end
    end
    return nil
end