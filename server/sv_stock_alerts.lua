-- EPIC STOCK ALERT & PREDICTION SYSTEM

local QBCore = exports['qb-core']:GetCoreObject()
local restockSuggestions = {}
-- Active alerts tracking
local activeAlerts = {}
local lastAlertTime = {}
local stockPredictions = {}
local calculateTrend
local sendStockAlerts  
local getAlertIcon
local getAlertColor

-- Load LB-Phone integration if it exists
local LBPhone = _G.LBPhone or nil

-- Convert all config values to numbers once to prevent string comparison errors
local THRESHOLDS = {
    critical = tonumber(Config.StockAlerts.thresholds.critical),
    low = tonumber(Config.StockAlerts.thresholds.low),
    moderate = tonumber(Config.StockAlerts.thresholds.moderate),
    healthy = tonumber(Config.StockAlerts.thresholds.healthy)
}

local MAX_STOCK_DEFAULT = tonumber(Config.StockAlerts.maxStock.default)
local ALERT_COOLDOWN = tonumber(Config.StockAlerts.notifications.alertCooldown)
local MAX_ALERTS_PER_CHECK = tonumber(Config.StockAlerts.notifications.maxAlertsPerCheck)

-- Calculate stock level percentage
local function getStockPercentage(currentStock, itemName)
    local maxStock = MAX_STOCK_DEFAULT
    
    -- Check if item has custom max stock
    if Config.StockAlerts.maxStock[itemName] then
        maxStock = tonumber(Config.StockAlerts.maxStock[itemName])
    end
    
    return math.min(100, (currentStock / maxStock) * 100)
end

-- Get alert level based on stock percentage
local function getAlertLevel(percentage)
    if percentage <= THRESHOLDS.critical then
        return "critical"
    elseif percentage <= THRESHOLDS.low then
        return "low"
    elseif percentage <= THRESHOLDS.moderate then
        return "moderate"
    else
        return "healthy"
    end
end

-- Analyze usage patterns for demand prediction
local function analyzeUsagePatterns(itemName)
    local analysisWindow = Config.StockAlerts.prediction.analysisWindow
    local startDate = os.date("%Y-%m-%d", os.time() - (analysisWindow * 24 * 3600))
    
    MySQL.Async.fetchAll([[
        SELECT 
            DATE(created_at) as order_date,
            SUM(quantity) as daily_usage,
            COUNT(*) as order_count
        FROM supply_orders 
        WHERE ingredient = ? 
        AND created_at >= ? 
        AND status = 'completed'
        GROUP BY DATE(created_at)
        ORDER BY order_date DESC
    ]], {itemName, startDate}, function(results)
        
        if not results or #results < Config.StockAlerts.prediction.minDataPoints then
            return
        end
        
        -- Calculate usage statistics
        local totalUsage = 0
        local usageByDay = {}
        local ordersByDay = {}
        
        for _, row in ipairs(results) do
            totalUsage = totalUsage + row.daily_usage
            table.insert(usageByDay, row.daily_usage)
            table.insert(ordersByDay, row.order_count)
        end
        
        local avgDailyUsage = totalUsage / #results
        local avgOrdersPerDay = (#ordersByDay > 0) and (table.concat(ordersByDay, "+") / #ordersByDay) or 0
        
        -- Calculate variance for confidence
        local variance = 0
        for _, usage in ipairs(usageByDay) do
            variance = variance + (usage - avgDailyUsage) ^ 2
        end
        variance = variance / #usageByDay
        local standardDeviation = math.sqrt(variance)
        
        -- Calculate confidence (lower variance = higher confidence)
        local confidence = math.max(0.1, 1 - (standardDeviation / avgDailyUsage))
        
        -- Predict future usage
        local forecastDays = Config.StockAlerts.prediction.forecastDays
        local predictedUsage = avgDailyUsage * forecastDays
        
        -- Store prediction
        stockPredictions[itemName] = {
            avgDailyUsage = avgDailyUsage,
            predictedUsage = predictedUsage,
            confidence = confidence,
            trend = calculateTrend(usageByDay),
            lastUpdated = os.time()
        }
    end)
end

-- Calculate trend (increasing, decreasing, stable)
calculateTrend = function(usageData)
    if #usageData < 3 then return "stable" end
    
    local recent = {}
    local older = {}
    local half = math.floor(#usageData / 2)
    
    for i = 1, half do
        table.insert(older, usageData[i])
    end
    
    for i = half + 1, #usageData do
        table.insert(recent, usageData[i])
    end
    
    local recentAvg = 0
    local olderAvg = 0
    
    for _, val in ipairs(recent) do recentAvg = recentAvg + val end
    for _, val in ipairs(older) do olderAvg = olderAvg + val end
    
    recentAvg = recentAvg / #recent
    olderAvg = olderAvg / #older
    
    local change = (recentAvg - olderAvg) / olderAvg
    
    if change > 0.15 then
        return "increasing"
    elseif change < -0.15 then
        return "decreasing"
    else
        return "stable"
    end
end

-- Send combined stock alert email to warehouse workers
local function sendWarehouseStockEmail(playerId, alerts)
    if not LBPhone then return end
    
    local xPlayer = QBCore.Functions.GetPlayer(playerId)
    if not xPlayer then return end
    
    -- REMOVED: We don't need to get phone number anymore
    -- LBPhone integration will handle that internally
    
    local itemNames = exports.ox_inventory:Items() or {}
    
    -- Group alerts by level
    local criticalAlerts = {}
    local lowAlerts = {}
    local moderateAlerts = {}
    
    for _, alert in ipairs(alerts) do
        if alert.alertLevel == "critical" then
            table.insert(criticalAlerts, alert)
        elseif alert.alertLevel == "low" then
            table.insert(lowAlerts, alert)
        else
            table.insert(moderateAlerts, alert)
        end
    end
    
    -- Build email content
    local emailContent = "<h2>📦 Warehouse Stock Alert Summary</h2><br>"
    
    -- Critical alerts
    if #criticalAlerts > 0 then
        emailContent = emailContent .. "<h3 style='color: red;'>🚨 CRITICAL ALERTS</h3>"
        for _, alert in ipairs(criticalAlerts) do
            local itemLabel = itemNames[alert.itemName] and itemNames[alert.itemName].label or alert.itemName
            emailContent = emailContent .. string.format(
                "<b>• %s:</b> <span style='color: red;'>%d units (%.1f%%)</span>",
                itemLabel, alert.currentStock, alert.percentage
            )
            if alert.daysUntilStockout then
                emailContent = emailContent .. string.format(" - <b>%.1f days until stockout!</b>", alert.daysUntilStockout)
            end
            emailContent = emailContent .. "<br>"
        end
        emailContent = emailContent .. "<br>"
    end
    
    -- Low alerts
    if #lowAlerts > 0 then
        emailContent = emailContent .. "<h3 style='color: orange;'>⚠️ LOW STOCK WARNINGS</h3>"
        for _, alert in ipairs(lowAlerts) do
            local itemLabel = itemNames[alert.itemName] and itemNames[alert.itemName].label or alert.itemName
            emailContent = emailContent .. string.format(
                "<b>• %s:</b> %d units (%.1f%%)",
                itemLabel, alert.currentStock, alert.percentage
            )
            if alert.prediction and alert.prediction.trend ~= "stable" then
                emailContent = emailContent .. string.format(" - Trend: %s", alert.prediction.trend)
            end
            emailContent = emailContent .. "<br>"
        end
        emailContent = emailContent .. "<br>"
    end
    
    -- Moderate alerts
    if #moderateAlerts > 0 then
        emailContent = emailContent .. "<h3 style='color: blue;'>📊 MODERATE STOCK LEVELS</h3>"
        for _, alert in ipairs(moderateAlerts) do
            local itemLabel = itemNames[alert.itemName] and itemNames[alert.itemName].label or alert.itemName
            emailContent = emailContent .. string.format(
                "<b>• %s:</b> %d units (%.1f%%)<br>",
                itemLabel, alert.currentStock, alert.percentage
            )
        end
    end
    
    emailContent = emailContent .. "<br><i>Check the warehouse Stock Alerts menu for detailed analysis and restock suggestions.</i>"
    
    -- Determine urgency for subject
    local urgencyLevel = #criticalAlerts > 0 and "🚨 CRITICAL" or (#lowAlerts > 0 and "⚠️ LOW" or "📊 MODERATE")
    
    -- Send the email - PASS PLAYER ID instead of phone number
    local emailData = {
        level = #criticalAlerts > 0 and "critical" or (#lowAlerts > 0 and "low" or "moderate"),
        itemLabel = string.format("%d items need attention", #alerts),
        percentage = 0, -- Not used for combined emails
        currentStock = #alerts,
        analysis = emailContent,
        recommendedOrder = 0
    }
    
    LBPhone.SendStockAlert(playerId, emailData)  -- CHANGED: Pass playerId instead of phoneNumber
end

-- Generate stock alerts
local function checkStockLevels()
    MySQL.Async.fetchAll('SELECT ingredient, SUM(quantity) as total_stock FROM supply_warehouse_stock GROUP BY ingredient', {}, function(stockResults)
        if not stockResults then return end
        
        local alerts = {}
        local currentTime = os.time()
        
        for _, stock in ipairs(stockResults) do
            local itemName = stock.ingredient
            local currentStock = stock.total_stock
            local percentage = getStockPercentage(currentStock, itemName)
            local alertLevel = getAlertLevel(percentage)
            
            -- Only alert for non-healthy stock levels
            if alertLevel ~= "healthy" then
                local alertKey = itemName .. "_" .. alertLevel
                local lastAlert = lastAlertTime[alertKey] or 0
                
                -- Check cooldown
                if currentTime - lastAlert > ALERT_COOLDOWN then
                    -- Get prediction data
                    local prediction = stockPredictions[itemName]
                    local daysUntilStockout = prediction and (currentStock / prediction.avgDailyUsage) or nil
                    
                    table.insert(alerts, {
                        itemName = itemName,
                        currentStock = currentStock,
                        percentage = percentage,
                        alertLevel = alertLevel,
                        prediction = prediction,
                        daysUntilStockout = daysUntilStockout,
                        timestamp = currentTime
                    })
                    
                    lastAlertTime[alertKey] = currentTime
                    
                    -- Limit alerts per check
                    if #alerts >= MAX_ALERTS_PER_CHECK then
                        break
                    end
                end
            end
        end
        
        -- Send alerts to relevant players
        if #alerts > 0 then
            sendStockAlerts(alerts)
        end
    end)
end

-- Send alerts to restaurant owners and warehouse workers
sendStockAlerts = function(alerts)
    local players = QBCore.Functions.GetPlayers()
    local itemNames = exports.ox_inventory:Items() or {}
    local warehouseAlerts = {} -- Collect alerts for warehouse workers
    
    for _, playerId in ipairs(players) do
        local xPlayer = QBCore.Functions.GetPlayer(playerId)
        if not xPlayer then goto continue end
        
        local playerJob = xPlayer.PlayerData.job.name
        local isBoss = xPlayer.PlayerData.job.isboss
        
        -- Check if player is a warehouse worker (Hurst job)
        local isWarehouseWorker = false
        for _, job in ipairs(Config.Jobs.warehouse) do
            if playerJob == job then
                isWarehouseWorker = true
                break
            end
        end
        
        -- Send to restaurant owners/bosses (existing functionality)
        if isBoss and not isWarehouseWorker then
            for _, alert in ipairs(alerts) do
                -- Check if this item is relevant to their restaurant
                local isRelevant = false
                for restaurantId, restaurant in pairs(Config.Restaurants) do
                    if restaurant.job == playerJob then
                        -- Check if item is in their menu
                        local restaurantItems = Config.Items[playerJob] or {}
                        for category, categoryItems in pairs(restaurantItems) do
                            if categoryItems[alert.itemName] then
                                isRelevant = true
                                break
                            end
                        end
                        break
                    end
                end
                
                if isRelevant then
                    local itemLabel = itemNames[alert.itemName] and itemNames[alert.itemName].label or alert.itemName
                    local alertIcon = getAlertIcon(alert.alertLevel)
                    local alertColor = getAlertColor(alert.alertLevel)
                    
                    local description = string.format(
                        "📦 **%s**: %d units (%.1f%%)\n%s%s",
                        itemLabel,
                        alert.currentStock,
                        alert.percentage,
                        alert.daysUntilStockout and string.format("⏰ **%.1f days** until stockout\n", alert.daysUntilStockout) or "",
                        alert.prediction and string.format("📈 Trend: **%s** (%.0f%% confidence)", alert.prediction.trend, alert.prediction.confidence * 100) or ""
                    )
                    
                    TriggerClientEvent('ox_lib:notify', playerId, {
                        title = alertIcon .. ' Stock Alert',
                        description = description,
                        type = alertColor,
                        duration = 12000,
                        position = Config.UI.notificationPosition,
                        markdown = Config.UI.enableMarkdown
                    })
                end
            end
        end
        
        -- Send emails to warehouse workers
        if isWarehouseWorker and LBPhone and Config.Notifications.phone.enabled and Config.Notifications.phone.types.stock_alerts then
            -- Collect this player for warehouse email
            if not warehouseAlerts[playerId] then
                warehouseAlerts[playerId] = true
            end
        end
        
        ::continue::
    end
    
    -- Send combined email to all warehouse workers
    for playerId, _ in pairs(warehouseAlerts) do
        sendWarehouseStockEmail(playerId, alerts)
    end
end

-- Get alert visual indicators
getAlertIcon = function(alertLevel)
    local icons = {
        critical = "🚨",
        low = "⚠️", 
        moderate = "ℹ️",
        healthy = "✅"
    }
    return icons[alertLevel] or "📦"
end

getAlertColor = function(alertLevel)
    local colors = {
        critical = "error",
        low = "warning",
        moderate = "info", 
        healthy = "success"
    }
    return colors[alertLevel] or "info"
end

-- Auto-generate restock suggestions
local function generateRestockSuggestions()
    local moderateThreshold = tonumber(Config.StockAlerts.thresholds.moderate)
    local criticalThreshold = tonumber(Config.StockAlerts.thresholds.critical)
    MySQL.Async.fetchAll([[
        SELECT 
            ws.ingredient,
            ws.quantity as current_stock,
            COALESCE(recent_orders.avg_daily_usage, 0) as avg_daily_usage,
            COALESCE(recent_orders.total_recent_orders, 0) as recent_demand
        FROM supply_warehouse_stock ws
        LEFT JOIN (
            SELECT 
                ingredient,
                AVG(daily_usage) as avg_daily_usage,
                SUM(daily_usage) as total_recent_orders
            FROM (
                SELECT 
                    ingredient,
                    DATE(created_at) as order_date,
                    SUM(quantity) as daily_usage
                FROM supply_orders 
                WHERE created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
                AND status = 'completed'
                GROUP BY ingredient, DATE(created_at)
            ) daily_stats
            GROUP BY ingredient
        ) recent_orders ON ws.ingredient = recent_orders.ingredient
    ]], {}, function(results)
        
        if not results then return end
        
        local suggestions = {}
        
        for _, item in ipairs(results) do
            local currentStock = tonumber(item.current_stock) or 0
            local dailyUsage = tonumber(item.avg_daily_usage) or 0
            local percentage = getStockPercentage(currentStock, item.ingredient)
            
            if percentage <= moderateThreshold and dailyUsage > 0 then
                local daysOfStock = currentStock / dailyUsage
                local targetDays = 14 -- Target 2 weeks of stock
                local suggestedOrder = math.max(0, math.ceil((targetDays - daysOfStock) * dailyUsage))
                
                if suggestedOrder > 0 then
                    table.insert(suggestions, {
                        ingredient = item.ingredient,
                        currentStock = currentStock,
                        daysOfStock = daysOfStock,
                        suggestedOrder = suggestedOrder,
                        dailyUsage = dailyUsage,
                        priority = percentage <= criticalThreshold and "high" or "normal"
                    })
                end
            end
        end
        
        -- Sort by priority and days of stock remaining
        table.sort(suggestions, function(a, b)
            if a.priority ~= b.priority then
                return a.priority == "high"
            end
            return a.daysOfStock < b.daysOfStock
        end)
        
        -- Store suggestions for retrieval
        restockSuggestions = suggestions
    end)
end

-- Event handlers for stock alerts system

    -- Get stock overview for dashboard
RegisterNetEvent('stockalerts:getOverview')
AddEventHandler('stockalerts:getOverview', function()
    local src = source
    
    MySQL.Async.fetchAll([[
        SELECT 
            ws.ingredient,
            ws.quantity as current_stock,
            COALESCE(usage_stats.avg_daily_usage, 0) as avg_daily_usage,
            COALESCE(usage_stats.trend, 'stable') as trend
        FROM supply_warehouse_stock ws
        LEFT JOIN (
            SELECT 
                ingredient,
                AVG(daily_usage) as avg_daily_usage,
                'stable' as trend
            FROM (
                SELECT 
                    ingredient,
                    DATE(created_at) as order_date,
                    SUM(quantity) as daily_usage
                FROM supply_orders 
                WHERE created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
                AND status = 'completed'
                GROUP BY ingredient, DATE(created_at)
            ) daily_stats
            GROUP BY ingredient
        ) usage_stats ON ws.ingredient = usage_stats.ingredient
        ORDER BY ws.quantity ASC
    ]], {}, function(results)
        
        local stockOverview = {}
        local itemNames = exports.ox_inventory:Items() or {}
        
        for _, item in ipairs(results) do
        -- Convert database strings to numbers
        local currentStock = tonumber(item.current_stock) or 0
        local avgDailyUsage = tonumber(item.avg_daily_usage) or 0
        
        local percentage = getStockPercentage(currentStock, item.ingredient)
        local alertLevel = getAlertLevel(percentage)
        local prediction = stockPredictions[item.ingredient]
        
        table.insert(stockOverview, {
            ingredient = item.ingredient,
            label = itemNames[item.ingredient] and itemNames[item.ingredient].label or item.ingredient,
            currentStock = currentStock,
            percentage = percentage,
            alertLevel = alertLevel,
            dailyUsage = avgDailyUsage,
            daysRemaining = avgDailyUsage > 0 and (currentStock / avgDailyUsage) or nil,
            trend = prediction and prediction.trend or "unknown",
            confidence = prediction and prediction.confidence or 0
        })
    end
        
        TriggerClientEvent('stockalerts:showOverview', src, stockOverview)
    end)
end)
        

-- Get restock suggestions
RegisterNetEvent('stockalerts:getSuggestions')
AddEventHandler('stockalerts:getSuggestions', function()
    local src = source
    generateRestockSuggestions()
    
    Citizen.Wait(1000) -- Wait for suggestions to generate
    
    TriggerClientEvent('stockalerts:showSuggestions', src, restockSuggestions or {})
end)

-- Initialize stock alerts system
RegisterNetEvent('stockalerts:initialize')
AddEventHandler('stockalerts:initialize', function()
    print("[STOCK ALERTS] Initializing stock alert system...")
    
    -- Initial analysis of all items
    MySQL.Async.fetchAll('SELECT DISTINCT ingredient FROM supply_warehouse_stock', {}, function(results)
        if results then
            for _, item in ipairs(results) do
                analyzeUsagePatterns(item.ingredient)
                Citizen.Wait(100) -- Prevent overwhelming the database
            end
        end
    end)
    
    -- Start periodic checks
    Citizen.CreateThread(function()
        while true do
            checkStockLevels()
            generateRestockSuggestions()
            Citizen.Wait(Config.StockAlerts.notifications.checkInterval * 1000)
        end
    end)
    
    -- Update predictions periodically
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(3600000) -- Every hour
            MySQL.Async.fetchAll('SELECT DISTINCT ingredient FROM supply_warehouse_stock', {}, function(results)
                if results then
                    for _, item in ipairs(results) do
                        analyzeUsagePatterns(item.ingredient)
                        Citizen.Wait(1000)
                    end
                end
            end)
        end
    end)
    
    print("[STOCK ALERTS] Stock alert system initialized successfully!")
end)

-- Start the system when resource starts
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        Citizen.Wait(5000) -- Wait for other systems to load
        TriggerEvent('stockalerts:initialize')
    end
end)

-- Get Critical Alerts Only
RegisterNetEvent('stockalerts:getCriticalAlerts')
AddEventHandler('stockalerts:getCriticalAlerts', function()
    local src = source
    
    MySQL.Async.fetchAll([[
        SELECT ws.ingredient, ws.quantity,
               COALESCE(ms.max_stock, ?) as max_stock
        FROM supply_warehouse_stock ws
        LEFT JOIN supply_market_settings ms ON ws.ingredient = ms.ingredient
        WHERE (ws.quantity / COALESCE(ms.max_stock, ?)) * 100 <= ?
        ORDER BY (ws.quantity / COALESCE(ms.max_stock, ?)) * 100 ASC
    ]], {
        tonumber(Config.StockAlerts.maxStock.default),
        tonumber(Config.StockAlerts.maxStock.default),
        tonumber(Config.StockAlerts.thresholds.critical),
        tonumber(Config.StockAlerts.maxStock.default)
    }, function(results)
        local criticalAlerts = {}
        local itemNames = exports.ox_inventory:Items() or {}
        
        for _, item in ipairs(results or {}) do
            local percentage = (item.quantity / item.max_stock) * 100
            table.insert(criticalAlerts, {
                ingredient = item.ingredient,
                label = itemNames[item.ingredient] and itemNames[item.ingredient].label or item.ingredient,
                currentStock = item.quantity,
                percentage = percentage,
                alertLevel = "critical"
            })
        end
        
        TriggerClientEvent('stockalerts:showOverview', src, criticalAlerts)
    end)
end)

-- Get Usage Trends
RegisterNetEvent('stockalerts:getUsageTrends')
AddEventHandler('stockalerts:getUsageTrends', function()
    local src = source
    
    MySQL.Async.fetchAll([[
        SELECT 
            ingredient,
            AVG(daily_usage) as avg_usage,
            MAX(daily_usage) as peak_usage,
            MIN(daily_usage) as min_usage,
            COUNT(*) as data_points
        FROM (
            SELECT 
                ingredient,
                DATE(created_at) as usage_date,
                SUM(quantity) as daily_usage
            FROM supply_orders 
            WHERE created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
            AND status = 'completed'
            GROUP BY ingredient, DATE(created_at)
        ) daily_stats
        GROUP BY ingredient
        HAVING COUNT(*) >= 5
        ORDER BY avg_usage DESC
    ]], {}, function(results)
        local trends = {}
        local itemNames = exports.ox_inventory:Items() or {}
        
        for _, item in ipairs(results or {}) do
            table.insert(trends, {
                ingredient = item.ingredient,
                label = itemNames[item.ingredient] and itemNames[item.ingredient].label or item.ingredient,
                avgUsage = item.avg_usage,
                peakUsage = item.peak_usage,
                minUsage = item.min_usage,
                dataPoints = item.data_points,
                trend = item.peak_usage > item.avg_usage * 1.2 and "increasing" or 
                       item.min_usage < item.avg_usage * 0.8 and "decreasing" or "stable"
            })
        end
        
        TriggerClientEvent('stockalerts:showUsageTrends', src, trends)
    end)
end)