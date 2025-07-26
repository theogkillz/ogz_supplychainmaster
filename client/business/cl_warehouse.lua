local QBCore = exports['qb-core']:GetCoreObject()

-- Job validation helper function
local function hasWarehouseAccess()
    local PlayerData = QBCore.Functions.GetPlayerData()
    if not PlayerData or not PlayerData.job then
        return false
    end
    
    local playerJob = PlayerData.job.name
    if not playerJob then
        return false
    end
    
    -- Check if player's job is in authorized list
    for _, authorizedJob in ipairs(Config.Jobs.warehouse) do
        if playerJob == authorizedJob then
            return true
        end
    end
    
    return false
end

-- Global Variables
local orderGroupId = nil
local cartContainerCount = 0
local deliveryStartTime = 0
local currentDeliveryData = {}
local deliveryBoxesRemaining = 0
local totalDeliveryBoxes = 0
local deliveryMarker = nil
local completedDeliveryData = nil

-- Enhanced box calculation with container logic
local function calculateDeliveryBoxes(orders)
    local totalItems = 0
    local itemsList = {}
    
    -- Handle both single orders and order groups
    if orders[1] and orders[1].items then
        -- Order group format
        for _, orderGroup in ipairs(orders) do
            for _, item in ipairs(orderGroup.items) do
                totalItems = totalItems + item.quantity
                table.insert(itemsList, item.quantity .. "x " .. item.itemName)
            end
        end
    else
        -- Single order format
        for _, order in ipairs(orders) do
            totalItems = totalItems + order.quantity
            table.insert(itemsList, order.quantity .. "x " .. (order.itemName or order.ingredient))
        end
    end
    
    local itemsPerContainer = (Config.ContainerSystem and Config.ContainerSystem.itemsPerContainer) or 12
    local containersPerBox = (Config.ContainerSystem and Config.ContainerSystem.containersPerBox) or 5
    
    local containersNeeded = math.ceil(totalItems / itemsPerContainer)
    local boxesNeeded = math.ceil(containersNeeded / containersPerBox)
    
    return boxesNeeded, containersNeeded, totalItems, itemsList
end

-- Select appropriate vehicle based on box count
local function selectDeliveryVehicle(boxCount)
    local vehicleModel = "speedo" -- Default
    
    if Config.VehicleSelection then
        if boxCount <= Config.VehicleSelection.small.maxBoxes then
            vehicleModel = Config.VehicleSelection.small.models[1]
        elseif boxCount <= Config.VehicleSelection.medium.maxBoxes then
            vehicleModel = Config.VehicleSelection.medium.models[math.random(#Config.VehicleSelection.medium.models)]
        else
            vehicleModel = Config.VehicleSelection.large.models[math.random(#Config.VehicleSelection.large.models)]
        end
    end
    
    return vehicleModel
end

-- Warehouse Targets and Peds
Citizen.CreateThread(function()
    for index, warehouse in ipairs(Config.WarehousesLocation) do
        exports.ox_target:addBoxZone({
            coords = warehouse.position,
            size = vector3(1.0, 0.5, 3.5),
            rotation = warehouse.heading,
            debug = false,
            options = {
                {
                    name = "warehouse_processing_" .. tostring(index),
                    icon = "fas fa-box",
                    label = "Process Orders",
                    jobs = Config.Jobs.warehouse, -- Use jobs array instead of groups
                    onSelect = function()
                    TriggerEvent("warehouse:openProcessingMenu")
                end
                }
            }
        })

        local pedModel = GetHashKey(warehouse.pedhash)
        RequestModel(pedModel)
        while not HasModelLoaded(pedModel) do
            Wait(500)
        end
        local ped = CreatePed(4, pedModel, warehouse.position.x, warehouse.position.y, warehouse.position.z, warehouse.heading, false, true)
        SetEntityAsMissionEntity(ped, true, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetModelAsNoLongerNeeded(pedModel)

        local blip = AddBlipForCoord(warehouse.position.x, warehouse.position.y, warehouse.position.z)
        SetBlipSprite(blip, 473)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.6)
        SetBlipColour(blip, 16)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Warehouse")
        EndTextCommandSetBlipName(blip)
        Citizen.Wait(0)
    end
end)

-- CLEAN Warehouse Menu - Removed non-existent options
RegisterNetEvent("warehouse:openProcessingMenu")
AddEventHandler("warehouse:openProcessingMenu", function()
    -- Validate job access
    if not hasWarehouseAccess() then
        local PlayerData = QBCore.Functions.GetPlayerData()
        local currentJob = PlayerData and PlayerData.job and PlayerData.job.name or "unemployed"
        
        lib.notify({
            title = "🚫 Access Denied",
            description = "Hurst Industries employees only. Current job: " .. currentJob,
            type = "error",
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    local options = {
        { 
            title = "📦 View Orders", 
            description = "Process pending delivery orders",
            icon = "fas fa-clipboard-list",
            onSelect = function() TriggerServerEvent("warehouse:getPendingOrders") end 
        },
        { 
            title = "📊 View Stock", 
            description = "Check warehouse inventory levels",
            icon = "fas fa-warehouse",
            onSelect = function() TriggerServerEvent("warehouse:getStocks") end 
        },
        {
            title = "🚨 Stock Alerts",
            description = "View low stock warnings and predictions",
            icon = "fas fa-exclamation-triangle",
            onSelect = function()
                TriggerServerEvent("stockalerts:getAlerts")
            end
        },
        {
            title = "🏆 Driver Leaderboards",
            description = "View top performing drivers and rankings",
            icon = "fas fa-trophy",
            onSelect = function()
                TriggerEvent("leaderboard:openMenu")
            end
        },
        {
            title = "📊 My Performance",
            description = "View your delivery stats, streaks, and daily progress",
            icon = "fas fa-chart-line",
            onSelect = function()
                TriggerServerEvent("leaderboard:getPersonalStats")
            end
        },
        {
            title = "🏆 Achievement Progress",
            description = "View achievement progress and vehicle tier",
            icon = "fas fa-medal",
            onSelect = function()
                TriggerServerEvent("achievements:getProgress")
            end
        },
    }
    lib.registerContext({
        id = "main_menu",
        title = "🏢 Hurst Industries - Warehouse Operations",
        options = options
    })
    lib.showContext("main_menu")
end)

-- Order Details
RegisterNetEvent("warehouse:showOrderDetails")
AddEventHandler("warehouse:showOrderDetails", function(orders)
    if not orders or #orders == 0 then
        lib.notify({
            title = "No Orders",
            description = "There are no active orders at the moment.",
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end

    local options = {}
    local itemNames = exports.ox_inventory:Items()
    
    for _, orderGroup in ipairs(orders) do
        local restaurantId = orderGroup.restaurantId
        local restaurantData = Config.Restaurants[restaurantId]
        local restaurantName = restaurantData and restaurantData.name or "Unknown Business"
        
        -- Calculate delivery info for this order
        local boxesNeeded, containersNeeded, totalItems = calculateDeliveryBoxes({orderGroup})
        
        -- Create description with all items in the order
        local itemList = {}
        for _, item in ipairs(orderGroup.items) do
            local itemLabel = itemNames[item.itemName:lower()] and itemNames[item.itemName:lower()].label or item.itemName
            table.insert(itemList, item.quantity .. "x " .. itemLabel)
        end
        
        -- Determine order size label
        local sizeLabel = ""
        if boxesNeeded <= 3 then
            sizeLabel = "🟢 Small Order"
        elseif boxesNeeded <= 7 then
            sizeLabel = "🟡 Medium Order"
        else
            sizeLabel = "🔴 Large Order"
        end
        
        table.insert(options, {
            title = sizeLabel .. " - Order: " .. orderGroup.orderGroupId,
            description = string.format("📦 %d boxes (%d containers)\n🏪 %s\n📋 %s\n💰 $%d", 
                boxesNeeded,
                containersNeeded,
                restaurantName, 
                table.concat(itemList, ", "), 
                orderGroup.totalCost),
            onSelect = function()
                lib.registerContext({
                    id = "order_action_menu",
                    title = "Order Actions",
                    options = {
                        { 
                            title = "✅ Accept Order", 
                            description = "Start delivery job (" .. boxesNeeded .. " boxes)",
                            onSelect = function() 
                                TriggerServerEvent("warehouse:acceptOrder", orderGroup.orderGroupId, restaurantId) 
                            end 
                        },
                        { 
                            title = "❌ Deny Order", 
                            description = "Reject this order",
                            onSelect = function() 
                                TriggerServerEvent("warehouse:denyOrder", orderGroup.orderGroupId) 
                            end 
                        }
                    }
                })
                lib.showContext("order_action_menu")
            end
        })
    end
    
    lib.registerContext({
        id = "order_menu",
        title = "Active Orders",
        options = options
    })
    lib.showContext("order_menu")
end)

-- Warehouse Stock Display
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
    local itemNames = exports.ox_inventory:Items()
    for ingredient, quantity in pairs(stock) do
        if string.find(string.lower(ingredient), string.lower(query)) then
            local itemData = itemNames[ingredient]
            local label = itemData and itemData.label or ingredient
            
            -- Add visual indicator for stock levels
            local stockIcon = "🟢"
            if quantity < 50 then stockIcon = "🔴"
            elseif quantity < 100 then stockIcon = "🟡" end
            
            table.insert(options, {
                title = string.format("%s %s | Quantity: %d", stockIcon, label, quantity)
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

-- ===================================
-- ENHANCED DELIVERY SYSTEM WITH VEHICLE SELECTION
-- ===================================

-- Enhanced Spawn Delivery Van with Multi-Box Support and Vehicle Selection
RegisterNetEvent("warehouse:spawnVehicles")
AddEventHandler("warehouse:spawnVehicles", function(restaurantId, orders)
    local boxesNeeded, containersNeeded, totalItems, itemsList = calculateDeliveryBoxes(orders)
    
    print("[DEBUG] Delivery calculated:", boxesNeeded, "boxes,", containersNeeded, "containers for", totalItems, "items")
    
    local warehouseConfig = Config.Warehouses[1]
    if not warehouseConfig then
        print("[ERROR] No warehouse configuration found")
        lib.notify({
            title = "Error",
            description = "No warehouse configuration found.",
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end

    -- Dynamic delivery briefing based on order size
    local briefingText = ""
    local vehicleType = ""
    if boxesNeeded <= 3 then
        briefingText = "Small delivery: Load " .. boxesNeeded .. " box(es) with " .. containersNeeded .. " containers."
        vehicleType = "Standard Van"
    elseif boxesNeeded <= 7 then
        briefingText = "Medium delivery: Load " .. boxesNeeded .. " boxes (" .. containersNeeded .. " containers total)."
        vehicleType = "Delivery Truck"
    else
        briefingText = "LARGE DELIVERY: Load " .. boxesNeeded .. " boxes (" .. containersNeeded .. " containers total). This is a big order!"
        vehicleType = "Heavy Truck"
    end

    lib.alertDialog({
        header = "📦 New Delivery Job",
        content = briefingText .. "\n\nVehicle: " .. vehicleType,
        centered = true,
        cancel = true
    })

    -- DoScreenFadeOut(2500)
    Citizen.Wait(2500)

    local playerPed = PlayerPedId()
    local vehicleModel = GetHashKey(selectDeliveryVehicle(boxesNeeded))
    
    RequestModel(vehicleModel)
    while not HasModelLoaded(vehicleModel) do
        Citizen.Wait(100)
    end

    local van = CreateVehicle(vehicleModel, warehouseConfig.vehicle.position.x, warehouseConfig.vehicle.position.y, warehouseConfig.vehicle.position.z, warehouseConfig.vehicle.position.w, true, false)
    SetEntityAsMissionEntity(van, true, true)
    SetVehicleHasBeenOwnedByPlayer(van, true)
    SetVehicleNeedsToBeHotwired(van, false)
    SetVehRadioStation(van, "OFF")
    SetVehicleEngineOn(van, true, true, false)
    SetEntityCleanupByEngine(van, false)
    
    -- Apply achievement-based vehicle mods if enabled
    if Config.AchievementVehicles and Config.AchievementVehicles.enabled then
        TriggerServerEvent("achievements:applyVehicleMods", NetworkGetNetworkIdFromEntity(van))
    end
    
    local vanPlate = GetVehicleNumberPlateText(van)
    TriggerEvent("vehiclekeys:client:SetOwner", vanPlate)

    deliveryStartTime = GetGameTimer()
    currentDeliveryData = { orderGroupId = orderGroupId, restaurantId = restaurantId }
    
    print("[DEBUG] Van spawned with entity ID:", van, "for", boxesNeeded, "boxes")

    -- DoScreenFadeIn(2500)

    lib.notify({
        title = "📦 " .. (boxesNeeded > 7 and "LARGE " or boxesNeeded > 3 and "MEDIUM " or "") .. "Delivery Ready",
        description = boxesNeeded .. " boxes (" .. containersNeeded .. " containers) need loading",
        type = "success",
        duration = 10000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })

    -- SetEntityCoords(playerPed, warehouseConfig.vehicle.position.x + 2.0, warehouseConfig.vehicle.position.y, warehouseConfig.vehicle.position.z, false, false, false, true)
    
    -- Use enhanced multi-box loading if more than 1 box needed
    if boxesNeeded > 1 then
        TriggerEvent("warehouse:loadMultipleBoxes", warehouseConfig, van, restaurantId, orders, boxesNeeded)
    else
        TriggerEvent("warehouse:loadBoxes", warehouseConfig, van, restaurantId, orders)
    end
end)

-- [REST OF THE FILE REMAINS THE SAME FROM LINE 319 ONWARDS...]
-- Single Box Loading System (for small orders)
RegisterNetEvent("warehouse:loadBoxes")
AddEventHandler("warehouse:loadBoxes", function(warehouseConfig, van, restaurantId, orders)
    print("[DEBUG] Loading single box system...")
    if not DoesEntityExist(van) then
        print("[ERROR] Van does not exist")
        lib.notify({
            title = "Error",
            description = "Delivery van not found. Please restart the job.",
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end

    local playerPed = PlayerPedId()
    local boxCount = 0
    local maxBoxes = 1
    local hasBox = false
    local boxProp = nil
    local boxBlips = {}
    local boxEntities = {}
    local targetZones = {}
    local vanTargetName = "van_load"

    -- Use consistent prop from config
    local propName = Config.DeliveryProps.boxProp
    local model = GetHashKey(propName)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Citizen.Wait(100)
    end

    local boxPositions = warehouseConfig.boxPositions
    if not boxPositions or #boxPositions == 0 then
        print("[ERROR] No boxPositions defined")
        lib.notify({
            title = "Error",
            description = "No box pickup locations available.",
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end

    -- Get item label from orders
    local itemNames = exports.ox_inventory:Items() or {}
    local itemLabel = "supplies"
    if orders and #orders > 0 then
        if orders[1].items and #orders[1].items > 0 then
            local itemKey = orders[1].items[1].itemName or "supplies"
            itemLabel = itemNames[itemKey:lower()] and itemNames[itemKey:lower()].label or itemKey
        elseif orders[1].itemName then
            local itemKey = orders[1].itemName
            itemLabel = itemNames[itemKey:lower()] and itemNames[itemKey:lower()].label or itemKey
        end
    end

    print("[DEBUG] Creating single box for item:", itemLabel)

    local pos = boxPositions[1]
    local box = CreateObject(model, pos.x, pos.y, pos.z, true, true, true)
    if DoesEntityExist(box) then
        PlaceObjectOnGroundProperly(box)
        table.insert(boxEntities, box)
        
        -- Light effect consistent with multi-box system
        Citizen.CreateThread(function()
            while DoesEntityExist(box) do
                DrawLightWithRange(pos.x, pos.y, pos.z + 0.5, 0, 255, 0, 2.0, 1.0)
                Citizen.Wait(0)
            end
        end)
    end

    -- Set delivery tracking for single box
    deliveryBoxesRemaining = 1
    totalDeliveryBoxes = 1

    -- Create blip
    local blip = AddBlipForCoord(pos.x, pos.y, pos.z)
    SetBlipSprite(blip, 1)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.7)
    SetBlipColour(blip, 4)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Box Pickup")
    EndTextCommandSetBlipName(blip)
    table.insert(boxBlips, blip)

    -- Create target zone
    local zoneName = "box_pickup_single"
    exports.ox_target:addBoxZone({
        coords = vector3(pos.x, pos.y, pos.z),
        size = vector3(2.0, 2.0, 2.0),
        rotation = 0,
        debug = false,
        name = zoneName,
        options = {
            {
                label = "Pick Up Box",
                icon = "fas fa-box",
                onSelect = function()
                    print("[DEBUG] Picking up single box")
                    if hasBox then
                        lib.notify({
                            title = "Error",
                            description = "You are already carrying a box.",
                            type = "error",
                            duration = 10000,
                            position = Config.UI.notificationPosition,
                            markdown = Config.UI.enableMarkdown
                        })
                        return
                    end
                    if not DoesEntityExist(van) then
                        lib.notify({
                            title = "Error",
                            description = "Delivery van not found. Please restart the job.",
                            type = "error",
                            duration = 10000,
                            position = Config.UI.notificationPosition,
                            markdown = Config.UI.enableMarkdown
                        })
                        return
                    end
                    if lib.progressBar({
                        duration = 3000,
                        position = "bottom",
                        label = "Picking Up Box...",
                        canCancel = false,
                        disable = { move = true, car = true, combat = true, sprint = true },
                        anim = { dict = "mini@repair", clip = "fixing_a_ped" }
                    }) then
                        if DoesEntityExist(box) then
                            DeleteObject(box)
                        end
                        
                        local playerCoords = GetEntityCoords(playerPed)
                        boxProp = CreateObject(model, playerCoords.x, playerCoords.y, playerCoords.z, true, true, true)
                        AttachEntityToEntity(boxProp, playerPed, GetPedBoneIndex(playerPed, 60309),
                            0.1, 0.2, 0.25, -90.0, 0.0, 0.0, true, true, false, true, 1, true)

                        hasBox = true
                        local animDict = "anim@heists@box_carry@"
                        RequestAnimDict(animDict)
                        while not HasAnimDictLoaded(animDict) do
                            Citizen.Wait(0)
                        end
                        TaskPlayAnim(playerPed, animDict, "idle", 8.0, -8.0, -1, 50, 0, false, false, false)

                        lib.notify({
                            title = "Box Picked Up",
                            description = "Load " .. itemLabel .. " into the van.",
                            type = "success",
                            duration = 10000,
                            position = Config.UI.notificationPosition,
                            markdown = Config.UI.enableMarkdown
                        })
                    end
                end
            }
        }
    })
    table.insert(targetZones, zoneName)

    -- Van blip
    local vanCoords = GetEntityCoords(van)
    local vanBlip = AddBlipForCoord(vanCoords.x, vanCoords.y, vanCoords.z)
    SetBlipSprite(vanBlip, 1)
    SetBlipDisplay(vanBlip, 4)
    SetBlipScale(vanBlip, 1.0)
    SetBlipColour(vanBlip, 3)
    SetBlipAsShortRange(vanBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Van Location")
    EndTextCommandSetBlipName(vanBlip)

    -- Van loading zone
    local function updateVanTargetZone()
        while DoesEntityExist(van) and boxCount < maxBoxes do
            local vanPos = GetEntityCoords(van)
            local vanHeading = GetEntityHeading(van)
            local vanBackPosition = vector3(
                vanPos.x + math.sin(math.rad(vanHeading)) * 3.0,
                vanPos.y - math.cos(math.rad(vanHeading)) * 3.0,
                vanPos.z + 0.5
            )

            exports.ox_target:removeZone(vanTargetName)
            exports.ox_target:addBoxZone({
                coords = vanBackPosition,
                size = vector3(3.0, 3.0, 2.0),
                rotation = vanHeading,
                debug = false,
                name = vanTargetName,
                options = {
                    {
                        label = "Load Box",
                        icon = "fas fa-truck-loading",
                        onSelect = function()
                            print("[DEBUG] Loading box into van")
                            if not hasBox then
                                lib.notify({
                                    title = "Error",
                                    description = "You need to pick up a box first.",
                                    type = "error",
                                    duration = 10000,
                                    position = Config.UI.notificationPosition,
                                    markdown = Config.UI.enableMarkdown
                                })
                                return
                            end
                            if lib.progressBar({
                                duration = 3000,
                                position = "bottom",
                                label = "Loading Box...",
                                canCancel = false,
                                disable = { move = true, car = true, combat = true, sprint = true },
                                anim = { dict = "mini@repair", clip = "fixing_a_ped" }
                            }) then
                                if boxProp and DoesEntityExist(boxProp) then
                                    DeleteObject(boxProp)
                                    boxProp = nil
                                end
                                hasBox = false
                                boxCount = boxCount + 1
                                ClearPedTasks(playerPed)
                                
                                lib.notify({
                                    title = "Box Loaded",
                                    description = itemLabel .. " loaded into the van. Start the delivery.",
                                    type = "success",
                                    duration = 10000,
                                    position = Config.UI.notificationPosition,
                                    markdown = Config.UI.enableMarkdown
                                })
                                
                                -- Clean up
                                RemoveBlip(vanBlip)
                                for _, blip in ipairs(boxBlips) do
                                    RemoveBlip(blip)
                                end
                                for _, zone in ipairs(targetZones) do
                                    exports.ox_target:removeZone(zone)
                                end
                                exports.ox_target:removeZone(vanTargetName)
                                for _, entity in ipairs(boxEntities) do
                                    if DoesEntityExist(entity) then
                                        DeleteObject(entity)
                                    end
                                end
                                
                                TriggerEvent("warehouse:startDelivery", restaurantId, van, orders)
                            end
                        end
                    }
                }
            })
            Citizen.Wait(1000)
        end
    end

    Citizen.CreateThread(updateVanTargetZone)

    lib.notify({
        title = "Box Available",
        description = "Pick up " .. itemLabel .. " from the marked location and load it into the van.",
        type = "success",
        duration = 10000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })
end)

-- Enhanced Multi-Box Loading System with Pallet Props
RegisterNetEvent("warehouse:loadMultipleBoxes")
AddEventHandler("warehouse:loadMultipleBoxes", function(warehouseConfig, van, restaurantId, orders, totalBoxes)
    print("[DEBUG] Starting enhanced multi-box loading system for", totalBoxes, "boxes")
    
    if not DoesEntityExist(van) then
        print("[ERROR] Van does not exist")
        lib.notify({
            title = "Error",
            description = "Delivery van not found. Please restart the job.",
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end

    local playerPed = PlayerPedId()
    local boxesLoaded = 0
    local hasBox = false
    local boxProp = nil
    local palletBlip = nil
    local palletEntity = nil
    local targetZones = {}
    local vanTargetName = "van_load_multi"
    local palletZoneName = "pallet_pickup_multi"

    -- Load both props
    local boxModel = GetHashKey(Config.DeliveryProps.boxProp)
    local palletModel = GetHashKey(Config.DeliveryProps.palletProp)
    
    RequestModel(boxModel)
    RequestModel(palletModel)
    while not HasModelLoaded(boxModel) or not HasModelLoaded(palletModel) do
        Citizen.Wait(100)
    end

    local boxPositions = warehouseConfig.boxPositions
    if not boxPositions or #boxPositions == 0 then
        print("[ERROR] No boxPositions defined")
        return
    end

    -- Create single pallet prop instead of individual boxes
    local palletPos = boxPositions[1]
    palletEntity = CreateObject(palletModel, palletPos.x, palletPos.y, palletPos.z, true, true, true)
    if DoesEntityExist(palletEntity) then
        PlaceObjectOnGroundProperly(palletEntity)
        
        -- Enhanced pallet light effect with pulsing
        Citizen.CreateThread(function()
            while DoesEntityExist(palletEntity) and boxesLoaded < totalBoxes do
                local lightColor = { r = 0, g = 255, b = 0 } -- Green for available
                if totalBoxes > 5 then 
                    lightColor = { r = 255, g = 165, b = 0 } -- Orange for large orders
                end
                
                DrawLightWithRange(palletPos.x, palletPos.y, palletPos.z + 1.0, 
                    lightColor.r, lightColor.g, lightColor.b, 3.0, 1.5)
                Citizen.Wait(0)
            end
        end)
    end

    -- Create blip for pallet
    palletBlip = AddBlipForCoord(palletPos.x, palletPos.y, palletPos.z)
    SetBlipSprite(palletBlip, 1)
    SetBlipDisplay(palletBlip, 4)
    SetBlipScale(palletBlip, 0.8)
    SetBlipColour(palletBlip, 2)
    SetBlipAsShortRange(palletBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Box Pallet (" .. totalBoxes .. " boxes needed)")
    EndTextCommandSetBlipName(palletBlip)

    -- Helper function to update pallet zone
    local function updatePalletZone()
        exports.ox_target:removeZone(palletZoneName)
        exports.ox_target:addBoxZone({
            coords = vector3(palletPos.x, palletPos.y, palletPos.z),
            size = vector3(3.0, 3.0, 2.0),
            rotation = 0,
            debug = false,
            name = palletZoneName,
            options = {
                {
                    label = string.format("Grab Box (%d/%d loaded)", boxesLoaded, totalBoxes),
                    icon = "fas fa-box",
                    disabled = hasBox or boxesLoaded >= totalBoxes,
                    onSelect = function()
                        if hasBox then
                            lib.notify({
                                title = "Error",
                                description = "You are already carrying a box.",
                                type = "error",
                                duration = 5000,
                                position = Config.UI.notificationPosition,
                                markdown = Config.UI.enableMarkdown
                            })
                            return
                        end
                        
                        if boxesLoaded == 0 then
                            -- Only show instruction on first box
                            lib.notify({
                                title = "📦 Loading Instructions",
                                description = string.format("Take %d boxes from pallet to van", totalBoxes),
                                type = "info",
                                duration = 10000,
                                position = Config.UI.notificationPosition,
                                markdown = Config.UI.enableMarkdown
                            })
                        end
                        
                        if lib.progressBar({
                            duration = 2500,
                            position = "bottom",
                            label = "Grabbing box from pallet...",
                            canCancel = false,
                            disable = { move = true, car = true, combat = true, sprint = true },
                            anim = { dict = "mini@repair", clip = "fixing_a_ped" }
                        }) then
                            -- Create box in player's hands
                            local playerCoords = GetEntityCoords(playerPed)
                            boxProp = CreateObject(boxModel, playerCoords.x, playerCoords.y, playerCoords.z, true, true, true)
                            AttachEntityToEntity(boxProp, playerPed, GetPedBoneIndex(playerPed, 60309),
                                0.1, 0.2, 0.25, -90.0, 0.0, 0.0, true, true, false, true, 1, true)

                            hasBox = true
                            local animDict = "anim@heists@box_carry@"
                            RequestAnimDict(animDict)
                            while not HasAnimDictLoaded(animDict) do
                                Citizen.Wait(0)
                            end
                            TaskPlayAnim(playerPed, animDict, "idle", 8.0, -8.0, -1, 50, 0, false, false, false)

                        end
                    end
                }
            }
        })
    end

    -- Initial pallet zone setup
    updatePalletZone()
    table.insert(targetZones, palletZoneName)

    -- Van loading with progress tracking
    local function updateVanTargetZone()
        while DoesEntityExist(van) and boxesLoaded < totalBoxes do
            local vanPos = GetEntityCoords(van)
            local vanHeading = GetEntityHeading(van)
            local vanBackPosition = vector3(
                vanPos.x + math.sin(math.rad(vanHeading)) * 3.0,
                vanPos.y - math.cos(math.rad(vanHeading)) * 3.0,
                vanPos.z + 0.5
            )

            exports.ox_target:removeZone(vanTargetName)
            exports.ox_target:addBoxZone({
                coords = vanBackPosition,
                size = vector3(3.0, 3.0, 2.0),
                rotation = vanHeading,
                debug = false,
                name = vanTargetName,
                options = {
                    {
                        label = string.format("Load Box (%d/%d)", boxesLoaded + 1, totalBoxes),
                        icon = "fas fa-truck-loading",
                        onSelect = function()
                            if not hasBox then
                                lib.notify({
                                    title = "Error",
                                    description = "You need to grab a box from the pallet first.",
                                    type = "error",
                                    duration = 5000,
                                    position = Config.UI.notificationPosition,
                                    markdown = Config.UI.enableMarkdown
                                })
                                return
                            end
                            
                            if lib.progressBar({
                                duration = 3000,
                                position = "bottom",
                                label = string.format("Loading box %d/%d...", boxesLoaded + 1, totalBoxes),
                                canCancel = false,
                                disable = { move = true, car = true, combat = true, sprint = true },
                                anim = { dict = "mini@repair", clip = "fixing_a_ped" }
                            }) then
                                if boxProp and DoesEntityExist(boxProp) then
                                    DeleteObject(boxProp)
                                    boxProp = nil
                                end
                                hasBox = false
                                boxesLoaded = boxesLoaded + 1
                                ClearPedTasks(playerPed)
                                
                                -- Update pallet zone when box is loaded into van
                                updatePalletZone()
                                
                                if boxesLoaded >= totalBoxes then
                                    -- All boxes loaded!
                                    lib.notify({
                                        title = "✅ Loading Complete",
                                        description = string.format("All %d boxes loaded! Drive to %s", totalBoxes, restaurantName or "restaurant"),
                                        type = "success",
                                        duration = 10000,
                                        position = Config.UI.notificationPosition,
                                        markdown = Config.UI.enableMarkdown
                                    })
                                    
                                    -- Clean up
                                    if palletBlip then RemoveBlip(palletBlip) end
                                    if DoesEntityExist(palletEntity) then DeleteObject(palletEntity) end
                                    
                                    for _, zone in ipairs(targetZones) do
                                        exports.ox_target:removeZone(zone)
                                    end
                                    exports.ox_target:removeZone(vanTargetName)
                                    
                                    TriggerEvent("warehouse:startDelivery", restaurantId, van, orders)
                                else
                                    lib.notify({
                                        title = "Box Loaded",
                                        description = string.format("%d boxes remaining", totalBoxes - boxesLoaded),
                                        type = "success",
                                        duration = 5000,
                                        position = Config.UI.notificationPosition,
                                        markdown = Config.UI.enableMarkdown
                                    })
                                end
                            end
                        end
                    }
                }
            })
            Citizen.Wait(1000)
        end
    end

    Citizen.CreateThread(updateVanTargetZone)

    lib.notify({
        title = "📦 Pallet Loading System",
        description = string.format("Grab boxes from the pallet and load %d boxes into the van", totalBoxes),
        type = "info",
        duration = 15000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })
end)

-- ===================================
-- ENHANCED DELIVERY SYSTEM
-- ===================================

-- Start Delivery with Enhanced Tracking
RegisterNetEvent("warehouse:startDelivery")
AddEventHandler("warehouse:startDelivery", function(restaurantId, van, orders)
    print("[DEBUG] Starting enhanced delivery to restaurant:", restaurantId)
    
    -- Calculate total boxes needed for delivery
    local boxesNeeded, containersNeeded, totalItems = calculateDeliveryBoxes(orders)
    deliveryBoxesRemaining = boxesNeeded
    totalDeliveryBoxes = boxesNeeded
    
    lib.alertDialog({
        header = "Van Loaded",
        content = string.format("Drive to the restaurant and deliver %d boxes to businesses door!", boxesNeeded),
        centered = true,
        cancel = true
    })

    local deliveryPosition = Config.Restaurants[restaurantId].delivery
    lib.notify({
        title = "Delivery Started",
        description = string.format("Drive to delivery location and deliver %d boxes", boxesNeeded),
        type = "success",
        duration = 10000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })

    SetNewWaypoint(deliveryPosition.x, deliveryPosition.y)
    local blip = AddBlipForCoord(deliveryPosition.x, deliveryPosition.y, deliveryPosition.z)
    SetBlipSprite(blip, 1)
    SetBlipScale(blip, 0.7)
    SetBlipColour(blip, 3)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Delivery Location")
    EndTextCommandSetBlipName(blip)

    Citizen.CreateThread(function()
        local isTextUIShown = false
        while DoesEntityExist(van) do
            local playerPed = PlayerPedId()
            local vanPos = GetEntityCoords(van)
            local distance = #(vanPos - vector3(deliveryPosition.x, deliveryPosition.y, deliveryPosition.z))
            
            if distance < 10.0 and IsPedInVehicle(playerPed, van, false) then
                if not isTextUIShown then
                    lib.showTextUI("[E] Park Van & Start Delivery", {
                        icon = "fas fa-parking"
                    })
                    isTextUIShown = true
                end
                if IsControlJustPressed(0, 38) then -- E key
                    if distance < 10.0 then
                        lib.hideTextUI()
                        isTextUIShown = false
                        RemoveBlip(blip)
                        TriggerEvent("warehouse:setupDeliveryZone", restaurantId, van, orders)
                        break
                    else
                        lib.notify({
                            title = "Error",
                            description = "Van is too far from the delivery zone.",
                            type = "error",
                            duration = 10000,
                            position = Config.UI.notificationPosition,
                            markdown = Config.UI.enableMarkdown
                        })
                    end
                end
            else
                if isTextUIShown then
                    lib.hideTextUI()
                    isTextUIShown = false
                end
            end
            Citizen.Wait(0)
        end
        if isTextUIShown then
            lib.hideTextUI()
        end
        RemoveBlip(blip)
    end)
end)

-- Setup Delivery Zone with Ground Marker
RegisterNetEvent("warehouse:setupDeliveryZone")
AddEventHandler("warehouse:setupDeliveryZone", function(restaurantId, van, orders)
    print("[DEBUG] Setting up delivery zone with", deliveryBoxesRemaining, "boxes to deliver")
    
    local deliverBoxPosition = Config.Restaurants[restaurantId] and Config.Restaurants[restaurantId].deliveryBox
    if not deliverBoxPosition then
        print("[ERROR] No deliveryBox position defined for restaurant " .. tostring(restaurantId))
        deliverBoxPosition = vector3(-1177.39, -890.98, 12.79) -- Fallback
    end

    -- Start the van grabbing and delivery loop
    TriggerEvent("warehouse:startDeliveryLoop", restaurantId, van, orders, deliverBoxPosition)
end)

-- Delivery Loop Handler
RegisterNetEvent("warehouse:startDeliveryLoop")
AddEventHandler("warehouse:startDeliveryLoop", function(restaurantId, van, orders, deliverBoxPosition)
    if deliveryBoxesRemaining == totalDeliveryBoxes then
    -- Only show instruction on first box
        lib.notify({
            title = "📦 Delivery Instructions", 
            description = string.format("Take %d boxes from van to business door", totalDeliveryBoxes),
            type = "info",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
    end
    
    -- Start with grabbing box from van
    TriggerEvent("warehouse:grabBoxFromVan", restaurantId, van, orders, deliverBoxPosition)
end)

-- Enhanced Grab Box from Van
RegisterNetEvent("warehouse:grabBoxFromVan")
AddEventHandler("warehouse:grabBoxFromVan", function(restaurantId, van, orders, deliverBoxPosition)
    print("[DEBUG] Setting up enhanced grab box from van")
    if not DoesEntityExist(van) then
        print("[ERROR] Van does not exist")
        lib.notify({
            title = "Error",
            description = "Delivery van not found.",
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end

    local playerPed = PlayerPedId()
    local hasBox = false
    local boxProp = nil
    local vanTargetName = "van_grab_" .. tostring(van)
    local propName = Config.DeliveryProps.boxProp
    local model = GetHashKey(propName)

    RequestModel(model)
    while not HasModelLoaded(model) do
        Citizen.Wait(100)
    end

    local itemNames = exports.ox_inventory:Items() or {}
    local itemLabel = "supplies"
    if orders and #orders > 0 then
        if orders[1].items and #orders[1].items > 0 then
            local itemKey = orders[1].items[1].itemName or "supplies"
            itemLabel = itemNames[itemKey:lower()] and itemNames[itemKey:lower()].label or itemKey
        elseif orders[1].itemName then
            local itemKey = orders[1].itemName
            itemLabel = itemNames[itemKey:lower()] and itemNames[itemKey:lower()].label or itemKey
        end
    end

    local function updateGrabBoxZone()
        while DoesEntityExist(van) and not hasBox do
            local vanPos = GetEntityCoords(van)
            local vanHeading = GetEntityHeading(van)
            local vanBackPosition = vector3(
                vanPos.x + math.sin(math.rad(vanHeading)) * 3.0,
                vanPos.y - math.cos(math.rad(vanHeading)) * 3.0,
                vanPos.z + 0.5
            )

            exports.ox_target:removeZone(vanTargetName)
            exports.ox_target:addBoxZone({
                coords = vanBackPosition,
                size = vector3(3.0, 3.0, 2.0),
                rotation = vanHeading,
                debug = false,
                name = vanTargetName,
                options = {
                    {
                        label = string.format("Grab Box (%d/%d)", totalDeliveryBoxes - deliveryBoxesRemaining + 1, totalDeliveryBoxes),
                        icon = "fas fa-box",
                        onSelect = function()
                            print("[DEBUG] Grabbing box from van")
                            if hasBox then
                                lib.notify({
                                    title = "Error",
                                    description = "You are already carrying a box.",
                                    type = "error",
                                    duration = 10000,
                                    position = Config.UI.notificationPosition,
                                    markdown = Config.UI.enableMarkdown
                                })
                                return
                            end
                            if lib.progressBar({
                                duration = 3000,
                                position = "bottom",
                                label = string.format("Grabbing box %d/%d...", totalDeliveryBoxes - deliveryBoxesRemaining + 1, totalDeliveryBoxes),
                                canCancel = false,
                                disable = { move = true, car = true, combat = true, sprint = true },
                                anim = { dict = "mini@repair", clip = "fixing_a_ped" }
                            }) then
                                local playerCoords = GetEntityCoords(playerPed)
                                boxProp = CreateObject(model, playerCoords.x, playerCoords.y, playerCoords.z, true, true, true)
                                AttachEntityToEntity(boxProp, playerPed, GetPedBoneIndex(playerPed, 60309),
                                    0.1, 0.2, 0.25, -90.0, 0.0, 0.0, true, true, false, true, 1, true)

                                hasBox = true
                                local animDict = "anim@heists@box_carry@"
                                RequestAnimDict(animDict)
                                while not HasAnimDictLoaded(animDict) do
                                    Citizen.Wait(0)
                                end
                                TaskPlayAnim(playerPed, animDict, "idle", 8.0, -8.0, -1, 50, 0, false, false, false)

                                exports.ox_target:removeZone(vanTargetName)
                                TriggerEvent("warehouse:deliverBoxWithMarker", restaurantId, van, orders, boxProp, deliverBoxPosition)
                            end
                        end
                    }
                }
            })
            Citizen.Wait(1000)
        end
    end

    Citizen.CreateThread(updateGrabBoxZone)
end)

-- Enhanced Deliver Box with Ground Marker
RegisterNetEvent("warehouse:deliverBoxWithMarker")
AddEventHandler("warehouse:deliverBoxWithMarker", function(restaurantId, van, orders, boxProp, deliverBoxPosition)
    print("[DEBUG] Setting up delivery with ground marker")
    if not boxProp or not DoesEntityExist(boxProp) then
        print("[ERROR] No valid boxProp")
        lib.notify({
            title = "Error",
            description = "You are not carrying a box.",
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end

    local playerPed = PlayerPedId()
    local targetName = "delivery_zone_" .. restaurantId .. "_" .. tostring(GetGameTimer())

    -- Create visual marker at delivery location
    Citizen.CreateThread(function()
        while DoesEntityExist(boxProp) do
            DrawMarker(
                Config.DeliveryProps.deliveryMarker.type,
                deliverBoxPosition.x, deliverBoxPosition.y, deliverBoxPosition.z,
                0.0, 0.0, 0.0,
                0.0, 0.0, 0.0,
                Config.DeliveryProps.deliveryMarker.size.x,
                Config.DeliveryProps.deliveryMarker.size.y,
                Config.DeliveryProps.deliveryMarker.size.z,
                Config.DeliveryProps.deliveryMarker.color.r,
                Config.DeliveryProps.deliveryMarker.color.g,
                Config.DeliveryProps.deliveryMarker.color.b,
                Config.DeliveryProps.deliveryMarker.color.a,
                Config.DeliveryProps.deliveryMarker.bobUpAndDown,
                Config.DeliveryProps.deliveryMarker.faceCamera,
                2,
                Config.DeliveryProps.deliveryMarker.rotate,
                nil, nil, false
            )
            Citizen.Wait(0)
        end
    end)

    -- Create delivery target zone
    exports.ox_target:addBoxZone({
        coords = vector3(deliverBoxPosition.x, deliverBoxPosition.y, deliverBoxPosition.z + 0.5),
        size = vector3(4.0, 4.0, 3.0),
        rotation = 0,
        debug = false,
        name = targetName,
        options = {
            {
                label = string.format("Deliver Box (%d/%d)", totalDeliveryBoxes - deliveryBoxesRemaining + 1, totalDeliveryBoxes),
                icon = "fas fa-box",
                onSelect = function()
                    print("[DEBUG] Delivering box to marker")
                    if not boxProp or not DoesEntityExist(boxProp) then
                        lib.notify({
                            title = "Error",
                            description = "You are not carrying a box.",
                            type = "error",
                            duration = 10000,
                            position = Config.UI.notificationPosition,
                            markdown = Config.UI.enableMarkdown
                        })
                        return
                    end
                    if lib.progressBar({
                        duration = 3000,
                        position = "bottom",
                        label = string.format("Delivering box %d/%d...", totalDeliveryBoxes - deliveryBoxesRemaining + 1, totalDeliveryBoxes),
                        canCancel = false,
                        disable = { move = true, car = true, combat = true, sprint = true },
                        anim = { dict = "mini@repair", clip = "fixing_a_ped" }
                    }) then
                        DeleteObject(boxProp)
                        ClearPedTasks(playerPed)
                        exports.ox_target:removeZone(targetName)
                        
                        deliveryBoxesRemaining = deliveryBoxesRemaining - 1
                        
                        if deliveryBoxesRemaining > 0 then
                            -- Don't show individual notifications, just continue
                            TriggerEvent("warehouse:startDeliveryLoop", restaurantId, van, orders, deliverBoxPosition)
                        else
                            -- All boxes delivered - single completion notification
                            lib.notify({
                                title = "✅ Delivery Complete", 
                                description = "All boxes delivered! Return van to warehouse.",
                                type = "success",
                                duration = 10000,
                                position = Config.UI.notificationPosition,
                                markdown = Config.UI.enableMarkdown
                            })
                            TriggerEvent("warehouse:completeDelivery", restaurantId, van, orders)
                        end
                    end
                end
            }
        }
    })

    lib.notify({
        title = "Delivery Zone Active",
        description = string.format("Drop Box %d/%d at business door", totalDeliveryBoxes - deliveryBoxesRemaining + 1, totalDeliveryBoxes),
        type = "success",
        duration = 10000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })
end)

-- Complete Delivery Handler - Stock Update Happens HERE (Not on van return)
RegisterNetEvent("warehouse:completeDelivery")
AddEventHandler("warehouse:completeDelivery", function(restaurantId, van, orders)
    -- All boxes delivered - trigger stock update immediately
    local deliveryEndTime = GetGameTimer()
    local totalDeliveryTime = math.floor((deliveryEndTime - deliveryStartTime) / 1000)
    
    -- Add delivery time to orders data
    for _, order in ipairs(orders) do
        order.deliveryTime = totalDeliveryTime
    end
    
    -- STOCK UPDATE HAPPENS IMMEDIATELY UPON DELIVERY COMPLETION
    TriggerServerEvent("update:stock", restaurantId, orders)
    
    lib.notify({
        title = "🎉 All Boxes Delivered!",
        description = string.format("Successfully delivered all %d boxes! Stock updated immediately. Return the van to complete job.", totalDeliveryBoxes),
        type = "success",
        duration = 12000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })
    
    TriggerEvent("warehouse:returnTruck", van, restaurantId, orders)
end)

RegisterNetEvent('delivery:storeCompletionData')
AddEventHandler('delivery:storeCompletionData', function(data)
    completedDeliveryData = data
    completedDeliveryData.deliveryTime = math.floor((GetGameTimer() - deliveryStartTime) / 1000)
end)

-- Return Van (Clean Van Return Only - Stock Already Updated)
RegisterNetEvent("warehouse:returnTruck")
AddEventHandler("warehouse:returnTruck", function(van, restaurantId, orders)
    print("[DEBUG] Returning van")
    lib.alertDialog({
        header = "Delivery Complete",
        content = "Great Work! Stock has been delivered and updated. Return the van to the warehouse for your payment.",
        centered = true,
        cancel = true
    })

    local playerPed = PlayerPedId()
    local vanReturnPosition = vector3(Config.Warehouses[1].vehicle.position.x, Config.Warehouses[1].vehicle.position.y, Config.Warehouses[1].vehicle.position.z)
    SetNewWaypoint(vanReturnPosition.x, vanReturnPosition.y)

    local blip = AddBlipForCoord(vanReturnPosition.x, vanReturnPosition.y, vanReturnPosition.z)
    SetBlipSprite(blip, 1)
    SetBlipScale(blip, 0.7)
    SetBlipColour(blip, 3)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Van Return Location")
    EndTextCommandSetBlipName(blip)

    Citizen.CreateThread(function()
        local isTextUIShown = false
        while DoesEntityExist(van) do
            local vanPos = GetEntityCoords(van)
            local distance = #(vanPos - vanReturnPosition)
            if distance < 10.0 and IsPedInVehicle(playerPed, van, false) then
                if not isTextUIShown then
                    lib.showTextUI("[E] Return Van", {
                        icon = "fas fa-parking"
                    })
                    isTextUIShown = true
                end
                if IsControlJustPressed(0, 38) then -- E key
                    if lib.progressBar({
                        duration = 3000,
                        label = "Returning Van...",
                        position = "bottom",
                        canCancel = false,
                        disable = { move = true, car = true, combat = true, sprint = true },
                        anim = { dict = "anim@scripted@heist@ig3_button_press@male@", clip = "button_press" }
                    }) then
                        lib.hideTextUI()
                        isTextUIShown = false
                        lib.alertDialog({
                            header = "Van Returned",
                            content = "Delivery job complete! Thank you for your excellent work!",
                            centered = true,
                            cancel = true
                        })
                        RemoveBlip(blip)
                        DeleteVehicle(van)
                        
                        if completedDeliveryData then
                    TriggerServerEvent('delivery:requestPayment', completedDeliveryData)
                        completedDeliveryData = nil -- Clear the data
                    end
                    
                    lib.alertDialog({
                        header = "Van Returned",
                        content = "Processing your payment...",
                        centered = true,
                        cancel = false
                    })
                    
                        -- Reset delivery variables for next job
                        deliveryBoxesRemaining = 0
                        totalDeliveryBoxes = 0
                        currentDeliveryData = {}
                        deliveryStartTime = 0
                        
                        break
                    end
                end
            else
                if isTextUIShown then
                    lib.hideTextUI()
                    isTextUIShown = false
                end
            end
            Citizen.Wait(0)
        end
        if isTextUIShown then
            lib.hideTextUI()
        end
        RemoveBlip(blip)
    end)
end)

-- Handle email action button click
RegisterNetEvent('supply:openWarehouseMenu')
AddEventHandler('supply:openWarehouseMenu', function(data)
    -- Get the nearest warehouse location
    local playerCoords = GetEntityCoords(PlayerPedId())
    local nearestWarehouse = nil
    local nearestDistance = 9999.0
    
    -- Find the closest warehouse
    for index, warehouse in ipairs(Config.WarehousesLocation) do
        local distance = #(playerCoords - warehouse.position)
        if distance < nearestDistance then
            nearestDistance = distance
            nearestWarehouse = warehouse
        end
    end
    
    if nearestWarehouse then
        -- Set waypoint to nearest warehouse
        SetNewWaypoint(nearestWarehouse.position.x, nearestWarehouse.position.y)
        
        -- Show notification
        lib.notify({
            title = "📍 Warehouse Location",
            description = "Waypoint set to nearest warehouse. Head there to view orders!",
            type = "info",
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        
        -- Optional: Create a temporary blip
        local warehouseBlip = AddBlipForCoord(nearestWarehouse.position.x, nearestWarehouse.position.y, nearestWarehouse.position.z)
        SetBlipSprite(warehouseBlip, 478) -- Warehouse icon
        SetBlipDisplay(warehouseBlip, 4)
        SetBlipScale(warehouseBlip, 1.2)
        SetBlipColour(warehouseBlip, 5) -- Yellow
        SetBlipAsShortRange(warehouseBlip, false)
        SetBlipFlashes(warehouseBlip, true) -- Make it flash
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("📦 New Order Available")
        EndTextCommandSetBlipName(warehouseBlip)
        
        -- Remove the flashing blip after 30 seconds
        Citizen.SetTimeout(30000, function()
            if DoesBlipExist(warehouseBlip) then
                RemoveBlip(warehouseBlip)
            end
        end)
    else
        lib.notify({
            title = "Error",
            description = "No warehouse location found!",
            type = "error",
            duration = 5000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
    end
end)