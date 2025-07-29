-- EMERGENCY RUSH ORDER SYSTEM
-- Add to sv_stock_alerts.lua or create sv_emergency_orders.lua

local QBCore = exports['qb-core']:GetCoreObject()

-- Active emergency orders
local activeEmergencyOrders = {}

-- Check for emergency conditions
local function checkEmergencyConditions()
    -- Check restaurant stockouts
    MySQL.Async.fetchAll([[
        SELECT r.restaurant_id, r.ingredient, 
               COALESCE(rs.quantity, 0) as restaurant_stock,
               COALESCE(ws.quantity, 0) as warehouse_stock
        FROM (
            SELECT DISTINCT restaurant_id, ingredient 
            FROM supply_orders 
            WHERE created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
        ) r
        LEFT JOIN supply_stock rs ON r.restaurant_id = rs.restaurant_id AND r.ingredient = rs.ingredient
        LEFT JOIN supply_warehouse_stock ws ON r.ingredient = ws.ingredient
        WHERE COALESCE(rs.quantity, 0) <= ? OR COALESCE(ws.quantity, 0) <= ?
    ]], {Config.EmergencyOrders.triggers.criticalStock, Config.EmergencyOrders.triggers.criticalStock}, function(results)
        
        for _, shortage in ipairs(results) do
            local emergencyKey = shortage.restaurant_id .. "_" .. shortage.ingredient
            
            -- Skip if emergency already active
            if activeEmergencyOrders[emergencyKey] then
                goto continue
            end
            
            local priorityLevel = "emergency"
            local restaurantStock = shortage.restaurant_stock or 0
            local warehouseStock = shortage.warehouse_stock or 0
            
            -- Determine priority level
            if restaurantStock == 0 and warehouseStock == 0 then
                priorityLevel = "critical"
            elseif restaurantStock == 0 or warehouseStock <= 2 then
                priorityLevel = "urgent"
            end
            
            createEmergencyOrder(shortage.restaurant_id, shortage.ingredient, priorityLevel, {
                restaurantStock = restaurantStock,
                warehouseStock = warehouseStock
            })
            
            ::continue::
        end
    end)
end

-- Create emergency order
function createEmergencyOrder(restaurantId, ingredient, priority, stockData)
    local emergencyKey = restaurantId .. "_" .. ingredient
    local priorityConfig = Config.EmergencyOrders.priorities[priority]
    local currentTime = os.time()
    
    -- Create emergency order record
    activeEmergencyOrders[emergencyKey] = {
        restaurantId = restaurantId,
        ingredient = ingredient,
        priority = priority,
        priorityLevel = priorityConfig.level,
        createdAt = currentTime,
        expiresAt = currentTime + priorityConfig.timeout,
        stockData = stockData,
        claimed = false,
        completed = false
    }
    
    -- Get item details
    local itemNames = exports.ox_inventory:Items() or {}
    local itemLabel = itemNames[ingredient] and itemNames[ingredient].label or ingredient
    local restaurantName = Config.Restaurants[restaurantId] and Config.Restaurants[restaurantId].name or "Restaurant"
    
    -- Calculate emergency pay
    local basePrice = getBasePriceForIngredient(ingredient) or 10
    local emergencyPay = math.floor(basePrice * 50 * Config.EmergencyOrders.bonuses.emergencyMultiplier)
    
    -- Broadcast to drivers
    local players = QBCore.Functions.GetPlayers()
    for _, playerId in ipairs(players) do
        local xPlayer = QBCore.Functions.GetPlayer(playerId)
        if xPlayer then
            local playerJob = xPlayer.PlayerData.job.name
            
            -- Send to warehouse workers and truck drivers
            if playerJob == "warehouse" or playerJob == "trucker" or priorityConfig.broadcastToAll then
                TriggerClientEvent('emergency:newOrder', playerId, {
                    emergencyKey = emergencyKey,
                    restaurantId = restaurantId,
                    restaurantName = restaurantName,
                    ingredient = ingredient,
                    itemLabel = itemLabel,
                    priority = priority,
                    priorityName = priorityConfig.name,
                    emergencyPay = emergencyPay,
                    stockData = stockData,
                    timeRemaining = priorityConfig.timeout
                })
                
                -- Play emergency sound for critical orders
                if priority == "critical" then
                    TriggerClientEvent('emergency:playAlarm', playerId)
                end
            end
        end
    end
    
    -- Log emergency event
    MySQL.Async.execute([[
        INSERT INTO supply_emergency_orders (
            restaurant_id, ingredient, priority_level, quantity_needed,
            bonus_multiplier, timeout_minutes
        ) VALUES (?, ?, ?, ?, ?, ?)
    ]], {
        restaurantId,           -- restaurant_id
        ingredient,             -- ingredient
        priority,               -- priority_level (emergency/urgent/critical)
        quantityNeeded or 50,   -- quantity_needed
        1.5,                    -- bonus_multiplier (default 1.5)
        30                      -- timeout_minutes (30 min emergency)
    })
    
    print(string.format("[EMERGENCY] %s order created: %s for %s (Pay: $%d)", 
        priorityConfig.name, itemLabel, restaurantName, emergencyPay))
end

-- Claim emergency order
RegisterNetEvent('emergency:claimOrder')
AddEventHandler('emergency:claimOrder', function(emergencyKey)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    local emergency = activeEmergencyOrders[emergencyKey]
    if not emergency or emergency.claimed then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Emergency Order Unavailable',
            description = 'This emergency order is no longer available.',
            type = 'error',
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    -- Mark as claimed
    emergency.claimed = true
    emergency.claimedBy = xPlayer.PlayerData.citizenid
    emergency.claimedAt = os.time()
    
    local itemNames = exports.ox_inventory:Items() or {}
    local itemLabel = itemNames[emergency.ingredient] and itemNames[emergency.ingredient].label or emergency.ingredient
    local priorityConfig = Config.EmergencyOrders.priorities[emergency.priority]
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = '🚨 Emergency Order Claimed!',
        description = string.format(
            '%s **%s** emergency claimed!\nDeliver to %s ASAP for bonus pay!',
            priorityConfig.name,
            itemLabel,
            Config.Restaurants[emergency.restaurantId].name
        ),
        type = 'success',
        duration = 12000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })
    
    -- Start emergency delivery process
    TriggerEvent('emergency:startDelivery', src, emergencyKey)
    
    -- Notify other drivers it's claimed
    local players = QBCore.Functions.GetPlayers()
    for _, playerId in ipairs(players) do
        if playerId ~= src then
            TriggerClientEvent('emergency:orderClaimed', playerId, emergencyKey, xPlayer.PlayerData.charinfo.firstname .. ' ' .. xPlayer.PlayerData.charinfo.lastname)
        end
    end
end)

-- Complete emergency order
RegisterNetEvent('emergency:completeOrder')
AddEventHandler('emergency:completeOrder', function(emergencyKey, deliveryTime)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    local emergency = activeEmergencyOrders[emergencyKey]
    if not emergency or emergency.completed then return end
    
    -- Mark as completed
    emergency.completed = true
    emergency.completedAt = os.time()
    emergency.deliveryTime = deliveryTime
    
    -- Calculate emergency pay with bonuses
    local basePrice = getBasePriceForIngredient(emergency.ingredient) or 10
    local basePay = math.floor(basePrice * 50)
    local priorityMultiplier = Config.EmergencyOrders.bonuses[emergency.priority .. "Multiplier"] or 2.0
    local emergencyPay = math.floor(basePay * priorityMultiplier)
    
    -- Speed bonus for fast delivery
    if deliveryTime <= 600 then -- Under 10 minutes
        emergencyPay = emergencyPay + Config.EmergencyOrders.bonuses.speedBonus
    end
    
    -- Hero bonus for preventing complete stockout
    if emergency.stockData.restaurantStock == 0 then
        emergencyPay = emergencyPay + Config.EmergencyOrders.bonuses.heroBonus
    end
    
    -- Pay the driver
    xPlayer.Functions.AddMoney('bank', emergencyPay, "Emergency delivery bonus")
    
    local itemNames = exports.ox_inventory:Items() or {}
    local itemLabel = itemNames[emergency.ingredient] and itemNames[emergency.ingredient].label or emergency.ingredient
    local priorityConfig = Config.EmergencyOrders.priorities[emergency.priority]
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = '🏆 EMERGENCY HERO!',
        description = string.format(
            '%s emergency completed!\n💰 **$%d** emergency bonus paid!\n⚡ Delivery time: %d minutes',
            priorityConfig.name,
            emergencyPay,
            math.floor(deliveryTime / 60)
        ),
        type = 'success',
        duration = 15000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })
    
    -- Update database
    MySQL.Async.execute([[
        UPDATE supply_emergency_orders 
        SET completed = 1, completed_by = ?, delivery_time = ?, emergency_pay_actual = ?
        WHERE restaurant_id = ? AND ingredient = ? AND created_at = ?
    ]], {
        xPlayer.PlayerData.citizenid, deliveryTime, emergencyPay,
        emergency.restaurantId, emergency.ingredient, emergency.createdAt
    })
    
    -- Clean up
    activeEmergencyOrders[emergencyKey] = nil
    
    print(string.format("[EMERGENCY] Order completed by %s: %s for %s (Pay: $%d, Time: %ds)", 
        xPlayer.PlayerData.charinfo.firstname, itemLabel, Config.Restaurants[emergency.restaurantId].name, emergencyPay, deliveryTime))
end)

-- Get active emergency orders
RegisterNetEvent('emergency:getActiveOrders')
AddEventHandler('emergency:getActiveOrders', function()
    local src = source
    local currentTime = os.time()
    local activeOrders = {}
    
    for emergencyKey, emergency in pairs(activeEmergencyOrders) do
        if not emergency.completed and currentTime < emergency.expiresAt then
            local itemNames = exports.ox_inventory:Items() or {}
            local itemLabel = itemNames[emergency.ingredient] and itemNames[emergency.ingredient].label or emergency.ingredient
            local timeRemaining = emergency.expiresAt - currentTime
            
            table.insert(activeOrders, {
                emergencyKey = emergencyKey,
                restaurantId = emergency.restaurantId,
                restaurantName = Config.Restaurants[emergency.restaurantId].name,
                ingredient = emergency.ingredient,
                itemLabel = itemLabel,
                priority = emergency.priority,
                priorityLevel = emergency.priorityLevel,
                timeRemaining = timeRemaining,
                claimed = emergency.claimed,
                claimedBy = emergency.claimedBy,
                stockData = emergency.stockData
            })
        end
    end
    
    -- Sort by priority level (highest first)
    table.sort(activeOrders, function(a, b)
        return a.priorityLevel > b.priorityLevel
    end)
    
    TriggerClientEvent('emergency:showActiveOrders', src, activeOrders)
end)

-- Clean up expired emergency orders
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(60000) -- Check every minute
        
        local currentTime = os.time()
        for emergencyKey, emergency in pairs(activeEmergencyOrders) do
            if currentTime > emergency.expiresAt then
                print("[EMERGENCY] Order expired: " .. emergencyKey)
                activeEmergencyOrders[emergencyKey] = nil
            end
        end
    end
end)

-- Start emergency monitoring
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(180000) -- Check every 3 minutes
        if Config.EmergencyOrders.enabled then
            checkEmergencyConditions()
        end
    end
end)

-- Initialize emergency system
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        Citizen.Wait(15000) -- Wait for other systems
        print("[EMERGENCY] Emergency order system initialized!")
    end
end)