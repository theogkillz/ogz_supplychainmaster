local QBCore = exports['qb-core']:GetCoreObject()

-- Achievement Progress Display
RegisterNetEvent("achievements:showProgress")
AddEventHandler("achievements:showProgress", function(data)
    local currentTier = data.currentTier or "rookie"
    local vehicleTier = data.vehicleTier or "rookie"
    local stats = data.stats or {}
    local progress = data.progress or {}
    
    local options = {
        {
            title = "← Back to Main Menu",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("warehouse:openProcessingMenu")
            end
        }
    }
    
    -- Current Tier Display
    local tierInfo = Config.AchievementVehicles.performanceTiers[currentTier]
    if tierInfo then
        table.insert(options, {
            title = "🏆 Current Achievement Tier",
            description = tierInfo.name .. " - " .. tierInfo.description,
            icon = "fas fa-medal",
            metadata = {
                ["Tier"] = tierInfo.name,
                ["Requirement"] = tierInfo.requirement,
                ["Vehicle Performance"] = string.format("+%.0f%% speed, +%.0f%% acceleration", 
                    (tierInfo.speedMultiplier - 1) * 100, 
                    tierInfo.accelerationBonus * 100)
            },
            disabled = true
        })
    end
    
    -- Stats Overview
    if stats.totalDeliveries then
        table.insert(options, {
            title = "📊 Delivery Statistics",
            description = "Your performance metrics",
            icon = "fas fa-chart-bar",
            metadata = {
                ["Total Deliveries"] = tostring(stats.totalDeliveries or 0),
                ["Perfect Deliveries"] = tostring(stats.perfectDeliveries or 0),
                ["Average Rating"] = string.format("%.1f%%", stats.averageRating or 0),
                ["Total Earnings"] = "$" .. tostring(stats.totalEarnings or 0)
            },
            disabled = true
        })
    end
    
    -- Progress to Next Tier
    local nextTierName = nil
    local tierOrder = {"rookie", "experienced", "professional", "elite", "legendary"}
    for i = 1, #tierOrder do
        if tierOrder[i] == currentTier and i < #tierOrder then
            nextTierName = tierOrder[i + 1]
            break
        end
    end
    
    if nextTierName then
        local nextTier = Config.AchievementVehicles.performanceTiers[nextTierName]
        if nextTier then
            -- Calculate progress (simplified)
            local progressPercent = 0
            if nextTierName == "experienced" and stats.totalDeliveries then
                progressPercent = math.min((stats.totalDeliveries / 50) * 100, 100)
            elseif nextTierName == "professional" and stats.totalDeliveries then
                progressPercent = math.min((stats.totalDeliveries / 150) * 100, 100)
            elseif nextTierName == "elite" and stats.totalDeliveries then
                progressPercent = math.min((stats.totalDeliveries / 300) * 100, 100)
            elseif nextTierName == "legendary" and stats.totalDeliveries then
                progressPercent = math.min((stats.totalDeliveries / 500) * 100, 100)
            end
            
            table.insert(options, {
                title = "🎯 Next Tier Progress",
                description = string.format("%.1f%% to %s", progressPercent, nextTier.name),
                icon = "fas fa-tasks",
                metadata = {
                    ["Next Tier"] = nextTier.name,
                    ["Requirement"] = nextTier.requirement,
                    ["Progress"] = string.format("%.1f%%", progressPercent)
                },
                disabled = true
            })
        end
    end
    
    -- Achievement Milestones
    table.insert(options, {
        title = "🏅 Achievement Milestones",
        description = "Track your progress",
        icon = "fas fa-trophy",
        disabled = true
    })
    
    -- Individual achievements
    local achievements = {
        {name = "First Delivery", req = 1, reward = "$150", completed = (stats.totalDeliveries or 0) >= 1},
        {name = "Speed Demon", req = "5 lightning deliveries", reward = "$300", completed = (progress.lightningDeliveries or 0) >= 5},
        {name = "Big Hauler", req = "10 large deliveries", reward = "$450", completed = (progress.largeDeliveries or 0) >= 10},
        {name = "Perfect Week", req = "7 perfect days", reward = "$1,250", completed = (progress.perfectDays or 0) >= 7},
        {name = "Century Club", req = "100 deliveries", reward = "$2,500", completed = (stats.totalDeliveries or 0) >= 100}
    }
    
    for _, achievement in ipairs(achievements) do
        local icon = achievement.completed and "✅" or "⭕"
        local color = achievement.completed and "success" or "primary"
        
        table.insert(options, {
            title = icon .. " " .. achievement.name,
            description = "Requirement: " .. achievement.req .. " | Reward: " .. achievement.reward,
            icon = achievement.completed and "fas fa-check-circle" or "fas fa-circle",
            metadata = {
                ["Status"] = achievement.completed and "COMPLETED" or "IN PROGRESS",
                ["Reward"] = achievement.reward
            },
            disabled = true
        })
    end
    
    lib.registerContext({
        id = "achievement_progress_menu",
        title = "🏆 Achievement Progress",
        options = options
    })
    lib.showContext("achievement_progress_menu")
end)