local QBCore = exports['qb-core']:GetCoreObject()

-- Helper function to format time (moved to top)
local function formatTime(seconds)
    -- Ensure seconds is a number
    seconds = tonumber(seconds) or 0
    
    if seconds < 60 then
        return string.format("%d seconds", seconds)
    elseif seconds < 3600 then
        local minutes = math.floor(seconds / 60)
        return string.format("%d minutes", minutes)
    elseif seconds < 86400 then
        local hours = math.floor(seconds / 3600)
        return string.format("%d hours", hours)
    else
        local days = math.floor(seconds / 86400)
        return string.format("%d days", days)
    end -- End streak section
end

-- Helper function to format numbers with commas
local function comma_value(amount)
    if not amount then return "0" end
    local formatted = tostring(amount)
    while true do  
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if (k == 0) then
            break
        end
    end
    return formatted
end

-- Driver Status Display
RegisterNetEvent("rewards:showDriverStatus")
AddEventHandler("rewards:showDriverStatus", function(playerStats)
    if not playerStats then
        lib.notify({
            title = "No Data",
            description = "No driver statistics found.",
            type = "error",
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end

    local options = {
        {
            title = "📊 Performance Overview",
            description = string.format(
                "🚛 Deliveries: %d\n💰 Total Earnings: $%s\n⭐ Current Streak: %d\n🏆 Best Streak: %d",
                tonumber(playerStats.total_deliveries) or 0,
                comma_value(playerStats.total_earnings or 0),
                tonumber(playerStats.current_streak) or 0,
                tonumber(playerStats.best_streak) or 0
            ),
            disabled = false
        },
        {
            title = "⏱️ Speed Performance",
            description = string.format(
                "🚀 Average Time: %s\n⚡ Fastest Delivery: %s\n🎯 Perfect Deliveries: %d",
                formatTime(playerStats.average_time or 0),
                formatTime(playerStats.fastest_time or 0),
                tonumber(playerStats.perfect_deliveries) or 0
            ),
            disabled = false
        },
        {
            title = "📦 Volume Statistics", 
            description = string.format(
                "📋 Total Boxes: %d\n📊 Avg Boxes/Delivery: %.1f\n🏗️ Largest Delivery: %d boxes",
                tonumber(playerStats.total_boxes) or 0,
                (tonumber(playerStats.total_deliveries) or 0) > 0 and ((tonumber(playerStats.total_boxes) or 0) / (tonumber(playerStats.total_deliveries) or 1)) or 0,
                tonumber(playerStats.largest_delivery) or 0
            ),
            disabled = false
        }
    }

    -- Add current streak bonus info
    local currentStreak = tonumber(playerStats.current_streak) or 0
    if currentStreak > 0 then
        local nextStreakBonus = nil
        for _, bonus in pairs(Config.DriverRewards.streakBonuses) do
            if currentStreak < bonus.streak then
                nextStreakBonus = bonus
                break
            end
        end
        
        if nextStreakBonus then
            table.insert(options, {
                title = "🔥 Streak Progress",
                description = string.format(
                    "Current: %d deliveries\nNext Bonus: %s at %d deliveries\n(%d more needed)",
                    currentStreak,
                    nextStreakBonus.name,
                    nextStreakBonus.streak,
                    nextStreakBonus.streak - currentStreak
                ),
                disabled = true
            })
        end
    end -- End daily progress section

    -- Add daily progress
    local dailyDeliveries = tonumber(playerStats.daily_deliveries) or 0
    if dailyDeliveries > 0 then
        local nextDailyBonus = nil
        for _, multiplier in ipairs(Config.DriverRewards.dailyMultipliers) do
            if dailyDeliveries < multiplier.deliveries then
                nextDailyBonus = multiplier
                break
            end
        end
        
        if nextDailyBonus then
            table.insert(options, {
                title = "📅 Daily Progress",
                description = string.format(
                    "Today: %d deliveries\nNext Milestone: %s\n(%.1fx multiplier at %d deliveries)",
                    dailyDeliveries,
                    nextDailyBonus.name,
                    nextDailyBonus.multiplier,
                    nextDailyBonus.deliveries
                ),
                disabled = true
            })
        end
    end

    lib.registerContext({
        id = "driver_status_menu",
        title = "🎯 My Driver Status",
        options = options
    })
    lib.showContext("driver_status_menu")
end)

-- Reward Notification Display
RegisterNetEvent("rewards:showRewardBreakdown")
AddEventHandler("rewards:showRewardBreakdown", function(rewardData)
    if not rewardData then return end
    
    local description = string.format("💰 **Base Pay: $%d**", rewardData.basePay or 0)
    
    if rewardData.speedBonus and rewardData.speedBonus.multiplier > 1 then
        description = description .. string.format("\n%s **%.1fx** Speed Bonus", 
            rewardData.speedBonus.icon, rewardData.speedBonus.multiplier)
    end
    
    if rewardData.volumeBonus and rewardData.volumeBonus.bonus > 0 then
        description = description .. string.format("\n📦 **+$%d** Volume Bonus", rewardData.volumeBonus.bonus)
    end
    
    if rewardData.streakBonus and rewardData.streakBonus.multiplier > 1 then
        description = description .. string.format("\n%s **%.1fx** Streak Multiplier", 
            rewardData.streakBonus.icon, rewardData.streakBonus.multiplier)
    end
    
    if rewardData.dailyMultiplier and rewardData.dailyMultiplier > 1 then
        description = description .. string.format("\n📅 **%.1fx** Daily Multiplier", rewardData.dailyMultiplier)
    end
    
    if rewardData.perfectDelivery then
        description = description .. string.format("\n🎯 **+$%d** Perfect Delivery", 
            Config.DriverRewards.perfectDelivery.onTimeBonus)
    end
    
    description = description .. string.format("\n\n🏆 **TOTAL: $%d**", rewardData.totalPay or 0)
    
    lib.notify({
        title = "🎉 Delivery Reward Breakdown",
        description = description,
        type = "success",
        duration = 12000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })
end)