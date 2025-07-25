-- server/sv_duty_emails.lua (UPDATED VERSION)
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
            
            -- Use LBPhone integration to send email - PASS PLAYER ID
            local LBPhone = _G.LBPhone
            if LBPhone then
                LBPhone.SendDutyEmail(playerId, {  -- CHANGED: Pass playerId instead of phoneNumber
                    subject = "📋 Duty Report - No Pending Orders",
                    message = "Welcome to your shift! There are currently no pending orders in the system."
                })
            else
                print("[DUTY EMAIL DEBUG] ERROR: LBPhone integration not found")
            end
            return
        end
        
        -- Process orders (rest of the code remains the same)
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
        
        -- Build simple email message
        local orderList = ""
        local orderNumber = 1
        
        for groupId, group in pairs(orderGroups) do
            orderList = orderList .. string.format("\nOrder #%d - %s (%d boxes)\n", 
                orderNumber, group.restaurantName, group.boxes)
            
            for _, item in ipairs(group.items) do
                orderList = orderList .. string.format("  - %s x%d\n", item.name, item.quantity)
            end
            
            orderList = orderList .. string.format("  Value: $%d\n", group.totalCost)
            orderNumber = orderNumber + 1
        end
        
        -- Calculate potential earnings
        local potentialEarnings = math.floor(totalValue * (Config.DriverPayPrec or 0.22))
        
        -- Build simple message
        local message = string.format([[
Welcome to your shift!

There are currently %d pending orders waiting for delivery.
Total potential earnings: $%d+ (base pay, bonuses not included)

PENDING ORDERS:
%s

Head to the warehouse to accept these orders!
        ]], totalOrders, potentialEarnings, orderList)
        
        print("[DUTY EMAIL DEBUG] Sending email with message length:", string.len(message))
        
        -- Send the email using LBPhone integration - PASS PLAYER ID
        local LBPhone = _G.LBPhone
        if LBPhone then
            LBPhone.SendDutyEmail(playerId, {  -- CHANGED: Pass playerId instead of phoneNumber
                subject = string.format("📋 Duty Report - %d Orders Pending", totalOrders),
                message = message
            })
        else
            print("[DUTY EMAIL DEBUG] ERROR: LBPhone integration not found")
        end
        
        -- Also send a notification
        -- TriggerClientEvent('ox_lib:notify', playerId, {
        --     title = '📋 Duty Report Sent',
        --     description = string.format('%d pending orders available. Check your email!', totalOrders),
        --     type = 'info',
        --     duration = 8000,
        --     position = Config.UI.notificationPosition,
        --     markdown = Config.UI.enableMarkdown
        -- })
    end)
end

-- Rest of the file remains the same (no other changes needed)

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

-- QBCore set duty event
RegisterNetEvent('QBCore:Client:SetDuty')
AddEventHandler('QBCore:Client:SetDuty', function(duty)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    -- If going ON duty (duty = true)
    if duty then
        local playerJob = xPlayer.PlayerData.job
        
        -- Check if it's a warehouse job
        for _, job in ipairs(Config.Jobs.warehouse) do
            if playerJob.name == job then
                sendDutySummaryEmail(src)
                break
            end
        end
    end
end)

-- Randol multijob integration
RegisterNetEvent('randol_multijob:server:setJob')
AddEventHandler('randol_multijob:server:setJob', function(job)
    -- Note: randol_multijob sets duty to FALSE when switching jobs
    -- So we don't send email here, wait for them to go on duty
    
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    -- Check if they switched TO a warehouse job
    for _, warehouseJob in ipairs(Config.Jobs.warehouse) do
        if job == warehouseJob then
            -- Remind them to go on duty
            TriggerClientEvent('ox_lib:notify', src, {
                title = '📋 Warehouse Job',
                description = 'Remember to toggle duty to receive pending orders!',
                type = 'info',
                duration = 8000,
                position = Config.UI.notificationPosition,
                markdown = Config.UI.enableMarkdown
            })
            break
        end
    end
end)

RegisterCommand('debugphone', function(source, args, rawCommand)
    if source == 0 then
        print("This command must be run in-game")
        return
    end
    
    local xPlayer = QBCore.Functions.GetPlayer(source)
    if not xPlayer then return end
    
    print("\n=== PHONE NUMBER DEBUG ===")
    print("Player:", GetPlayerName(source))
    print("Source ID:", source)
    
    -- 1. Check charinfo phone
    local charInfoPhone = xPlayer.PlayerData.charinfo.phone
    print("\n[1] CharInfo Phone:", charInfoPhone or "NONE")
    
    -- 2. Check lb-phone equipped number
    local equippedPhone = exports["lb-phone"]:GetEquippedPhoneNumber(source)
    print("[2] LB-Phone Equipped:", equippedPhone or "NONE")
    
    -- 3. Try to get email for charinfo phone
    local charInfoEmail = nil
    if charInfoPhone then
        charInfoEmail = exports["lb-phone"]:GetEmailAddress(charInfoPhone)
        print("[3] CharInfo Phone Email:", charInfoEmail or "NO EMAIL")
    end
    
    -- 4. Try to get email for equipped phone
    local equippedEmail = nil
    if equippedPhone then
        equippedEmail = exports["lb-phone"]:GetEmailAddress(equippedPhone)
        print("[4] Equipped Phone Email:", equippedEmail or "NO EMAIL")
    end
    
    -- 5. Check if player has phone item
    local hasCharPhone = false
    local hasEquippedPhone = false
    if charInfoPhone then
        hasCharPhone = exports["lb-phone"]:HasPhoneItem(source, charInfoPhone)
        print("[5] Has CharInfo Phone Item:", hasCharPhone)
    end
    if equippedPhone and equippedPhone ~= charInfoPhone then
        hasEquippedPhone = exports["lb-phone"]:HasPhoneItem(source, equippedPhone)
        print("[6] Has Equipped Phone Item:", hasEquippedPhone)
    end
    
    -- 6. Get phone from all sources
    local sourceFromCharPhone = nil
    local sourceFromEquippedPhone = nil
    if charInfoPhone then
        sourceFromCharPhone = exports["lb-phone"]:GetSourceFromNumber(charInfoPhone)
        print("[7] Source from CharInfo Phone:", sourceFromCharPhone or "NONE")
    end
    if equippedPhone then
        sourceFromEquippedPhone = exports["lb-phone"]:GetSourceFromNumber(equippedPhone)
        print("[8] Source from Equipped Phone:", sourceFromEquippedPhone or "NONE")
    end
    
    -- Send results to player
    TriggerClientEvent('ox_lib:notify', source, {
        title = '📱 Phone Debug Info',
        description = string.format([[
CharInfo: %s %s
Equipped: %s %s
Mismatch: %s
        ]], 
            charInfoPhone or "NONE",
            charInfoEmail and "✅" or "❌",
            equippedPhone or "NONE", 
            equippedEmail and "✅" or "❌",
            (charInfoPhone ~= equippedPhone) and "⚠️ YES" or "✅ NO"
        ),
        type = (charInfoPhone == equippedPhone and equippedEmail) and 'success' or 'warning',
        duration = 10000,
        position = 'top'
    })
    
    -- Recommendation
    print("\n=== RECOMMENDATION ===")
    if charInfoPhone ~= equippedPhone then
        print("⚠️  PHONE MISMATCH DETECTED!")
        print("CharInfo has:", charInfoPhone)
        print("But equipped phone is:", equippedPhone)
        print("\nSOLUTION: The system will now use the equipped phone number")
        print("This ensures emails go to the correct phone/email address")
    elseif not equippedEmail then
        print("❌ NO EMAIL ADDRESS SET UP!")
        print("The player needs to set up an email account in their phone")
    else
        print("✅ Everything looks good!")
    end
    
    print("========================\n")
end, false)

-- Command to fix phone mismatch (admin only)
RegisterCommand('fixplayerphone', function(source, args, rawCommand)
    if source ~= 0 then
        -- Check if player is admin
        local xPlayer = QBCore.Functions.GetPlayer(source)
        if not xPlayer or not QBCore.Functions.HasPermission(source, 'admin') then
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'No Permission',
                description = 'This command requires admin permission',
                type = 'error',
                duration = 5000
            })
            return
        end
    end
    
    local targetId = tonumber(args[1])
    if not targetId then
        print("Usage: /fixplayerphone [playerid]")
        return
    end
    
    local targetPlayer = QBCore.Functions.GetPlayer(targetId)
    if not targetPlayer then
        print("Player not found")
        return
    end
    
    -- Get equipped phone
    local equippedPhone = exports["lb-phone"]:GetEquippedPhoneNumber(targetId)
    if not equippedPhone then
        print("Player has no equipped phone")
        return
    end
    
    -- Update charinfo to match equipped phone
    targetPlayer.PlayerData.charinfo.phone = equippedPhone
    targetPlayer.Functions.SetPlayerData('charinfo', targetPlayer.PlayerData.charinfo)
    
    -- Update database
    MySQL.Async.execute('UPDATE players SET charinfo = ? WHERE citizenid = ?', {
        json.encode(targetPlayer.PlayerData.charinfo),
        targetPlayer.PlayerData.citizenid
    })
    
    print(string.format("✅ Fixed phone mismatch for %s - Set charinfo phone to %s", 
        GetPlayerName(targetId), equippedPhone))
    
    if source ~= 0 then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Phone Fixed',
            description = string.format('Updated player phone to %s', equippedPhone),
            type = 'success',
            duration = 5000
        })
    end
end, true)

RegisterCommand('checkphoneexport', function(source, args, rawCommand)
    if source == 0 then
        print("This command must be run in-game")
        return
    end
    
    print("\n=== LB-PHONE EXPORT CHECK ===")
    print("Testing player:", GetPlayerName(source), "ID:", source)
    
    -- Test 1: GetEquippedPhoneNumber
    print("\n[TEST 1] GetEquippedPhoneNumber:")
    local success1, result1 = pcall(function()
        return exports["lb-phone"]:GetEquippedPhoneNumber(source)
    end)
    if success1 then
        print("✅ Success:", result1 or "nil (no phone equipped)")
    else
        print("❌ Error:", result1)
    end
    
    -- Test 2: GetSourceFromNumber (if we have a number)
    if success1 and result1 then
        print("\n[TEST 2] GetSourceFromNumber:")
        local success2, result2 = pcall(function()
            return exports["lb-phone"]:GetSourceFromNumber(result1)
        end)
        if success2 then
            print("✅ Success:", result2 == source and "Matches!" or "Different source: " .. tostring(result2))
        else
            print("❌ Error:", result2)
        end
        
        -- Test 3: GetEmailAddress
        print("\n[TEST 3] GetEmailAddress:")
        local success3, result3 = pcall(function()
            return exports["lb-phone"]:GetEmailAddress(result1)
        end)
        if success3 then
            print("✅ Success:", result3 or "nil (no email set)")
        else
            print("❌ Error:", result3)
        end
        
        -- Test 4: HasPhoneItem
        print("\n[TEST 4] HasPhoneItem:")
        local success4, result4 = pcall(function()
            return exports["lb-phone"]:HasPhoneItem(source, result1)
        end)
        if success4 then
            print("✅ Success:", result4 and "Has phone item" or "No phone item")
        else
            print("❌ Error:", result4)
        end
    end
    
    -- Test 5: Check player data
    print("\n[TEST 5] Player Data Check:")
    local xPlayer = QBCore.Functions.GetPlayer(source)
    if xPlayer then
        print("CharInfo Phone:", xPlayer.PlayerData.charinfo.phone or "NONE")
        print("Player Name:", xPlayer.PlayerData.charinfo.firstname .. " " .. xPlayer.PlayerData.charinfo.lastname)
    else
        print("❌ Failed to get player data")
    end
    
    print("=============================\n")
    
    -- Send summary to player
    TriggerClientEvent('ox_lib:notify', source, {
        title = '📱 Phone Export Check',
        description = success1 and result1 and 'Phone exports working! Phone: ' .. result1 or 'Phone exports may have issues - check F8',
        type = success1 and 'success' or 'warning',
        duration = 8000,
        position = 'top'
    })
end, false)

-- Alternative duty email sender for testing
RegisterCommand('senddutyemailtest', function(source, args, rawCommand)
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
    
    -- Try to send duty email manually
    local LBPhone = _G.LBPhone
    if not LBPhone then
        print("❌ LBPhone integration not loaded!")
        return
    end
    
    -- Send a simple test duty email
    local success = LBPhone.SendDutyEmail(source, {
        subject = "📋 Test Duty Report",
        message = [[
This is a test duty email.

If you receive this, the email system is working!

Time: ]] .. os.date("%H:%M:%S") .. [[

Your phone exports are functioning correctly.
]]
    })
    
    if success then
        print("✅ Duty email sent successfully!")
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Email Sent',
            description = 'Check your phone for the test duty email',
            type = 'success',
            duration = 5000
        })
    else
        print("❌ Failed to send duty email")
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Email Failed',
            description = 'Could not send email - check F8 console',
            type = 'error',
            duration = 5000
        })
    end
    
    print("==========================\n")
end, false)