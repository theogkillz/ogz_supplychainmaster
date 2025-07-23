local QBCore = exports['qb-core']:GetCoreObject()

-- ===================================
-- STOCK CACHE SYSTEM
-- ===================================
local stockCache = {}
local cacheExpiry = {}
local CACHE_DURATION = 30000 -- 30 seconds in milliseconds

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

-- Get Pending Orders (MISSING IN CURRENT VERSION)
RegisterNetEvent('warehouse:getPendingOrders')
AddEventHandler('warehouse:getPendingOrders', function()
    local playerId = source
    if not hasWarehouseAccess(playerId) then
        return -- Silently reject unauthorized access
    end
    
    MySQL.Async.fetchAll('SELECT * FROM supply_orders WHERE status = ?', { 'pending' }, function(results)
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
                local item = (Config.Items[restaurantJob].Meats[itemKey] or Config.Items[restaurantJob].Vegetables[itemKey] or Config.Items[restaurantJob].Fruits[itemKey])
                local itemLabel = itemNames[itemKey] and itemNames[itemKey].label or item and item.label or itemKey

            if item then
                local orderGroupId = order.order_group_id or tostring(order.id)
                if not ordersByGroup[orderGroupId] then
                    ordersByGroup[orderGroupId] = {
                        orderGroupId = orderGroupId,
                        id = order.id,
                        ownerId = order.owner_id,
                        restaurantId = order.restaurant_id,
                        totalCost = 0,
                        items = {}
                    }
                end
                table.insert(ordersByGroup[orderGroupId].items, {
                    id = order.id,
                    itemName = itemKey,        -- Keep internal name for logic
                    itemLabel = itemLabel,     -- ADD THIS: proper display label
                    quantity = order.quantity,
                    totalCost = order.total_cost
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
            
            table.insert(orders, orderGroup)
        end
        
        TriggerClientEvent('warehouse:showOrderDetails', playerId, orders)
    end)
end)

-- Accept Order (MISSING IN CURRENT VERSION)
RegisterNetEvent('warehouse:acceptOrder') 
AddEventHandler('warehouse:acceptOrder', function(orderGroupId, restaurantId)
    local workerId = source
    if not hasWarehouseAccess(workerId) then
        return -- Silently reject unauthorized access
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
        
        for _, order in ipairs(orderResults) do
            local ingredient = order.ingredient:lower()
            local itemData = (Config.Items[restaurantJob].Meats[ingredient] or Config.Items[restaurantJob].Vegetables[ingredient] or Config.Items[restaurantJob].Fruits[ingredient])
            
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

            -- Check warehouse stock
            local stockResults = MySQL.Sync.fetchAll('SELECT quantity FROM supply_warehouse_stock WHERE ingredient = ?', { ingredient })
            if not stockResults or #stockResults == 0 or stockResults[1].quantity < order.quantity then
                print("[ERROR] Insufficient stock for", ingredient, ":", stockResults[1] and stockResults[1].quantity or 0, "<", order.quantity)
                TriggerClientEvent('ox_lib:notify', workerId, {
                    title = 'Insufficient Stock',
                    description = 'Not enough stock for **' .. (itemNames[ingredient] and itemNames[ingredient].label or ingredient) .. '**',
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
                restaurantId = order.restaurant_id
            })

            table.insert(queries, {
                query = 'UPDATE supply_warehouse_stock SET quantity = quantity - ? WHERE ingredient = ?',
                values = { order.quantity, ingredient }
            })
            table.insert(queries, {
                query = 'UPDATE supply_orders SET status = ? WHERE id = ?',
                values = { 'accepted', order.id }
            })
        end

        MySQL.Async.transaction(queries, function(success)
            if success then
                clearStockCache() -- Clear cache when stock changes
                TriggerClientEvent('warehouse:spawnVehicles', workerId, restaurantId, orders)
                TriggerClientEvent('ox_lib:notify', workerId, {
                    title = 'Order Accepted',
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
    
    if not Config.Restaurants then
        print("[ERROR] Config.Restaurants not loaded in sv_warehouse.lua")
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

    local orderGroupId = orders[1].orderGroupId
    local queries = {}
    local totalCost = 0
    local stashId = "restaurant_stock_" .. tostring(restaurantId)
    
    for _, order in ipairs(orders) do
        local ingredient = order.itemName:lower()
        local quantity = tonumber(order.quantity)
        local orderCost = order.totalCost or 0
        
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
            print("[ERROR] Invalid order data: ingredient or quantity is nil for order ID:", order.id)
        end
    end

    MySQL.Async.transaction(queries, function(success)
        if success then
            clearStockCache() -- Clear cache when stock changes
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Stock Updated',
                description = 'Orders completed and stock updated!',
                type = 'success',
                duration = 10000,
                position = Config.UI.notificationPosition,
                markdown = Config.UI.enableMarkdown
            })
            
            local basePay = totalCost * Config.DriverPayPrec
            local xPlayer = QBCore.Functions.GetPlayer(src)
            
            if xPlayer then
            -- Calculate delivery time and other data
            local deliveryTime = orders[1].deliveryTime or 900 -- Default if missing
            local totalBoxes = 0
            
            -- Calculate total boxes properly
            for _, order in ipairs(orders) do
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
            
            -- THESE EVENTS MUST BE TRIGGERED:
            TriggerEvent('rewards:calculateDeliveryReward', src, {
                basePay = basePay,
                deliveryTime = deliveryTime,
                boxes = totalBoxes,
                orderGroupId = orderGroupId,
                totalCost = totalCost,
                isPerfect = deliveryTime < 1200 -- Under 20 minutes = perfect
            })
            
            TriggerEvent('leaderboard:trackDelivery', src, {
                boxes = totalBoxes,
                deliveryTime = deliveryTime,
                earnings = basePay,
                isPerfect = deliveryTime < 1200
            })
        end
        else
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

-- Get Warehouse Stock
RegisterNetEvent("warehouse:getStocks")
AddEventHandler("warehouse:getStocks", function()
    local src = source
    if not hasWarehouseAccess(src) then
        return -- Silently reject unauthorized access
    end
    local playerId = source
    
    MySQL.Async.fetchAll('SELECT * FROM supply_warehouse_stock', {}, function(results)
        local stock = {}
        for _, item in ipairs(results) do
            stock[item.ingredient:lower()] = item.quantity
        end
        TriggerClientEvent('restaurant:showStockDetails', playerId, stock)
    end)
end)

-- Get Warehouse Stock for Ordering
RegisterNetEvent("warehouse:getStocksForOrder")
AddEventHandler("warehouse:getStocksForOrder", function(restaurantId)
    local src = source
    
    if not Config.Restaurants then
        print("[ERROR] Config.Restaurants not loaded in sv_warehouse.lua")
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Error",
            description = "Configuration not loaded.",
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    -- Simplified restaurant ID validation
    local restaurantData = Config.Restaurants[restaurantId] or Config.Restaurants[tostring(restaurantId)] or Config.Restaurants[tonumber(restaurantId)]
    if not restaurantData then
        print("[ERROR] Restaurant not found with ID:", restaurantId)
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Error",
            description = "Invalid restaurant ID: " .. tostring(restaurantId),
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end

    local restaurantJob = restaurantData.job
    
    -- print("[DEBUG] Original ID:", restaurantId, "Type:", type(restaurantId))
    -- print("[DEBUG] Using ID:", actualRestaurantId, "Type:", type(actualRestaurantId))
    
    if not Config.Restaurants[restaurantId] then
        print("[ERROR] Restaurant not found with any ID variant")
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Error",
            description = "Invalid restaurant ID: " .. tostring(restaurantId),
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end

    local stock = {}
    local dynamicPrices = {}

    -- Get warehouse stock (NOT restaurant stock) - WITH CACHING
    local cacheKey = "warehouse_stock_all"
    local cachedStock = getCache(cacheKey)

    if cachedStock then
        print("[CACHE HIT] Using cached warehouse stock data")
        stock = cachedStock
    else
        local result = MySQL.query.await('SELECT ingredient, quantity FROM supply_warehouse_stock')
        if result then
            for _, row in ipairs(result) do
                stock[row.ingredient] = row.quantity or 0
            end
        end
        setCache(cacheKey, stock)
        print("[CACHE SET] Warehouse stock cached")
    end

    local restaurantJob = Config.Restaurants[restaurantId].job
    if not restaurantJob or not Config.Items[restaurantJob] then
        TriggerClientEvent('ox_lib:notify', src, {
            title = "Error",
            description = "Restaurant job or items not found.",
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end

    local items = Config.Items[restaurantJob]
    for category, categoryItems in pairs(items) do
        for item, details in pairs(categoryItems) do
            dynamicPrices[item] = details.price or 0
        end
    end

    -- print("[DEBUG] Sending back to client with restaurant ID:", actualRestaurantId)
    TriggerClientEvent("restaurant:openOrderMenu", src, { 
        restaurantId = restaurantId, 
        warehouseStock = stock, 
        dynamicPrices = dynamicPrices 
    })
end)