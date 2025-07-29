local QBCore = exports['qb-core']:GetCoreObject()

-- Simple variables - no complex state tracking
local currentOrder = {}

-- Restaurant Computer Targets  
Citizen.CreateThread(function()
    for id, restaurant in pairs(Config.Restaurants) do
        exports.ox_target:addBoxZone({
            coords = restaurant.position,
            size = vector3(2.0, 2.0, 1.5),
            rotation = restaurant.heading,
            debug = true,
            options = {
                {
                    name = "restaurant_computer_" .. id,
                    icon = "fas fa-laptop",
                    label = "Order Ingredients",
                    onSelect = function()
                    -- Add animation for ordering
                    local animDict = "anim@heists@prison_heiststation@cop_reactions"
                    local animName = "cop_b_idle"
                    RequestAnimDict(animDict)
                    while not HasAnimDictLoaded(animDict) do
                        Wait(10)
                    end
                    TaskPlayAnim(PlayerPedId(), animDict, animName, 8.0, -8.0, 1500, 0, 0, false, false, false)
                    
                    Wait(1500)
                        TriggerEvent("restaurant:openOrderMenu", { restaurantId = id })
                    end,
                    groups = restaurant.job
                }
            }
        })
    end
end)

-- Order Menu - Simple approach like original
local shoppingCart = {}
local cartTotalCost = 0
local cartBoxCount = 0

-- Clear cart function
local function clearCart()
    shoppingCart = {}
    cartTotalCost = 0
    cartBoxCount = 0
end

-- Calculate boxes needed (configurable items per box)
local function calculateBoxes(totalItems)
    local containersNeeded = math.ceil(totalItems / Config.ContainerSystem.itemsPerContainer)
    local boxesNeeded = math.ceil(containersNeeded / Config.ContainerSystem.containersPerBox)
    return boxesNeeded, containersNeeded
end

-- Calculate cart totals
local function updateCartTotals()
    cartTotalCost = 0
    local totalItems = 0
    
    for _, cartItem in ipairs(shoppingCart) do
        cartTotalCost = cartTotalCost + (cartItem.price * cartItem.quantity)
        totalItems = totalItems + cartItem.quantity
    end
    
    local boxesNeeded, containersNeeded = calculateBoxes(totalItems)
    cartBoxCount = boxesNeeded
    cartContainerCount = containersNeeded
end

-- Add item to cart
local function addToCart(ingredient, quantity, label, price)
    -- Check if item already in cart
    for i, cartItem in ipairs(shoppingCart) do
        if cartItem.ingredient == ingredient then
            cartItem.quantity = cartItem.quantity + quantity
            updateCartTotals()
            return
        end
    end
    
    -- Add new item to cart
    table.insert(shoppingCart, {
        ingredient = ingredient,
        quantity = quantity,
        label = label,
        price = price
    })
    updateCartTotals()
end

-- Remove item from cart
local function removeFromCart(index)
    table.remove(shoppingCart, index)
    updateCartTotals()
end

-- Main Order Menu with Categories
RegisterNetEvent("restaurant:openOrderMenu")
AddEventHandler("restaurant:openOrderMenu", function(data)
    local PlayerData = QBCore.Functions.GetPlayerData()
    local PlayerJob = PlayerData.job
    if not PlayerJob or not PlayerJob.name or not PlayerJob.isboss then
        lib.notify({
            title = "Error",
            description = "You do not have permission to access this menu.",
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end

    local restaurantId = data.restaurantId
    if type(restaurantId) ~= "number" and type(restaurantId) ~= "string" then
        lib.notify({
            title = "Error",
            description = "Invalid restaurant ID.",
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end

    local restaurantJob = Config.Restaurants[restaurantId].job
    local items = Config.Items[restaurantJob] or {}
    
    -- Main menu with categories
    local options = {
        {
            title = "🛒 Shopping Cart (" .. #shoppingCart .. " items)",
            description = "📦 " .. cartBoxCount .. " boxes • 💰 $" .. cartTotalCost,
            icon = "fas fa-shopping-cart",
            onSelect = function()
                TriggerEvent("restaurant:openCartMenu", restaurantId)
            end,
            disabled = #shoppingCart == 0
        },
        { 
            title = "📦 Order Goods", 
            description = "Browse and order supplies for the restaurant",
            icon = "fas fa-shopping-cart",
            onSelect = function() 
                TriggerEvent("restaurant:openOrderGoodsMenu", restaurantId) 
            end 
        },
        { 
            title = "📋 Current Orders",
            description = "View pending and active delivery orders", 
            icon = "fas fa-clipboard-list",
            onSelect = function()
                TriggerServerEvent("restaurant:getCurrentOrders", restaurantId)
            end
        },
        { 
            title = "📦 View Stock", 
            description = "Check current restaurant inventory",
            icon = "fas fa-warehouse",
            onSelect = function() 
                TriggerServerEvent("restaurant:requestStock", restaurantId) 
            end 
        },
        { 
            title = "❓ Help & Tips",
            description = "Learn how to maximize your restaurant operations",
            icon = "fas fa-question-circle",
            onSelect = function()
                TriggerEvent("restaurant:openHelpMenu", restaurantId)
            end
        }
    }
    
    lib.registerContext({
        id = "order_main_menu",
        title = "🍔 Restaurant Management System",
        options = options
    })
    lib.showContext("order_main_menu")
end)

-- Help Menu Handler
RegisterNetEvent("restaurant:openHelpMenu")
AddEventHandler("restaurant:openHelpMenu", function(restaurantId)
    local options = {
        {
            title = "← Back to Main Menu",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("restaurant:openOrderMenu", { restaurantId = restaurantId })
            end
        },
        {
            title = "📦 Container System Explained",
            description = "Understanding boxes and containers",
            icon = "fas fa-box",
            onSelect = function()
                lib.notify({
                    title = "📦 Container System",
                    description = [[
**How it works:**
• 12 items = 1 container
• 5 containers = 1 delivery box
• Drivers deliver by the box

**Example:** 100 tomatoes = 9 containers = 2 boxes]],
                    type = "info",
                    duration = 15000,
                    position = Config.UI.notificationPosition,
                    markdown = true
                })
            end
        },
        {
            title = "🌍 Import vs Regular Orders",
            description = "Learn about our dual warehouse system",
            icon = "fas fa-globe",
            onSelect = function()
                lib.notify({
                    title = "🌍 Import System",
                    description = [[
**Regular Items:** 
• Delivered from Main Warehouse
• Standard pricing
• Faster delivery times

**Import Items (🌍):**
• Premium global ingredients
• 25% markup for quality
• Delivered from Import Center
• Worth the wait!]],
                    type = "info",
                    duration = 15000,
                    position = Config.UI.notificationPosition,
                    markdown = true
                })
            end
        },
        {
            title = "🤝 Building Driver Relationships",
            description = "Tips for great driver partnerships",
            icon = "fas fa-handshake",
            onSelect = function()
                lib.notify({
                    title = "🤝 Driver Relations",
                    description = [[
**Build loyalty by:**
• Ordering regularly (keeps drivers busy)
• Large orders = bigger driver bonuses
• Emergency orders pay drivers extra
• Team deliveries build community

**Happy drivers = Priority service!**]],
                    type = "info",
                    duration = 15000,
                    position = Config.UI.notificationPosition,
                    markdown = true
                })
            end
        },
        {
            title = "📈 Market Timing Strategy",
            description = "When to buy for best prices",
            icon = "fas fa-chart-line",
            onSelect = function()
                lib.notify({
                    title = "📈 Smart Ordering",
                    description = [[
**Price Patterns:**
• 🟢 Green = Surplus (20-30% cheaper!)
• 🟡 Yellow = Normal pricing
• 🔴 Red = Shortage (30%+ markup)

**Pro Tips:**
• Check price history before ordering
• Buy during surplus events
• Stock up when prices drop
• Emergency orders cost more!]],
                    type = "info",
                    duration = 15000,
                    position = Config.UI.notificationPosition,
                    markdown = true
                })
            end
        },
        {
            title = "💡 Stock Management Tips",
            description = "Optimize your inventory",
            icon = "fas fa-lightbulb",
            onSelect = function()
                lib.notify({
                    title = "💡 Pro Tips",
                    description = [[
**Inventory Best Practices:**
• Keep 2-3 days stock minimum
• Order before hitting critical levels
• Use stock alerts to stay informed
• Monitor fast-moving items closely

**Save Money:**
• Bulk orders reduce delivery frequency
• Watch for market surplus events
• Quick reorder saves time]],
                    type = "info",
                    duration = 15000,
                    position = Config.UI.notificationPosition,
                    markdown = true
                })
            end
        },
        {
            title = "🚀 Quick Actions Guide",
            description = "Keyboard shortcuts & tips",
            icon = "fas fa-keyboard",
            onSelect = function()
                lib.notify({
                    title = "🚀 Quick Tips",
                    description = [[
**Navigation:**
• ESC = Close/Back
• Arrow Keys = Navigate
• Enter = Select

**Shopping Tips:**
• Cart saves between categories
• Remove items by clicking them
• Submit when ready
• Clear cart to start over]],
                    type = "info",
                    duration = 12000,
                    position = Config.UI.notificationPosition,
                    markdown = true
                })
            end
        }
    }
    
    lib.registerContext({
        id = "restaurant_help_menu",
        title = "❓ Restaurant Help & Tips",
        options = options
    })
    lib.showContext("restaurant_help_menu")
end)

-- Category Menu (Meats, Vegetables, etc.)
RegisterNetEvent("restaurant:openCategoryMenu")
AddEventHandler("restaurant:openCategoryMenu", function(restaurantId, category)
    local restaurantJob = Config.Restaurants[restaurantId].job
    local categoryItems = Config.Items[restaurantJob][category] or {}
    local itemNames = exports.ox_inventory:Items()
    
    -- Category icons and colors
    local categoryInfo = {
        Meats = { icon = "🥩", color = "#E74C3C" },
        Vegetables = { icon = "🥬", color = "#27AE60" },
        Fruits = { icon = "🍎", color = "#E67E22" },
        Dairy = { icon = "🧀", color = "#F39C12" },
        DryGoods = { icon = "🌾", color = "#8B6914" },
        Beverages = { icon = "🥤", color = "#3498DB" },
        Seafood = { icon = "🦐", color = "#5DADE2" }
    }
    
    local catInfo = categoryInfo[category] or { icon = "📦", color = "#95A5A6" }
    
    local options = {
        {
            title = "← Back to Categories",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("restaurant:openOrderMenu", { restaurantId = restaurantId })
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
        }
    }
    
    -- Sort items alphabetically
    local sortedItems = {}
    for ingredient, details in pairs(categoryItems) do
        if type(details) == "table" then
            local itemLabel = itemNames[ingredient] and itemNames[ingredient].label or details.label or details.name or ingredient
            table.insert(sortedItems, {
                ingredient = ingredient,
                details = details,
                label = itemLabel
            })
        end
    end
    table.sort(sortedItems, function(a, b) return a.label < b.label end)
    
    -- Add items to menu with enhanced visuals
    for _, item in ipairs(sortedItems) do
        local importIcon = item.details.import and " 🌍" or ""
        local priceColor = item.details.import and "💎" or "💰"
        local actualPrice = item.details.import and 
            math.floor(item.details.price * (Config.ImportSystem.importMarkup or 1.25)) or 
            item.details.price
        
        -- Check if item is in cart
        local inCart = false
        local cartQuantity = 0
        for _, cartItem in ipairs(shoppingCart) do
            if cartItem.ingredient == item.ingredient then
                inCart = true
                cartQuantity = cartItem.quantity
                break
            end
        end
        
        local cartIndicator = inCart and string.format(" ✅ (%d in cart)", cartQuantity) or ""
        
        table.insert(options, {
            title = item.label .. importIcon .. cartIndicator,
            description = string.format("%s $%d each%s", 
                priceColor, 
                actualPrice,
                item.details.import and " • Premium Import" or ""),
            icon = itemNames[item.ingredient] and itemNames[item.ingredient].image or "fas fa-box",
            metadata = {
                Price = "$" .. actualPrice,
                Category = category,
                Type = item.details.import and "Import 🌍" or "Local",
                ["In Cart"] = inCart and cartQuantity .. " units" or "Not in cart"
            },
            onSelect = function()
                local input = lib.inputDialog("Add " .. item.label .. " to Cart", {
                    { 
                        type = "number", 
                        label = "Quantity", 
                        placeholder = "Enter amount (current: " .. cartQuantity .. ")", 
                        default = 10,
                        min = 1, 
                        max = 999, 
                        required = true 
                    }
                })
                if input and input[1] and tonumber(input[1]) > 0 then
                    local quantity = tonumber(input[1])
                    addToCart(item.ingredient, quantity, item.label, actualPrice)
                    
                    lib.notify({
                        title = "✅ Added to Cart",
                        description = string.format([[
**%d×** %s%s
**Subtotal:** $%d
**Cart Total:** $%d (%d boxes)]],
                            quantity, item.label, importIcon,
                            actualPrice * quantity,
                            cartTotalCost, cartBoxCount),
                        type = "success",
                        duration = 5000,
                        position = Config.UI.notificationPosition,
                        markdown = true
                    })
                    
                    -- Refresh menu to show updated cart
                    TriggerEvent("restaurant:openCategoryMenu", restaurantId, category)
                end
            end
        })
    end
    
    -- Add category summary at bottom
    local importCount = 0
    local totalItems = #sortedItems
    for _, item in ipairs(sortedItems) do
        if item.details.import then
            importCount = importCount + 1
        end
    end
    
    table.insert(options, {
        title = "📊 Category Summary",
        description = string.format("%d total items • %d imports • %d local", 
            totalItems, importCount, totalItems - importCount),
        disabled = true
    })
    
    lib.registerContext({
        id = "category_menu",
        title = catInfo.icon .. " " .. category .. " - " .. #sortedItems .. " items",
        options = options
    })
    lib.showContext("category_menu")
end)

-- Enhanced Shopping Cart with better organization
RegisterNetEvent("restaurant:openCartMenu")
AddEventHandler("restaurant:openCartMenu", function(restaurantId)
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
            title = "🛒 Cart is Empty",
            description = "Add items from the categories to get started",
            disabled = true,
            icon = "fas fa-shopping-cart"
        })
    else
        -- Cart summary with visual indicators
        local importItems = 0
        local regularItems = 0
        
        for _, item in ipairs(shoppingCart) do
            -- Check if import
            local isImport = false
            local restaurantJob = Config.Restaurants[restaurantId].job
            for category, categoryItems in pairs(Config.Items[restaurantJob]) do
                if categoryItems[item.ingredient] and categoryItems[item.ingredient].import then
                    isImport = true
                    break
                end
            end
            
            if isImport then
                importItems = importItems + 1
            else
                regularItems = regularItems + 1
            end
        end
        
        table.insert(options, {
            title = "📋 Order Summary",
            description = string.format([[
📦 **%d** boxes • 🏭 **%d** containers
💰 **Total: $%d**
🏭 Regular: %d items • 🌍 Import: %d items]], 
                cartBoxCount, cartContainerCount, cartTotalCost,
                regularItems, importItems),
            disabled = true
        })
        
        -- Separate imports and regular items
        if importItems > 0 then
            table.insert(options, {
                title = "🌍 Import Items",
                disabled = true
            })
        end
        
        -- Cart items organized
        for i, cartItem in ipairs(shoppingCart) do
            -- Check if import
            local isImport = false
            local restaurantJob = Config.Restaurants[restaurantId].job
            for category, categoryItems in pairs(Config.Items[restaurantJob]) do
                if categoryItems[cartItem.ingredient] and categoryItems[cartItem.ingredient].import then
                    isImport = true
                    break
                end
            end
            
            if isImport then
                table.insert(options, {
                    title = cartItem.quantity .. "× " .. cartItem.label .. " 🌍",
                    description = "$" .. cartItem.price .. " each • Subtotal: $" .. (cartItem.price * cartItem.quantity),
                    icon = "fas fa-globe",
                    onSelect = function()
                        removeFromCart(i)
                        lib.notify({
                            title = "🗑️ Removed from Cart",
                            description = cartItem.label .. " removed",
                            type = "info",
                            duration = 3000,
                            position = Config.UI.notificationPosition,
                            markdown = Config.UI.enableMarkdown
                        })
                        TriggerEvent("restaurant:openCartMenu", restaurantId)
                    end
                })
            end
        end
        
        if regularItems > 0 then
            table.insert(options, {
                title = "📦 Regular Items",
                disabled = true
            })
        end
        
        -- Regular items
        for i, cartItem in ipairs(shoppingCart) do
            local isImport = false
            local restaurantJob = Config.Restaurants[restaurantId].job
            for category, categoryItems in pairs(Config.Items[restaurantJob]) do
                if categoryItems[cartItem.ingredient] and categoryItems[cartItem.ingredient].import then
                    isImport = true
                    break
                end
            end
            
            if not isImport then
                table.insert(options, {
                    title = cartItem.quantity .. "× " .. cartItem.label,
                    description = "$" .. cartItem.price .. " each • Subtotal: $" .. (cartItem.price * cartItem.quantity),
                    icon = "fas fa-box",
                    onSelect = function()
                        removeFromCart(i)
                        lib.notify({
                            title = "🗑️ Removed from Cart",
                            description = cartItem.label .. " removed",
                            type = "info",
                            duration = 3000,
                            position = Config.UI.notificationPosition,
                            markdown = Config.UI.enableMarkdown
                        })
                        TriggerEvent("restaurant:openCartMenu", restaurantId)
                    end
                })
            end
        end
        
        -- Action buttons with enhanced visuals
        table.insert(options, {
            title = "🗑️ Clear Cart",
            description = "Remove all items and start over",
            icon = "fas fa-trash",
            onSelect = function()
                clearCart()
                lib.notify({
                    title = "🗑️ Cart Cleared",
                    description = "All items removed from cart",
                    type = "info",
                    duration = 3000,
                    position = Config.UI.notificationPosition,
                    markdown = Config.UI.enableMarkdown
                })
                TriggerEvent("restaurant:openCartMenu", restaurantId)
            end
        })
        
        table.insert(options, {
            title = "✅ Submit Order",
            description = string.format("💰 Place order for **$%d** (%d boxes)", cartTotalCost, cartBoxCount),
            icon = "fas fa-check-circle",
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
                
                -- Show confirmation dialog
                local confirm = lib.alertDialog({
                    header = "✅ Confirm Order",
                    content = string.format([[
**Total Cost:** $%d  
**Total Boxes:** %d  
**Delivery:** %s

Orders will be charged from your **bank account**.

%s]], 
                        cartTotalCost, 
                        cartBoxCount,
                        importItems > 0 and "Split delivery (Import + Regular)" or "Main Warehouse",
                        importItems > 0 and "🌍 Import items will be delivered separately" or ""),
                    centered = true,
                    cancel = true
                })
                
                if confirm == "confirm" then
                    -- Convert cart to order format
                    local orderItems = {}
                    for _, cartItem in ipairs(shoppingCart) do
                        table.insert(orderItems, {
                            ingredient = cartItem.ingredient,
                            quantity = cartItem.quantity,
                            label = cartItem.label
                        })
                    end
                    
                    TriggerServerEvent("restaurant:orderIngredients", orderItems, restaurantId)
                    clearCart()
                    
                    lib.notify({
                        title = "✅ Order Submitted",
                        description = string.format([[
Order sent to warehouse!
**Boxes:** %d • **Containers:** %d
📧 Check email for confirmation]], 
                            cartBoxCount, cartContainerCount),
                        type = "success",
                        duration = 10000,
                        position = Config.UI.notificationPosition,
                        markdown = true
                    })
                end
            end
        })
    end
    
    lib.registerContext({
        id = "cart_menu",
        title = "🛒 Shopping Cart (" .. #shoppingCart .. " items)",
        options = options
    })
    lib.showContext("cart_menu")
end)

-- Stock Display - Simple like original
RegisterNetEvent("restaurant:showResturantStock")
AddEventHandler("restaurant:showResturantStock", function(restaurantId)
    if type(restaurantId) ~= "number" and type(restaurantId) ~= "string" then
        lib.notify({
            title = "Error",
            description = "Invalid restaurant ID.",
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    if not Config.Restaurants or not Config.Restaurants[restaurantId] then
        lib.notify({
            title = "Error",
            description = "Invalid restaurant ID or configuration not loaded.",
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    local stashId = "restaurant_stock_" .. tostring(restaurantId)
    
    -- Simple stash opening - server should handle registration
    local success = exports.ox_inventory:openInventory('stash', stashId)
    if not success then
        lib.notify({
            title = "Error",
            description = "Failed to open restaurant stock.",
            type = "error",
            duration = 5000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
    end
end)

RegisterNetEvent("restaurant:showIngredientPicker")
AddEventHandler("restaurant:showIngredientPicker", function(restaurantId)
    local restaurantJob = Config.Restaurants[restaurantId].job
    local allItems = Config.Items[restaurantJob]
    local itemNames = exports.ox_inventory:Items() or {}
    
    local options = {
        {
            title = "Back to Categories",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("restaurant:openOrderMenu", { restaurantId = restaurantId })
            end
        }
    }
    
    -- Collect all ingredients
    local ingredients = {}
    for category, categoryItems in pairs(allItems) do
        for ingredient, details in pairs(categoryItems) do
            if type(details) == "table" then
                local label = itemNames[ingredient] and itemNames[ingredient].label or details.label or ingredient
                table.insert(ingredients, {
                    ingredient = ingredient,
                    label = label,
                    category = category
                })
            end
        end
    end
    
    -- Sort alphabetically
    table.sort(ingredients, function(a, b) return a.label < b.label end)
    
    -- Add to menu
    for _, item in ipairs(ingredients) do
        table.insert(options, {
            title = item.label,
            description = "View price history for " .. item.label,
            onSelect = function()
                TriggerServerEvent('market:getPriceHistory', item.ingredient, "restaurant")
            end
        })
    end
    
    lib.registerContext({
        id = "restaurant_ingredient_picker",
        title = "📈 Select Ingredient for Price History",
        options = options
    })
    lib.showContext("restaurant_ingredient_picker")
end)

RegisterNetEvent("restaurant:showCurrentOrders")
AddEventHandler("restaurant:showCurrentOrders", function(orders, restaurantId)
    local itemNames = exports.ox_inventory:Items() or {}

    local options = {
        {
        title = "Back to Categories",
        icon = "fas fa-arrow-left",
        onSelect = function()
            TriggerEvent("restaurant:openOrderMenu", { restaurantId = restaurantId })
        end
    }
    }
    
    if #orders == 0 then
        table.insert(options, {
            title = "📦 No Active Orders",
            description = "All orders have been completed",
            disabled = true
        })
    else
        for _, order in ipairs(orders) do
            local statusIcon = {
                pending = "⏳",
                accepted = "🚛", 
                in_transit = "🚚"
            }
            
            local itemNames = exports.ox_inventory:Items() or {}
            local itemLabel = itemNames[order.ingredient] and itemNames[order.ingredient].label or order.ingredient

            table.insert(options, {
                title = statusIcon[order.status] .. " Order #" .. order.order_group_id,
                description = string.format("%dx %s - $%d (%s)", 
                    order.quantity, itemLabel, order.total_cost, order.status),
                disabled = true
            })
        end
    end
    
    lib.registerContext({
        id = "restaurant_current_orders",
        title = "📋 Current Orders Status",
        options = options
    })
    lib.showContext("restaurant_current_orders")
end)

RegisterNetEvent("restaurant:openOrderGoodsMenu")
AddEventHandler("restaurant:openOrderGoodsMenu", function(restaurantId)
    local options = {
        {
            title = "Back to Main Menu",
            icon = "fas fa-arrow-left", 
            onSelect = function()
                TriggerEvent("restaurant:openOrderMenu", { restaurantId = restaurantId })
            end
        },
        { 
            title = "🛒 Browse Categories", 
            description = "Order ingredients by category",
            icon = "fas fa-list",
            onSelect = function() 
                TriggerEvent("restaurant:openCategorySelection", restaurantId) -- New event
            end 
        },
        {
            title = "📈 Price History",
            description = "View ingredient price trends and market timing",
            icon = "fas fa-chart-bar", 
            onSelect = function()
                TriggerEvent("restaurant:showIngredientPicker", restaurantId)
            end
        },
    }
    
    lib.registerContext({
        id = "restaurant_order_goods",
        title = "📦 Order Goods",
        options = options
    })
    lib.showContext("restaurant_order_goods")
end)

RegisterNetEvent("restaurant:openCategorySelection")
AddEventHandler("restaurant:openCategorySelection", function(restaurantId)
    local restaurantJob = Config.Restaurants[restaurantId].job
    local items = Config.Items[restaurantJob] or {}
    
    local options = {
        {
            title = "← Back to Order Goods",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("restaurant:openOrderGoodsMenu", restaurantId)
            end
        }
    }
    
    -- Add categories here (copy from your existing category loop)
    for category, categoryItems in pairs(items) do
        if type(categoryItems) == "table" and next(categoryItems) then
            local categoryIcon = "fas fa-box"
            if category == "Meats" then categoryIcon = "fas fa-drumstick-bite"
            elseif category == "Vegetables" then categoryIcon = "fas fa-carrot"
            elseif category == "Fruits" then categoryIcon = "fas fa-apple-alt"
            elseif category == "Dairy" then categoryIcon = "fas fa-cheese"
            elseif category == "DryGoods" then categoryIcon = "fas fa-seedling"
            end
            
            local itemCount = 0
            for _ in pairs(categoryItems) do itemCount = itemCount + 1 end
            
            table.insert(options, {
                title = category,
                description = itemCount .. " items available",
                icon = categoryIcon,
                onSelect = function()
                    TriggerEvent("restaurant:openCategoryMenu", restaurantId, category)
                end
            })
        end
    end
    
    lib.registerContext({
        id = "category_selection",
        title = "Select Category",
        options = options
    })
    lib.showContext("category_selection")
end)

-- RegisterNetEvent("restaurant:showQuickReorderMenu")
-- AddEventHandler("restaurant:showQuickReorderMenu", function(quickItems, restaurantId)
--     local itemNames = exports.ox_inventory:Items() or {}
    
--     local options = {
--         {
--             title = "← Back to Order Goods",
--             icon = "fas fa-arrow-left",
--             onSelect = function()
--                 TriggerEvent("restaurant:openOrderGoodsMenu", restaurantId)
--             end
--         }
--     }
    
--     if #quickItems == 0 then
--         table.insert(options, {
--             title = "📦 No Recent Orders",
--             description = "No order history found for quick reorder",
--             disabled = true
--         })
--     else
--         table.insert(options, {
--             title = "📊 Frequently Ordered Items (30 days)",
--             description = "Click to add common quantities to cart",
--             disabled = true
--         })
        
--         for _, item in ipairs(quickItems) do
--             local itemLabel = itemNames[item.ingredient] and itemNames[item.ingredient].label or item.ingredient
--             local avgQuantity = math.ceil(item.total_quantity / item.order_count)
            
--             table.insert(options, {
--                 title = itemLabel,
--                 description = string.format("Ordered %d times • Avg: %d units • Recently ordered", 
--                 item.order_count, avgQuantity),
--                 onSelect = function()
--                     local input = lib.inputDialog("Quick Reorder: " .. itemLabel, {
--                         { 
--                             type = "number", 
--                             label = "Quantity", 
--                             placeholder = "Suggested: " .. avgQuantity,
--                             default = avgQuantity,
--                             min = 1, 
--                             max = 999, 
--                             required = true 
--                         }
--                     })
--                     if input and input[1] and tonumber(input[1]) > 0 then
--                         local quantity = tonumber(input[1])
                        
--                         -- Get price from config
--                         local restaurantJob = Config.Restaurants[restaurantId].job
--                         local price = 0
--                         for category, categoryItems in pairs(Config.Items[restaurantJob]) do
--                             if categoryItems[item.ingredient] then
--                                 price = categoryItems[item.ingredient].price
--                                 break
--                             end
--                         end
                        
--                         addToCart(item.ingredient, quantity, itemLabel, price)
                        
--                         lib.notify({
--                             title = "Added to Cart",
--                             description = quantity .. "x " .. itemLabel .. " (Quick Reorder)",
--                             type = "success",
--                             duration = 5000,
--                             position = Config.UI.notificationPosition,
--                             markdown = Config.UI.enableMarkdown
--                         })
                        
--                         TriggerEvent("restaurant:showQuickReorderMenu", quickItems, restaurantId)
--                     end
--                 end
--             })
--         end
--     end
    
--     lib.registerContext({
--         id = "quick_reorder_menu",
--         title = "🔄 Quick Reorder",
--         options = options
--     })
--     lib.showContext("quick_reorder_menu")
-- end)