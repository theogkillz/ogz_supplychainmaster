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
        }
    }
    
    lib.registerContext({
        id = "order_main_menu",
        title = "Order Ingredients",
        options = options
    })
    lib.showContext("order_main_menu")
end)

-- Category Menu (Meats, Vegetables, etc.)
RegisterNetEvent("restaurant:openCategoryMenu")
AddEventHandler("restaurant:openCategoryMenu", function(restaurantId, category)
    local restaurantJob = Config.Restaurants[restaurantId].job
    local categoryItems = Config.Items[restaurantJob][category] or {}
    local itemNames = exports.ox_inventory:Items()
    
    local options = {
        {
            title = "Back to Categories",
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
    
    -- Add items to menu
    for _, item in ipairs(sortedItems) do
        table.insert(options, {
            title = item.label,
            description = "💰 $" .. item.details.price .. " each",
            icon = itemNames[item.ingredient] and itemNames[item.ingredient].image or "fas fa-box",
            metadata = {
                Price = "$" .. item.details.price,
                Category = category
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
                    addToCart(item.ingredient, quantity, item.label, item.details.price)
                    
                    lib.notify({
                        title = "Added to Cart",
                        description = quantity .. "x " .. item.label .. " ($" .. (item.details.price * quantity) .. ")",
                        type = "success",
                        duration = 5000,
                        position = Config.UI.notificationPosition,
                        markdown = Config.UI.enableMarkdown
                    })
                    
                    -- Refresh menu to show updated cart
                    TriggerEvent("restaurant:openCategoryMenu", restaurantId, category)
                end
            end
        })
    end
    
    lib.registerContext({
        id = "category_menu",
        title = category .. " - " .. #sortedItems .. " items",
        options = options
    })
    lib.showContext("category_menu")
end)

-- Shopping Cart Menu
RegisterNetEvent("restaurant:openCartMenu")
AddEventHandler("restaurant:openCartMenu", function(restaurantId)
    local options = {
        {
            title = "Back to Categories",
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
        -- Cart summary
        table.insert(options, {
            title = "📋 Order Summary",
            description = string.format("📦 %d boxes • 🏭 %d containers • 💰 Total: $%d", 
                cartBoxCount, cartContainerCount, cartTotalCost),
            disabled = true
        })
        
        -- Cart items
        for i, cartItem in ipairs(shoppingCart) do
            table.insert(options, {
                title = cartItem.quantity .. "x " .. cartItem.label,
                description = "$" .. cartItem.price .. " each • Subtotal: $" .. (cartItem.price * cartItem.quantity),
                icon = "fas fa-times",
                onSelect = function()
                    removeFromCart(i)
                    lib.notify({
                        title = "Removed from Cart",
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
                TriggerEvent("restaurant:openCartMenu", restaurantId)
            end
        })
        
        table.insert(options, {
            title = "✅ Submit Order",
            description = "Place order for $" .. cartTotalCost .. " (" .. cartBoxCount .. " boxes)",
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
                        label = cartItem.label
                    })
                end
                
                TriggerServerEvent("restaurant:orderIngredients", orderItems, restaurantId)
                clearCart()
                
                lib.notify({
                    title = "Order Submitted",
                    description = string.format("Order sent to warehouse (%d boxes, %d containers)", 
                        cartBoxCount, cartContainerCount),
                    type = "success",
                    duration = 10000,
                    position = Config.UI.notificationPosition,
                    markdown = Config.UI.enableMarkdown
                })
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