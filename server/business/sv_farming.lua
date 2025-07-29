local QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent('farming:sellFruit')
AddEventHandler('farming:sellFruit', function(fruit, amount)
    local src = source
    local itemCount = exports.ox_inventory:GetItemCount(src, fruit)
    if itemCount >= amount then
        local price = (Config.ItemsFarming.Meats[fruit] or Config.ItemsFarming.Vegetables[fruit] or Config.ItemsFarming.Fruits[fruit]).price
        local total = amount * price
        exports.ox_inventory:RemoveItem(src, fruit, amount)
        local xPlayer = QBCore.Functions.GetPlayer(src)
        xPlayer.Functions.AddMoney('cash', total)
        
        MySQL.Async.fetchAll('SELECT * FROM supply_warehouse_stock WHERE ingredient = ?', {
            fruit:lower()
        }, function(stockResults)
            if #stockResults > 0 then
                MySQL.Async.execute('UPDATE supply_warehouse_stock SET quantity = quantity + ? WHERE ingredient = ?', {
                    amount,
                    fruit:lower()
                })
            else
                MySQL.Async.execute('INSERT INTO supply_warehouse_stock (ingredient, quantity) VALUES (?, ?)', {
                    fruit:lower(),
                    amount
                })
            end
        end)
        
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Sold ' .. amount .. ' ' .. (Config.ItemsFarming.Meats[fruit] or Config.ItemsFarming.Vegetables[fruit] or Config.ItemsFarming.Fruits[fruit]).label,
            description = 'for $' .. total,
            type = 'success',
            duration = 9000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Not enough ' .. (Config.ItemsFarming.Meats[fruit] or Config.ItemsFarming.Vegetables[fruit] or Config.ItemsFarming.Fruits[fruit]).label,
            type = 'error',
            duration = 3000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
    end
end)

-- Bulk selling handler
RegisterNetEvent('farming:sellBulkItems')
AddEventHandler('farming:sellBulkItems', function(cartItems, totalValue)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    -- Verify all items
    local verified = true
    local verifiedTotal = 0
    
    for _, item in ipairs(cartItems) do
        local itemCount = exports.ox_inventory:GetItemCount(src, item.name)
        if itemCount < item.quantity then
            verified = false
            break
        end
        
        -- Recalculate price to prevent exploitation
        local itemConfig = Config.ItemsFarming.Meats[item.name] or 
                          Config.ItemsFarming.Vegetables[item.name] or 
                          Config.ItemsFarming.Fruits[item.name]
        
        if itemConfig then
            verifiedTotal = verifiedTotal + (itemConfig.price * item.quantity)
        else
            verified = false
            break
        end
    end
    
    if not verified or verifiedTotal ~= totalValue then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Sale Failed',
            description = 'Unable to verify items. Please try again.',
            type = 'error',
            duration = 5000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    -- Process the sale
    local itemsSold = {}
    local totalActualValue = 0
    
    for _, item in ipairs(cartItems) do
        -- Remove items
        exports.ox_inventory:RemoveItem(src, item.name, item.quantity)
        
        -- Update warehouse stock
        MySQL.Async.fetchAll('SELECT * FROM supply_warehouse_stock WHERE ingredient = ?', {
            item.name:lower()
        }, function(stockResults)
            if #stockResults > 0 then
                MySQL.Async.execute('UPDATE supply_warehouse_stock SET quantity = quantity + ? WHERE ingredient = ?', {
                    item.quantity,
                    item.name:lower()
                })
            else
                MySQL.Async.execute('INSERT INTO supply_warehouse_stock (ingredient, quantity) VALUES (?, ?)', {
                    item.name:lower(),
                    item.quantity
                })
            end
        end)
        
        -- Track for notification
        table.insert(itemsSold, {
            label = item.label,
            quantity = item.quantity,
            value = item.price * item.quantity
        })
        
        totalActualValue = totalActualValue + (item.price * item.quantity)
    end
    
    -- Give money
    xPlayer.Functions.AddMoney('cash', totalActualValue)
    
    -- Build detailed notification
    local itemsList = ""
    for _, sold in ipairs(itemsSold) do
        itemsList = itemsList .. string.format("• %s x%d - $%d\n", sold.label, sold.quantity, sold.value)
    end
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = '💸 Sale Complete!',
        description = string.format([[
**Items Sold:**
%s
**Total Earned:** $%d

_Warehouse stock updated_]], itemsList, totalActualValue),
        type = 'success',
        duration = 10000,
        position = Config.UI.notificationPosition,
        markdown = true
    })
    
    -- Log the transaction
    print(string.format("[FARMING] %s sold %d items for $%d", 
        GetPlayerName(src), #cartItems, totalActualValue))
end)

-- Container material purchase handler
RegisterNetEvent('containers:buyMaterial')
AddEventHandler('containers:buyMaterial', function(itemName, amount, totalCost)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    -- Verify the price
    local itemData = Config.ContainerMaterials[itemName]
    if not itemData then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Purchase Failed',
            description = 'Invalid item.',
            type = 'error',
            duration = 5000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    local verifiedCost = itemData.price * amount
    if verifiedCost ~= totalCost then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Purchase Failed',
            description = 'Price verification failed.',
            type = 'error',
            duration = 5000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    -- Check money
    if xPlayer.PlayerData.money.cash < totalCost then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Insufficient Funds',
            description = 'Not enough cash. Need $' .. totalCost,
            type = 'error',
            duration = 5000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    -- Process purchase
    xPlayer.Functions.RemoveMoney('cash', totalCost)
    xPlayer.Functions.AddItem(itemName, amount)
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = '✅ Purchase Complete',
        description = string.format([[
**Bought:** %d× %s
**Cost:** $%d
**Use at:** Packaging locations]], amount, itemData.label, totalCost),
        type = 'success',
        duration = 8000,
        position = Config.UI.notificationPosition,
        markdown = true
    })
end)

-- Market prices request handler
RegisterNetEvent('farming:requestMarketPrices')
AddEventHandler('farming:requestMarketPrices', function()
    local src = source
    local marketData = {}
    
    -- Get current prices with trends
    local categories = { "Meats", "Vegetables", "Fruits" }
    
    for _, category in ipairs(categories) do
        local categoryConfig = Config.ItemsFarming[category]
        if categoryConfig then
            for itemName, itemData in pairs(categoryConfig) do
                -- Get warehouse stock levels
                MySQL.Async.fetchScalar('SELECT quantity FROM supply_warehouse_stock WHERE ingredient = ?', 
                {itemName:lower()}, function(stock)
                    local stockLevel = stock or 0
                    
                    -- Get market settings
                    MySQL.Async.fetchAll('SELECT max_stock FROM supply_market_settings WHERE ingredient = ?',
                    {itemName:lower()}, function(settings)
                        local maxStock = (settings and settings[1] and settings[1].max_stock) or 500
                        local percentage = (stockLevel / maxStock) * 100
                        
                        -- Determine trend
                        local trend = "stable"
                        local priceMultiplier = 1.0
                        
                        if percentage <= 20 then
                            trend = "up"
                            priceMultiplier = 1.3 -- 30% increase
                        elseif percentage <= 50 then
                            trend = "up"
                            priceMultiplier = 1.15 -- 15% increase
                        elseif percentage >= 80 then
                            trend = "down"
                            priceMultiplier = 0.85 -- 15% decrease
                        elseif percentage >= 95 then
                            trend = "down"
                            priceMultiplier = 0.7 -- 30% decrease
                        end
                        
                        marketData[itemName] = {
                            currentPrice = math.floor(itemData.price * priceMultiplier),
                            basePrice = itemData.price,
                            trend = trend,
                            stockLevel = stockLevel,
                            percentage = percentage
                        }
                    end)
                end)
            end
        end
    end
    
    -- Wait for queries to complete
    Citizen.SetTimeout(1000, function()
        TriggerClientEvent('seller:displayMarketPrices', src, marketData)
    end)
end)

-- Email notifications for farmers when prices spike
RegisterNetEvent('farming:notifyPriceSpike')
AddEventHandler('farming:notifyPriceSpike', function(ingredient, oldPrice, newPrice)
    local itemNames = exports.ox_inventory:Items() or {}
    local itemLabel = itemNames[ingredient] and itemNames[ingredient].label or ingredient
    local change = ((newPrice - oldPrice) / oldPrice) * 100
    
    -- Get all players
    local players = QBCore.Functions.GetPlayers()
    
    for _, playerId in ipairs(players) do
        local xPlayer = QBCore.Functions.GetPlayer(playerId)
        if xPlayer then
            -- Check if player has farming job or the item in inventory
            local hasItem = exports.ox_inventory:GetItemCount(playerId, ingredient) > 0
            
            if hasItem then
                -- Send notification
                TriggerClientEvent('ox_lib:notify', playerId, {
                    title = '📈 Price Spike Alert!',
                    description = string.format([[
**%s** prices surged **+%.0f%%**!
**New Price:** $%d (was $%d)

Head to the distributor to sell!]], 
                        itemLabel, change, newPrice, oldPrice),
                    type = 'success',
                    duration = 15000,
                    position = Config.UI.notificationPosition,
                    markdown = true
                })
            end
        end
    end
end)