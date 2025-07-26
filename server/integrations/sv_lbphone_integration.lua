-- server/sv_lbphone_integration.lua
-- ===============================================
-- LB-PHONE EMAIL INTEGRATION
-- ===============================================

local QBCore = exports['qb-core']:GetCoreObject()
local LBPhone = {}

-- Email configuration
local EmailConfig = {
    stockAlerts = {
        sender = "warehouse@supply.chain",
        senderName = "Supply Chain Warehouse",
        icon = "📦"
    },
    orderNotifications = {
        sender = "orders@supply.chain", 
        senderName = "Order Management System",
        icon = "🚚"
    },
    emergencyAlerts = {
        sender = "emergency@supply.chain",
        senderName = "Emergency Response System",
        icon = "🚨"
    }
}

-- ===============================================
-- HELPER FUNCTION TO GET EMAIL FROM PHONE NUMBER
-- ===============================================

local function getEmailFromPhoneNumber(phoneNumber)
    -- Check if phone number is valid
    if not phoneNumber then
        print("[LBPhone] ERROR: No phone number provided to getEmailFromPhoneNumber")
        return nil
    end
    
    -- Get email address from phone number
    local success, email = pcall(function()
        return exports["lb-phone"]:GetEmailAddress(phoneNumber)
    end)
    
    if not success then
        print("[LBPhone] ERROR: Failed to get email address:", email)
        return nil
    end
    
    if not email then
        print("[LBPhone] No email address found for phone number:", phoneNumber)
        return nil
    end
    
    return email
end

-- ===============================================
-- GET PLAYER'S ACTUAL PHONE NUMBER
-- ===============================================

local function getPlayerActualPhoneNumber(source)
    -- Validate source
    if not source or type(source) ~= "number" then
        print("[LBPhone] ERROR: Invalid source provided:", source)
        return nil
    end
    
    -- First try to get the equipped phone number from lb-phone
    local success, equippedPhone = pcall(function()
        return exports["lb-phone"]:GetEquippedPhoneNumber(source)
    end)
    
    if success and equippedPhone then
        print("[LBPhone] Using equipped phone number:", equippedPhone, "for player:", source)
        return equippedPhone
    end
    
    -- If that failed, log the error
    if not success then
        print("[LBPhone] ERROR: Failed to get equipped phone:", equippedPhone)
    else
        print("[LBPhone] Player has no equipped phone, checking charinfo...")
    end
    
    -- Fallback to character data if no equipped phone
    local xPlayer = QBCore.Functions.GetPlayer(source)
    if xPlayer and xPlayer.PlayerData.charinfo.phone then
        print("[LBPhone] WARNING: Using charinfo phone number (not equipped):", xPlayer.PlayerData.charinfo.phone)
        return xPlayer.PlayerData.charinfo.phone
    end
    
    print("[LBPhone] ERROR: No phone number found for player:", source)
    return nil
end

-- ===============================================
-- UNIFIED EMAIL SENDING FUNCTION
-- ===============================================

local function sendEmailToPlayer(playerId, emailData)
    -- Validate player ID
    if not playerId then
        print("[LBPhone] ERROR: No player ID provided to sendEmailToPlayer")
        return false
    end
    
    -- Get the player's actual phone number from lb-phone
    local phoneNumber = getPlayerActualPhoneNumber(playerId)
    if not phoneNumber then
        print("[LBPhone] ERROR: Failed to get phone number for player:", playerId)
        -- Try one more time with a small delay
        Citizen.Wait(100)
        phoneNumber = getPlayerActualPhoneNumber(playerId)
        if not phoneNumber then
            print("[LBPhone] ERROR: Player has no equipped phone after retry:", playerId)
            return false
        end
    end
    
    -- Get email address from phone number
    local email = getEmailFromPhoneNumber(phoneNumber)
    if not email then
        print("[LBPhone] ERROR: Failed to get email address for phone:", phoneNumber, "Player:", playerId)
        return false
    end
    
    -- Send the email
    emailData.to = email
    local success, result = pcall(function()
        return exports["lb-phone"]:SendMail(emailData)
    end)
    
    if not success then
        print("[LBPhone] ERROR: Failed to send email:", result)
        return false
    end
    
    local emailId = result
    
    if success and result then
        print(string.format("[LBPhone] Email sent successfully to %s (phone: %s)", email, phoneNumber))
    else
        print(string.format("[LBPhone] Failed to send email to %s (phone: %s)", email, phoneNumber))
    end
    
    return success and result, emailId
end

-- ===============================================
-- STOCK ALERT EMAILS
-- ===============================================

function LBPhone.SendStockAlert(phoneNumber, alertData)
    -- THIS FUNCTION NOW EXPECTS A PLAYER ID, NOT PHONE NUMBER
    local playerId = phoneNumber -- Rename for clarity in future update
    
    -- Build email content based on alert level
    local subject = ""
    local message = ""
    local urgencyIcon = ""
    
    if alertData.level == "critical" then
        urgencyIcon = "🚨"
        subject = string.format("%s CRITICAL: %s Stock at %d%%", urgencyIcon, alertData.itemLabel, alertData.percentage)
        message = string.format([[
<h2>%s Critical Stock Alert</h2>
<br>
<b>Item:</b> %s<br>
<b>Current Stock:</b> %d units (%d%%)<br>
<b>Status:</b> <span style="color: red;">CRITICAL - Immediate action required!</span><br>
<br>
<h3>📊 Analysis:</h3>
%s<br>
<br>
<h3>🎯 Recommended Action:</h3>
Order at least <b>%d units</b> immediately to avoid stockout.<br>
<br>
<i>This is an automated alert from your Supply Chain Management System</i>
        ]], urgencyIcon, alertData.itemLabel, alertData.currentStock, alertData.percentage, 
        alertData.analysis or "Stock levels are critically low and require immediate attention.",
        alertData.recommendedOrder or 100)
        
    elseif alertData.level == "low" then
        urgencyIcon = "⚠️"
        subject = string.format("%s Low Stock: %s at %d%%", urgencyIcon, alertData.itemLabel, alertData.percentage)
        message = string.format([[
<h2>%s Low Stock Warning</h2>
<br>
<b>Item:</b> %s<br>
<b>Current Stock:</b> %d units (%d%%)<br>
<b>Status:</b> <span style="color: orange;">LOW - Restock soon</span><br>
<br>
<h3>📊 Analysis:</h3>
%s<br>
<br>
<h3>🎯 Recommended Action:</h3>
Consider ordering <b>%d units</b> within the next 24 hours.<br>
<br>
<i>Supply Chain Management System</i>
        ]], urgencyIcon, alertData.itemLabel, alertData.currentStock, alertData.percentage,
        alertData.analysis or "Stock levels are running low based on current demand.",
        alertData.recommendedOrder or 75)
        
    else -- moderate
        urgencyIcon = "📊"
        subject = string.format("%s Stock Update: %s at %d%%", urgencyIcon, alertData.itemLabel, alertData.percentage)
        message = string.format([[
<h2>%s Stock Level Update</h2>
<br>
<b>Item:</b> %s<br>
<b>Current Stock:</b> %d units (%d%%)<br>
<b>Status:</b> <span style="color: blue;">MODERATE - Monitor levels</span><br>
<br>
<h3>📊 Analysis:</h3>
%s<br>
<br>
<i>Supply Chain Management System</i>
        ]], urgencyIcon, alertData.itemLabel, alertData.currentStock, alertData.percentage,
        alertData.analysis or "Stock levels are moderate. Continue monitoring.")
    end
    
    -- Send the email using unified function
    local emailData = {
        sender = EmailConfig.stockAlerts.sender,
        subject = subject,
        message = message
    }
    
    return sendEmailToPlayer(playerId, emailData)
end

-- ===============================================
-- ORDER NOTIFICATION EMAILS
-- ===============================================

function LBPhone.SendOrderNotification(phoneNumber, orderData)
    -- THIS FUNCTION NOW EXPECTS A PLAYER ID, NOT PHONE NUMBER
    local playerId = phoneNumber -- Rename for clarity in future update
    
    local subject = string.format("🚚 New Order: %s (%d boxes)", orderData.restaurantName, orderData.totalBoxes)
    
    -- Build order items list
    local itemsList = ""
    for _, item in ipairs(orderData.items) do
        itemsList = itemsList .. string.format("• %s x%d<br>", item.label, item.quantity)
    end
    
    local message = string.format([[
<h2>📦 New Supply Order Available</h2>
<br>
<b>Restaurant:</b> %s<br>
<b>Total Boxes:</b> %d<br>
<b>Base Pay:</b> $%d<br>
<br>
<h3>📋 Order Details:</h3>
%s
<br>
<b>Delivery Location:</b> %s<br>
<b>Distance:</b> %.1f miles<br>
<br>
<h3>💰 Potential Bonuses:</h3>
• Speed Bonus: Up to %.0f%%<br>
• Volume Bonus: $%d<br>
• Perfect Delivery: +$%d<br>
<br>
<i>Head to the warehouse to accept this order!</i>
    ]], orderData.restaurantName, orderData.totalBoxes, orderData.basePay,
    itemsList, orderData.location or "Restaurant District", orderData.distance or 0,
    orderData.maxSpeedBonus or 40, orderData.volumeBonus or 0, orderData.perfectBonus or 100)
    
    local emailData = {
        sender = EmailConfig.orderNotifications.sender,
        subject = subject,
        message = message,
        actions = {
            {
                label = "📍 Set Warehouse Waypoint",
                data = {
                    event = "supply:openWarehouseMenu",
                    isServer = false,
                    data = { action = "setWaypoint" }
                }
            }
        }
    }
    
    return sendEmailToPlayer(playerId, emailData)
end

-- ===============================================
-- EMERGENCY ORDER EMAILS
-- ===============================================

function LBPhone.SendEmergencyOrderEmail(phoneNumber, emergencyData)
    -- THIS FUNCTION NOW EXPECTS A PLAYER ID, NOT PHONE NUMBER
    local playerId = phoneNumber -- Rename for clarity in future update
    
    local urgencyEmoji = emergencyData.priority == 3 and "🚨" or "🔥"
    local subject = string.format("%s EMERGENCY: %s needs %s NOW!", 
        urgencyEmoji, emergencyData.restaurantName, emergencyData.itemLabel)
    
    local message = string.format([[
<h1 style="color: red;">%s EMERGENCY SUPPLY REQUEST</h1>
<br>
<b>Restaurant:</b> %s<br>
<b>Critical Item:</b> %s<br>
<b>Units Needed:</b> %d<br>
<b>Current Stock:</b> <span style="color: red;">%d units</span><br>
<br>
<h2>⚡ URGENT DELIVERY REQUIRED</h2>
<b>Time Limit:</b> %d minutes<br>
<b>Base Pay:</b> <span style="color: green;">$%d</span><br>
<b>Emergency Multiplier:</b> <span style="color: green;">%.1fx</span><br>
<b>Speed Bonus:</b> Up to <span style="color: green;">+$%d</span><br>
<b>Hero Bonus:</b> <span style="color: gold;">+$%d</span> for preventing stockout!<br>
<br>
<h3>💰 Total Potential Earnings: <span style="color: green;">$%d+</span></h3>
<br>
<b>⏰ RESPOND IMMEDIATELY!</b><br>
<i>This restaurant will run out of stock without immediate assistance!</i>
    ]], urgencyEmoji, emergencyData.restaurantName, emergencyData.itemLabel,
    emergencyData.unitsNeeded, emergencyData.currentStock,
    emergencyData.timeLimit or 30, emergencyData.basePay,
    emergencyData.multiplier, emergencyData.speedBonus,
    emergencyData.heroBonus, emergencyData.totalPotential)
    
    local emailData = {
        sender = EmailConfig.emergencyAlerts.sender,
        subject = subject,
        message = message,
        actions = {
            {
                label = "🚨 ACCEPT EMERGENCY",
                data = {
                    event = "supply:acceptEmergencyOrder",
                    isServer = false,
                    data = { orderId = emergencyData.orderId }
                }
            }
        }
    }
    
    return sendEmailToPlayer(playerId, emailData)
end

-- ===============================================
-- DELIVERY COMPLETION EMAILS
-- ===============================================

function LBPhone.SendDeliveryReceipt(phoneNumber, deliveryData)
    -- Get email address from phone number
    local email = getEmailFromPhoneNumber(phoneNumber)
    if not email then
        print("[DELIVERY] Failed to get email for phone:", phoneNumber)
        return false
    end
    
    local subject = string.format("✅ Delivery Complete - Earned $%d", deliveryData.totalPay)
    
    -- Build bonuses list
    local bonusList = ""
    if deliveryData.speedBonus > 0 then
        bonusList = bonusList .. string.format("• Speed Bonus: +$%d (%.0f%%)<br>", 
            deliveryData.speedBonus, deliveryData.speedMultiplier * 100 - 100)
    end
    if deliveryData.volumeBonus > 0 then
        bonusList = bonusList .. string.format("• Volume Bonus: +$%d<br>", deliveryData.volumeBonus)
    end
    if deliveryData.streakBonus > 0 then
        bonusList = bonusList .. string.format("• Streak Bonus: +$%d (x%d streak)<br>", 
            deliveryData.streakBonus, deliveryData.currentStreak)
    end
    if deliveryData.perfectBonus > 0 then
        bonusList = bonusList .. string.format("• Perfect Delivery: +$%d<br>", deliveryData.perfectBonus)
    end
    
    local message = string.format([[
<h2>✅ Delivery Receipt</h2>
<br>
<b>Restaurant:</b> %s<br>
<b>Boxes Delivered:</b> %d<br>
<b>Delivery Time:</b> %s<br>
<br>
<h3>💰 Earnings Breakdown:</h3>
<b>Base Pay:</b> $%d<br>
%s
<hr>
<b>Total Earned:</b> <span style="color: green; font-size: 1.2em;">$%d</span><br>
<br>
<h3>📊 Performance Stats:</h3>
• Current Streak: %d deliveries<br>
• Daily Deliveries: %d<br>
• Average Rating: %.1f%%<br>
<br>
<i>Great work! Keep up the excellent deliveries!</i>
    ]], deliveryData.restaurantName, deliveryData.boxesDelivered,
    deliveryData.deliveryTime, deliveryData.basePay,
    bonusList, deliveryData.totalPay,
    deliveryData.currentStreak, deliveryData.dailyDeliveries,
    deliveryData.averageRating or 95.0)
    
    local emailData = {
        to = email,  -- FIXED: Using email address instead of phone number
        sender = EmailConfig.orderNotifications.sender,
        subject = subject,
        message = message
    }
    
    local success = exports["lb-phone"]:SendMail(emailData)
    
    if success then
        print(string.format("[DELIVERY] Email sent to %s (Phone: %s)", email, phoneNumber))
    else
        print(string.format("[DELIVERY] Failed to send email to %s", email))
    end
    
    return success
end

-- ===============================================
-- HELPER FUNCTION TO GET PHONE NUMBER
-- ===============================================

function LBPhone.GetPlayerPhoneNumber(source)
    -- This might vary based on your phone/framework setup
    local xPlayer = QBCore.Functions.GetPlayer(source)
    if xPlayer then
        return xPlayer.PlayerData.charinfo.phone
    end
    return nil
end

-- ===============================================
-- DUTY EMAIL FUNCTION (for sv_duty_emails.lua)
-- ===============================================

function LBPhone.SendDutyEmail(phoneNumber, emailData)
    -- Get email address from phone number
    local email = getEmailFromPhoneNumber(phoneNumber)
    if not email then
        print("[DUTY EMAIL] Failed to get email for phone:", phoneNumber)
        return false
    end
    
    -- Send the email
    local success = exports["lb-phone"]:SendMail({
        to = email,
        sender = emailData.sender or "warehouse@supply.chain",
        subject = emailData.subject,
        message = emailData.message
    })
    
    if success then
        print(string.format("[DUTY EMAIL] Email sent to %s", email))
    else
        print(string.format("[DUTY EMAIL] Failed to send email to %s", email))
    end
    
    return success
end

-- ===============================================
-- TEST COMMAND
-- ===============================================

RegisterCommand('testlbphoneemail', function(source, args, rawCommand)
    if source == 0 then
        print("This command must be run in-game")
        return
    end
    
    local xPlayer = QBCore.Functions.GetPlayer(source)
    if not xPlayer then return end
    
    -- Get the actual phone number from lb-phone
    local phoneNumber = getPlayerActualPhoneNumber(source)
    local charInfoPhone = xPlayer.PlayerData.charinfo.phone
    
    print("\n=== LB-PHONE EMAIL TEST ===")
    print("Player:", GetPlayerName(source))
    print("CharInfo Phone:", charInfoPhone)
    print("LB-Phone Equipped:", phoneNumber or "NONE")
    
    if not phoneNumber then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Email Test Failed',
            description = 'No equipped phone found!',
            type = 'error',
            duration = 5000,
            position = Config.UI.notificationPosition
        })
        return
    end
    
    local email = getEmailFromPhoneNumber(phoneNumber)
    
    if not email then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Email Test Failed',
            description = 'No email address found for your phone',
            type = 'error',
            duration = 5000,
            position = Config.UI.notificationPosition
        })
        return
    end
    
    local success = exports["lb-phone"]:SendMail({
        to = email,
        sender = "test@supply.chain",
        subject = "📧 Email Integration Test",
        message = string.format([[
<h2>✅ Email Test Successful!</h2>
<br>
Your email integration is working correctly.<br>
<br>
<b>CharInfo Phone:</b> %s<br>
<b>Equipped Phone:</b> %s<br>
<b>Email Address:</b> %s<br>
<br>
All supply chain emails will be sent to this address.
        ]], charInfoPhone, phoneNumber, email)
    })
    
    if success then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Email Test Sent!',
            description = 'Check your phone email app',
            type = 'success',
            duration = 5000,
            position = Config.UI.notificationPosition
        })
        print(string.format("[EMAIL TEST] Successfully sent test email from phone %s to email %s", phoneNumber, email))
    else
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Email Test Failed',
            description = 'Failed to send test email',
            type = 'error',
            duration = 5000,
            position = Config.UI.notificationPosition
        })
    end
    
    print("==========================\n")
end, false)

-- Export the module
_G.LBPhone = LBPhone
return LBPhone