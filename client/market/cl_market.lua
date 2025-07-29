-- DYNAMIC MARKET CLIENT INTERFACE

-- Config safety
local Config = Config or {
    UI = {
        notificationposition = 'top-right',
        enableMarkdown = true
    }
}

-- Market data storage
local currentMarketPrices = {}
local marketOverview = {}

-- Variables (will be linked with cl_restaurant.lua if integrated)
local shoppingCart = {}
local cartBoxCount = 0
local cartTotalCost = 0

-- Function declarations with safe defaults
local function updateCartTotals()
    -- This would normally update cart totals
    -- If integrated with cl_restaurant.lua, this gets overridden
    print("[DEBUG] updateCartTotals called")
end

local function clearCart()
    shoppingCart = {}
    cartBoxCount = 0
    cartTotalCost = 0
    print("[DEBUG] clearCart executed")
end

-- Enhanced restaurant menu with market integration
-- Modified addToCart function with dynamic pricing
local function addToCartWithMarketPrice(ingredient, quantity, label, basePrice)
    -- Get current market price
    TriggerServerEvent('market:getCurrentPrices', {ingredient})
    
    -- Wait for price response (handled in market:receivePrices event)
    Citizen.Wait(100)
    
    local currentPrice = currentMarketPrices[ingredient] or basePrice
    local multiplier = currentPrice / basePrice
    local isHighPrice = multiplier > 1.2
    local isLowPrice = multiplier < 0.9
    
    -- Check if item already in cart
    for i, cartItem in ipairs(shoppingCart) do
        if cartItem.ingredient == ingredient then
            cartItem.quantity = cartItem.quantity + quantity
            cartItem.price = currentPrice -- Update to current market price
            updateCartTotals()
            
            -- Show price change notification
            if isHighPrice then
                lib.notify({
                    title = "💹 Price Alert",
                    description = string.format("**%s** is %.0f%% above normal price due to market conditions!", label, (multiplier - 1) * 100),
                    type = "warning",
                    duration = 8000,
                    position = Config.UI.notificationPosition,
                    markdown = Config.UI.enableMarkdown
                })
            elseif isLowPrice then
                lib.notify({
                    title = "💰 Great Deal",
                    description = string.format("**%s** is %.0f%% below normal price! Great time to buy!", label, (1 - multiplier) * 100),
                    type = "success",
                    duration = 8000,
                    position = Config.UI.notificationPosition,
                    markdown = Config.UI.enableMarkdown
                })
            end
            return
        end
    end
    
    -- Add new item to cart with current market price
    table.insert(shoppingCart, {
        ingredient = ingredient,
        quantity = quantity,
        label = label,
        price = currentPrice,
        basePrice = basePrice,
        multiplier = multiplier
    })
    updateCartTotals()
end

-- Market price receiver
RegisterNetEvent('market:receivePrices')
AddEventHandler('market:receivePrices', function(prices)
    currentMarketPrices = prices
end)

-- Enhanced category menu with live pricing
RegisterNetEvent("restaurant:openCategoryMenuWithPricing")
AddEventHandler("restaurant:openCategoryMenuWithPricing", function(restaurantId, category)
    local restaurantJob = Config.Restaurants[restaurantId].job
    local categoryItems = Config.Items[restaurantJob][category] or {}
    local itemNames = exports.ox_inventory:Items()
    
    -- Get current market prices for all items in this category
    local ingredients = {}
    for ingredient, _ in pairs(categoryItems) do
        table.insert(ingredients, ingredient)
    end
    TriggerServerEvent('market:getCurrentPrices', ingredients)
    
    Citizen.Wait(200) -- Wait for price data
    
    local options = {
        {
            title = "← Back to Categories",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("restaurant:openOrderMenu", {})
            end
        },
        {
            title = "🛒 View Cart (" .. #shoppingCart .. ")",
            description = "📦 " .. cartBoxCount .. " boxes • 💰 $" .. cartTotalCost,
            icon = "fas fa-shopping-cart",
            onSelect = function()
                TriggerEvent("restaurant:openCartMenu", restaurantId)
            end,
            disabled = #shoppingCart == 0
        },
        {
            title = "📊 Market Overview",
            description = "View current market conditions",
            icon = "fas fa-chart-line",
            onSelect = function()
                TriggerServerEvent("market:getOverview")
            end
        }
    }
    
    -- Sort items alphabetically
    local sortedItems = {}
    for ingredient, details in pairs(categoryItems) do
        if type(details) == "table" then
            local itemLabel = itemNames[ingredient] and itemNames[ingredient].label or details.label or details.name or ingredient
            local currentPrice = currentMarketPrices[ingredient] or details.price
            local basePrice = details.price
            local multiplier = currentPrice / basePrice
            
            table.insert(sortedItems, {
                ingredient = ingredient,
                details = details,
                label = itemLabel,
                currentPrice = currentPrice,
                basePrice = basePrice,
                multiplier = multiplier
            })
        end
    end
    table.sort(sortedItems, function(a, b) return a.label < b.label end)
    
    -- Add items to menu with dynamic pricing
    for _, item in ipairs(sortedItems) do
        local priceIcon = "💰"
        local priceColor = ""
        local changeText = ""
        
        if item.multiplier > 1.2 then
            priceIcon = "📈"
            priceColor = " ⚠️"
            changeText = string.format(" (+%.0f%%)", (item.multiplier - 1) * 100)
        elseif item.multiplier < 0.9 then
            priceIcon = "💸"
            priceColor = " 🟢"
            changeText = string.format(" (-%.0f%%)", (1 - item.multiplier) * 100)
        elseif item.multiplier ~= 1.0 then
            changeText = string.format(" (%.0f%%)", (item.multiplier - 1) * 100)
        end
        
        table.insert(options, {
            title = item.label .. priceColor,
            description = string.format("%s **$%d** %s%s", priceIcon, item.currentPrice, item.basePrice ~= item.currentPrice and "(was $" .. item.basePrice .. ")" or "", changeText),
            metadata = {
                ["Current Price"] = "$" .. item.currentPrice,
                ["Base Price"] = "$" .. item.basePrice,
                ["Market Change"] = changeText ~= "" and changeText or "No change",
                ["Category"] = category
            },
            onSelect = function()
                local input = lib.inputDialog("Add " .. item.label .. " to Cart", {
                    { 
                        type = "number", 
                        label = "Quantity", 
                        placeholder = "Enter amount", 
                        min = 1, 
                        max = 999, 
                        required = true 
                    }
                })
                if input and input[1] and tonumber(input[1]) > 0 then
                    local quantity = tonumber(input[1])
                    addToCartWithMarketPrice(item.ingredient, quantity, item.label, item.basePrice)
                    
                    local totalCost = item.currentPrice * quantity
                    lib.notify({
                        title = "Added to Cart",
                        description = string.format("%dx %s - $%d%s", quantity, item.label, totalCost, changeText),
                        type = "success",
                        duration = 5000,
                        position = Config.UI.notificationPosition,
                        markdown = Config.UI.enableMarkdown
                    })
                    
                    -- Refresh menu to show updated cart
                    TriggerEvent("restaurant:openCategoryMenuWithPricing", restaurantId, category)
                end
            end
        })
    end
    
    lib.registerContext({
        id = "category_menu_pricing",
        title = category .. " - Live Market Prices",
        options = options
    })
    lib.showContext("category_menu_pricing")
end)

-- Market Overview Display
RegisterNetEvent('market:showOverview')
AddEventHandler('market:showOverview', function(overview)
    local options = {
        {
            title = "← Back to Menu",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("restaurant:openOrderMenu", {})
            end
        },
        {
            title = "📊 Market Status: " .. overview.marketStatus:gsub("_", " "):gsub("^%l", string.upper),
            description = string.format(
                "📈 Average multiplier: **%.2fx**\n📦 %d items tracked\n🔥 %d active events",
                overview.averageMultiplier,
                overview.totalItems,
                #overview.activeEvents
            ),
            disabled = true
        }
    }
    
    -- Show active market events
    if #overview.activeEvents > 0 then
        table.insert(options, {
            title = "🚨 Active Market Events",
            description = "Special pricing conditions currently active",
            disabled = true
        })
        
        for _, event in ipairs(overview.activeEvents) do
            local itemNames = exports.ox_inventory:Items() or {}
            local itemLabel = itemNames[event.ingredient] and itemNames[event.ingredient].label or event.ingredient
            local eventIcon = event.type == "shortage" and "🚨" or "💰"
            local timeRemaining = math.floor(event.timeRemaining / 60)
            
            table.insert(options, {
                title = eventIcon .. " " .. itemLabel,
                description = string.format(
                    "%s event: **%.1fx** pricing\n⏰ %d minutes remaining",
                    event.type:gsub("^%l", string.upper),
                    event.multiplier,
                    timeRemaining
                ),
                onSelect = function()
                    TriggerServerEvent('market:getPriceHistory', event.ingredient)
                end
            })
        end
    end
    
    -- Show top price movers
    if #overview.topMovers > 0 then
        table.insert(options, {
            title = "📈 Top Price Movers",
            description = "Items with biggest price changes",
            disabled = true
        })
        
        for i, mover in ipairs(overview.topMovers) do
            if i > 5 then break end -- Show only top 5
            
            local itemNames = exports.ox_inventory:Items() or {}
            local itemLabel = itemNames[mover.ingredient] and itemNames[mover.ingredient].label or mover.ingredient
            local changeIcon = mover.change > 0 and "📈" or "📉"
            local changeColor = mover.change > 0 and "⚠️" or "🟢"
            
            table.insert(options, {
                title = changeIcon .. " " .. itemLabel .. " " .. changeColor,
                description = string.format(
                    "**$%d** (was $%d) • **%+.1f%%** change",
                    mover.currentPrice,
                    mover.basePrice,
                    mover.change
                ),
                metadata = {
                    ["Current Price"] = "$" .. mover.currentPrice,
                    ["Base Price"] = "$" .. mover.basePrice,
                    ["Change"] = string.format("%+.1f%%", mover.change),
                    ["Multiplier"] = string.format("%.2fx", mover.multiplier)
                },
                onSelect = function()
                    TriggerServerEvent('market:getPriceHistory', mover.ingredient)
                end
            })
        end
    end
    
    table.insert(options, {
        title = "🔄 Refresh Market Data",
        description = "Update current market information",
        icon = "fas fa-sync",
        onSelect = function()
            TriggerServerEvent("market:getOverview")
        end
    })
    
    lib.registerContext({
        id = "market_overview",
        title = "📊 Market Overview",
        options = options
    })
    lib.showContext("market_overview")
end)

-- Price History Display
RegisterNetEvent('market:showPriceHistory')
AddEventHandler('market:showPriceHistory', function(ingredient, history, returnContext)
    local itemNames = exports.ox_inventory:Items() or {}
    local itemLabel = itemNames[ingredient] and itemNames[ingredient].label or ingredient
    
    local options = {
        {
            title = "← Back to Menu",
            icon = "fas fa-arrow-left",
            onSelect = function()
                if returnContext == "restaurant" then
                    TriggerEvent("restaurant:openMainMenu")
                else
                    TriggerServerEvent("market:getOverview")
                end
            end
        }
    }
    
    if not history or #history == 0 then
        table.insert(options, {
            title = "No Price History",
            description = "Not enough data available for this item",
            disabled = true
        })
    else
        -- Calculate price statistics
        local minPrice = math.huge
        local maxPrice = 0
        local totalPrice = 0
        
        for _, record in ipairs(history) do
            minPrice = math.min(minPrice, record.price)
            maxPrice = math.max(maxPrice, record.price)
            totalPrice = totalPrice + record.price
        end
        
        local avgPrice = totalPrice / #history
        local currentPrice = history[#history].price
        local basePrice = history[#history].basePrice
        
        table.insert(options, {
            title = "📊 Price Statistics (24h)",
            description = string.format(
                "Current: **$%d** • Average: **$%.0f**\nHigh: **$%d** • Low: **$%d**\nBase Price: **$%d**",
                currentPrice,
                avgPrice,
                maxPrice,
                minPrice,
                basePrice
            ),
            disabled = true
        })
        
        -- Show recent price points (use server-provided time text)
        if #history > 0 then
            table.insert(options, {
                title = "📈 Recent Price Movement",
                description = "Latest price changes",
                disabled = true
            })
            
            for i = math.max(1, #history - 5), #history do
                local record = history[i]
                
                -- Use server-provided timeText instead of calculating client-side
                local timeText = record.timeText or "Unknown time"
                
                local multiplierText = string.format("%.2fx", record.multiplier or 1.0)
                local changeIcon = (record.multiplier or 1.0) > 1.1 and "📈" or (record.multiplier or 1.0) < 0.9 and "📉" or "➡️"
                
                table.insert(options, {
                    title = changeIcon .. " $" .. record.price .. " (" .. multiplierText .. ")",
                    description = timeText,
                    disabled = true
                })
            end
        end
    end
    
    lib.registerContext({
        id = "price_history",
        title = "📈 " .. itemLabel .. " - Price History",
        options = options
    })
    lib.showContext("price_history")
end)

-- Enhanced shopping cart with market pricing awareness
RegisterNetEvent("restaurant:openCartMenuWithPricing")
AddEventHandler("restaurant:openCartMenuWithPricing", function(restaurantId)
    local options = {
        {
            title = "← Back to Categories",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("restaurant:openOrderMenu", { restaurantId = restaurantId })
            end
        }
    }
    
    if #shoppingCart == 0 then
        table.insert(options, {
            title = "Cart is Empty",
            description = "Add items from the categories",
            disabled = true
        })
    else
        -- Calculate market impact
        local totalSavings = 0
        local totalOvercharge = 0
        
        for _, cartItem in ipairs(shoppingCart) do
            local baseTotal = cartItem.basePrice * cartItem.quantity
            local currentTotal = cartItem.price * cartItem.quantity
            local difference = currentTotal - baseTotal
            
            if difference > 0 then
                totalOvercharge = totalOvercharge + difference
            else
                totalSavings = totalSavings + math.abs(difference)
            end
        end
        
        -- Cart summary with market impact
        local summaryText = string.format("📦 %d boxes needed • 💰 Total: $%d", cartBoxCount, cartTotalCost)
        
        if totalSavings > 0 then
            summaryText = summaryText .. string.format("\n💸 You're saving $%d vs base prices!", totalSavings)
        elseif totalOvercharge > 0 then
            summaryText = summaryText .. string.format("\n📈 Market premium: +$%d vs base prices", totalOvercharge)
        end
        
        table.insert(options, {
            title = "📋 Order Summary",
            description = summaryText,
            disabled = true
        })
        
        -- Cart items with price indicators
        for i, cartItem in ipairs(shoppingCart) do
            local priceIndicator = ""
            local multiplier = cartItem.price / cartItem.basePrice
            
            if multiplier > 1.1 then
                priceIndicator = " 📈"
            elseif multiplier < 0.9 then
                priceIndicator = " 💸"
            end
            
            table.insert(options, {
                title = cartItem.quantity .. "x " .. cartItem.label .. priceIndicator,
                description = string.format(
                    "$%d each • Subtotal: $%d%s",
                    cartItem.price,
                    cartItem.price * cartItem.quantity,
                    cartItem.price ~= cartItem.basePrice and string.format(" (base: $%d)", cartItem.basePrice) or ""
                ),
                icon = "fas fa-times",
                onSelect = function()
                    table.remove(shoppingCart, i)
                    updateCartTotals()
                    lib.notify({
                        title = "Removed from Cart",
                        description = cartItem.label .. " removed",
                        type = "info",
                        duration = 3000,
                        position = Config.UI.notificationPosition,
                        markdown = Config.UI.enableMarkdown
                    })
                    TriggerEvent("restaurant:openCartMenuWithPricing", restaurantId)
                end
            })
        end
        
        -- Action buttons
        table.insert(options, {
            title = "🗑️ Clear Cart",
            description = "Remove all items",
            icon = "fas fa-trash",
            onSelect = function()
                clearCart()
                lib.notify({
                    title = "Cart Cleared",
                    description = "All items removed from cart",
                    type = "info",
                    duration = 3000,
                    position = Config.UI.notificationPosition,
                    markdown = Config.UI.enableMarkdown
                })
                TriggerEvent("restaurant:openCartMenuWithPricing", restaurantId)
            end
        })
        
        table.insert(options, {
            title = "✅ Submit Order",
            description = string.format("Place order for $%d (%d boxes)", cartTotalCost, cartBoxCount),
            icon = "fas fa-check",
            onSelect = function()
                if #shoppingCart == 0 then
                    lib.notify({
                        title = "Error",
                        description = "Cart is empty",
                        type = "error",
                        duration = 5000,
                        position = Config.UI.notificationPosition,
                        markdown = Config.UI.enableMarkdown
                    })
                    return
                end
                
                -- Convert cart to order format
                local orderItems = {}
                for _, cartItem in ipairs(shoppingCart) do
                    table.insert(orderItems, {
                        ingredient = cartItem.ingredient,
                        quantity = cartItem.quantity,
                        label = cartItem.label,
                        price = cartItem.price -- Use current market price
                    })
                end
                
                TriggerServerEvent("restaurant:orderIngredientsWithMarketPricing", orderItems, restaurantId)
                clearCart()
                
                lib.notify({
                    title = "Order Submitted",
                    description = string.format("Order sent to warehouse (%d boxes) at current market prices", cartBoxCount),
                    type = "success",
                    duration = 10000,
                    position = Config.UI.notificationPosition,
                    markdown = Config.UI.enableMarkdown
                })
            end
        })
    end
    
    lib.registerContext({
        id = "cart_menu_pricing",
        title = "🛒 Shopping Cart - Market Pricing",
        options = options
    })
    lib.showContext("cart_menu_pricing")
end)

-- Market alerts for price changes
RegisterNetEvent('market:priceAlert')
AddEventHandler('market:priceAlert', function(ingredient, oldPrice, newPrice, eventType)
    local itemNames = exports.ox_inventory:Items() or {}
    local itemLabel = itemNames[ingredient] and itemNames[ingredient].label or ingredient
    local change = ((newPrice - oldPrice) / oldPrice) * 100
    
    local title, description, alertType, icon
    
    if eventType == "shortage" then
        title = "🚨 SHORTAGE ALERT"
        description = string.format("**%s** shortage! Price increased to **$%d** (+%.1f%%)", itemLabel, newPrice, change)
        alertType = "error"
    elseif eventType == "surplus" then
        title = "💰 SURPLUS ALERT"
        description = string.format("**%s** surplus! Price reduced to **$%d** (-%.1f%%)", itemLabel, newPrice, math.abs(change))
        alertType = "success"
    elseif change > 20 then
        title = "📈 PRICE SPIKE"
        description = string.format("**%s** price jumped to **$%d** (+%.1f%%)", itemLabel, newPrice, change)
        alertType = "warning"
    elseif change < -20 then
        title = "📉 PRICE DROP"
        description = string.format("**%s** price dropped to **$%d** (-%.1f%%)", itemLabel, newPrice, math.abs(change))
        alertType = "success"
    else
        return -- Don't show alerts for small changes
    end
    
    lib.notify({
        title = title,
        description = description,
        type = alertType,
        duration = 8000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })
end)