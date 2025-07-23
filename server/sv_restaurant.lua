local QBCore = exports['qb-core']:GetCoreObject()

-- Generate a simple unique ID
local function generateOrderGroupId()
    return "order_" .. os.time() .. "_" .. math.random(1000, 9999)
end

-- Calculate dynamic price multiplier
local function getPriceMultiplier()
    local playerCount = #GetPlayers()
    local baseMultiplier = 1.0
    if Config.DynamicPricing and Config.DynamicPricing.enabled then
        if playerCount > Config.DynamicPricing.peakThreshold then
            baseMultiplier = baseMultiplier + 0.2
        elseif playerCount < Config.DynamicPricing.lowThreshold then
            baseMultiplier = baseMultiplier - 0.1
        end
        return math.max(Config.DynamicPricing.minMultiplier, math.min(Config.DynamicPricing.maxMultiplier, baseMultiplier))
    end
    return baseMultiplier
end

-- Handle Order Submission
RegisterNetEvent('restaurant:orderIngredients')
AddEventHandler('restaurant:orderIngredients', function(orderItems, restaurantId)
    local playerId = source
    local xPlayer = QBCore.Functions.GetPlayer(playerId)
    
    if not xPlayer then
        print("[ERROR] Player not found:", playerId)
        return
    end
    
    if not Config.Restaurants[restaurantId] then
        TriggerClientEvent('ox_lib:notify', playerId, {
            title = 'Order Error',
            description = 'Invalid restaurant ID.',
            type = 'error',
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    local restaurantJob = Config.Restaurants[restaurantId] and Config.Restaurants[restaurantId].job
    if not restaurantJob then
        TriggerClientEvent('ox_lib:notify', playerId, {
            title = 'Order Error',
            description = 'Invalid restaurant configuration.',
            type = 'error',
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end

    local restaurantItems = Config.Items[restaurantJob] or {}
    local totalCost = 0
    local orderGroupId = generateOrderGroupId()
    local queries = {}
    local priceMultiplier = getPriceMultiplier()

    -- Validate all items first
    for _, orderItem in ipairs(orderItems) do
        local ingredient = orderItem.ingredient:lower()
        local quantity = tonumber(orderItem.quantity)
        
        if not quantity or quantity <= 0 then
            TriggerClientEvent('ox_lib:notify', playerId, {
                title = 'Order Error',
                description = 'Invalid quantity for ' .. orderItem.label .. '.',
                type = 'error',
                duration = 10000,
                position = Config.UI.notificationPosition,
                markdown = Config.UI.enableMarkdown
            })
            return
        end
        
        -- Check nested structure (Meats, Vegetables, Fruits)
        local item = nil
        for category, categoryItems in pairs(restaurantItems) do
            if categoryItems[ingredient] then
                item = categoryItems[ingredient]
                break
            end
        end
        
        if not item then
            TriggerClientEvent('ox_lib:notify', playerId, {
                title = 'Order Error',
                description = 'Ingredient not found: ' .. orderItem.label,
                type = 'error',
                duration = 10000,
                position = Config.UI.notificationPosition,
                markdown = Config.UI.enableMarkdown
            })
            return
        end
        
        local dynamicPrice = math.floor((item.price or 0) * priceMultiplier)
        totalCost = totalCost + (dynamicPrice * quantity)
    end

    -- Check if player has enough money
    if xPlayer.PlayerData.money.bank < totalCost then
        TriggerClientEvent('ox_lib:notify', playerId, {
            title = 'Insufficient Funds',
            description = 'Not enough money in bank. Need $' .. totalCost,
            type = 'error',
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end

    -- Process each item in the order
    for _, orderItem in ipairs(orderItems) do
        local ingredient = orderItem.ingredient:lower()
        local quantity = tonumber(orderItem.quantity)
        
        -- Find the item again (we already validated it exists)
        local item = nil
        for category, categoryItems in pairs(restaurantItems) do
            if categoryItems[ingredient] then
                item = categoryItems[ingredient]
                break
            end
        end

        if not item or not item.price then
            TriggerClientEvent('ox_lib:notify', playerId, {
                title = 'Order Error',
                description = 'Ingredient not found: ' .. orderItem.label,
                type = 'error',
                duration = 10000,
                position = Config.UI.notificationPosition,
                markdown = Config.UI.enableMarkdown
            })
            return
        end

local dynamicPrice = math.floor(item.price * priceMultiplier)
        local itemCost = dynamicPrice * quantity
        
        table.insert(queries, {
            query = 'INSERT INTO supply_orders (owner_id, ingredient, quantity, status, restaurant_id, total_cost, order_group_id) VALUES (?, ?, ?, ?, ?, ?, ?)',
            values = { playerId, ingredient, quantity, 'pending', restaurantId, itemCost, orderGroupId }
        })
    end

    -- Remove money and execute queries
    xPlayer.Functions.RemoveMoney('bank', totalCost, "Ordered ingredients")
    
    MySQL.Async.transaction(queries, function(success)
        if success then
            local itemList = {}
            for _, orderItem in ipairs(orderItems) do
                table.insert(itemList, orderItem.quantity .. " **" .. orderItem.label .. "**")
            end
            
            local priceChangeText = ""
            if priceMultiplier ~= 1.0 then
                priceChangeText = " (**" .. math.floor((priceMultiplier - 1) * 100) .. "%** price adjustment)"
            end
            
            TriggerClientEvent('ox_lib:notify', playerId, {
                title = 'Order Submitted',
                description = 'Ordered ' .. table.concat(itemList, ", ") .. ' for $' .. totalCost .. priceChangeText,
                type = 'success',
                duration = 10000,
                position = Config.UI.notificationPosition,
                markdown = Config.UI.enableMarkdown
            })
        else
            xPlayer.Functions.AddMoney('bank', totalCost, "Order failed - refund")
            TriggerClientEvent('ox_lib:notify', playerId, {
                title = 'Order Error',
                description = 'Error processing order. Money refunded.',
                type = 'error',
                duration = 10000,
                position = Config.UI.notificationPosition,
                markdown = Config.UI.enableMarkdown
            })
        end
    end)
end)

-- Request Restaurant Stock
RegisterNetEvent("restaurant:requestStock")
AddEventHandler("restaurant:requestStock", function(restaurantId)
    local src = source
    
    -- Handle both number and string restaurant IDs
    local actualRestaurantId = restaurantId
    if not Config.Restaurants[restaurantId] then
        actualRestaurantId = tostring(restaurantId)
        if not Config.Restaurants[actualRestaurantId] then
            actualRestaurantId = tonumber(restaurantId)
        end
    end
    
    if not Config.Restaurants[actualRestaurantId] then
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Error",
            description = "Invalid restaurant ID.",
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end

    local stashId = "restaurant_stock_" .. tostring(actualRestaurantId)
    
    -- Register/create the stash before client tries to open it
    exports.ox_inventory:RegisterStash(stashId, "Restaurant Stock", 50, 100000, false)
    
    TriggerClientEvent("restaurant:showResturantStock", src, actualRestaurantId)
end)

-- Withdraw Stock
RegisterNetEvent('restaurant:withdrawStock')
AddEventHandler('restaurant:withdrawStock', function(restaurantId, ingredient, amount)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    
    if not player then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'Player not found.',
            type = 'error',
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    ingredient = ingredient:lower()
    local restaurantJob = Config.Restaurants[restaurantId].job
    
    -- Find item in nested structure
    local itemData = nil
    if Config.Items[restaurantJob] then
        for category, categoryItems in pairs(Config.Items[restaurantJob]) do
            if categoryItems[ingredient] then
                itemData = categoryItems[ingredient]
                break
            end
        end
    end
    
    if itemData then
        local amountNum = tonumber(amount)
        if amountNum and amountNum > 0 then
            local stashId = "restaurant_stock_" .. tostring(restaurantId)
            local stashItems = exports.ox_inventory:GetInventoryItems(stashId)
            local currentAmount = 0
            
            for _, item in pairs(stashItems) do
                if item.name == ingredient then
                    currentAmount = item.count
                    break
                end
            end
            
            if currentAmount >= amountNum then
                exports.ox_inventory:RemoveItem(stashId, ingredient, amountNum)
                player.Functions.AddItem(ingredient, amountNum)
                TriggerClientEvent('ox_lib:notify', src, {
                    title = 'Stock Withdrawn',
                    description = 'Withdrawn ' .. amountNum .. ' of ' .. itemData.label,
                    type = 'success',
                    duration = 10000,
                    position = Config.UI.notificationPosition,
                    markdown = Config.UI.enableMarkdown
                })
            else
                TriggerClientEvent('ox_lib:notify', src, {
                    title = 'Error',
                    description = 'Not enough ' .. itemData.label .. ' in stock.',
                    type = 'error',
                    duration = 10000,
                    position = Config.UI.notificationPosition,
                    markdown = Config.UI.enableMarkdown
                })
            end
        else
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Error',
                description = 'Invalid amount.',
                type = 'error',
                duration = 10000,
                position = Config.UI.notificationPosition,
                markdown = Config.UI.enableMarkdown
            })
        end
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'Item not found: ' .. ingredient,
            type = 'error',
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
    end
end)

-- Get Restaurant Stock Alerts
RegisterNetEvent('restaurant:getStockAlerts')
AddEventHandler('restaurant:getStockAlerts', function(restaurantId)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    local restaurantJob = Config.Restaurants[restaurantId] and Config.Restaurants[restaurantId].job
    if not restaurantJob then return end
    
    -- Get restaurant's ingredients from config
    local restaurantItems = Config.Items[restaurantJob] or {}
    local alerts = {}
    
    for category, categoryItems in pairs(restaurantItems) do
        for ingredient, itemData in pairs(categoryItems) do
            -- Get warehouse stock
            MySQL.Async.fetchAll('SELECT quantity FROM supply_warehouse_stock WHERE ingredient = ?', {ingredient}, function(warehouseResult)
                local warehouseStock = (warehouseResult and warehouseResult[1]) and warehouseResult[1].quantity or 0
                
                -- Get restaurant stock
                local stashId = "restaurant_stock_" .. tostring(restaurantId)
                local restaurantStock = 0
                local stashItems = exports.ox_inventory:GetInventoryItems(stashId)
                if stashItems then
                    for _, item in pairs(stashItems) do
                        if item.name == ingredient then
                            restaurantStock = item.count or 0
                            break
                        end
                    end
                end
                
                -- Check if alert needed
                local maxStock = Config.StockAlerts and Config.StockAlerts.maxStock.default or 500
                local percentage = (warehouseStock / maxStock) * 100
                
                if percentage <= (Config.StockAlerts and Config.StockAlerts.thresholds.moderate or 50) then
                    local alertLevel = "moderate"
                    if percentage <= (Config.StockAlerts and Config.StockAlerts.thresholds.critical or 5) then
                        alertLevel = "critical"
                    elseif percentage <= (Config.StockAlerts and Config.StockAlerts.thresholds.low or 20) then
                        alertLevel = "low"
                    end
                    
                    local itemNames = exports.ox_inventory:Items() or {}
                    local itemLabel = itemNames[ingredient] and itemNames[ingredient].label or itemData.label or ingredient
                    
                    table.insert(alerts, {
                        ingredient = ingredient,
                        itemLabel = itemLabel,
                        warehouseStock = warehouseStock,
                        restaurantStock = restaurantStock,
                        percentage = percentage,
                        alertLevel = alertLevel,
                        price = itemData.price,
                        suggestedOrder = math.max(50, math.ceil((maxStock * 0.8) - warehouseStock)),
                        estimatedCost = math.max(50, math.ceil((maxStock * 0.8) - warehouseStock)) * itemData.price
                    })
                end
            end)
        end
    end
    
    -- Wait a bit for all queries to complete
    Citizen.Wait(1000)
    TriggerClientEvent('restaurant:showStockAlerts', src, alerts, restaurantId)
end)

-- Quick Order from Alerts
RegisterNetEvent('restaurant:quickOrder')
AddEventHandler('restaurant:quickOrder', function(restaurantId, ingredient, quantity)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    -- Find item data
    local restaurantJob = Config.Restaurants[restaurantId] and Config.Restaurants[restaurantId].job
    if not restaurantJob then return end
    
    local itemData = nil
    local restaurantItems = Config.Items[restaurantJob] or {}
    for category, categoryItems in pairs(restaurantItems) do
        if categoryItems[ingredient] then
            itemData = categoryItems[ingredient]
            break
        end
    end
    
    if not itemData then return end
    
    local totalCost = itemData.price * quantity
    
    -- Check money and process order
    if xPlayer.PlayerData.money.bank >= totalCost then
        xPlayer.Functions.RemoveMoney('bank', totalCost, "Quick order from alerts")
        
        local orderGroupId = "quick_" .. os.time() .. "_" .. math.random(1000, 9999)
        
        MySQL.Async.execute([[
            INSERT INTO supply_orders (owner_id, ingredient, quantity, status, restaurant_id, total_cost, order_group_id)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ]], {src, ingredient, quantity, 'pending', restaurantId, totalCost, orderGroupId}, function(success)
            if success then
                local itemNames = exports.ox_inventory:Items() or {}
                local itemLabel = itemNames[ingredient] and itemNames[ingredient].label or itemData.label or ingredient
                
                TriggerClientEvent('restaurant:orderSuccess', src, 
                    string.format('Quick order placed: %d %s for $%d', quantity, itemLabel, totalCost)
                )
            end
        end)
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Insufficient Funds',
            description = 'Not enough money in bank.',
            type = 'error',
            duration = 5000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
    end
end)

RegisterNetEvent("restaurant:getCurrentOrders")
AddEventHandler("restaurant:getCurrentOrders", function(restaurantId)
    local src = source
    
    MySQL.Async.fetchAll('SELECT * FROM supply_orders WHERE restaurant_id = ? AND status IN (?, ?, ?)', 
    {restaurantId, 'pending', 'accepted', 'in_transit'}, function(results)
        TriggerClientEvent("restaurant:showCurrentOrders", src, results or {}, restaurantId)
    end)
end)

-- Smart Order (AI Suggestion)
RegisterNetEvent('restaurant:smartOrder')
AddEventHandler('restaurant:smartOrder', function(restaurantId, ingredient, quantity)
    -- Similar to quickOrder but with smart pricing
    TriggerEvent('restaurant:quickOrder', source, restaurantId, ingredient, quantity)
end)

-- Bulk Smart Order
RegisterNetEvent('restaurant:bulkSmartOrder')
AddEventHandler('restaurant:bulkSmartOrder', function(restaurantId, suggestions)
    local src = source
    
    for _, suggestion in ipairs(suggestions) do
        TriggerEvent('restaurant:quickOrder', src, restaurantId, suggestion.ingredient, suggestion.suggestedQuantity)
        Citizen.Wait(100) -- Small delay between orders
    end
end)

RegisterNetEvent("restaurant:getQuickReorderItems")
AddEventHandler("restaurant:getQuickReorderItems", function(restaurantId)
    local src = source
    
    -- Get recently ordered items for this restaurant
    MySQL.Async.fetchAll([[
        SELECT 
            wh.ingredient,
            wh.quantity as warehouse_stock,
            COALESCE(inv.count, 0) as restaurant_stock,
            ms.max_stock,
            (wh.quantity / ms.max_stock * 100) as percentage
        FROM supply_warehouse_stock wh
        LEFT JOIN supply_market_settings ms ON wh.ingredient = ms.ingredient
        -- Add inventory join logic here
        WHERE (wh.quantity / ms.max_stock * 100) <= 50;
    ]], {restaurantId}, function(results)
        TriggerClientEvent("restaurant:showQuickReorderMenu", src, results or {}, restaurantId)
    end)
end)