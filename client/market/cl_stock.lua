local QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent("restaurant:showStockDetails")
AddEventHandler("restaurant:showStockDetails", function(stock, query)
    if not stock or next(stock) == nil then
        lib.notify({
            title = "No Stock",
            description = "There is no stock available in the warehouse.",
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end

    local options = {
        {
            title = "Search",
            description = "Search for an ingredient",
            icon = "fas fa-search",
            onSelect = function()
                local input = lib.inputDialog("Search Stock", {
                    { type = "input", label = "Enter ingredient name" }
                })
                if input and input[1] then
                    TriggerEvent("restaurant:showStockDetails", stock, input[1])
                end
            end
        }
    }
    query = query or ""
    local itemNames = exports.ox_inventory:Items() or {}
    for ingredient, quantity in pairs(stock) do
        if string.find(string.lower(ingredient), string.lower(query)) then
            local itemData = itemNames[ingredient]
            local label = itemData and itemData.label or ingredient
            table.insert(options, {
                title = string.format("Ingredient: %s | Quantity: %d", label, quantity)
            })
        end
    end
    lib.registerContext({
        id = "stock_menu",
        title = "Warehouse Stock",
        options = options
    })
    lib.showContext("stock_menu")
end)

RegisterNetEvent("warehouse:showStockForOrder")
AddEventHandler("warehouse:showStockForOrder", function(stock, restaurantId, dynamicPrices)
    if not Config.Restaurants then
        print("[ERROR] Config.Restaurants not loaded in cl_stock.lua")
        lib.notify({
            title = "Error",
            description = "Configuration not loaded.",
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    if not Config.Restaurants[tostring(restaurantId)] then
        print("[ERROR] Invalid restaurant ID: " .. tostring(restaurantId))
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
    lib.hideContext()
    TriggerEvent("restaurant:openOrderMenu", { restaurantId = restaurantId, warehouseStock = stock, dynamicPrices = dynamicPrices, skipStockCheck = true })
end)