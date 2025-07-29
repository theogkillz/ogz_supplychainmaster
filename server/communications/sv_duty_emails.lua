local QBCore = exports['qb-core']:GetCoreObject()

-- ===============================================
-- DUTY EMAIL NOTIFICATIONS
-- Send pending orders email when going on duty
-- ===============================================

-- Function to send duty summary email
local function sendDutySummaryEmail(playerId)
    print("[DUTY EMAIL DEBUG] Starting sendDutySummaryEmail for player:", playerId)
    
    local xPlayer = QBCore.Functions.GetPlayer(playerId)
    if not xPlayer then 
        print("[DUTY EMAIL DEBUG] ERROR: xPlayer not found")
        return 
    end
    
    -- Get all pending orders
    print("[DUTY EMAIL DEBUG] Fetching pending orders from database...")
    
    MySQL.Async.fetchAll([[
        SELECT 
            o.*,
            o.restaurant_id
        FROM supply_orders o
        WHERE o.status = 'pending'
        ORDER BY o.created_at ASC
    ]], {}, function(results)
        
        print("[DUTY EMAIL DEBUG] Query returned", results and #results or 0, "orders")
        
        if not results or #results == 0 then
            print("[DUTY EMAIL DEBUG] Sending 'no orders' email")
            
            -- Use LBPhone integration to send email - NOW CORRECTLY PASSING PLAYER ID
            local LBPhone = _G.LBPhone
            if LBPhone then
                LBPhone.SendDutyEmail(playerId, {  -- FIXED: Correctly passing playerId
                    subject = "📋 Duty Report - No Pending Orders",
                    message = "Welcome to your shift! There are currently no pending orders in the system."
                })
            else
                print("[DUTY EMAIL DEBUG] ERROR: LBPhone integration not found")
            end
            return
        end
        
        -- Process orders
        print("[DUTY EMAIL DEBUG] Processing", #results, "orders")
        
        -- Group orders by order_group_id
        local orderGroups = {}
        local totalValue = 0
        local itemNames = exports.ox_inventory:Items() or {}
        
        for _, order in ipairs(results) do
            print("[DUTY EMAIL DEBUG] Processing order:", order.id, "Group:", order.order_group_id, "Restaurant:", order.restaurant_id)
            
            local groupId = order.order_group_id or tostring(order.id)
            
            if not orderGroups[groupId] then
                orderGroups[groupId] = {
                    restaurantName = "Restaurant #" .. (order.restaurant_id or "Unknown"),
                    restaurantId = order.restaurant_id,
                    items = {},
                    totalCost = 0,
                    boxes = 0
                }
            end
            
            -- Get item label
            local itemLabel = order.ingredient
            if itemNames[order.ingredient] then
                itemLabel = itemNames[order.ingredient].label
            end
            
            table.insert(orderGroups[groupId].items, {
                name = itemLabel,
                quantity = order.quantity
            })
            
            orderGroups[groupId].totalCost = orderGroups[groupId].totalCost + (order.total_cost or 0)
            totalValue = totalValue + (order.total_cost or 0)
            
            -- Calculate boxes
            local itemsPerContainer = 12
            local containersPerBox = 5
            if Config.ContainerSystem then
                itemsPerContainer = Config.ContainerSystem.itemsPerContainer or 12
                containersPerBox = Config.ContainerSystem.containersPerBox or 5
            end
            
            local containersNeeded = math.ceil((order.quantity or 1) / itemsPerContainer)
            local boxesNeeded = math.ceil(containersNeeded / containersPerBox)
            orderGroups[groupId].boxes = orderGroups[groupId].boxes + boxesNeeded
        end
        
        -- Count total order groups
        local totalOrders = 0
        for _ in pairs(orderGroups) do
            totalOrders = totalOrders + 1
        end
        
        print("[DUTY EMAIL DEBUG] Total order groups:", totalOrders)
        
        -- Build plain text email message (NO HTML)
        local orderList = ""
        local orderNumber = 1
        
        for groupId, group in pairs(orderGroups) do
            orderList = orderList .. string.format("\n📦 Order #%d - %s (%d boxes)\n", 
                orderNumber, group.restaurantName, group.boxes)
            
            for _, item in ipairs(group.items) do
                orderList = orderList .. string.format("  - %s x%d\n", item.name, item.quantity)
            end
            
            orderList = orderList .. string.format("  💰 Value: $%d\n", group.totalCost)
            orderNumber = orderNumber + 1
        end
        
        -- Calculate potential earnings
        local potentialEarnings = math.floor(totalValue * (Config.DriverPayPrec or 0.22))
        
        -- Build plain text message for LB-Phone
        local message = string.format([[
📋 DUTY REPORT 📋

Welcome to your shift!

There are currently *%d pending orders* waiting for delivery.
Total potential earnings: *$%d+* (base pay, bonuses not included)

=== PENDING ORDERS ===
%s

Head to the warehouse to accept these orders!

_Good luck and drive safely!_
        ]], totalOrders, potentialEarnings, orderList)
        
        print("[DUTY EMAIL DEBUG] Sending email with message length:", string.len(message))
        
        -- Send the email using LBPhone integration - CORRECTLY PASSING PLAYER ID
        local LBPhone = _G.LBPhone
        if LBPhone then
            LBPhone.SendDutyEmail(playerId, {  -- FIXED: Correctly passing playerId
                subject = string.format("📋 Duty Report - %d Orders Pending", totalOrders),
                message = message
            })
        else
            print("[DUTY EMAIL DEBUG] ERROR: LBPhone integration not found")
        end
        
        -- Also send a notification
        TriggerClientEvent('ox_lib:notify', playerId, {
            title = '📋 Duty Report Sent',
            description = string.format('%d pending orders available. Check your email!', totalOrders),
            type = 'info',
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
    end)
end

local function sendDutySummaryEmailEnhanced(playerId)
    print("[DUTY EMAIL DEBUG] Starting enhanced duty email for player:", playerId)
    
    local xPlayer = QBCore.Functions.GetPlayer(playerId)
    if not xPlayer then return end
    
    -- Get regular orders
    MySQL.Async.fetchAll([[
        SELECT * FROM supply_orders 
        WHERE status = 'pending' AND (order_group_id NOT LIKE 'import_%' OR order_group_id IS NULL)
        ORDER BY created_at ASC
    ]], {}, function(regularResults)
        
        -- Get import orders
        MySQL.Async.fetchAll([[
            SELECT * FROM supply_orders 
            WHERE status = 'pending' AND order_group_id LIKE 'import_%'
            ORDER BY created_at ASC
        ]], {}, function(importResults)
            
            local regularCount = regularResults and #regularResults or 0
            local importCount = importResults and #importResults or 0
            local totalOrders = regularCount + importCount
            
            if totalOrders == 0 then
                -- No orders email (existing logic)
                local LBPhone = _G.LBPhone
                if LBPhone then
                    LBPhone.SendDutyEmail(playerId, {
                        subject = "📋 Duty Report - No Pending Orders",
                        message = "Welcome to your shift! There are currently no pending orders in the system."
                    })
                end
                return
            end
            
            -- Build enhanced duty report
            local message = "📋 DUTY REPORT 📋\n\nWelcome to your shift!\n\n"
            
            if regularCount > 0 then
                message = message .. string.format("🏭 MAIN WAREHOUSE: %d orders pending\n", regularCount)
            end
            
            if importCount > 0 then
                message = message .. string.format("🌍 IMPORT CENTER: %d import orders pending\n", importCount)
            end
            
            message = message .. "\nHead to the appropriate warehouse to process orders!\n\n_Good luck and drive safely!_"
            
            local LBPhone = _G.LBPhone
            if LBPhone then
                LBPhone.SendDutyEmail(playerId, {
                    subject = string.format("📋 Duty Report - %d Orders (%d Import)", totalOrders, importCount),
                    message = message
                })
            end
        end)
    end)
end

-- Import arrival notification
local function sendImportArrivalEmail(restaurantId, importItems)
    print("[IMPORT EMAIL DEBUG] Sending import arrival notification for restaurant:", restaurantId)
    
    -- Get restaurant data
    local restaurantData = Config.Restaurants[restaurantId]
    if not restaurantData then return end
    
    local restaurantName = restaurantData.name
    local restaurantJob = restaurantData.job
    
    -- Get all players with this restaurant job
    local players = QBCore.Functions.GetPlayers()
    local itemNames = exports.ox_inventory:Items() or {}
    
    -- Build item list
    local itemList = ""
    local totalValue = 0
    
    for _, item in ipairs(importItems) do
        local itemLabel = itemNames[item.ingredient] and itemNames[item.ingredient].label or item.ingredient
        itemList = itemList .. string.format("- %s x%d (Value: $%d)\n", itemLabel, item.quantity, item.total_cost)
        totalValue = totalValue + item.total_cost
    end
    
    -- Calculate import details
    local itemsPerContainer = Config.ContainerSystem.itemsPerContainer or 12
    local containersPerBox = Config.ContainerSystem.containersPerBox or 5
    local totalItems = 0
    
    for _, item in ipairs(importItems) do
        totalItems = totalItems + item.quantity
    end
    
    local containersNeeded = math.ceil(totalItems / itemsPerContainer)
    local boxesNeeded = math.ceil(containersNeeded / containersPerBox)
    
    -- Build email message
    local message = string.format([[
🌍 IMPORT DELIVERY ARRIVED! 🌍

Your premium import items have arrived at the Import Distribution Center and are ready for delivery to %s!

=== IMPORT MANIFEST ===
%s
📦 Total Boxes: %d
💰 Total Value: $%d

=== DELIVERY INSTRUCTIONS ===
These are premium import items that require immediate delivery to maintain quality.

A warehouse driver will deliver these items to your restaurant shortly. Please ensure someone is available to receive the delivery.

_Import Distribution Center - Premium Global Ingredients_
    ]], restaurantName, itemList, boxesNeeded, totalValue)
    
    -- Send to restaurant staff
    for _, playerId in ipairs(players) do
        local xPlayer = QBCore.Functions.GetPlayer(playerId)
        if xPlayer and xPlayer.PlayerData.job.name == restaurantJob then
            -- Send using LBPhone integration
            local LBPhone = _G.LBPhone
            if LBPhone then
                LBPhone.SendDutyEmail(playerId, {
                    subject = string.format("🌍 Import Delivery Ready - %d boxes", boxesNeeded),
                    message = message
                })
            end
            
            -- Also send notification
            TriggerClientEvent('ox_lib:notify', playerId, {
                title = '🌍 Import Arrival',
                description = string.format('Import delivery ready! %d boxes of premium ingredients', boxesNeeded),
                type = 'success',
                duration = 10000,
                position = Config.UI.notificationPosition,
                markdown = Config.UI.enableMarkdown
            })
        end
    end
    
    -- Also notify warehouse workers about the import delivery job
    sendImportDeliveryAlert(restaurantId, importItems, boxesNeeded)
end

-- Import delivery alert for warehouse workers
local function sendImportDeliveryAlert(restaurantId, importItems, boxesNeeded)
    local restaurantName = Config.Restaurants[restaurantId].name
    local players = QBCore.Functions.GetPlayers()
    
    -- Calculate potential earnings with import bonus
    local totalValue = 0
    for _, item in ipairs(importItems) do
        totalValue = totalValue + item.total_cost
    end
    
    local basePay = math.floor(totalValue * Config.DriverPayPrec)
    local importBonus = Config.ImportSystem and Config.ImportSystem.importDeliveryBonus or 1.15
    local totalPay = math.floor(basePay * importBonus)
    
    local message = string.format([[
🌍 IMPORT DELIVERY AVAILABLE! 🌍

Premium import items need delivery from the Import Distribution Center!

=== DELIVERY DETAILS ===
📍 Destination: %s
📦 Total Boxes: %d
💰 Base Pay: $%d
🌟 Import Bonus: +%d%% 
💵 Total Potential: $%d+

=== ITEMS ===
Premium imported ingredients requiring careful handling.

⚡ These are high-priority deliveries with bonus pay!

Head to the Import Distribution Center to accept this delivery.
    ]], restaurantName, boxesNeeded, basePay, 
    math.floor((importBonus - 1) * 100), totalPay)
    
    -- Send to all warehouse workers
    for _, playerId in ipairs(players) do
        local xPlayer = QBCore.Functions.GetPlayer(playerId)
        if xPlayer then
            local playerJob = xPlayer.PlayerData.job.name
            
            -- Check if player has warehouse access
            local hasAccess = false
            for _, job in ipairs(Config.Jobs.warehouse) do
                if playerJob == job then
                    hasAccess = true
                    break
                end
            end
            
            if hasAccess then
                local LBPhone = _G.LBPhone
                if LBPhone then
                    LBPhone.SendDutyEmail(playerId, {
                        subject = string.format("🌍 Import Delivery - $%d+ (%d boxes)", totalPay, boxesNeeded),
                        message = message
                    })
                end
            end
        end
    end
end

-- Rest of the file remains the same but with debug improvements
local playersOnDuty = {}

-- Main duty monitoring system
local function monitorDutyStatus()
    while true do
        Citizen.Wait(2000) -- Check every 2 seconds
        
        local players = QBCore.Functions.GetPlayers()
        
        for _, playerId in ipairs(players) do
            local xPlayer = QBCore.Functions.GetPlayer(playerId)
            if xPlayer then
                local playerJob = xPlayer.PlayerData.job
                local citizenid = xPlayer.PlayerData.citizenid
                
                -- Check if warehouse job
                local isWarehouseJob = false
                for _, job in ipairs(Config.Jobs.warehouse) do
                    if playerJob.name == job then
                        isWarehouseJob = true
                        break
                    end
                end
                
                if isWarehouseJob then
                    -- Check if just went on duty
                    if playerJob.onduty and not playersOnDuty[citizenid] then
                        playersOnDuty[citizenid] = true
                        -- Send duty email
                        sendDutySummaryEmailEnhanced(playerId)
                        
                        print(string.format("[DUTY] %s (%s) went ON duty for %s", 
                            xPlayer.PlayerData.charinfo.firstname .. " " .. xPlayer.PlayerData.charinfo.lastname,
                            GetPlayerName(playerId), 
                            playerJob.name
                        ))
                    elseif not playerJob.onduty and playersOnDuty[citizenid] then
                        playersOnDuty[citizenid] = nil
                        
                        print(string.format("[DUTY] %s (%s) went OFF duty from %s", 
                            xPlayer.PlayerData.charinfo.firstname .. " " .. xPlayer.PlayerData.charinfo.lastname,
                            GetPlayerName(playerId), 
                            playerJob.name
                        ))
                    end
                elseif playersOnDuty[citizenid] then
                    -- They switched to a non-warehouse job
                    playersOnDuty[citizenid] = nil
                end
            end
        end
    end
end

-- Start the duty monitor
Citizen.CreateThread(monitorDutyStatus)

-- Clean up when player drops
AddEventHandler('playerDropped', function()
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if xPlayer then
        playersOnDuty[xPlayer.PlayerData.citizenid] = nil
    end
end)

RegisterNetEvent('imports:notifyArrival')
AddEventHandler('imports:notifyArrival', function(restaurantId, orderGroupId)
    -- Get import items from the order
    MySQL.Async.fetchAll([[
        SELECT ingredient, quantity, total_cost 
        FROM supply_orders 
        WHERE order_group_id = ? AND status = 'completed'
    ]], {orderGroupId}, function(results)
        if results and #results > 0 then
            sendImportArrivalEmail(restaurantId, results)
        end
    end)
end)

-- QBCore duty toggle event
RegisterNetEvent('QBCore:ToggleDuty')
AddEventHandler('QBCore:ToggleDuty', function()
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    -- Small delay to ensure duty status is updated
    Citizen.SetTimeout(2000, function()
        local playerJob = xPlayer.PlayerData.job
        
        -- Check if player is now ON duty
        if playerJob.onduty then
            -- Check if it's a warehouse job
            for _, job in ipairs(Config.Jobs.warehouse) do
                if playerJob.name == job then
                    sendDutySummaryEmail(src)
                    break
                end
            end
        end
    end)
end)

-- Additional debug commands
RegisterCommand('debugphonestatus', function(source, args, rawCommand)
    if source == 0 then
        print("This command must be run in-game")
        return
    end
    
    local xPlayer = QBCore.Functions.GetPlayer(source)
    if not xPlayer then return end
    
    -- Get phone info using proper exports
    local phoneNumber = exports["lb-phone"]:GetEquippedPhoneNumber(source)
    local email = phoneNumber and exports["lb-phone"]:GetEmailAddress(phoneNumber) or nil
    
    print("\n=== PHONE STATUS DEBUG ===")
    print("Player:", GetPlayerName(source))
    print("Source ID:", source)
    print("Equipped Phone:", phoneNumber or "NONE")
    print("Email Address:", email or "NONE")
    
    -- Send results to player
    TriggerClientEvent('ox_lib:notify', source, {
        title = '📱 Phone Status',
        description = string.format([[
Phone: %s
Email: %s
Status: %s
        ]], 
            phoneNumber or "No phone equipped",
            email and "✅ Set up" or "❌ Not set up",
            (phoneNumber and email) and "✅ Ready" or "⚠️ Setup needed"
        ),
        type = (phoneNumber and email) and 'success' or 'warning',
        duration = 10000,
        position = 'top'
    })
    
    print("========================\n")
end, false)

-- Manual duty email test command
RegisterCommand('senddutyemail', function(source, args, rawCommand)
    if source == 0 then
        print("This command must be run in-game")
        return
    end
    
    local xPlayer = QBCore.Functions.GetPlayer(source)
    if not xPlayer then return end
    
    -- Check if warehouse job
    local playerJob = xPlayer.PlayerData.job.name
    local isWarehouse = false
    for _, job in ipairs(Config.Jobs.warehouse) do
        if playerJob == job then
            isWarehouse = true
            break
        end
    end
    
    if not isWarehouse then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Not Warehouse Job',
            description = 'You must be a warehouse worker to test this',
            type = 'error',
            duration = 5000
        })
        return
    end
    
    print("\n=== MANUAL DUTY EMAIL TEST ===")
    sendDutySummaryEmail(source)
    print("==========================\n")
end, false)