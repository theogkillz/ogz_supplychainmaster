local QBCore = exports['qb-core']:GetCoreObject()

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
                label = "Sell Ingredients",
                onSelect = function()
                    TriggerEvent("seller:openSellMenu")
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

RegisterNetEvent("seller:openSellMenu")
AddEventHandler("seller:openSellMenu", function()
    if not QBCore then
        print("[ERROR] QBCore not initialized in cl_seller.lua")
        lib.notify({
            title = "Error",
            description = "QBCore framework not loaded. Contact server admin.",
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end

    local PlayerData = QBCore.Functions.GetPlayerData()
    local items = PlayerData.items
    local itemNames = exports.ox_inventory:Items() or {}
    local options = {}

    -- ADD SELLING OPTIONS FIRST
    for _, item in pairs(items) do
        local itemName = item.name or item.item
        local itemAmount = item.amount or item.count or 1
        if itemName and (Config.ItemsFarming.Meats[itemName] or Config.ItemsFarming.Vegetables[itemName] or Config.ItemsFarming.Fruits[itemName]) then
            local label = itemNames[itemName] and itemNames[itemName].label or (Config.ItemsFarming.Meats[itemName] or Config.ItemsFarming.Vegetables[itemName] or Config.ItemsFarming.Fruits[itemName]).label or itemName
            table.insert(options, {
                title = label .. " (x" .. itemAmount .. ")",
                description = "Sell for $" .. (Config.ItemsFarming.Meats[itemName] or Config.ItemsFarming.Vegetables[itemName] or Config.ItemsFarming.Fruits[itemName]).price .. " each",
                icon = itemNames[itemName] and itemNames[itemName].image or "fas fa-box",
                onSelect = function()
                    local input = lib.inputDialog("Sell " .. label, {
                        { type = "number", label = "Enter Amount", placeholder = "Amount", min = 1, max = itemAmount, required = true }
                    })
                    if input and input[1] and tonumber(input[1]) > 0 then
                        local amount = tonumber(input[1])
                        if lib.progressBar({
                            duration = Config.SellProgress or 8000,
                            position = "bottom",
                            label = "Selling " .. label .. "...",
                            canCancel = false,
                            disable = { move = true, car = true, combat = true, sprint = true },
                            anim = { dict = "mp_common", clip = "givetake1_a", flag = 49 },
                            style = Config.UI.theme
                        }) then
                            TriggerServerEvent("farming:sellFruit", itemName, amount)
                        end
                    else
                        lib.notify({
                            title = "Error",
                            description = "Invalid amount entered.",
                            type = "error",
                            duration = 10000,
                            position = Config.UI.notificationPosition,
                            markdown = Config.UI.enableMarkdown
                        })
                    end
                end
            })
        end
    end

    -- ADD SEPARATOR IF THERE ARE SELLABLE ITEMS
    if #options > 0 then
        table.insert(options, {
            title = "── Container Materials ──",
            description = "Purchase packing supplies",
            disabled = true
        })
    end

    -- ADD CONTAINER MATERIALS FOR PURCHASE
    if Config.ContainerMaterials then
        for itemName, itemData in pairs(Config.ContainerMaterials) do
            table.insert(options, {
                title = "🛒 " .. itemData.label,
                description = "Buy for $" .. itemData.price .. " each",
                icon = "fas fa-shopping-cart",
                onSelect = function()
                    local input = lib.inputDialog("Buy " .. itemData.label, {
                        { type = "number", label = "Amount", placeholder = "Enter quantity", min = 1, max = 100, required = true }
                    })
                    if input and input[1] and tonumber(input[1]) > 0 then
                        local amount = tonumber(input[1])
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
                    else
                        lib.notify({
                            title = "Error",
                            description = "Invalid amount entered.",
                            type = "error",
                            duration = 10000,
                            position = Config.UI.notificationPosition,
                            markdown = Config.UI.enableMarkdown
                        })
                    end
                end
            })
        end
    end

    -- CHECK IF MENU HAS ANY OPTIONS
    if #options == 0 then
        lib.notify({
            title = "No Items",
            description = "You have no ingredients to sell and no materials to buy.",
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end

    lib.registerContext({
        id = "seller_menu",
        title = "Ingredient Seller & Supplies",
        options = options
    })
    lib.showContext("seller_menu")
end)