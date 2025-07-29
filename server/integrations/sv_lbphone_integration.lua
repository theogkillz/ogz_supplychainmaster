-- server/integrations/sv_lbphone_integration.lua
-- ===============================================
-- LB-PHONE EMAIL INTEGRATION - FIXED VERSION
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
    },
    dutyAlerts = {
        sender = "duty@supply.chain",
        senderName = "Duty Management System",
        icon = "📋"
    }
}

-- ===============================================
-- HELPER FUNCTIONS
-- ===============================================

-- Convert HTML email to plain text with icons
local function htmlToPlainText(htmlContent)
    -- Remove HTML tags but keep line breaks
    local plainText = htmlContent
    
    -- Replace headers with uppercase text
    plainText = plainText:gsub("<h1>(.-)</h1>", "\n=== %1 ===\n")
    plainText = plainText:gsub("<h2>(.-)</h2>", "\n--- %1 ---\n")
    plainText = plainText:gsub("<h3>(.-)</h3>", "\n%1:\n")
    
    -- Replace styling
    plainText = plainText:gsub('<span style="color: %w+;">(.-)</span>', "%1")
    plainText = plainText:gsub('<span style="[^"]-">(.-)</span>', "%1")
    
    -- Replace breaks and paragraphs
    plainText = plainText:gsub("<br>", "\n")
    plainText = plainText:gsub("<br/>", "\n")
    plainText = plainText:gsub("<br />", "\n")
    plainText = plainText:gsub("<p>", "\n")
    plainText = plainText:gsub("</p>", "\n")
    
    -- Replace lists
    plainText = plainText:gsub("•", "-")
    plainText = plainText:gsub("<ul>", "\n")
    plainText = plainText:gsub("</ul>", "\n")
    plainText = plainText:gsub("<li>(.-)</li>", "- %1\n")
    
    -- Replace bold/italic
    plainText = plainText:gsub("<b>(.-)</b>", "*%1*")
    plainText = plainText:gsub("<strong>(.-)</strong>", "*%1*")
    plainText = plainText:gsub("<i>(.-)</i>", "_%1_")
    plainText = plainText:gsub("<em>(.-)</em>", "_%1_")
    
    -- Replace horizontal rules
    plainText = plainText:gsub("<hr>", "\n" .. string.rep("-", 40) .. "\n")
    plainText = plainText:gsub("<hr/>", "\n" .. string.rep("-", 40) .. "\n")
    plainText = plainText:gsub("<hr />", "\n" .. string.rep("-", 40) .. "\n")
    
    -- Remove any remaining HTML tags
    plainText = plainText:gsub("<[^>]+>", "")
    
    -- Clean up excessive newlines
    plainText = plainText:gsub("\n\n\n+", "\n\n")
    
    -- Trim whitespace
    plainText = plainText:gsub("^%s+", ""):gsub("%s+$", "")
    
    return plainText
end

-- Get player's phone number from source
local function getPlayerPhoneNumber(source)
    if not source or type(source) ~= "number" then
        print("[LBPhone] ERROR: Invalid source provided:", source)
        return nil
    end
    
    -- Get equipped phone number from LB-Phone
    local success, phoneNumber = pcall(function()
        return exports["lb-phone"]:GetEquippedPhoneNumber(source)
    end)
    
    if success and phoneNumber then
        return phoneNumber
    end
    
    -- Fallback to QBCore character data
    local xPlayer = QBCore.Functions.GetPlayer(source)
    if xPlayer and xPlayer.PlayerData.charinfo.phone then
        print("[LBPhone] WARNING: Using charinfo phone (player may not have phone equipped)")
        return xPlayer.PlayerData.charinfo.phone
    end
    
    return nil
end

-- Get email address from phone number
local function getEmailFromPhoneNumber(phoneNumber)
    if not phoneNumber then
        print("[LBPhone] ERROR: No phone number provided")
        return nil
    end
    
    local success, email = pcall(function()
        return exports["lb-phone"]:GetEmailAddress(phoneNumber)
    end)
    
    if not success then
        print("[LBPhone] ERROR: Failed to get email address:", email)
        return nil
    end
    
    return email
end

-- ===============================================
-- MAIN EMAIL SENDING FUNCTION
-- ===============================================

local function sendEmailToPlayer(playerId, emailData)
    -- Validate input
    if not playerId or type(playerId) ~= "number" then
        print("[LBPhone] ERROR: Invalid player ID:", playerId)
        return false
    end
    
    -- Get phone number
    local phoneNumber = getPlayerPhoneNumber(playerId)
    if not phoneNumber then
        print("[LBPhone] ERROR: No phone number found for player:", playerId)
        return false
    end
    
    -- Get email address
    local email = getEmailFromPhoneNumber(phoneNumber)
    if not email then
        print("[LBPhone] WARNING: No email address for phone:", phoneNumber)
        -- Player hasn't set up email yet - notify them
        TriggerClientEvent('ox_lib:notify', playerId, {
            title = '📧 Email Setup Required',
            description = 'Please set up an email account in your phone to receive supply chain notifications',
            type = 'warning',
            duration = 8000,
            position = Config.UI.notificationPosition
        })
        return false
    end
    
    -- Convert HTML message to plain text if needed
    if emailData.message and emailData.message:find("<") then
        emailData.message = htmlToPlainText(emailData.message)
    end
    
    -- Prepare email data
    local mailData = {
        to = email,
        sender = emailData.sender,
        subject = emailData.subject,
        message = emailData.message,
        attachments = emailData.attachments,
        actions = emailData.actions
    }
    
    -- Send email
    local success, emailId = pcall(function()
        return exports["lb-phone"]:SendMail(mailData)
    end)
    
    if success and emailId then
        print(string.format("[LBPhone] Email sent successfully - ID: %s, To: %s", emailId, email))
        return true, emailId
    else
        print(string.format("[LBPhone] Failed to send email to %s - Error: %s", email, tostring(emailId)))
        return false
    end
end

-- ===============================================
-- PUBLIC FUNCTIONS
-- ===============================================

-- Stock Alert Emails
function LBPhone.SendStockAlert(playerId, alertData)
    local urgencyIcon = ""
    local subject = ""
    local message = ""
    
    if alertData.level == "critical" then
        urgencyIcon = "🚨"
        subject = string.format("%s CRITICAL: %s Stock at %d%%", 
            urgencyIcon, alertData.itemLabel, alertData.percentage)
        
        message = string.format([[
%s CRITICAL STOCK ALERT %s

*Item:* %s
*Current Stock:* %d units (%d%%)
*Status:* CRITICAL - Immediate action required!

--- 📊 Analysis ---
%s

--- 🎯 Recommended Action ---
Order at least *%d units* immediately to avoid stockout.

_This is an automated alert from your Supply Chain Management System_
        ]], urgencyIcon, urgencyIcon,
        alertData.itemLabel, alertData.currentStock, alertData.percentage,
        alertData.analysis or "Stock levels are critically low and require immediate attention.",
        alertData.recommendedOrder or 100)
        
    elseif alertData.level == "low" then
        urgencyIcon = "⚠️"
        subject = string.format("%s Low Stock: %s at %d%%", 
            urgencyIcon, alertData.itemLabel, alertData.percentage)
        
        message = string.format([[
%s LOW STOCK WARNING %s

*Item:* %s
*Current Stock:* %d units (%d%%)
*Status:* LOW - Restock soon

--- 📊 Analysis ---
%s

--- 🎯 Recommended Action ---
Consider ordering *%d units* within the next 24 hours.

_Supply Chain Management System_
        ]], urgencyIcon, urgencyIcon,
        alertData.itemLabel, alertData.currentStock, alertData.percentage,
        alertData.analysis or "Stock levels are running low based on current demand.",
        alertData.recommendedOrder or 75)
    else
        urgencyIcon = "📊"
        subject = string.format("%s Stock Update: %s at %d%%", 
            urgencyIcon, alertData.itemLabel, alertData.percentage)
        
        message = string.format([[
%s STOCK LEVEL UPDATE %s

*Item:* %s
*Current Stock:* %d units (%d%%)
*Status:* MODERATE - Monitor levels

--- 📊 Analysis ---
%s

_Supply Chain Management System_
        ]], urgencyIcon, urgencyIcon,
        alertData.itemLabel, alertData.currentStock, alertData.percentage,
        alertData.analysis or "Stock levels are moderate. Continue monitoring.")
    end
    
    return sendEmailToPlayer(playerId, {
        sender = EmailConfig.stockAlerts.sender,
        subject = subject,
        message = message
    })
end

-- Order Notification Emails
function LBPhone.SendOrderNotification(playerId, orderData)
    local subject = string.format("🚚 New Order: %s (%d boxes)", 
        orderData.restaurantName, orderData.totalBoxes)
    
    -- Build items list
    local itemsList = ""
    for _, item in ipairs(orderData.items) do
        itemsList = itemsList .. string.format("- %s x%d\n", item.label, item.quantity)
    end
    
    local message = string.format([[
📦 NEW SUPPLY ORDER AVAILABLE 📦

*Restaurant:* %s
*Total Boxes:* %d
*Base Pay:* $%d

--- 📋 Order Details ---
%s
*Delivery Location:* %s
*Distance:* %.1f miles

--- 💰 Potential Bonuses ---
- Speed Bonus: Up to %.0f%%
- Volume Bonus: $%d
- Perfect Delivery: +$%d

_Head to the warehouse to accept this order!_
    ]], orderData.restaurantName, orderData.totalBoxes, orderData.basePay,
    itemsList, orderData.location or "Restaurant District", orderData.distance or 0,
    orderData.maxSpeedBonus or 40, orderData.volumeBonus or 0, orderData.perfectBonus or 100)
    
    return sendEmailToPlayer(playerId, {
        sender = EmailConfig.orderNotifications.sender,
        subject = subject,
        message = message,
        actions = orderData.actions
    })
end

-- Emergency Order Emails
function LBPhone.SendEmergencyOrderEmail(playerId, emergencyData)
    local urgencyEmoji = emergencyData.priority == 3 and "🚨" or "🔥"
    local subject = string.format("%s EMERGENCY: %s needs %s NOW!", 
        urgencyEmoji, emergencyData.restaurantName, emergencyData.itemLabel)
    
    local message = string.format([[
%s EMERGENCY SUPPLY REQUEST %s

*Restaurant:* %s
*Critical Item:* %s
*Units Needed:* %d
*Current Stock:* %d units

=== ⚡ URGENT DELIVERY REQUIRED ===
*Time Limit:* %d minutes
*Base Pay:* $%d
*Emergency Multiplier:* %.1fx
*Speed Bonus:* Up to +$%d
*Hero Bonus:* +$%d for preventing stockout!

💰 *Total Potential Earnings: $%d+*

⏰ *RESPOND IMMEDIATELY!*
_This restaurant will run out of stock without immediate assistance!_
    ]], urgencyEmoji, urgencyEmoji,
    emergencyData.restaurantName, emergencyData.itemLabel,
    emergencyData.unitsNeeded, emergencyData.currentStock,
    emergencyData.timeLimit or 30, emergencyData.basePay,
    emergencyData.multiplier, emergencyData.speedBonus,
    emergencyData.heroBonus, emergencyData.totalPotential)
    
    return sendEmailToPlayer(playerId, {
        sender = EmailConfig.emergencyAlerts.sender,
        subject = subject,
        message = message,
        actions = emergencyData.actions
    })
end

-- Delivery Completion Emails
function LBPhone.SendDeliveryReceipt(playerId, deliveryData)
    local subject = string.format("✅ Delivery Complete - Earned $%d", deliveryData.totalPay)
    
    -- Build bonuses list
    local bonusList = ""
    if deliveryData.speedBonus > 0 then
        bonusList = bonusList .. string.format("- Speed Bonus: +$%d (%.0f%%)\n", 
            deliveryData.speedBonus, (deliveryData.speedMultiplier * 100) - 100)
    end
    if deliveryData.volumeBonus > 0 then
        bonusList = bonusList .. string.format("- Volume Bonus: +$%d\n", deliveryData.volumeBonus)
    end
    if deliveryData.streakBonus > 0 then
        bonusList = bonusList .. string.format("- Streak Bonus: +$%d (x%d streak)\n", 
            deliveryData.streakBonus, deliveryData.currentStreak)
    end
    if deliveryData.perfectBonus > 0 then
        bonusList = bonusList .. string.format("- Perfect Delivery: +$%d\n", deliveryData.perfectBonus)
    end
    
    local message = string.format([[
✅ DELIVERY RECEIPT ✅

*Restaurant:* %s
*Boxes Delivered:* %d
*Delivery Time:* %s

--- 💰 Earnings Breakdown ---
*Base Pay:* $%d
%s
----------------------------------------
*Total Earned:* $%d

--- 📊 Performance Stats ---
- Current Streak: %d deliveries
- Daily Deliveries: %d
- Average Rating: %.1f%%

_Great work! Keep up the excellent deliveries!_
    ]], deliveryData.restaurantName, deliveryData.boxesDelivered,
    deliveryData.deliveryTime, deliveryData.basePay,
    bonusList, deliveryData.totalPay,
    deliveryData.currentStreak, deliveryData.dailyDeliveries,
    deliveryData.averageRating or 95.0)
    
    return sendEmailToPlayer(playerId, {
        sender = EmailConfig.orderNotifications.sender,
        subject = subject,
        message = message
    })
end

-- Duty Email Function
function LBPhone.SendDutyEmail(playerId, emailData)
    return sendEmailToPlayer(playerId, {
        sender = emailData.sender or EmailConfig.dutyAlerts.sender,
        subject = emailData.subject,
        message = emailData.message,
        actions = emailData.actions
    })
end

-- ===============================================
-- EMAIL SETUP CHECK HANDLERS
-- ===============================================

-- Check if player has email set up
RegisterNetEvent('supply:checkEmailSetup')
AddEventHandler('supply:checkEmailSetup', function()
    local src = source
    local phoneNumber = getPlayerPhoneNumber(src)
    local hasEmail = false
    
    if phoneNumber then
        local email = getEmailFromPhoneNumber(phoneNumber)
        hasEmail = email ~= nil
    end
    
    -- Send response to client
    TriggerClientEvent('supply:emailSetupStatus', src, hasEmail)
    TriggerClientEvent('supply:emailSetupResponse', src, hasEmail) -- For export
    
    -- Log for debugging
    if not hasEmail then
        print(string.format("[LBPhone] Player %s (%s) needs to set up email", 
            GetPlayerName(src), src))
    end
end)

-- Also add this helper function to send email notifications to client
local function notifyEmailReceived(playerId, emailType)
    TriggerClientEvent('supply:emailReceived', playerId, emailType)
end

-- Update the main send functions to include client notification
-- Example for SendDutyEmail (add similar to other functions):
local originalSendDutyEmail = LBPhone.SendDutyEmail
function LBPhone.SendDutyEmail(playerId, emailData)
    local success, emailId = originalSendDutyEmail(playerId, emailData)
    if success then
        notifyEmailReceived(playerId, 'duty')
    end
    return success, emailId
end

-- ===============================================
-- TEST COMMANDS
-- ===============================================

RegisterCommand('testlbphoneemail', function(source, args, rawCommand)
    if source == 0 then
        print("This command must be run in-game")
        return
    end
    
    local phoneNumber = getPlayerPhoneNumber(source)
    local email = phoneNumber and getEmailFromPhoneNumber(phoneNumber) or nil
    
    print("\n=== LB-PHONE EMAIL TEST ===")
    print("Player:", GetPlayerName(source))
    print("Phone Number:", phoneNumber or "NONE")
    print("Email Address:", email or "NONE")
    
    if not email then
        TriggerClientEvent('ox_lib:notify', source, {
            title = '📧 Email Test Failed',
            description = phoneNumber and 'No email address set up in phone' or 'No phone equipped',
            type = 'error',
            duration = 5000
        })
        return
    end
    
    -- Send test email
    local success = sendEmailToPlayer(source, {
        sender = "test@supply.chain",
        subject = "📧 Email Integration Test",
        message = string.format([[
✅ EMAIL TEST SUCCESSFUL! ✅

Your email integration is working correctly.

*Phone Number:* %s
*Email Address:* %s
*Test Time:* %s

All supply chain emails will be sent to this address.

--- Test Features ---
- Plain text formatting ✅
- Icon support 📱
- Line breaks working
- *Bold text* support
- _Italic text_ support

If you're seeing this message, everything is configured properly!
        ]], phoneNumber, email, os.date("%H:%M:%S"))
    })
    
    if success then
        TriggerClientEvent('ox_lib:notify', source, {
            title = '📧 Email Test Sent!',
            description = 'Check your phone email app',
            type = 'success',
            duration = 5000
        })
    else
        TriggerClientEvent('ox_lib:notify', source, {
            title = '📧 Email Test Failed',
            description = 'Failed to send test email',
            type = 'error',
            duration = 5000
        })
    end
end, false)

-- Export the module
_G.LBPhone = LBPhone
return LBPhone