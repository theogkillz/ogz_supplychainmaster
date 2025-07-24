-- ===============================================
-- LB-PHONE EMAIL INTEGRATION
-- ===============================================

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
-- STOCK ALERT EMAILS
-- ===============================================

function LBPhone.SendStockAlert(phoneNumber, alertData)
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
    
    -- Send the email
    local emailData = {
        to = phoneNumber,
        sender = EmailConfig.stockAlerts.sender,
        subject = subject,
        message = message
    }
    
    local success, emailId = exports["lb-phone"]:SendMail(emailData)
    
    if success then
        print(string.format("[STOCK ALERTS] Email sent to %s for %s (ID: %s)", 
            phoneNumber, alertData.itemLabel, emailId or "unknown"))
    else
        print(string.format("[STOCK ALERTS] Failed to send email to %s for %s", 
            phoneNumber, alertData.itemLabel))
    end
    
    return success, emailId
end

-- ===============================================
-- ORDER NOTIFICATION EMAILS
-- ===============================================

function LBPhone.SendOrderNotification(phoneNumber, orderData)
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
        to = phoneNumber,
        sender = EmailConfig.orderNotifications.sender,
        subject = subject,
        message = message,
        actions = {
            {
                label = "📍 Set Warehouse Waypoint",  -- Changed from "View Orders"
                data = {
                    event = "supply:openWarehouseMenu",
                    isServer = false,
                    data = { action = "setWaypoint" }
                }
            }
        }
    }
    
    local success, emailId = exports["lb-phone"]:SendMail(emailData)
    
    if success then
        print(string.format("[ORDERS] Email sent to %s for order %s (ID: %s)", 
            phoneNumber, orderData.orderId, emailId or "unknown"))
    end
    
    return success, emailId
end

-- ===============================================
-- EMERGENCY ORDER EMAILS
-- ===============================================

function LBPhone.SendEmergencyOrderEmail(phoneNumber, emergencyData)
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
        to = phoneNumber,
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
    
    return exports["lb-phone"]:SendMail(emailData)
end

-- ===============================================
-- DELIVERY COMPLETION EMAILS
-- ===============================================

function LBPhone.SendDeliveryReceipt(phoneNumber, deliveryData)
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
        to = phoneNumber,
        sender = EmailConfig.orderNotifications.sender,
        subject = subject,
        message = message
    }
    
    return exports["lb-phone"]:SendMail(emailData)
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

-- Export the module
_G.LBPhone = LBPhone
return LBPhone