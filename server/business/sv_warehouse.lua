local QBCore = exports['qb-core']:GetCoreObject()

local DEBUG_MODE = false -- Set to false when fixed

local function debugPrint(source, stage, message)
    if DEBUG_MODE then
        print(string.format("^3[SERVER DEBUG - %s - Player %s]^0 %s", stage, source, message))
    end
end
-- ===================================
-- STOCK CACHE SYSTEM
-- ===================================
local stockCache = {}
local cacheExpiry = {}
local CACHE_DURATION = 30000 -- 30 seconds in milliseconds

local function getPlayerWarehouseLocation(source)
    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    
    -- Check which warehouse the player is closest to
    local closestWarehouse = 1
    local closestDistance = 9999
    
    for warehouseId, warehouse in ipairs(Config.WarehousesLocation) do
        local distance = #(coords - warehouse.position)
        if distance < closestDistance then
            closestDistance = distance
            closestWarehouse = warehouseId
        end
    end
    
    -- Must be within 50 units of a warehouse
    if closestDistance > 50 then
        return nil
    end
    
    return closestWarehouse
end

-- Cache helper functions
local function isCacheValid(key)
    return cacheExpiry[key] and GetGameTimer() < cacheExpiry[key]
end

local function setCache(key, data)
    stockCache[key] = data
    cacheExpiry[key] = GetGameTimer() + CACHE_DURATION
end

local function getCache(key)
    if isCacheValid(key) then
        return stockCache[key]
    end
    return nil
end

-- Clear cache when stock updates
local function clearStockCache()
    stockCache = {}
    cacheExpiry = {}
end

-- Validate critical config on script start
Citizen.CreateThread(function()
    if not Config.Jobs or not Config.Jobs.warehouse then
        print("[ERROR] Config.Jobs.warehouse not found! Add job configuration to config_main.lua")
    end
    if not Config.Restaurants then
        print("[ERROR] Config.Restaurants not found!")
    end
    if not Config.Items then
        print("[ERROR] Config.Items not found!")
    end
end)

-- Server-side job validation
local function hasWarehouseAccess(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    
    local playerJob = Player.PlayerData.job.name
    for _, authorizedJob in ipairs(Config.Jobs.warehouse) do
        if playerJob == authorizedJob then
            return true
        end
    end
    
    return false
end

-- Calculate delivery requirements
local function calculateDeliveryInfo(orderGroup)
    local totalItems = 0
    for _, item in ipairs(orderGroup.items) do
        totalItems = totalItems + item.quantity
    end
    
    local itemsPerContainer = (Config.ContainerSystem and Config.ContainerSystem.itemsPerContainer) or 12
    local containersPerBox = (Config.ContainerSystem and Config.ContainerSystem.containersPerBox) or 5
    
    local containersNeeded = math.ceil(totalItems / itemsPerContainer)
    local boxesNeeded = math.ceil(containersNeeded / containersPerBox)
    
    return {
        totalItems = totalItems,
        containersNeeded = containersNeeded,
        boxesNeeded = boxesNeeded
    }
end

-- ===================================
-- ENHANCED STOCK VIEWING SYSTEM
-- ===================================

-- Get category stock with visual data
RegisterNetEvent('warehouse:requestCategoryStock')
AddEventHandler('warehouse:requestCategoryStock', function(warehouseId, category)
    local src = source
    if not hasWarehouseAccess(src) then
        return
    end
    
    -- Determine which stock table to use
    local stockTable = warehouseId == 2 and 'supply_import_stock' or 'supply_warehouse_stock'
    
    -- Get all items for all restaurant jobs in this category
    local categoryItems = {}
    for restaurantId, restaurant in pairs(Config.Restaurants) do
        local jobItems = Config.Items[restaurant.job]
        if jobItems and jobItems[category] then
            for itemName, itemData in pairs(jobItems[category]) do
                categoryItems[itemName:lower()] = itemData
            end
        end
    end
    
    -- Get stock data for these items
    local stockData = {}
    local itemNames = exports.ox_inventory:Items() or {}
    
    for itemName, itemConfig in pairs(categoryItems) do
        MySQL.Async.fetchAll([[
            SELECT 
                ws.ingredient,
                ws.quantity,
                COALESCE(ms.max_stock, 500) as max_stock
            FROM ]] .. stockTable .. [[ ws
            LEFT JOIN supply_market_settings ms ON ws.ingredient = ms.ingredient
            WHERE ws.ingredient = ?
        ]], {itemName}, function(results)
            if results and results[1] then
                local item = results[1]
                local percentage = (item.quantity / item.max_stock) * 100
                
                table.insert(stockData, {
                    ingredient = item.ingredient,
                    label = itemNames[item.ingredient] and itemNames[item.ingredient].label or itemConfig.label or item.ingredient,
                    quantity = item.quantity,
                    price = itemConfig.price or 0,
                    percentage = percentage,
                    isImport = itemConfig.import or false
                })
            end
        end)
    end
    
    -- Wait for queries to complete
    Citizen.SetTimeout(500, function()
        TriggerClientEvent('warehouse:showCategoryStock', src, warehouseId, category, stockData)
    end)
end)

-- Get stock summary
RegisterNetEvent('warehouse:requestStockSummary')
AddEventHandler('warehouse:requestStockSummary', function(warehouseId)
    local src = source
    if not hasWarehouseAccess(src) then
        return
    end
    
    -- Determine which stock table to use
    local stockTable = warehouseId == 2 and 'supply_import_stock' or 'supply_warehouse_stock'
    
    MySQL.Async.fetchAll('SELECT * FROM ' .. stockTable, {}, function(results)
        local summaryData = {
            totalItems = 0,
            totalValue = 0,
            categoryCount = 0,
            categories = {},
            stockHealth = {
                critical = 0,
                low = 0,
                healthy = 0
            }
        }
        
        local itemNames = exports.ox_inventory:Items() or {}
        
        -- Process each stock item
        for _, stockItem in ipairs(results) do
            local ingredient = stockItem.ingredient:lower()
            local quantity = stockItem.quantity
            
            -- Find which category this item belongs to
            local foundCategory = nil
            local itemConfig = nil
            
            for restaurantId, restaurant in pairs(Config.Restaurants) do
                local jobItems = Config.Items[restaurant.job]
                if jobItems then
                    for category, categoryItems in pairs(jobItems) do
                        if categoryItems[ingredient] then
                            foundCategory = category
                            itemConfig = categoryItems[ingredient]
                            break
                        end
                    end
                end
                if foundCategory then break end
            end
            
            if foundCategory and itemConfig then
                -- Initialize category if needed
                if not summaryData.categories[foundCategory] then
                    summaryData.categories[foundCategory] = {
                        items = 0,
                        value = 0
                    }
                    summaryData.categoryCount = summaryData.categoryCount + 1
                end
                
                -- Update totals
                local itemValue = quantity * (itemConfig.price or 0)
                summaryData.totalItems = summaryData.totalItems + quantity
                summaryData.totalValue = summaryData.totalValue + itemValue
                summaryData.categories[foundCategory].items = summaryData.categories[foundCategory].items + quantity
                summaryData.categories[foundCategory].value = summaryData.categories[foundCategory].value + itemValue
                
                -- Check stock health
                MySQL.Async.fetchScalar('SELECT max_stock FROM supply_market_settings WHERE ingredient = ?', 
                {ingredient}, function(maxStock)
                    maxStock = maxStock or 500
                    local percentage = (quantity / maxStock) * 100
                    
                    if percentage <= 20 then
                        summaryData.stockHealth.critical = summaryData.stockHealth.critical + 1
                    elseif percentage <= 50 then
                        summaryData.stockHealth.low = summaryData.stockHealth.low + 1
                    else
                        summaryData.stockHealth.healthy = summaryData.stockHealth.healthy + 1
                    end
                end)
            end
        end
        
        -- Send summary after short delay for health calculations
        Citizen.SetTimeout(500, function()
            TriggerClientEvent('warehouse:showStockSummary', src, warehouseId, summaryData)
        end)
    end)
end)

-- Handle order menu request with warehouse context
RegisterNetEvent('warehouse:requestOrdersMenu')
AddEventHandler('warehouse:requestOrdersMenu', function(warehouseId)
    local playerId = source
    if not hasWarehouseAccess(playerId) then
        return
    end
    
    -- Store the warehouse context for this player
    -- This ensures orders are filtered correctly
    
    -- Build query based on warehouse location
    local queryCondition = ""
    if warehouseId == 2 then
        -- Import warehouse - only show import orders
        queryCondition = "WHERE status = 'pending' AND order_group_id LIKE 'import_%'"
    else
        -- Regular warehouse - exclude import orders
        queryCondition = "WHERE status = 'pending' AND (order_group_id NOT LIKE 'import_%' OR order_group_id IS NULL)"
    end
    
    MySQL.Async.fetchAll('SELECT * FROM supply_orders ' .. queryCondition, {}, function(results)
        if not results then
            print("[ERROR] No results from supply_orders query")
            return
        end
        
        local ordersByGroup = {}
        local itemNames = exports.ox_inventory:Items() or {}
        
        for _, order in ipairs(results) do
            local restaurantJob = Config.Restaurants[order.restaurant_id] and Config.Restaurants[order.restaurant_id].job
            if restaurantJob then
                local itemKey = order.ingredient:lower()
                local item = nil
                
                -- Find item in categories
                for category, categoryItems in pairs(Config.Items[restaurantJob]) do
                    if categoryItems[itemKey] then
                        item = categoryItems[itemKey]
                        break
                    end
                end
                
                local itemLabel = itemNames[itemKey] and itemNames[itemKey].label or (item and item.label) or itemKey

                if item then
                    local orderGroupId = order.order_group_id or tostring(order.id)
                    if not ordersByGroup[orderGroupId] then
                        ordersByGroup[orderGroupId] = {
                            orderGroupId = orderGroupId,
                            id = order.id,
                            ownerId = order.owner_id,
                            restaurantId = order.restaurant_id,
                            totalCost = 0,
                            items = {},
                            isImport = string.find(orderGroupId, "import_") ~= nil
                        }
                    end
                    table.insert(ordersByGroup[orderGroupId].items, {
                        id = order.id,
                        itemName = itemKey,
                        itemLabel = itemLabel,
                        quantity = order.quantity,
                        totalCost = order.total_cost,
                        isImport = item.import or false
                    })
                    ordersByGroup[orderGroupId].totalCost = ordersByGroup[orderGroupId].totalCost + order.total_cost
                else
                    print("[ERROR] Item not found: ", itemKey, " for job: ", restaurantJob)
                end
            else
                print("[ERROR] Invalid restaurant job for restaurant_id: ", order.restaurant_id)
            end
        end
        
        local orders = {}
        for _, orderGroup in pairs(ordersByGroup) do
            -- Add delivery calculation info
            local deliveryInfo = calculateDeliveryInfo(orderGroup)
            orderGroup.deliveryInfo = deliveryInfo
            
            -- Add warehouse info
            orderGroup.warehouseId = warehouseId
            orderGroup.warehouseName = warehouseId == 2 and "Import Distribution Center" or "Main Warehouse"
            
            table.insert(orders, orderGroup)
        end
        
        -- Add warehouse info to client display
        if #orders == 0 then
            local warehouseName = warehouseId == 2 and "Import Distribution Center" or "Main Warehouse"
            TriggerClientEvent('ox_lib:notify', playerId, {
                title = 'No Orders',
                description = 'No pending orders for ' .. warehouseName,
                type = 'info',
                duration = 5000,
                position = Config.UI.notificationPosition
            })
        end
        
        TriggerClientEvent('warehouse:showOrderDetails', playerId, orders)
    end)
end)

RegisterNetEvent("warehouse:getImportTracking")
AddEventHandler("warehouse:getImportTracking", function()
    local src = source
    -- Check warehouse access
    if not hasWarehouseAccess(src) then
        return
    end
    
    -- Simply trigger the client event to open the menu
    TriggerClientEvent("imports:openTrackingMenu", src)
end)

-- Stock alerts handler (only for main warehouse)
RegisterNetEvent('stockalerts:getDashboard')
AddEventHandler('stockalerts:getDashboard', function()
    local src = source
    if not hasWarehouseAccess(src) then
        return
    end
    
    TriggerEvent('stockalerts:getAlerts') -- Use existing handler
end)

-- Import tracking simulation (for testing)
RegisterNetEvent('imports:simulateArrival')
AddEventHandler('imports:simulateArrival', function()
    local src = source
    if not hasWarehouseAccess(src) then
        return
    end
    
    -- Simulate an import arrival
    local testImportOrder = {
        order_id = "IMP_" .. os.time(),
        ingredient = "reign_lettuce",
        quantity = 500,
        origin_country = "Netherlands",
        arrival_date = os.time() + 3600, -- 1 hour from now
        status = "in_transit"
    }
    
    MySQL.Async.execute([[
        INSERT INTO supply_import_orders 
        (order_id, ingredient, quantity, origin_country, arrival_date, status)
        VALUES (?, ?, ?, ?, FROM_UNIXTIME(?), ?)
    ]], {
        testImportOrder.order_id,
        testImportOrder.ingredient,
        testImportOrder.quantity,
        testImportOrder.origin_country,
        testImportOrder.arrival_date,
        testImportOrder.status
    }, function(success)
        if success then
            TriggerClientEvent('ox_lib:notify', src, {
                title = '🌍 Import Simulated',
                description = 'Test import order created for tracking',
                type = 'success',
                duration = 5000,
                position = Config.UI.notificationPosition
            })
        end
    end)
end)

-- Get Pending Orders
RegisterNetEvent('warehouse:getPendingOrders')
AddEventHandler('warehouse:getPendingOrders', function()
    local playerId = source
    if not hasWarehouseAccess(playerId) then
        return -- Silently reject unauthorized access
    end
    
    -- Determine which warehouse the player is at
    local warehouseId = getPlayerWarehouseLocation(playerId)
    if not warehouseId then
        TriggerClientEvent('ox_lib:notify', playerId, {
            title = 'Error',
            description = 'You must be at a warehouse to view orders.',
            type = 'error',
            duration = 5000,
            position = Config.UI.notificationPosition
        })
        return
    end
    
    -- Build query based on warehouse location
    local queryCondition = ""
    if warehouseId == 2 then
        -- Import warehouse - only show import orders
        queryCondition = "WHERE status = 'pending' AND order_group_id LIKE 'import_%'"
    else
        -- Regular warehouse - exclude import orders
        queryCondition = "WHERE status = 'pending' AND (order_group_id NOT LIKE 'import_%' OR order_group_id IS NULL)"
    end
    
    MySQL.Async.fetchAll('SELECT * FROM supply_orders ' .. queryCondition, {}, function(results)
        if not results then
            print("[ERROR] No results from supply_orders query")
            return
        end
        
        local ordersByGroup = {}
        local itemNames = exports.ox_inventory:Items() or {}
        
        for _, order in ipairs(results) do
            local restaurantJob = Config.Restaurants[order.restaurant_id] and Config.Restaurants[order.restaurant_id].job
            if restaurantJob then
                local itemKey = order.ingredient:lower()
                local item = nil
                
                -- Find item in categories
                for category, categoryItems in pairs(Config.Items[restaurantJob]) do
                    if categoryItems[itemKey] then
                        item = categoryItems[itemKey]
                        break
                    end
                end
                
                local itemLabel = itemNames[itemKey] and itemNames[itemKey].label or (item and item.label) or itemKey

                if item then
                    local orderGroupId = order.order_group_id or tostring(order.id)
                    if not ordersByGroup[orderGroupId] then
                        ordersByGroup[orderGroupId] = {
                            orderGroupId = orderGroupId,
                            id = order.id,
                            ownerId = order.owner_id,
                            restaurantId = order.restaurant_id,
                            totalCost = 0,
                            items = {},
                            isImport = string.find(orderGroupId, "import_") ~= nil
                        }
                    end
                    table.insert(ordersByGroup[orderGroupId].items, {
                        id = order.id,
                        itemName = itemKey,
                        itemLabel = itemLabel,
                        quantity = order.quantity,
                        totalCost = order.total_cost,
                        isImport = item.import or false
                    })
                    ordersByGroup[orderGroupId].totalCost = ordersByGroup[orderGroupId].totalCost + order.total_cost
                else
                    print("[ERROR] Item not found: ", itemKey, " for job: ", restaurantJob)
                end
            else
                print("[ERROR] Invalid restaurant job for restaurant_id: ", order.restaurant_id)
            end
        end
        
        local orders = {}
        for _, orderGroup in pairs(ordersByGroup) do
            -- Add delivery calculation info
            local deliveryInfo = calculateDeliveryInfo(orderGroup)
            orderGroup.deliveryInfo = deliveryInfo
            
            -- Add warehouse info
            orderGroup.warehouseId = warehouseId
            orderGroup.warehouseName = warehouseId == 2 and "Import Distribution Center" or "Main Warehouse"
            
            table.insert(orders, orderGroup)
        end
        
        -- Add warehouse info to client display
        if #orders == 0 then
            local warehouseName = warehouseId == 2 and "Import Distribution Center" or "Main Warehouse"
            TriggerClientEvent('ox_lib:notify', playerId, {
                title = 'No Orders',
                description = 'No pending orders for ' .. warehouseName,
                type = 'info',
                duration = 5000,
                position = Config.UI.notificationPosition
            })
        end
        
        TriggerClientEvent('warehouse:showOrderDetails', playerId, orders)
    end)
end)

-- Add new handler for import stock management
RegisterNetEvent('warehouse:getImportStock')
AddEventHandler('warehouse:getImportStock', function()
    local src = source
    if not hasWarehouseAccess(src) then
        return
    end
    
    MySQL.Async.fetchAll('SELECT * FROM supply_import_stock', {}, function(results)
        local stock = {}
        for _, item in ipairs(results) do
            stock[item.ingredient:lower()] = item.quantity
        end
        
        -- Send with import flag
        TriggerClientEvent('restaurant:showStockDetails', src, stock, nil, true) -- true = isImportStock
    end)
end)

-- Accept Order (MISSING IN CURRENT VERSION)
RegisterNetEvent('warehouse:acceptOrder') 
AddEventHandler('warehouse:acceptOrder', function(orderGroupId, restaurantId)
    local workerId = source
    if not hasWarehouseAccess(workerId) then
        return
    end
    
    MySQL.Async.fetchAll('SELECT * FROM supply_orders WHERE order_group_id = ?', { orderGroupId }, function(orderResults)
        if not orderResults or #orderResults == 0 then
            print("[ERROR] No order found with group ID:", orderGroupId)
            TriggerClientEvent('ox_lib:notify', workerId, {
                title = 'Error',
                description = 'Order not found or already processed.',
                type = 'error',
                duration = 10000,
                position = Config.UI.notificationPosition,
                markdown = Config.UI.enableMarkdown
            })
            return
        end

        local restaurantJob = Config.Restaurants[restaurantId] and Config.Restaurants[restaurantId].job
        if not restaurantJob then
            print("[ERROR] Invalid restaurant job for restaurant_id:", restaurantId)
            TriggerClientEvent('ox_lib:notify', workerId, {
                title = 'Error',
                description = 'Invalid restaurant ID.',
                type = 'error',
                duration = 10000,
                position = Config.UI.notificationPosition,
                markdown = Config.UI.enableMarkdown
            })
            return
        end

        local orders = {}
        local queries = {}
        local itemNames = exports.ox_inventory:Items() or {}
        local isImportOrder = string.find(orderGroupId, "import_") ~= nil
        
        for _, order in ipairs(orderResults) do
            local ingredient = order.ingredient:lower()
            local itemData = nil
            
            -- Find item in categories
            for category, categoryItems in pairs(Config.Items[restaurantJob]) do
                if categoryItems[ingredient] then
                    itemData = categoryItems[ingredient]
                    break
                end
            end
            
            if not itemData then
                print("[ERROR] Item not found for ingredient:", ingredient)
                TriggerClientEvent('ox_lib:notify', workerId, {
                    title = 'Error',
                    description = 'Item not found: ' .. ingredient,
                    type = 'error',
                    duration = 10000,
                    position = Config.UI.notificationPosition,
                    markdown = Config.UI.enableMarkdown
                })
                return
            end

            -- Check appropriate stock based on order type
            local stockTable = isImportOrder and 'supply_import_stock' or 'supply_warehouse_stock'
            local stockResults = MySQL.Sync.fetchAll('SELECT quantity FROM ' .. stockTable .. ' WHERE ingredient = ?', { ingredient })
            
            if not stockResults or #stockResults == 0 or stockResults[1].quantity < order.quantity then
                local currentStock = stockResults[1] and stockResults[1].quantity or 0
                print("[ERROR] Insufficient stock for", ingredient, ":", currentStock, "<", order.quantity)
                
                local stockType = isImportOrder and "import" or "warehouse"
                TriggerClientEvent('ox_lib:notify', workerId, {
                    title = 'Insufficient Stock',
                    description = string.format('Not enough %s stock for **%s** (%d/%d)', 
                        stockType, 
                        itemNames[ingredient] and itemNames[ingredient].label or ingredient,
                        currentStock,
                        order.quantity
                    ),
                    type = 'error',
                    duration = 10000,
                    position = Config.UI.notificationPosition,
                    markdown = Config.UI.enableMarkdown
                })
                return
            end

            table.insert(orders, {
                id = order.id,
                orderGroupId = order.order_group_id,
                ownerId = order.owner_id,
                itemName = ingredient,
                quantity = order.quantity,
                totalCost = order.total_cost,
                restaurantId = order.restaurant_id,
                isImport = itemData.import or false
            })

            -- Update appropriate stock table
            table.insert(queries, {
                query = 'UPDATE ' .. stockTable .. ' SET quantity = quantity - ? WHERE ingredient = ?',
                values = { order.quantity, ingredient }
            })
            table.insert(queries, {
                query = 'UPDATE supply_orders SET status = ? WHERE id = ?',
                values = { 'accepted', order.id }
            })
        end

        MySQL.Async.transaction(queries, function(success)
            if success then
                clearStockCache()
                TriggerClientEvent('warehouse:spawnVehicles', workerId, restaurantId, orders)
                
                local orderType = isImportOrder and "Import" or "Regular"
                TriggerClientEvent('ox_lib:notify', workerId, {
                    title = orderType .. ' Order Accepted',
                    description = 'Delivery started! Prepare to load boxes.',
                    type = 'success',
                    duration = 10000,
                    position = Config.UI.notificationPosition,
                    markdown = Config.UI.enableMarkdown
                })
            else
                TriggerClientEvent('ox_lib:notify', workerId, {
                    title = 'Error',
                    description = 'Failed to accept order.',
                    type = 'error',
                    duration = 10000,
                    position = Config.UI.notificationPosition,
                    markdown = Config.UI.enableMarkdown
                })
            end
        end)
    end)
end)

-- Deny Order (MISSING IN CURRENT VERSION)
RegisterNetEvent('warehouse:denyOrder')
AddEventHandler('warehouse:denyOrder', function(orderGroupId)
    local playerId = source
    if not hasWarehouseAccess(playerId) then
        return -- Silently reject unauthorized access
    end
    
    MySQL.Async.execute('UPDATE supply_orders SET status = ? WHERE order_group_id = ?', { 'denied', orderGroupId }, function(rowsAffected)
        if rowsAffected > 0 then
            TriggerClientEvent('ox_lib:notify', playerId, {
                title = 'Order Denied',
                description = 'The order has been denied.',
                type = 'success',
                duration = 10000,
                position = Config.UI.notificationPosition,
                markdown = Config.UI.enableMarkdown
            })
        else
            TriggerClientEvent('ox_lib:notify', playerId, {
                title = 'Error',
                description = 'Failed to deny order.',
                type = 'error',
                duration = 10000,
                position = Config.UI.notificationPosition,
                markdown = Config.UI.enableMarkdown
            })
        end
    end)
end)

-- Update Stock after Delivery
RegisterNetEvent('update:stock')
AddEventHandler('update:stock', function(restaurantId, orders)
    local src = source
    debugPrint(src, "STOCK_1", "Received stock update request")
    
    if not Config.Restaurants then
        debugPrint(src, "STOCK_ERROR", "Config.Restaurants not loaded!")
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'Configuration not loaded.',
            type = 'error',
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    if not restaurantId or not orders or #orders == 0 then
        debugPrint(src, "STOCK_ERROR", "Invalid restaurant ID or order data")
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'Invalid restaurant ID or order data.',
            type = 'error',
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end

    debugPrint(src, "STOCK_2", "Processing " .. #orders .. " orders for restaurant " .. restaurantId)

    local orderGroupId = orders[1].orderGroupId
    local queries = {}
    local totalCost = 0
    local stashId = "restaurant_stock_" .. tostring(restaurantId)
    
    debugPrint(src, "STOCK_3", "Order group ID: " .. (orderGroupId or "nil"))
    
    for i, order in ipairs(orders) do
        local ingredient = order.itemName:lower()
        local quantity = tonumber(order.quantity)
        local orderCost = order.totalCost or 0
        
        debugPrint(src, "STOCK_4", "Processing item " .. i .. ": " .. ingredient .. " x" .. quantity)
        
        if ingredient and quantity then
            table.insert(queries, {
                query = 'UPDATE supply_orders SET status = ? WHERE id = ? AND order_group_id = ?',
                values = { 'completed', order.id, orderGroupId }
            })
            table.insert(queries, {
                query = 'INSERT INTO supply_stock (restaurant_id, ingredient, quantity) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE quantity = quantity + ?',
                values = { restaurantId, ingredient, quantity, quantity }
            })
            
            exports.ox_inventory:AddItem(stashId, ingredient, quantity)
            totalCost = totalCost + orderCost
        else
            debugPrint(src, "STOCK_ERROR", "Invalid order data for order ID: " .. (order.id or "nil"))
        end
    end

    debugPrint(src, "STOCK_5", "Executing " .. #queries .. " queries...")

    MySQL.Async.transaction(queries, function(success)
        debugPrint(src, "STOCK_6", "Transaction result: " .. tostring(success))
        
        if success then
            clearStockCache()
            
            debugPrint(src, "STOCK_7", "Sending success notification")
            
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Stock Updated',
                description = 'Orders completed and stock updated!',
                type = 'success',
                duration = 10000,
                position = Config.UI.notificationPosition,
                markdown = Config.UI.enableMarkdown
            })
            
            debugPrint(src, "STOCK_8", "Triggering delivery:storeCompletionData")
            
            TriggerClientEvent('delivery:storeCompletionData', src, {
                restaurantId = restaurantId,
                orders = orders,
                totalCost = totalCost
            })
            
            debugPrint(src, "STOCK_9", "Stock update complete!")
        else
            debugPrint(src, "STOCK_ERROR", "Transaction failed!")
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Error',
                description = 'Failed to update stock.',
                type = 'error',
                duration = 10000,
                position = Config.UI.notificationPosition,
                markdown = Config.UI.enableMarkdown
            })
        end
    end)
end)

RegisterNetEvent('delivery:requestPayment')
AddEventHandler('delivery:requestPayment', function(deliveryData)
    local src = source
    debugPrint(src, "PAYMENT_1", "Payment request received")
    
    local xPlayer = QBCore.Functions.GetPlayer(src)
    
    if not xPlayer then
        debugPrint(src, "PAYMENT_ERROR", "Player not found!")
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Payment Error',
            description = 'Unable to process payment. Please contact admin.',
            type = 'error',
            duration = 10000,
            position = Config.UI.notificationPosition
        })
        return
    end
    
    if not deliveryData then
        debugPrint(src, "PAYMENT_ERROR", "No delivery data provided!")
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Payment Error',
            description = 'No delivery data found.',
            type = 'error',
            duration = 10000,
            position = Config.UI.notificationPosition
        })
        return
    end
    
    debugPrint(src, "PAYMENT_2", "Processing payment for delivery time: " .. (deliveryData.deliveryTime or "nil"))
    
    -- Wrap in pcall to catch any errors
    local success, err = pcall(function()
        -- Calculate base pay
        local basePay = math.floor(deliveryData.totalCost * Config.DriverPayPrec)
        debugPrint(src, "PAYMENT_3", "Base pay calculated: $" .. basePay)
        
        -- Calculate total boxes
        local totalBoxes = 0
        for _, order in ipairs(deliveryData.orders) do
            local totalItems = 0
            if order.items then
                for _, item in ipairs(order.items) do
                    totalItems = totalItems + item.quantity
                end
            else
                totalItems = order.quantity or 0
            end
            
            local itemsPerContainer = (Config.ContainerSystem and Config.ContainerSystem.itemsPerContainer) or 12
            local containersPerBox = (Config.ContainerSystem and Config.ContainerSystem.containersPerBox) or 5
            local containersNeeded = math.ceil(totalItems / itemsPerContainer)
            local boxesNeeded = math.ceil(containersNeeded / containersPerBox)
            totalBoxes = totalBoxes + boxesNeeded
        end
        
        debugPrint(src, "PAYMENT_4", "Total boxes calculated: " .. totalBoxes)
        
        -- Give basic payment immediately to prevent freeze
        xPlayer.Functions.AddMoney('cash', basePay, "Delivery base payment")
        
        debugPrint(src, "PAYMENT_5", "Base payment added to cash")
        
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Payment Received',
            description = 'Base payment of $' .. basePay .. ' added to your account!',
            type = 'success',
            duration = 10000,
            position = Config.UI.notificationPosition
        })
        
        -- Trigger reward calculation in separate thread to prevent blocking
        Citizen.CreateThread(function()
            debugPrint(src, "PAYMENT_6", "Triggering reward calculation in thread")
            
            TriggerEvent('rewards:calculateDeliveryReward', src, {
                basePay = basePay,
                deliveryTime = deliveryData.deliveryTime,
                boxes = totalBoxes,
                orderGroupId = deliveryData.orders[1].orderGroupId,
                totalCost = deliveryData.totalCost,
                isPerfect = deliveryData.deliveryTime < 1200,
                restaurantId = deliveryData.restaurantId
            })
        end)
        
        -- Trigger leaderboard tracking in separate thread
        Citizen.CreateThread(function()
            debugPrint(src, "PAYMENT_7", "Triggering leaderboard tracking in thread")
            
            TriggerEvent('leaderboard:trackDelivery', src, {
                boxes = totalBoxes,
                deliveryTime = deliveryData.deliveryTime,
                earnings = basePay,
                isPerfect = deliveryData.deliveryTime < 1200
            })
        end)
        
        debugPrint(src, "PAYMENT_8", "Payment processing complete!")
    end)
    
    if not success then
        debugPrint(src, "PAYMENT_CRITICAL_ERROR", "Payment processing failed: " .. tostring(err))
        
        -- Emergency fallback payment
        local fallbackPay = 500
        xPlayer.Functions.AddMoney('cash', fallbackPay, "Delivery payment (fallback)")
        
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Payment Processed',
            description = 'Emergency payment of $' .. fallbackPay .. ' added.',
            type = 'warning',
            duration = 10000,
            position = Config.UI.notificationPosition
        })
    end
end)

-- Get pending orders filtered for team delivery eligibility
RegisterNetEvent("warehouse:getPendingOrdersForTeam")
AddEventHandler("warehouse:getPendingOrdersForTeam", function()
    local src = source
    
    -- Use the same query as regular orders but filter on client side
    -- This maintains compatibility with existing system
    MySQL.Async.fetchAll([[
        SELECT 
            o.order_group_id as orderGroupId,
            o.restaurant_id as restaurantId,
            o.status,
            SUM(o.total_cost) as totalCost,
            GROUP_CONCAT(CONCAT(o.ingredient, ':', o.quantity) SEPARATOR ',') as itemsConcat
        FROM supply_orders o
        WHERE o.status = 'pending'
        GROUP BY o.order_group_id, o.restaurant_id
        ORDER BY MIN(o.created_at) ASC
    ]], {}, function(orderGroups)
        if not orderGroups or #orderGroups == 0 then
            TriggerClientEvent("warehouse:showTeamOrderDetails", src, {})
            return
        end
        
        -- Process the order groups
        for _, orderGroup in ipairs(orderGroups) do
            -- Parse concatenated items
            orderGroup.items = {}
            if orderGroup.itemsConcat then
                for itemStr in string.gmatch(orderGroup.itemsConcat, "[^,]+") do
                    local itemName, quantity = itemStr:match("([^:]+):(%d+)")
                    if itemName and quantity then
                        table.insert(orderGroup.items, {
                            itemName = itemName,
                            quantity = tonumber(quantity)
                        })
                    end
                end
            end
            orderGroup.itemsConcat = nil
        end
        
        -- Send all orders to client - client will filter for team eligibility
        TriggerClientEvent("warehouse:showTeamOrderDetails", src, orderGroups)
    end)
end)

-- ===================================
-- IMPORT TRACKING HANDLERS
-- ===================================

-- Get incoming import shipments
RegisterNetEvent('imports:getIncomingShipments')
AddEventHandler('imports:getIncomingShipments', function()
    local src = source
    if not hasWarehouseAccess(src) then
        return
    end
    
    MySQL.Async.fetchAll([[
        SELECT * FROM supply_import_orders 
        WHERE status IN ('ordered', 'in_transit') 
        ORDER BY arrival_date ASC
    ]], {}, function(results)
        local shipments = {}
        local itemNames = exports.ox_inventory:Items() or {}
        
        for _, shipment in ipairs(results) do
            local itemLabel = itemNames[shipment.ingredient] and itemNames[shipment.ingredient].label or shipment.ingredient
            table.insert(shipments, {
                order_id = shipment.order_id,
                item = itemLabel,
                quantity = shipment.quantity,
                origin = shipment.origin_country,
                arrival = shipment.arrival_date,
                status = shipment.status
            })
        end
        
        TriggerClientEvent('imports:showIncomingShipments', src, shipments)
    end)
end)

RegisterNetEvent('imports:showIncomingShipments')
AddEventHandler('imports:showIncomingShipments', function(shipments)
    local options = {
        {
            title = "← Back to Import Tracking",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("imports:openTrackingMenu")
            end
        }
    }
    
    if #shipments == 0 then
        table.insert(options, {
            title = "📦 No Incoming Shipments",
            description = "All shipments have been delivered",
            disabled = true
        })
    else
        for _, shipment in ipairs(shipments) do
            local statusIcon = shipment.status == "in_transit" and "🚢" or "📋"
            local arrivalText = shipment.arrival and os.date("%m/%d %I:%M %p", shipment.arrival) or "TBD"
            
            table.insert(options, {
                title = statusIcon .. " " .. shipment.item .. " (" .. shipment.quantity .. " units)",
                description = string.format("From: %s | Arrival: %s | Status: %s",
                    shipment.origin, arrivalText, shipment.status),
                disabled = true
            })
        end
    end
    
    lib.registerContext({
        id = "import_shipments",
        title = "📥 Incoming Import Shipments",
        options = options
    })
    lib.showContext("import_shipments")
end)

-- Get import analytics
RegisterNetEvent('imports:getAnalytics')
AddEventHandler('imports:getAnalytics', function()
    local src = source
    if not hasWarehouseAccess(src) then
        return
    end
    
    -- Get import statistics
    MySQL.Async.fetchAll([[
        SELECT 
            ingredient,
            COUNT(*) as total_orders,
            SUM(quantity) as total_quantity,
            AVG(quantity) as avg_quantity,
            MAX(arrival_date) as last_import
        FROM supply_import_orders
        WHERE status = 'distributed'
        GROUP BY ingredient
    ]], {}, function(results)
        local analytics = {}
        local itemNames = exports.ox_inventory:Items() or {}
        
        for _, stat in ipairs(results) do
            local itemLabel = itemNames[stat.ingredient] and itemNames[stat.ingredient].label or stat.ingredient
            table.insert(analytics, {
                item = itemLabel,
                total_orders = stat.total_orders,
                total_quantity = stat.total_quantity,
                avg_quantity = math.floor(stat.avg_quantity),
                last_import = stat.last_import
            })
        end
        
        TriggerClientEvent('imports:showAnalytics', src, analytics)
    end)
end)

-- Show import analytics
RegisterNetEvent('imports:showAnalytics')
AddEventHandler('imports:showAnalytics', function(analytics)
    local options = {
        {
            title = "← Back to Import Tracking",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("imports:openTrackingMenu")
            end
        }
    }
    
    if #analytics == 0 then
        table.insert(options, {
            title = "📊 No Import Data",
            description = "No imports have been completed yet",
            disabled = true
        })
    else
        -- Summary header
        local totalOrders = 0
        local totalQuantity = 0
        for _, stat in ipairs(analytics) do
            totalOrders = totalOrders + stat.total_orders
            totalQuantity = totalQuantity + stat.total_quantity
        end
        
        table.insert(options, {
            title = "📈 Import Summary",
            description = string.format("Total Orders: %d | Total Units: %d",
                totalOrders, totalQuantity),
            disabled = true
        })
        
        -- Individual items
        for _, stat in ipairs(analytics) do
            local lastImportText = stat.last_import and os.date("%m/%d/%Y", stat.last_import) or "Never"
            
            table.insert(options, {
                title = "📦 " .. stat.item,
                description = string.format("Orders: %d | Total: %d units | Avg: %d units | Last: %s",
                    stat.total_orders, stat.total_quantity, stat.avg_quantity, lastImportText),
                disabled = true
            })
        end
    end
    
    lib.registerContext({
        id = "import_analytics",
        title = "📊 Import Analytics & Statistics",
        options = options
    })
    lib.showContext("import_analytics")
end)

-- Configure notifications (client-side only for now)
RegisterNetEvent('imports:configureNotifications')
AddEventHandler('imports:configureNotifications', function()
    lib.notify({
        title = "🔔 Import Notifications",
        description = "Email notifications are automatically sent when import shipments arrive",
        type = "info",
        duration = 8000,
        position = Config.UI.notificationPosition
    })
end)

-- ===================================
-- STOCK ALERTS HANDLER
-- ===================================

RegisterNetEvent('stockalerts:getAlerts')
AddEventHandler('stockalerts:getAlerts', function()
    local src = source
    if not hasWarehouseAccess(src) then
        return
    end
    
    -- Get current stock levels and check for alerts
    MySQL.Async.fetchAll([[
        SELECT 
            ws.ingredient,
            ws.quantity as warehouse_stock,
            COALESCE(ms.max_stock, 500) as max_stock,
            COALESCE(ims.quantity, 0) as import_stock
        FROM supply_warehouse_stock ws
        LEFT JOIN supply_market_settings ms ON ws.ingredient = ms.ingredient
        LEFT JOIN supply_import_stock ims ON ws.ingredient = ims.ingredient
        WHERE (ws.quantity / COALESCE(ms.max_stock, 500) * 100) <= 50
        OR COALESCE(ims.quantity, 0) < 100
    ]], {}, function(results)
        local alerts = {}
        local itemNames = exports.ox_inventory:Items() or {}
        
        for _, item in ipairs(results) do
            local itemLabel = itemNames[item.ingredient] and itemNames[item.ingredient].label or item.ingredient
            local percentage = (item.warehouse_stock / item.max_stock) * 100
            
            local alertLevel = "moderate"
            if percentage <= 5 then
                alertLevel = "critical"
            elseif percentage <= 20 then
                alertLevel = "low"
            end
            
            -- Check import stock separately
            local importAlert = nil
            if item.import_stock > 0 and item.import_stock < 100 then
                importAlert = {
                    level = item.import_stock < 25 and "critical" or "low",
                    stock = item.import_stock
                }
            end
            
            table.insert(alerts, {
                ingredient = item.ingredient,
                label = itemLabel,
                warehouse_stock = item.warehouse_stock,
                import_stock = item.import_stock,
                max_stock = item.max_stock,
                percentage = percentage,
                alert_level = alertLevel,
                import_alert = importAlert
            })
        end
        
        TriggerClientEvent('stockalerts:showAlerts', src, alerts)
    end)
end)