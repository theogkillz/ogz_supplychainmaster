-- EPIC DYNAMIC MARKET PRICING SYSTEM

local QBCore = exports['qb-core']:GetCoreObject()

-- Market state tracking
local marketData = {
    currentPrices = {},
    priceHistory = {},
    demandMetrics = {},
    activeEvents = {},
    lastUpdate = 0
}

-- Calculate stock level factor
local function calculateStockFactor(ingredient, currentStock)
    if not Config.MarketPricing.factors.stockLevel.enabled then
        return 1.0
    end
    
    -- Get max stock for this item
    local maxStock = Config.StockAlerts.maxStock.default
    if Config.StockAlerts.maxStock[ingredient] then
        maxStock = Config.StockAlerts.maxStock[ingredient]
    end
    
    local stockPercentage = (currentStock / maxStock) * 100
    local factor = Config.MarketPricing.factors.stockLevel
    
    if stockPercentage <= 5 then
        return factor.criticalMultiplier
    elseif stockPercentage <= 20 then
        return factor.lowMultiplier
    elseif stockPercentage <= 50 then
        return factor.moderateMultiplier
    else
        return factor.healthyMultiplier
    end
end

-- Calculate demand factor
local function calculateDemandFactor(ingredient)
    if not Config.MarketPricing.factors.demand.enabled then
        return 1.0
    end
    
    local hoursAgo = Config.MarketPricing.factors.demand.analysisWindow
    local startTime = os.date("%Y-%m-%d %H:%M:%S", os.time() - (hoursAgo * 3600))
    
    MySQL.Async.fetchScalar('SELECT COUNT(*) FROM supply_orders WHERE ingredient = ? AND created_at >= ? AND status != "denied"', 
        {ingredient, startTime}, function(orderCount)
        
        local demandLevel = "normal"
        if orderCount >= 10 then
            demandLevel = "high"
        elseif orderCount <= 2 then
            demandLevel = "low"
        end
        
        marketData.demandMetrics[ingredient] = {
            level = demandLevel,
            orderCount = orderCount,
            lastUpdated = os.time()
        }
    end)
    
    local demand = marketData.demandMetrics[ingredient]
    if not demand then return 1.0 end
    
    local factor = Config.MarketPricing.factors.demand
    if demand.level == "high" then
        return factor.highDemandMultiplier
    elseif demand.level == "low" then
        return factor.lowDemandMultiplier
    else
        return factor.normalDemandMultiplier
    end
end

-- Calculate player activity factor
local function calculatePlayerActivityFactor()
    if not Config.MarketPricing.factors.playerActivity.enabled then
        return 1.0
    end
    
    local playerCount = #GetPlayers()
    local factor = Config.MarketPricing.factors.playerActivity
    
    if playerCount >= factor.peakThreshold then
        return factor.peakMultiplier
    elseif playerCount >= factor.moderateThreshold then
        return factor.moderateMultiplier
    elseif playerCount >= factor.lowThreshold then
        return 1.0
    else
        return factor.lowMultiplier
    end
end

-- Calculate time of day factor
local function calculateTimeOfDayFactor()
    if not Config.MarketPricing.factors.timeOfDay.enabled then
        return 1.0
    end
    
    local currentHour = tonumber(os.date("%H"))
    local factor = Config.MarketPricing.factors.timeOfDay
    
    for _, hour in ipairs(factor.peakHours) do
        if currentHour == hour then
            return factor.peakMultiplier
        end
    end
    
    for _, hour in ipairs(factor.moderateHours) do
        if currentHour == hour then
            return factor.moderateMultiplier
        end
    end
    
    return factor.offPeakMultiplier
end

-- Calculate dynamic price for an ingredient
local function calculateDynamicPrice(ingredient, basePrice, currentStock)
    if not Config.MarketPricing.enabled then
        return basePrice
    end
    
    local factors = Config.MarketPricing.factors
    local stockFactor = calculateStockFactor(ingredient, currentStock)
    local demandFactor = calculateDemandFactor(ingredient)
    local activityFactor = calculatePlayerActivityFactor()
    local timeFactor = calculateTimeOfDayFactor()
    
    -- Weighted calculation
    local totalMultiplier = 1.0
    totalMultiplier = totalMultiplier + ((stockFactor - 1.0) * factors.stockLevel.weight)
    totalMultiplier = totalMultiplier + ((demandFactor - 1.0) * factors.demand.weight)
    totalMultiplier = totalMultiplier + ((activityFactor - 1.0) * factors.playerActivity.weight)
    totalMultiplier = totalMultiplier + ((timeFactor - 1.0) * factors.timeOfDay.weight)
    
    -- Apply limits
    local limits = Config.MarketPricing.limits
    totalMultiplier = math.max(limits.minMultiplier, math.min(limits.maxMultiplier, totalMultiplier))
    
    -- Apply gradual change limit
    local currentPrice = marketData.currentPrices[ingredient] or basePrice
    local targetPrice = basePrice * totalMultiplier
    local currentMultiplier = currentPrice / basePrice
    local maxChange = limits.maxChangePerUpdate
    
    if targetPrice > currentPrice then
        totalMultiplier = math.min(targetPrice / basePrice, currentMultiplier + maxChange)
    elseif targetPrice < currentPrice then
        totalMultiplier = math.max(targetPrice / basePrice, currentMultiplier - maxChange)
    end
    
    return math.floor(basePrice * totalMultiplier)
end

-- Check for special market events
local function checkMarketEvents()
    local events = Config.MarketPricing.events
    local currentTime = os.time()
    
    -- Clean up expired events
    for ingredient, event in pairs(marketData.activeEvents) do
        if currentTime > event.expires then
            marketData.activeEvents[ingredient] = nil
        end
    end
    
    -- Check for new shortage events
    if events.shortage.enabled then
        MySQL.Async.fetchAll([[
            SELECT ws.ingredient, ws.quantity, 
                   COALESCE(ms.max_stock, ?) as max_stock
            FROM supply_warehouse_stock ws
            LEFT JOIN supply_market_settings ms ON ws.ingredient = ms.ingredient
        ]], {Config.StockAlerts.maxStock.default}, function(results)
            
            for _, item in ipairs(results) do
                local stockPercentage = (item.quantity / item.max_stock) * 100
                
                if stockPercentage <= events.shortage.threshold then
                    if not marketData.activeEvents[item.ingredient] then
                        marketData.activeEvents[item.ingredient] = {
                            type = "shortage",
                            multiplier = events.shortage.multiplier,
                            expires = currentTime + events.shortage.duration,
                            startedAt = currentTime
                        }
                        
                        -- Notify all players of shortage event
                        broadcastMarketEvent("shortage", item.ingredient, stockPercentage)
                    end
                elseif stockPercentage >= events.surplus.threshold then
                    if not marketData.activeEvents[item.ingredient] then
                        marketData.activeEvents[item.ingredient] = {
                            type = "surplus",
                            multiplier = events.surplus.multiplier,
                            expires = currentTime + events.surplus.duration,
                            startedAt = currentTime
                        }
                        
                        -- Notify all players of surplus event
                        broadcastMarketEvent("surplus", item.ingredient, stockPercentage)
                    end
                end
            end
        end)
    end
end

-- Broadcast market events to all players
function broadcastMarketEvent(eventType, ingredient, stockPercentage)
    local itemNames = exports.ox_inventory:Items() or {}
    local itemLabel = itemNames[ingredient] and itemNames[ingredient].label or ingredient
    
    local title, description, alertType
    if eventType == "shortage" then
        title = "🚨 MARKET ALERT: SHORTAGE"
        description = string.format("**%s** shortage detected! (%.1f%% stock remaining)\nPrices increased significantly!", itemLabel, stockPercentage)
        alertType = "error"
    elseif eventType == "surplus" then
        title = "💰 MARKET ALERT: SURPLUS"
        description = string.format("**%s** surplus detected! (%.1f%% stock available)\nPrices reduced for quick sale!", itemLabel, stockPercentage)
        alertType = "success"
    end
    
    local players = QBCore.Functions.GetPlayers()
    for _, playerId in ipairs(players) do
        TriggerClientEvent('ox_lib:notify', playerId, {
            title = title,
            description = description,
            type = alertType,
            duration = 12000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
    end
end

-- Update all market prices
local function updateMarketPrices()
    MySQL.Async.fetchAll('SELECT ingredient, quantity FROM supply_warehouse_stock', {}, function(stockResults)
        if not stockResults then return end
        
        for _, stock in ipairs(stockResults) do
            local ingredient = stock.ingredient
            
            -- Get base price for this ingredient
            local basePrice = getBasePriceForIngredient(ingredient)
            if basePrice then
                local newPrice = calculateDynamicPrice(ingredient, basePrice, stock.quantity)
                
                -- Apply event multipliers
                local event = marketData.activeEvents[ingredient]
                if event then
                    newPrice = math.floor(newPrice * event.multiplier)
                end
                
                marketData.currentPrices[ingredient] = newPrice
                
                -- Store price history
                if not marketData.priceHistory[ingredient] then
                    marketData.priceHistory[ingredient] = {}
                end
                
                table.insert(marketData.priceHistory[ingredient], {
                    price = newPrice,
                    basePrice = basePrice,
                    multiplier = newPrice / basePrice,
                    timestamp = os.time()
                })
                
                -- Keep only last 24 hours of history
                local oneDayAgo = os.time() - 86400
                for i = #marketData.priceHistory[ingredient], 1, -1 do
                    if marketData.priceHistory[ingredient][i].timestamp < oneDayAgo then
                        table.remove(marketData.priceHistory[ingredient], i)
                    end
                end
            end
        end
        
        marketData.lastUpdate = os.time()
        
        -- Save market snapshot to database
        -- saveMarketSnapshot()
    end)
end

-- Get base price for an ingredient
function getBasePriceForIngredient(ingredient)
    -- Search through all restaurant configurations
    for restaurantJob, categories in pairs(Config.Items) do
        for category, items in pairs(categories) do
            if items[ingredient] then
                return items[ingredient].price
            end
        end
    end
    
    -- Check farming items
    if Config.ItemsFarming then
        for category, items in pairs(Config.ItemsFarming) do
            if type(items) == "table" and items[ingredient] then
                return items[ingredient].price
            end
        end
    end
    
    return nil
end

-- -- Save market snapshot to database
-- function saveMarketSnapshot()
--     for ingredient, price in pairs(marketData.currentPrices) do
--         MySQL.Async.execute([[
--             INSERT INTO supply_market_snapshots (id, ingredient, base_price, multiplier, final_price, stock_level, demand_level, player_count, created_at)
--             VALUES (?, ?, ?, ?, ?, ?)
--         ]], {
--             ingredient,
--             price,
--             getBasePriceForIngredient(ingredient) or 0,
--             price / (getBasePriceForIngredient(ingredient) or 1),
--             #GetPlayers(),
--             os.time()
--         })
--     end
-- end

-- Event handlers for market pricing system

-- Get current market prices
RegisterNetEvent('market:getCurrentPrices')
AddEventHandler('market:getCurrentPrices', function(ingredients)
    local src = source
    local prices = {}
    
    if ingredients then
        -- Get prices for specific ingredients
        for _, ingredient in ipairs(ingredients) do
            prices[ingredient] = marketData.currentPrices[ingredient] or getBasePriceForIngredient(ingredient)
        end
    else
        -- Get all current prices
        prices = marketData.currentPrices
    end
    
    TriggerClientEvent('market:receivePrices', src, prices)
end)

-- Get market overview
RegisterNetEvent('market:getOverview')
AddEventHandler('market:getOverview', function()
    local src = source
    
    local overview = {
        totalItems = 0,
        averageMultiplier = 0,
        activeEvents = {},
        topMovers = {},
        marketStatus = "normal"
    }
    
    local totalMultiplier = 0
    local itemCount = 0
    
    for ingredient, price in pairs(marketData.currentPrices) do
        local basePrice = getBasePriceForIngredient(ingredient)
        if basePrice then
            local multiplier = price / basePrice
            totalMultiplier = totalMultiplier + multiplier
            itemCount = itemCount + 1
            
            table.insert(overview.topMovers, {
                ingredient = ingredient,
                currentPrice = price,
                basePrice = basePrice,
                multiplier = multiplier,
                change = ((multiplier - 1) * 100)
            })
        end
    end
    
    if itemCount > 0 then
        overview.averageMultiplier = totalMultiplier / itemCount
        overview.totalItems = itemCount
    end
    
    -- Sort top movers by change percentage
    table.sort(overview.topMovers, function(a, b)
        return math.abs(a.change) > math.abs(b.change)
    end)
    
    -- Only keep top 10
    for i = #overview.topMovers, 11, -1 do
        table.remove(overview.topMovers, i)
    end
    
    -- Add active events
    for ingredient, event in pairs(marketData.activeEvents) do
        table.insert(overview.activeEvents, {
            ingredient = ingredient,
            type = event.type,
            multiplier = event.multiplier,
            timeRemaining = event.expires - os.time()
        })
    end
    
    -- Determine market status
    if overview.averageMultiplier > 1.3 then
        overview.marketStatus = "volatile_high"
    elseif overview.averageMultiplier < 0.9 then
        overview.marketStatus = "volatile_low"
    elseif #overview.activeEvents > 3 then
        overview.marketStatus = "volatile"
    end
    
    TriggerClientEvent('market:showOverview', src, overview)
end)

-- Get price history for specific ingredient
RegisterNetEvent('market:getPriceHistory')
AddEventHandler('market:getPriceHistory', function(ingredient, returnContext)
    local src = source
    
    MySQL.Async.fetchAll([[
        SELECT price, multiplier, timestamp, base_price 
        FROM supply_market_history 
        WHERE ingredient = ? 
        ORDER BY timestamp DESC 
        LIMIT 20
    ]], {ingredient}, function(results)
        
        local history = {}
        local currentTime = os.time() -- Server-side os.time() works fine
        
        if results then
            for _, record in ipairs(results) do
                -- Calculate time difference on server
                local timeAgo = currentTime - record.timestamp
                local timeText = ""
                
                if timeAgo < 3600 then -- Less than 1 hour
                    timeText = math.floor(timeAgo / 60) .. "m ago"
                elseif timeAgo < 86400 then -- Less than 1 day
                    timeText = math.floor(timeAgo / 3600) .. "h ago"
                else
                    timeText = math.floor(timeAgo / 86400) .. "d ago"
                end
                
                table.insert(history, {
                    price = record.price,
                    multiplier = record.multiplier,
                    timestamp = record.timestamp,
                    basePrice = record.base_price,
                    timeText = timeText -- Send calculated time to client
                })
            end
        end
        
        TriggerClientEvent('market:showPriceHistory', src, ingredient, history, returnContext or "warehouse")
    end)
end)

-- Initialize market pricing system
RegisterNetEvent('market:initialize')
AddEventHandler('market:initialize', function()
    print("[MARKET] Initializing dynamic pricing system...")
    
    if not Config.MarketPricing.enabled then
        print("[MARKET] Dynamic pricing is disabled in config")
        return
    end
    
    -- Initial price calculation
    updateMarketPrices()
    
    -- Start price update cycle
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(Config.MarketPricing.intervals.priceUpdate * 1000)
            updateMarketPrices()
            checkMarketEvents()
        end
    end)
    
    -- Start demand analysis cycle
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(Config.MarketPricing.intervals.demandAnalysis * 1000)
            -- Update demand metrics for all ingredients
            for ingredient, _ in pairs(marketData.currentPrices) do
                calculateDemandFactor(ingredient)
                Citizen.Wait(100)
            end
        end
    end)
    
    print("[MARKET] Dynamic pricing system initialized successfully!")
end)

-- Start the system when resource starts
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        Citizen.Wait(10000) -- Wait for other systems to load
        TriggerEvent('market:initialize')
    end
end)

-- Export functions for other scripts
exports('getCurrentPrice', function(ingredient)
    return marketData.currentPrices[ingredient] or getBasePriceForIngredient(ingredient)
end)

exports('getMarketMultiplier', function(ingredient)
    local currentPrice = marketData.currentPrices[ingredient]
    local basePrice = getBasePriceForIngredient(ingredient)
    if currentPrice and basePrice then
        return currentPrice / basePrice
    end
    return 1.0
end)