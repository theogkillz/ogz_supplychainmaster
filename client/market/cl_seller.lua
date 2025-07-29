local QBCore = exports['qb-core']:GetCoreObject()

-- Shopping cart for selling
local sellingCart = {}
local cartTotalValue = 0

-- Clear cart function
local function clearSellingCart()
    sellingCart = {}
    cartTotalValue = 0
end

-- Update cart totals
local function updateCartTotals()
    cartTotalValue = 0
    for _, item in ipairs(sellingCart) do
        cartTotalValue = cartTotalValue + (item.price * item.quantity)
    end
end

-- Add item to selling cart
local function addToSellingCart(itemName, quantity, label, price)
    -- Check if item already in cart
    for i, cartItem in ipairs(sellingCart) do
        if cartItem.name == itemName then
            cartItem.quantity = cartItem.quantity + quantity
            updateCartTotals()
            return
        end
    end
    
    -- Add new item to cart
    table.insert(sellingCart, {
        name = itemName,
        quantity = quantity,
        label = label,
        price = price
    })
    updateCartTotals()
end

-- Remove item from selling cart
local function removeFromSellingCart(index)
    table.remove(sellingCart, index)
    updateCartTotals()
end

Citizen.CreateThread(function()
    if not Config.Location or not Config.SellerBlip then
        print("[ERROR] Config.Location or Config.SellerBlip not defined in cl_seller.lua")
        return
    end
    local sellerPos = Config.Location.coords
    local sellerHeading = Config.Location.heading
    local blipPos = Config.SellerBlip.coords

    exports.ox_target:addBoxZone({
        coords = sellerPos,
        size = vector3(1.0, 1.0, 2.0),
        rotation = sellerHeading,
        debug = false,
        options = {
            {
                name = "seller_distributor",
                icon = "fas fa-hand-holding-usd",
                label = "Ingredient Distributor",
                onSelect = function()
                    -- Add animation for interaction
                    local animDict = "misscarsteal4@actor"
                    local animName = "actor_berating_loop"
                    RequestAnimDict(animDict)
                    while not HasAnimDictLoaded(animDict) do
                        Wait(10)
                    end
                    TaskPlayAnim(PlayerPedId(), animDict, animName, 8.0, -8.0, 1500, 0, 0, false, false, false)
                    
                    Wait(1500)
                    TriggerEvent("seller:openMainMenu")
                end
            }
        }
    })

    local pedModel = GetHashKey(Config.PedModel or "a_m_m_farmer_01")
    RequestModel(pedModel)
    while not HasModelLoaded(pedModel) do
        Citizen.Wait(100)
    end
    local ped = CreatePed(4, pedModel, sellerPos.x, sellerPos.y, sellerPos.z - 1.0, sellerHeading, false, true)
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetModelAsNoLongerNeeded(pedModel)

    local blip = AddBlipForCoord(blipPos.x, blipPos.y, blipPos.z)
    SetBlipSprite(blip, Config.SellerBlip.blipSprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, Config.SellerBlip.blipScale)
    SetBlipColour(blip, Config.SellerBlip.blipColor)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Config.SellerBlip.label)
    EndTextCommandSetBlipName(blip)
end)

-- Main Menu
RegisterNetEvent("seller:openMainMenu")
AddEventHandler("seller:openMainMenu", function()
    local options = {
        {
            title = "💰 Selling Cart (" .. #sellingCart .. " items)",
            description = "🤑 Total Value: $" .. cartTotalValue,
            icon = "fas fa-shopping-cart",
            onSelect = function()
                TriggerEvent("seller:openSellingCart")
            end,
            disabled = #sellingCart == 0
        },
        {
            title = "🛒 Sell Ingredients",
            description = "Browse your inventory by category",
            icon = "fas fa-hand-holding-usd",
            onSelect = function()
                TriggerEvent("seller:openCategorySelection")
            end
        },
        {
            title = "📦 Buy Container Materials",
            description = "Purchase packing supplies for your goods",
            icon = "fas fa-box",
            onSelect = function()
                TriggerEvent("seller:openContainerShop")
            end
        },
        {
            title = "📈 Market Prices",
            description = "Check current ingredient market values",
            icon = "fas fa-chart-line",
            onSelect = function()
                TriggerEvent("seller:showMarketPrices")
            end
        },
        {
            title = "❓ Help & Tips",
            description = "Learn about farming and selling strategies",
            icon = "fas fa-question-circle",
            onSelect = function()
                TriggerEvent("seller:openHelpMenu")
            end
        }
    }
    
    lib.registerContext({
        id = "seller_main_menu",
        title = "🌾 Ingredient Distributor",
        options = options
    })
    lib.showContext("seller_main_menu")
end)

-- Category Selection
RegisterNetEvent("seller:openCategorySelection")
AddEventHandler("seller:openCategorySelection", function()
    local options = {
        {
            title = "← Back to Main Menu",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("seller:openMainMenu")
            end
        },
        {
            title = "💰 View Cart (" .. #sellingCart .. ")",
            description = "🤑 Total: $" .. cartTotalValue,
            icon = "fas fa-shopping-cart",
            onSelect = function()
                TriggerEvent("seller:openSellingCart")
            end,
            disabled = #sellingCart == 0
        }
    }
    
    -- Category counts
    local PlayerData = QBCore.Functions.GetPlayerData()
    local items = PlayerData.items
    local meatCount, vegCount, fruitCount = 0, 0, 0
    
    for _, item in pairs(items) do
        local itemName = item.name or item.item
        if Config.ItemsFarming.Meats[itemName] then
            meatCount = meatCount + 1
        elseif Config.ItemsFarming.Vegetables[itemName] then
            vegCount = vegCount + 1
        elseif Config.ItemsFarming.Fruits[itemName] then
            fruitCount = fruitCount + 1
        end
    end
    
    -- Add categories
    table.insert(options, {
        title = "🥩 Meats",
        description = meatCount .. " different meat products available",
        icon = "fas fa-drumstick-bite",
        onSelect = function()
            TriggerEvent("seller:openCategoryMenu", "Meats")
        end,
        disabled = meatCount == 0
    })
    
    table.insert(options, {
        title = "🥬 Vegetables",
        description = vegCount .. " different vegetables available",
        icon = "fas fa-carrot",
        onSelect = function()
            TriggerEvent("seller:openCategoryMenu", "Vegetables")
        end,
        disabled = vegCount == 0
    })
    
    table.insert(options, {
        title = "🍎 Fruits",
        description = fruitCount .. " different fruits available",
        icon = "fas fa-apple-alt",
        onSelect = function()
            TriggerEvent("seller:openCategoryMenu", "Fruits")
        end,
        disabled = fruitCount == 0
    })
    
    lib.registerContext({
        id = "seller_category_selection",
        title = "🛒 Select Category to Sell",
        options = options
    })
    lib.showContext("seller_category_selection")
end)

-- Category Menu with Items
RegisterNetEvent("seller:openCategoryMenu")
AddEventHandler("seller:openCategoryMenu", function(category)
    local PlayerData = QBCore.Functions.GetPlayerData()
    local items = PlayerData.items
    local itemNames = exports.ox_inventory:Items() or {}
    
    local options = {
        {
            title = "← Back to Categories",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("seller:openCategorySelection")
            end
        },
        {
            title = "💰 View Cart (" .. #sellingCart .. ")",
            description = "🤑 Total: $" .. cartTotalValue,
            icon = "fas fa-shopping-cart",
            onSelect = function()
                TriggerEvent("seller:openSellingCart")
            end,
            disabled = #sellingCart == 0
        }
    }
    
    -- Get category items
    local categoryConfig = nil
    if category == "Meats" then
        categoryConfig = Config.ItemsFarming.Meats
    elseif category == "Vegetables" then
        categoryConfig = Config.ItemsFarming.Vegetables
    elseif category == "Fruits" then
        categoryConfig = Config.ItemsFarming.Fruits
    end
    
    -- Sort and add items
    local sortedItems = {}
    for _, item in pairs(items) do
        local itemName = item.name or item.item
        local itemAmount = item.amount or item.count or 0
        
        if categoryConfig[itemName] and itemAmount > 0 then
            local label = itemNames[itemName] and itemNames[itemName].label or categoryConfig[itemName].label or itemName
            table.insert(sortedItems, {
                name = itemName,
                label = label,
                amount = itemAmount,
                price = categoryConfig[itemName].price
            })
        end
    end
    
    table.sort(sortedItems, function(a, b) return a.label < b.label end)
    
    -- Add items to menu
    for _, item in ipairs(sortedItems) do
        -- Check if in cart
        local inCart = false
        local cartQuantity = 0
        for _, cartItem in ipairs(sellingCart) do
            if cartItem.name == item.name then
                inCart = true
                cartQuantity = cartItem.quantity
                break
            end
        end
        
        local cartIndicator = inCart and string.format(" ✅ (%d in cart)", cartQuantity) or ""
        
        table.insert(options, {
            title = item.label .. " (x" .. item.amount .. ")" .. cartIndicator,
            description = "💰 $" .. item.price .. " each • Max value: $" .. (item.price * item.amount),
            icon = itemNames[item.name] and itemNames[item.name].image or "fas fa-box",
            metadata = {
                ["Unit Price"] = "$" .. item.price,
                ["You Have"] = item.amount .. " units",
                ["Max Value"] = "$" .. (item.price * item.amount),
                ["In Cart"] = inCart and cartQuantity .. " units" or "Not in cart"
            },
            onSelect = function()
                local input = lib.inputDialog("Add " .. item.label .. " to Selling Cart", {
                    { 
                        type = "number", 
                        label = "Quantity to sell", 
                        placeholder = "Max: " .. item.amount,
                        default = math.min(10, item.amount),
                        min = 1, 
                        max = item.amount, 
                        required = true 
                    }
                })
                
                if input and input[1] and tonumber(input[1]) > 0 then
                    local quantity = tonumber(input[1])
                    addToSellingCart(item.name, quantity, item.label, item.price)
                    
                    lib.notify({
                        title = "✅ Added to Cart",
                        description = string.format([[
**%d×** %s
**Value:** $%d
**Cart Total:** $%d]],
                            quantity, item.label,
                            item.price * quantity,
                            cartTotalValue),
                        type = "success",
                        duration = 5000,
                        position = Config.UI.notificationPosition,
                        markdown = true
                    })
                    
                    -- Refresh menu
                    TriggerEvent("seller:openCategoryMenu", category)
                end
            end
        })
    end
    
    -- Category icon
    local categoryIcon = "📦"
    if category == "Meats" then categoryIcon = "🥩"
    elseif category == "Vegetables" then categoryIcon = "🥬"
    elseif category == "Fruits" then categoryIcon = "🍎"
    end
    
    lib.registerContext({
        id = "seller_category_menu",
        title = categoryIcon .. " " .. category .. " - " .. #sortedItems .. " items",
        options = options
    })
    lib.showContext("seller_category_menu")
end)

-- Selling Cart
RegisterNetEvent("seller:openSellingCart")
AddEventHandler("seller:openSellingCart", function()
    local options = {
        {
            title = "← Back to Categories",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("seller:openCategorySelection")
            end
        }
    }
    
    if #sellingCart == 0 then
        table.insert(options, {
            title = "💰 Cart is Empty",
            description = "Add items from your inventory to sell",
            disabled = true
        })
    else
        -- Cart summary
        table.insert(options, {
            title = "📋 Selling Summary",
            description = string.format("**%d** items • **Total Value: $%d**", #sellingCart, cartTotalValue),
            disabled = true
        })
        
        -- Cart items
        for i, item in ipairs(sellingCart) do
            table.insert(options, {
                title = item.quantity .. "× " .. item.label,
                description = "$" .. item.price .. " each • Subtotal: $" .. (item.price * item.quantity),
                icon = "fas fa-times",
                onSelect = function()
                    removeFromSellingCart(i)
                    lib.notify({
                        title = "🗑️ Removed from Cart",
                        description = item.label .. " removed",
                        type = "info",
                        duration = 3000,
                        position = Config.UI.notificationPosition,
                        markdown = Config.UI.enableMarkdown
                    })
                    TriggerEvent("seller:openSellingCart")
                end
            })
        end
        
        -- Action buttons
        table.insert(options, {
            title = "🗑️ Clear Cart",
            description = "Remove all items",
            icon = "fas fa-trash",
            onSelect = function()
                clearSellingCart()
                lib.notify({
                    title = "🗑️ Cart Cleared",
                    description = "All items removed from selling cart",
                    type = "info",
                    duration = 3000,
                    position = Config.UI.notificationPosition,
                    markdown = Config.UI.enableMarkdown
                })
                TriggerEvent("seller:openSellingCart")
            end
        })
        
        table.insert(options, {
            title = "💸 Sell All Items",
            description = "Complete sale for **$" .. cartTotalValue .. "**",
            icon = "fas fa-cash-register",
            onSelect = function()
                -- Confirmation dialog
                local confirm = lib.alertDialog({
                    header = "💸 Confirm Sale",
                    content = string.format([[
**Total Items:** %d  
**Total Value:** $%d  
**Payment:** Cash

Are you sure you want to sell these items?]], 
                        #sellingCart, cartTotalValue),
                    centered = true,
                    cancel = true
                })
                
                if confirm == "confirm" then
                    -- Progress bar for selling
                    if lib.progressBar({
                        duration = #sellingCart * 2000, -- 2 seconds per item type
                        position = "bottom",
                        label = "Selling ingredients...",
                        canCancel = false,
                        disable = { move = true, car = true, combat = true, sprint = true },
                        anim = { dict = "mp_common", clip = "givetake1_a", flag = 49 }
                    }) then
                        -- Send cart to server
                        TriggerServerEvent("farming:sellBulkItems", sellingCart, cartTotalValue)
                        clearSellingCart()
                        
                        lib.notify({
                            title = "💸 Sale Complete!",
                            description = "Items sold successfully!",
                            type = "success",
                            duration = 8000,
                            position = Config.UI.notificationPosition,
                            markdown = Config.UI.enableMarkdown
                        })
                    end
                end
            end
        })
    end
    
    lib.registerContext({
        id = "seller_cart_menu",
        title = "💰 Selling Cart (" .. #sellingCart .. " items)",
        options = options
    })
    lib.showContext("seller_cart_menu")
end)

-- Container Shop
RegisterNetEvent("seller:openContainerShop")
AddEventHandler("seller:openContainerShop", function()
    local options = {
        {
            title = "← Back to Main Menu",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("seller:openMainMenu")
            end
        },
        {
            title = "📦 Container Materials Information",
            description = "Learn about packaging locations",
            icon = "fas fa-info-circle",
            onSelect = function()
                lib.notify({
                    title = "📦 Packaging Locations",
                    description = [[
**Where to package goods:**
• 🥩 **Cluck Pluck Butchers** - Meat packaging
• 🔪 **Quick Chops** - Vegetable processing
• 🌾 **Hurst Farms** - Fruit packaging

Buy containers here or at these locations!]],
                    type = "info",
                    duration = 12000,
                    position = Config.UI.notificationPosition,
                    markdown = true
                })
            end
        }
    }
    
    -- Add container materials
    if Config.ContainerMaterials then
        for itemName, itemData in pairs(Config.ContainerMaterials) do
            table.insert(options, {
                title = "🛒 " .. itemData.label,
                description = "💰 $" .. itemData.price .. " each • Essential for packaging",
                icon = "fas fa-shopping-cart",
                metadata = {
                    ["Unit Price"] = "$" .. itemData.price,
                    ["Bulk 10"] = "$" .. (itemData.price * 10),
                    ["Bulk 50"] = "$" .. (itemData.price * 50),
                    ["Bulk 100"] = "$" .. (itemData.price * 100)
                },
                onSelect = function()
                    local input = lib.inputDialog("Buy " .. itemData.label, {
                        { 
                            type = "select", 
                            label = "Purchase Amount",
                            options = {
                                { value = 10, label = "10 units - $" .. (itemData.price * 10) },
                                { value = 25, label = "25 units - $" .. (itemData.price * 25) },
                                { value = 50, label = "50 units - $" .. (itemData.price * 50) },
                                { value = 100, label = "100 units - $" .. (itemData.price * 100) },
                                { value = "custom", label = "Custom amount" }
                            },
                            default = 10,
                            required = true
                        }
                    })
                    
                    if input and input[1] then
                        local amount = input[1]
                        
                        -- Handle custom amount
                        if amount == "custom" then
                            local customInput = lib.inputDialog("Custom Amount", {
                                { type = "number", label = "Quantity", min = 1, max = 500, required = true }
                            })
                            if customInput and customInput[1] then
                                amount = customInput[1]
                            else
                                return
                            end
                        end
                        
                        local totalCost = amount * itemData.price
                        
                        if lib.progressBar({
                            duration = 3000,
                            position = "bottom",
                            label = "Purchasing " .. itemData.label .. "...",
                            canCancel = false,
                            disable = { move = true, car = true, combat = true, sprint = true },
                            anim = { dict = "misscarsteal4@actor", clip = "actor_berating_loop" }
                        }) then
                            TriggerServerEvent("containers:buyMaterial", itemName, amount, totalCost)
                        end
                    end
                end
            })
        end
    end
    
    lib.registerContext({
        id = "container_shop_menu",
        title = "📦 Container Materials Shop",
        options = options
    })
    lib.showContext("container_shop_menu")
end)

-- Help Menu
RegisterNetEvent("seller:openHelpMenu")
AddEventHandler("seller:openHelpMenu", function()
    local options = {
        {
            title = "← Back to Main Menu",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("seller:openMainMenu")
            end
        },
        {
            title = "📦 Container System Guide",
            description = "Understanding the packaging process",
            icon = "fas fa-box",
            onSelect = function()
                lib.notify({
                    title = "📦 Container System",
                    description = [[
**How packaging works:**
• Raw ingredients need containers
• 12 items = 1 container
• Different locations for different goods

**Packaging Locations:**
• 🥩 Cluck Pluck - Meats
• 🔪 Quick Chops - Vegetables  
• 🌾 Hurst Farms - Fruits

**Pro Tip:** Buy containers in bulk!]],
                    type = "info",
                    duration = 15000,
                    position = Config.UI.notificationPosition,
                    markdown = true
                })
            end
        },
        {
            title = "💰 Selling Strategy",
            description = "Maximize your farming profits",
            icon = "fas fa-coins",
            onSelect = function()
                lib.notify({
                    title = "💰 Profit Tips",
                    description = [[
**Market Intelligence:**
• Prices fluctuate with demand
• Shortages = Higher prices
• Surplus = Lower prices

**Best Practices:**
• Sell during shortages
• Stock up containers when cheap
• Build relationships with restaurants
• Diversify your crops]],
                    type = "info",
                    duration = 15000,
                    position = Config.UI.notificationPosition,
                    markdown = true
                })
            end
        },
        {
            title = "🌱 Supply Chain Role",
            description = "Your importance in the ecosystem",
            icon = "fas fa-seedling",
            onSelect = function()
                lib.notify({
                    title = "🌱 Your Role",
                    description = [[
**You're Essential!**
• Farmers supply warehouses
• Warehouses supply restaurants
• Restaurants feed the city

**Your Impact:**
• Stock levels affect prices
• Regular supply prevents shortages
• Quality ingredients = happy restaurants
• More supply = competitive prices]],
                    type = "info",
                    duration = 15000,
                    position = Config.UI.notificationPosition,
                    markdown = true
                })
            end
        },
        {
            title = "🎯 Quick Tips",
            description = "Efficiency shortcuts",
            icon = "fas fa-lightbulb",
            onSelect = function()
                lib.notify({
                    title = "🎯 Quick Tips",
                    description = [[
**Cart System:**
• Add multiple items before selling
• Bulk sales save time
• Review total before confirming

**Navigation:**
• ESC = Back/Close
• Use categories for organization
• Check market prices regularly]],
                    type = "info",
                    duration = 12000,
                    position = Config.UI.notificationPosition,
                    markdown = true
                })
            end
        },
        {
            title = "🏆 Farming Goals",
            description = "What to aim for",
            icon = "fas fa-trophy",
            onSelect = function()
                lib.notify({
                    title = "🏆 Farming Goals",
                    description = [[
**Short Term:**
• Learn market patterns
• Build container stock
• Establish regular sales

**Long Term:**
• Become preferred supplier
• Time sales for max profit
• Supply multiple categories
• Help prevent city shortages]],
                    type = "info",
                    duration = 12000,
                    position = Config.UI.notificationPosition,
                    markdown = true
                })
            end
        }
    }
    
    lib.registerContext({
        id = "seller_help_menu",
        title = "❓ Farming & Selling Guide",
        options = options
    })
    lib.showContext("seller_help_menu")
end)

-- Market Prices Display
RegisterNetEvent("seller:showMarketPrices")
AddEventHandler("seller:showMarketPrices", function()
    -- Request current market data from server
    TriggerServerEvent("farming:requestMarketPrices")
end)

-- Receive market prices from server
RegisterNetEvent("seller:displayMarketPrices")
AddEventHandler("seller:displayMarketPrices", function(marketData)
    local options = {
        {
            title = "← Back to Main Menu",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("seller:openMainMenu")
            end
        }
    }
    
    -- Add price information
    local categories = { "Meats", "Vegetables", "Fruits" }
    for _, category in ipairs(categories) do
        local categoryIcon = "📦"
        if category == "Meats" then categoryIcon = "🥩"
        elseif category == "Vegetables" then categoryIcon = "🥬"
        elseif category == "Fruits" then categoryIcon = "🍎"
        end
        
        table.insert(options, {
            title = categoryIcon .. " " .. category .. " Prices",
            disabled = true
        })
        
        local categoryConfig = Config.ItemsFarming[category]
        if categoryConfig then
            for itemName, itemData in pairs(categoryConfig) do
                local marketInfo = marketData and marketData[itemName] or {}
                local currentPrice = marketInfo.currentPrice or itemData.price
                local trend = marketInfo.trend or "stable"
                local trendIcon = trend == "up" and "📈" or (trend == "down" and "📉" or "➡️")
                
                table.insert(options, {
                    title = itemData.label,
                    description = string.format("%s $%d %s", trendIcon, currentPrice, 
                        trend == "up" and "(+)" or trend == "down" and "(-)" or ""),
                    disabled = true
                })
            end
        end
    end
    
    lib.registerContext({
        id = "market_prices_menu",
        title = "📈 Current Market Prices",
        options = options
    })
    lib.showContext("market_prices_menu")
end)