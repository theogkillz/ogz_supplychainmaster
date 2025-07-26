-- Helper function to format money
local function formatMoney(amount)
    local formatted = tostring(math.floor(amount))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then
            break
        end
    end
    return formatted
end

-- Driver Status Display
RegisterNetEvent("rewards:showPlayerStatus")
AddEventHandler("rewards:showPlayerStatus", function(statusData)
    local options = {
        {
            title = "← Back to Warehouse",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("warehouse:openProcessingMenu")
            end
        },
        {
            title = "🔥 Current Status",
            description = string.format(
                "⚡ Perfect Streak: %d deliveries\n📅 Today's Deliveries: %d",
                statusData.currentStreak,
                statusData.dailyDeliveries
            ),
            disabled = true
        }
    }
    
    if statusData.nextStreakBonus then
        table.insert(options, {
            title = "🎯 Next Streak Bonus",
            description = statusData.nextStreakBonus.name .. " - " .. statusData.nextStreakBonus.multiplier .. "x multiplier",
            disabled = true
        })
    end
    
    if statusData.nextDailyBonus then
        table.insert(options, {
            title = "🔥 Next Daily Bonus", 
            description = statusData.nextDailyBonus.name .. " - " .. statusData.nextDailyBonus.multiplier .. "x multiplier",
            disabled = true
        })
    end
    
    lib.registerContext({
        id = "driver_status",
        title = "🎯 Driver Status",
        options = options
    })
    lib.showContext("driver_status")
end)

-- Leaderboard Menu
RegisterNetEvent("leaderboard:openMenu")
AddEventHandler("leaderboard:openMenu", function()
    local options = {
        {
            title = "🏆 All-Time Champions",
            description = "Top drivers of all time",
            icon = "fas fa-crown",
            onSelect = function()
                TriggerServerEvent("leaderboard:getDriverStats", "all_time")
            end
        },
        {
            title = "📅 Monthly Leaders",
            description = "This month's top performers",
            icon = "fas fa-calendar-alt",
            onSelect = function()
                TriggerServerEvent("leaderboard:getDriverStats", "monthly")
            end
        },
        {
            title = "📅 Weekly Leaders",
            description = "This week's top performers",
            icon = "fas fa-calendar-week",
            onSelect = function()
                TriggerServerEvent("leaderboard:getDriverStats", "weekly")
            end
        },
        {
            title = "📅 Today's Leaders",
            description = "Today's top performers",
            icon = "fas fa-calendar-day",
            onSelect = function()
                TriggerServerEvent("leaderboard:getDriverStats", "daily")
            end
        },
        {
            title = "← Back to Warehouse",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("warehouse:openProcessingMenu")
            end
        }
    }
    
    lib.registerContext({
        id = "leaderboard_menu",
        title = "🏆 Driver Leaderboards",
        options = options
    })
    lib.showContext("leaderboard_menu")
end)

-- Display Leaderboard Results
RegisterNetEvent("leaderboard:showDriverStats")
AddEventHandler("leaderboard:showDriverStats", function(drivers, filter)
    local filterNames = {
        all_time = "All-Time Champions",
        monthly = "Monthly Leaders", 
        weekly = "Weekly Leaders",
        daily = "Today's Leaders"
    }
    
    local options = {
        {
            title = "← Back to Leaderboards",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("leaderboard:openMenu")
            end
        }
    }
    
    if #drivers == 0 then
        table.insert(options, {
            title = "No Data Available",
            description = "No drivers found for this time period",
            disabled = true
        })
    else
        for i, driver in ipairs(drivers) do
            local rankIcon = "🥉"
            if i == 1 then rankIcon = "🥇"
            elseif i == 2 then rankIcon = "🥈"
            elseif i <= 5 then rankIcon = "⭐"
            end
            
            local achievementCount = driver.achievements and #driver.achievements or 0
            local lastActiveText = "Never"
            if driver.last_active and driver.last_active > 0 then
                -- Convert timestamp to days ago (simple client-safe calculation)
                local currentTime = GetGameTimer() / 1000
                local daysSince = math.floor((currentTime - driver.last_active) / 86400)
                
                if daysSince == 0 then
                    lastActiveText = "Today"
                elseif daysSince == 1 then
                    lastActiveText = "Yesterday"
                elseif daysSince < 7 then
                    lastActiveText = daysSince .. " days ago"
                elseif daysSince < 30 then
                    lastActiveText = math.floor(daysSince / 7) .. " weeks ago"
                else
                    lastActiveText = math.floor(daysSince / 30) .. " months ago"
                end
            end
            
            table.insert(options, {
                title = rankIcon .. " #" .. i .. " " .. driver.name,
                description = string.format(
                    "💰 $%s earned • 📦 %d deliveries • 🏆 %d achievements\n⭐ Rating: %d/100 • 📅 Last Active: %s",
                    formatMoney(driver.total_earnings or 0),
                    driver.total_deliveries or 0,
                    achievementCount,
                    math.floor(driver.avg_rating or 0),
                    lastActiveText
                ),
                metadata = {
                    ["Rank"] = "#" .. i,
                    ["Earnings"] = "$" .. formatMoney(driver.total_earnings or 0),
                    ["Deliveries"] = tostring(driver.total_deliveries or 0),
                    ["Boxes"] = tostring(driver.total_boxes or 0),
                    ["Rating"] = math.floor(driver.avg_rating or 0) .. "/100",
                    ["Achievements"] = tostring(achievementCount)
                }
            })
        end
    end
    
    lib.registerContext({
        id = "leaderboard_results",
        title = "🏆 " .. filterNames[filter],
        options = options
    })
    lib.showContext("leaderboard_results")
end)

-- Display Personal Stats
RegisterNetEvent("leaderboard:showPersonalStats")
AddEventHandler("leaderboard:showPersonalStats", function(stats)
    local options = {
        {
            title = "← Back to Warehouse",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("warehouse:openProcessingMenu")
            end
        },
        {
            title = "📊 Performance Overview",
            description = string.format(
                "⭐ Performance Rating: %d/100\n📦 Total Deliveries: %d\n💰 Total Earnings: $%s\n📅 Active Days: %d",
                math.floor(stats.performance_rating or 0),
                stats.total_deliveries or 0,
                formatMoney(stats.total_earnings or 0),
                stats.active_days or 0
            ),
            disabled = true
        }
    }
    
    -- Add achievements section
    if stats.achievements and #stats.achievements > 0 then
        table.insert(options, {
            title = "🏆 Achievements (" .. #stats.achievements .. ")",
            description = "Your earned achievements",
            disabled = true
        })
        
        -- Get achievement details
        local achievementDetails = {
            first_delivery = {name = "First Steps", icon = "🚚"},
            speed_demon = {name = "Speed Demon", icon = "⚡"},
            big_hauler = {name = "Big Hauler", icon = "📦"},
            perfect_week = {name = "Perfect Week", icon = "👑"},
            century_club = {name = "Century Club", icon = "💯"}
        }
        
        for _, achievement in ipairs(stats.achievements) do
            local details = achievementDetails[achievement.achievement_id]
            if details then
                table.insert(options, {
                    title = details.icon .. " " .. details.name,
                    description = "Earned: " .. os.date("%m/%d/%Y", achievement.earned_date),
                    disabled = true
                })
            end
        end
    else
        table.insert(options, {
            title = "🏆 No Achievements Yet",
            description = "Complete deliveries to earn achievements!",
            disabled = true
        })
    end
    
    lib.registerContext({
        id = "personal_stats",
        title = "📊 My Performance",
        options = options
    })
    lib.showContext("personal_stats")
end)