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
                        sendDutySummaryEmail(playerId)
                        
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