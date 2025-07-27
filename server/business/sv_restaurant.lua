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

-- Split orders into regular and import groups
local function splitOrdersByImportStatus(orderItems, restaurantJob)
    local regularOrders = {}
    local importOrders = {}
    
    for _, orderItem in ipairs(orderItems) do
        local ingredient = orderItem.ingredient:lower()
        local isImport = false
        
        -- Check all categories for this item
        for category, categoryItems in pairs(Config.Items[restaurantJob]) do
            if categoryItems[ingredient] and categoryItems[ingredient].import then
                isImport = true
                break
            end
        end
        
        if isImport then
            table.insert(importOrders, orderItem)
        else
            table.insert(regularOrders, orderItem)
        end
    end
    
    return regularOrders, importOrders
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
    
    local restaurantJob = Config.Restaurants[restaurantId].job
    local restaurantItems = Config.Items[restaurantJob] or {}
    local totalCost = 0
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
        
        -- Check nested structure
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
        
        -- Apply import markup if applicable
        local itemPrice = item.price or 0
        if item.import and Config.ImportSystem and Config.ImportSystem.importMarkup then
            itemPrice = math.floor(itemPrice * Config.ImportSystem.importMarkup)
        end
        
        local dynamicPrice = math.floor(itemPrice * priceMultiplier)
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

    -- IMPORT SYSTEM: Split orders by type
    local regularOrders, importOrders = splitOrdersByImportStatus(orderItems, restaurantJob)
    
    -- Generate order group IDs
    local regularGroupId = #regularOrders > 0 and generateOrderGroupId() or nil
    local importGroupId = #importOrders > 0 and ("import_" .. generateOrderGroupId()) or nil
    
    local queries = {}
    local hasImports = #importOrders > 0
    local hasRegular = #regularOrders > 0

    -- Process regular orders
    if hasRegular then
        for _, orderItem in ipairs(regularOrders) do
            local ingredient = orderItem.ingredient:lower()
            local quantity = tonumber(orderItem.quantity)
            
            -- Find the item again
            local item = nil
            for category, categoryItems in pairs(restaurantItems) do
                if categoryItems[ingredient] then
                    item = categoryItems[ingredient]
                    break
                end
            end

            local dynamicPrice = math.floor(item.price * priceMultiplier)
            local itemCost = dynamicPrice * quantity
            
            table.insert(queries, {
                query = 'INSERT INTO supply_orders (owner_id, ingredient, quantity, status, restaurant_id, total_cost, order_group_id) VALUES (?, ?, ?, ?, ?, ?, ?)',
                values = { playerId, ingredient, quantity, 'pending', restaurantId, itemCost, regularGroupId }
            })
        end
    end
    
    -- Process import orders
    if hasImports then
        for _, orderItem in ipairs(importOrders) do
            local ingredient = orderItem.ingredient:lower()
            local quantity = tonumber(orderItem.quantity)
            
            -- Find the item again
            local item = nil
            for category, categoryItems in pairs(restaurantItems) do
                if categoryItems[ingredient] then
                    item = categoryItems[ingredient]
                    break
                end
            end

            -- Apply import markup
            local itemPrice = item.price * (Config.ImportSystem.importMarkup or 1.25)
            local dynamicPrice = math.floor(itemPrice * priceMultiplier)
            local itemCost = dynamicPrice * quantity
            
            -- Regular order entry
            table.insert(queries, {
                query = 'INSERT INTO supply_orders (owner_id, ingredient, quantity, status, restaurant_id, total_cost, order_group_id) VALUES (?, ?, ?, ?, ?, ?, ?)',
                values = { playerId, ingredient, quantity, 'pending', restaurantId, itemCost, importGroupId }
            })
        end
    end

    -- Remove money and execute queries
    xPlayer.Functions.RemoveMoney('bank', totalCost, "Ordered ingredients")
    
    MySQL.Async.transaction(queries, function(success)
        if success then
            -- Build notification message
            local notificationMsg = ""
            if hasRegular and hasImports then
                notificationMsg = string.format('Orders split! Regular items → Main Warehouse | Import items → Import Center | Total: $%d', totalCost)
            elseif hasImports then
                notificationMsg = string.format('Import order sent to Import Distribution Center | Total: $%d', totalCost)
            else
                notificationMsg = string.format('Order sent to Main Warehouse | Total: $%d', totalCost)
            end
            
            TriggerClientEvent('ox_lib:notify', playerId, {
                title = '✅ Order Submitted',
                description = notificationMsg,
                type = 'success',
                duration = 8000,
                position = Config.UI.notificationPosition
            })
            
            -- Send notifications to appropriate warehouses
            if hasRegular then
                -- Notify main warehouse workers
                TriggerEvent('notifications:sendWarehouseAlert', 1, regularGroupId, #regularOrders)
            end
            
            if hasImports then
                -- Notify import warehouse workers
                TriggerEvent('notifications:sendWarehouseAlert', 2, importGroupId, #importOrders)
            end
    -- SEND ORDER NOTIFICATION EMAILS TO WAREHOUSE WORKERS
    local LBPhone = _G.LBPhone
if LBPhone and Config.Notifications.phone.enabled and Config.Notifications.phone.types.new_orders then
    -- Get all online players
    local players = QBCore.Functions.GetPlayers()
    local itemNames = exports.ox_inventory:Items() or {}
    
    -- Calculate delivery requirements
    local totalItems = 0
    local itemsList = {}
    
    for _, orderItem in ipairs(orderItems) do
        totalItems = totalItems + orderItem.quantity
        table.insert(itemsList, {
            label = orderItem.label,
            quantity = orderItem.quantity
        })
    end
    
    local itemsPerContainer = (Config.ContainerSystem and Config.ContainerSystem.itemsPerContainer) or 12
    local containersPerBox = (Config.ContainerSystem and Config.ContainerSystem.containersPerBox) or 5
    local containersNeeded = math.ceil(totalItems / itemsPerContainer)
    local boxesNeeded = math.ceil(containersNeeded / containersPerBox)
    
    -- Calculate potential earnings
    local basePay = math.floor(totalCost * Config.DriverPayPrec)
    local maxSpeedBonus = 40 -- 40% for lightning fast (using new balanced config)
    local volumeBonus = boxesNeeded >= 15 and 200 or (boxesNeeded >= 10 and 125 or (boxesNeeded >= 5 and 50 or 0))
    
    -- Get restaurant name
    local restaurantName = Config.Restaurants[restaurantId] and Config.Restaurants[restaurantId].name or "Unknown Restaurant"
    
    -- Send email to each warehouse worker
    for _, playerId in ipairs(players) do
        local warehousePlayer = QBCore.Functions.GetPlayer(playerId)
        if warehousePlayer then
            local playerJob = warehousePlayer.PlayerData.job.name
            
            -- Check if player has warehouse access
            local hasAccess = false
            for _, job in ipairs(Config.Jobs.warehouse) do
                if playerJob == job then
                    hasAccess = true
                    break
                end
            end
            
            if hasAccess then
                -- CHANGED: Pass playerId instead of phoneNumber
                -- Prepare order data for email
                local emailOrderData = {
                    orderId = orderGroupId,
                    restaurantName = restaurantName,
                    totalBoxes = boxesNeeded,
                    items = itemsList,
                    basePay = basePay,
                    location = restaurantName,
                    distance = 0, -- Could calculate actual distance if needed
                    maxSpeedBonus = maxSpeedBonus,
                    volumeBonus = volumeBonus,
                    perfectBonus = Config.DriverRewards.perfectDelivery.onTimeBonus
                }
                
                -- Send the email - PASS PLAYER ID
                LBPhone.SendOrderNotification(playerId, emailOrderData)  -- CHANGED: Pass playerId instead of phoneNumber
            end
        end
    end
end
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