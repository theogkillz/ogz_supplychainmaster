-- MOBILE NOTIFICATIONS & DISCORD INTEGRATION

local QBCore = exports['qb-core']:GetCoreObject()

-- Send Discord webhook
local function sendDiscordWebhook(webhookURL, embeds, content)
    if not Config.Notifications.discord.enabled or not webhookURL then
        return
    end
    
    local data = {
        username = Config.Notifications.discord.botName,
        avatar_url = Config.Notifications.discord.botAvatar,
        content = content or "",
        embeds = embeds
    }
    
    PerformHttpRequest(webhookURL, function(statusCode, response)
        if statusCode ~= 200 and statusCode ~= 204 then
            print("[DISCORD] Failed to send webhook: " .. statusCode)
        end
    end, 'POST', json.encode(data), {
        ['Content-Type'] = 'application/json'
    })
end

-- Send phone notification
local function sendPhoneNotification(playerId, title, message, app)
    if not Config.Notifications.phone.enabled then
        return
    end
    
    local phoneResource = Config.Notifications.phone.resource
    
    if phoneResource == "qb-phone" then
        TriggerClientEvent('qb-phone:client:CustomNotification', playerId, title, message, "fas fa-truck", "#FF6B35", 8000)
    elseif phoneResource == "lb-phone" then
        exports["lb-phone"]:SendNotification(playerId, {
            app = app or "Messages",
            title = title,
            content = message,
            time = 8000
        })
    elseif phoneResource == "qs-smartphone" then
        TriggerClientEvent('qs-smartphone:client:notification', playerId, {
            title = title,
            message = message,
            icon = "fas fa-truck",
            timeout = 8000
        })
    end
end

-- Market Event Notifications
RegisterNetEvent('notifications:marketEvent')
AddEventHandler('notifications:marketEvent', function(eventType, ingredient, oldPrice, newPrice, percentage)
    local itemNames = exports.ox_inventory:Items() or {}
    local itemLabel = itemNames[ingredient] and itemNames[ingredient].label or ingredient
    local change = ((newPrice - oldPrice) / oldPrice) * 100
    
    -- Discord notification
    local embed = {
        title = "🚨 MARKET ALERT",
        description = string.format("**%s** %s detected!", itemLabel, eventType:upper()),
        color = eventType == "shortage" and 15158332 or 3066993, -- Red for shortage, green for surplus
        fields = {
            {
                name = "📊 Price Change",
                value = string.format("$%d → $%d (%+.1f%%)", oldPrice, newPrice, change),
                inline = true
            },
            {
                name = "📦 Stock Level", 
                value = string.format("%.1f%%", percentage),
                inline = true
            },
            {
                name = "⏰ Event Time",
                value = os.date("%H:%M:%S"),
                inline = true
            }
        },
        footer = {
            text = "Supply Chain AI • Market Monitoring"
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    
    sendDiscordWebhook(Config.Notifications.discord.channels.market_events, {embed})
    
    -- Phone notifications to relevant players
    local players = QBCore.Functions.GetPlayers()
    for _, playerId in ipairs(players) do
        local xPlayer = QBCore.Functions.GetPlayer(playerId)
        if xPlayer then
            local playerJob = xPlayer.PlayerData.job.name
            
            -- Notify restaurant owners and warehouse workers
            if playerJob == "burgershot" or playerJob == "warehouse" then
                sendPhoneNotification(playerId, "📊 Market Alert", 
                    string.format("%s %s! Price: $%d (%+.1f%%)", itemLabel, eventType, newPrice, change),
                    "SupplyChain")
            end
        end
    end
end)

-- Emergency Order Notifications
RegisterNetEvent('notifications:emergencyOrder')
AddEventHandler('notifications:emergencyOrder', function(orderData)
    -- Discord notification
    local embed = {
        title = "🚨 EMERGENCY ORDER",
        description = string.format("%s **%s** needed at %s!", 
            orderData.priorityName, orderData.itemLabel, orderData.restaurantName),
        color = 15158332, -- Red
        fields = {
            {
                name = "💰 Emergency Pay",
                value = "$" .. orderData.emergencyPay,
                inline = true
            },
            {
                name = "📦 Stock Status",
                value = string.format("Restaurant: %d | Warehouse: %d", 
                    orderData.stockData.restaurantStock, orderData.stockData.warehouseStock),
                inline = true
            },
            {
                name = "⏰ Time Limit",
                value = math.floor(orderData.timeRemaining / 60) .. " minutes",
                inline = true
            }
        },
        footer = {
            text = "Supply Chain AI • Emergency System"
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    
    sendDiscordWebhook(Config.Notifications.discord.channels.emergency_orders, {embed})
    
    -- Phone notifications to drivers
    local players = QBCore.Functions.GetPlayers()
    for _, playerId in ipairs(players) do
        local xPlayer = QBCore.Functions.GetPlayer(playerId)
        if xPlayer then
            local playerJob = xPlayer.PlayerData.job.name
            
            if playerJob == "warehouse" or playerJob == "trucker" then
                sendPhoneNotification(playerId, "🚨 Emergency Order", 
                    string.format("%s needed! Pay: $%d", orderData.itemLabel, orderData.emergencyPay),
                    "SupplyChain")
            end
        end
    end
end)

-- Achievement Notifications
RegisterNetEvent('notifications:achievement')
AddEventHandler('notifications:achievement', function(playerId, achievementData)
    local xPlayer = QBCore.Functions.GetPlayer(playerId)
    if not xPlayer then return end
    
    local playerName = xPlayer.PlayerData.charinfo.firstname .. ' ' .. xPlayer.PlayerData.charinfo.lastname
    
    -- Discord notification
    local embed = {
        title = "🏆 ACHIEVEMENT UNLOCKED",
        description = string.format("**%s** earned: %s %s!", 
            playerName, achievementData.icon, achievementData.name),
        color = 16776960, -- Gold
        fields = {
            {
                name = "📝 Description",
                value = achievementData.description,
                inline = false
            },
            {
                name = "💰 Reward",
                value = "$" .. achievementData.reward,
                inline = true
            },
            {
                name = "⏰ Earned At",
                value = os.date("%H:%M:%S"),
                inline = true
            }
        },
        footer = {
            text = "Supply Chain AI • Achievement System"
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    
    sendDiscordWebhook(Config.Notifications.discord.channels.achievements, {embed})
    
    -- Phone notification to player
    sendPhoneNotification(playerId, "🏆 Achievement Unlocked!", 
        string.format("%s %s earned! Reward: $%d", achievementData.icon, achievementData.name, achievementData.reward),
        "SupplyChain")
end)

-- Team Delivery Notifications
RegisterNetEvent('notifications:teamDelivery')
AddEventHandler('notifications:teamDelivery', function(eventType, teamData)
    if eventType == "created" then
        -- Notify available drivers about new team
        local players = QBCore.Functions.GetPlayers()
        for _, playerId in ipairs(players) do
            local xPlayer = QBCore.Functions.GetPlayer(playerId)
            if xPlayer then
                local playerJob = xPlayer.PlayerData.job.name
                
                if playerJob == "warehouse" or playerJob == "trucker" then
                    sendPhoneNotification(playerId, "👥 Team Delivery Available", 
                        string.format("%s started a %d-box team delivery! Join for bonus pay!", 
                            teamData.leaderName, teamData.totalBoxes),
                        "SupplyChain")
                end
            end
        end
        
    elseif eventType == "completed" then
        -- Discord notification for completed team delivery
        local embed = {
            title = "🚛 TEAM DELIVERY COMPLETED",
            description = string.format("**%d-driver convoy** completed %d-box delivery!", 
                teamData.memberCount, teamData.totalBoxes),
            color = 3066993, -- Green
            fields = {
                {
                    name = "👥 Team Size",
                    value = string.format("%d drivers", teamData.memberCount),
                    inline = true
                },
                {
                    name = "📦 Total Boxes",
                    value = tostring(teamData.totalBoxes),
                    inline = true
                },
                {
                    name = "🎯 Coordination",
                    value = string.format("%.1fs sync", teamData.syncTime or 0),
                    inline = true
                }
            },
            footer = {
                text = "Supply Chain AI • Team System"
            },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }
        
        sendDiscordWebhook(Config.Notifications.discord.webhookURL, {embed})
    end
end)

-- Stock Alert Notifications
RegisterNetEvent('notifications:stockAlert')
AddEventHandler('notifications:stockAlert', function(alertData)
    -- Phone notification to restaurant owners
    local players = QBCore.Functions.GetPlayers()
    for _, playerId in ipairs(players) do
        local xPlayer = QBCore.Functions.GetPlayer(playerId)
        if xPlayer then
            local playerJob = xPlayer.PlayerData.job.name
            local isBoss = xPlayer.PlayerData.job.isboss
            
            -- Check if this item is relevant to their restaurant
            if isBoss then
                for restaurantId, restaurant in pairs(Config.Restaurants) do
                    if restaurant.job == playerJob then
                        local restaurantItems = Config.Items[playerJob] or {}
                        for category, categoryItems in pairs(restaurantItems) do
                            if categoryItems[alertData.ingredient] then
                                local alertIcon = alertData.alertLevel == "critical" and "🚨" or "⚠️"
                                
                                sendPhoneNotification(playerId, alertIcon .. " Stock Alert", 
                                    string.format("%s is %s! Only %.1f%% remaining", 
                                        alertData.itemLabel, alertData.alertLevel, alertData.percentage),
                                    "SupplyChain")
                                break
                            end
                        end
                        break
                    end
                end
            end
        end
    end
end)

-- System Status Notifications (for admins)
RegisterNetEvent('notifications:systemStatus')
AddEventHandler('notifications:systemStatus', function(statusData)
    local embed = {
        title = "⚙️ SYSTEM STATUS",
        description = "Supply Chain System Health Report",
        color = statusData.status == "healthy" and 3066993 or 15158332,
        fields = {
            {
                name = "📊 Active Orders",
                value = tostring(statusData.activeOrders or 0),
                inline = true
            },
            {
                name = "🚛 Active Drivers",
                value = tostring(statusData.activeDrivers or 0),
                inline = true
            },
            {
                name = "💰 Market Status",
                value = statusData.marketStatus or "normal",
                inline = true
            },
            {
                name = "🚨 Emergency Orders",
                value = tostring(statusData.emergencyOrders or 0),
                inline = true
            },
            {
                name = "⚠️ Critical Stock Items",
                value = tostring(statusData.criticalStock or 0),
                inline = true
            },
            {
                name = "📈 Avg Price Multiplier",
                value = string.format("%.2fx", statusData.avgMultiplier or 1.0),
                inline = true
            }
        },
        footer = {
            text = "Supply Chain AI • System Monitor"
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
    
    sendDiscordWebhook(Config.Notifications.discord.channels.system_alerts, {embed})
end)

-- Send test notification (for setup)
RegisterCommand('testsupplynotif', function(source, args)
    if source == 0 then -- Console only
        local testEmbed = {
            title = "🧪 TEST NOTIFICATION",
            description = "Supply Chain notification system is working!",
            color = 3066993,
            fields = {
                {
                    name = "✅ Status",
                    value = "All systems operational",
                    inline = true
                },
                {
                    name = "⏰ Time",
                    value = os.date("%H:%M:%S"),
                    inline = true
                }
            },
            footer = {
                text = "Supply Chain AI • Test Message"
            },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }
        
        sendDiscordWebhook(Config.Notifications.discord.webhookURL, {testEmbed}, "Test notification from Supply Chain AI!")
        print("[NOTIFICATIONS] Test Discord webhook sent!")
    end
end)

-- Phone notification preferences
RegisterNetEvent('notifications:updatePreferences')
AddEventHandler('notifications:updatePreferences', function(preferences)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    -- Save preferences to database
    MySQL.Async.execute([[
        INSERT INTO supply_notification_preferences (citizenid, new_orders, emergency_alerts, market_changes, team_invites, achievements, stock_alerts)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            new_orders = VALUES(new_orders),
            emergency_alerts = VALUES(emergency_alerts),
            market_changes = VALUES(market_changes),
            team_invites = VALUES(team_invites),
            achievements = VALUES(achievements),
            stock_alerts = VALUES(stock_alerts)
    ]], {
        xPlayer.PlayerData.citizenid,
        preferences.new_orders and 1 or 0,
        preferences.emergency_alerts and 1 or 0,
        preferences.market_changes and 1 or 0,
        preferences.team_invites and 1 or 0,
        preferences.achievements and 1 or 0,
        preferences.stock_alerts and 1 or 0
    })
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = '📱 Notification Preferences Updated',
        description = 'Your mobile notification settings have been saved.',
        type = 'success',
        duration = 5000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })
end)

-- Achievement unlock notifications
local function sendAchievementNotification(citizenid, newTier, oldTier)
    local src = QBCore.Functions.GetPlayerByCitizenId(citizenid)
    if not src then return end
    
    local tierInfo = Config.AchievementVehicles.performanceTiers[newTier]
    
    -- Discord webhook notification
    if Config.Webhooks.achievements then
        local embed = {
            {
                title = "🏆 Achievement Unlocked!",
                description = string.format("Player achieved **%s** tier!", tierInfo.name),
                color = 65280, -- Green
                fields = {
                    {name = "Player", value = GetPlayerName(src), inline = true},
                    {name = "Previous Tier", value = oldTier, inline = true},
                    {name = "New Tier", value = newTier, inline = true},
                    {name = "Vehicle Benefits", value = tierInfo.description, inline = false}
                },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
        }
        
        PerformHttpRequest(Config.Webhooks.achievements, function() end, 'POST', 
            json.encode({username = "Achievement System", embeds = embed}), 
            {['Content-Type'] = 'application/json'})
    end
end

-- Get surplus level information for notifications
local function getSurplusLevelInfo(surplusLevel)
    local surplusLevels = {
        ["critical"] = {
            icon = "🚨",
            color = "red", 
            priority = 5,
            description = "Critical surplus - immediate action required"
        },
        ["high"] = {
            icon = "⚠️",
            color = "orange",
            priority = 4,
            description = "High surplus detected"
        },
        ["moderate"] = {
            icon = "ℹ️", 
            color = "yellow",
            priority = 3,
            description = "Moderate surplus levels"
        },
        ["low"] = {
            icon = "✅",
            color = "green",
            priority = 2,
            description = "Low surplus - within normal range"
        },
        ["normal"] = {
            icon = "📊",
            color = "blue",
            priority = 1,
            description = "Normal surplus levels"
        }
    }
    
    return surplusLevels[surplusLevel] or surplusLevels["normal"]
end

-- NPC surplus notifications
local function sendSurplusAlert(surplusLevel, ingredientCount)
    if Config.Webhooks.npc_system then
        local levelInfo = getSurplusLevelInfo(surplusLevel)
        
        local embed = {
            {
                title = levelInfo.icon .. " Warehouse Surplus Alert",
                description = string.format("**%s surplus** detected - NPC deliveries now available", levelInfo.name),
                color = surplusLevel == "critical_surplus" and 16711680 or 16776960, -- Red or Yellow
                fields = {
                    {name = "Surplus Level", value = levelInfo.name, inline = true},
                    {name = "Affected Items", value = tostring(ingredientCount), inline = true},
                    {name = "Action Required", value = "Warehouse workers can now dispatch NPC drivers", inline = false}
                },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
        }
        
        PerformHttpRequest(Config.Webhooks.npc_system, function() end, 'POST', 
            json.encode({username = "NPC Surplus System", embeds = embed}), 
            {['Content-Type'] = 'application/json'})
    end
end

-- Export notification functions
exports('sendAchievementNotification', sendAchievementNotification)
exports('sendSurplusAlert', sendSurplusAlert)

-- Initialize notifications system
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print("[NOTIFICATIONS] Mobile notification system initialized!")
        print("[NOTIFICATIONS] Discord webhooks: " .. (Config.Notifications.discord.enabled and "ENABLED" or "DISABLED"))
        print("[NOTIFICATIONS] Phone notifications: " .. (Config.Notifications.phone.enabled and "ENABLED" or "DISABLED"))
    end
end)