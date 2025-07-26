local QBCore = exports['qb-core']:GetCoreObject()
local lib = exports['ox_lib']

-- Helper functions for icons
local function getAlertIcon(alertLevel)
    local icons = {
        critical = "🚨",
        low = "⚠️", 
        moderate = "ℹ️",
        healthy = "✅"
    }
    return icons[alertLevel] or "📦"
end

local function getTrendIcon(trend)
    local icons = {
        increasing = "📈",
        decreasing = "📉",
        stable = "➡️",
        unknown = "❓"
    }
    return icons[trend] or "➡️"
end

-- -- Stock Alerts Dashboard
-- RegisterNetEvent("stockalerts:openDashboard")
-- AddEventHandler("stockalerts:openDashboard", function()
--     local options = {
--         {
--             title = "📊 Stock Overview",
--             description = "View all inventory levels with alerts",
--             icon = "fas fa-chart-bar",
--             onSelect = function()
--                 TriggerServerEvent("stockalerts:getOverview")
--             end
--         },
--         {
--             title = "🔮 Predictive Analytics",
--             description = "View demand forecasts and trends",
--             icon = "fas fa-crystal-ball",
--             onSelect = function()
--                 TriggerEvent("stockalerts:showPredictions")
--             end
--         },
--         {
--             title = "⚠️ Critical Alerts",
--             description = "View only urgent stock alerts",
--             icon = "fas fa-exclamation-triangle",
--             onSelect = function()
--                 TriggerServerEvent("stockalerts:getCriticalAlerts")
--             end
--         },
--         {
--             title = "📈 Usage Trends",
--             description = "Analyze consumption patterns",
--             icon = "fas fa-trending-up",
--             onSelect = function()
--                 TriggerServerEvent("stockalerts:getUsageTrends")
--             end
--         },
--         {
--             title = "← Back to Warehouse",
--             icon = "fas fa-arrow-left",
--             onSelect = function()
--                 TriggerEvent("warehouse:openProcessingMenu")
--             end
--         }
--     }
    
--     lib.registerContext({
--         id = "stock_dashboard",
--         title = "🚨 Stock Alerts Dashboard",
--         options = options
--     })
--     lib.showContext("stock_dashboard")
-- end)

-- -- Display Stock Overview
-- RegisterNetEvent("stockalerts:showOverview")
-- AddEventHandler("stockalerts:showOverview", function(stockData)
--     local options = {
--         {
--             title = "← Back to Dashboard",
--             icon = "fas fa-arrow-left",
--             onSelect = function()
--                 TriggerEvent("stockalerts:openDashboard")
--             end
--         }
--     }
    
--     if not stockData or #stockData == 0 then
--         table.insert(options, {
--             title = "No Stock Data",
--             description = "No inventory information available",
--             disabled = true
--         })
--     else
--         -- Sort by alert level priority
--         table.sort(stockData, function(a, b)
--             local priorities = { critical = 4, low = 3, moderate = 2, healthy = 1 }
--             return (priorities[a.alertLevel] or 0) > (priorities[b.alertLevel] or 0)
--         end)
        
--         for _, item in ipairs(stockData) do
--             local alertIcon = getAlertIcon(item.alertLevel)
--             local trendIcon = getTrendIcon(item.trend)
            
--             local description = string.format(
--                 "%s **%d units** (%.1f%%)\n📈 %s %s • 📊 %.0f%% confidence",
--                 alertIcon,
--                 item.currentStock,
--                 item.percentage,
--                 trendIcon,
--                 item.trend:gsub("^%l", string.upper),
--                 item.confidence * 100
--             )
            
--             if item.daysRemaining then
--                 description = description .. string.format("\n⏰ **%.1f days** remaining", item.daysRemaining)
--             end
            
--             if item.dailyUsage > 0 then
--                 description = description .. string.format("\n📦 **%.1f** avg daily usage", item.dailyUsage)
--             end
            
--             table.insert(options, {
--                 title = item.label,
--                 description = description,
--                 metadata = {
--                     ["Stock Level"] = item.currentStock .. " units",
--                     ["Percentage"] = string.format("%.1f%%", item.percentage),
--                     ["Alert Level"] = item.alertLevel:gsub("^%l", string.upper),
--                     ["Daily Usage"] = string.format("%.1f", item.dailyUsage),
--                     ["Days Remaining"] = item.daysRemaining and string.format("%.1f", item.daysRemaining) or "N/A",
--                     ["Trend"] = item.trend:gsub("^%l", string.upper)
--                 }
--             })
--         end
--     end
    
--     lib.registerContext({
--         id = "stock_overview",
--         title = "📊 Stock Overview",
--         options = options
--     })
--     lib.showContext("stock_overview")
-- end)

-- -- Display Restock Suggestions
-- RegisterNetEvent("stockalerts:showSuggestions")
-- AddEventHandler("stockalerts:showSuggestions", function(suggestions)
--     local options = {
--         {
--             title = "← Back to Warehouse",
--             icon = "fas fa-arrow-left",
--             onSelect = function()
--                 TriggerEvent("warehouse:openProcessingMenu")
--             end
--         }
--     }
    
--     if not suggestions or #suggestions == 0 then
--         table.insert(options, {
--             title = "✅ All Stock Levels Good",
--             description = "No restock recommendations at this time",
--             disabled = true
--         })
--     else
--         table.insert(options, {
--             title = "🤖 AI Recommendations",
--             description = string.format("Based on %d days of usage analysis", Config.StockAlerts and Config.StockAlerts.prediction.analysisWindow or 7),
--             disabled = true
--         })
        
--         for _, suggestion in ipairs(suggestions) do
--             local priorityIcon = suggestion.priority == "high" and "🚨" or "📦"
--             local itemNames = exports.ox_inventory:Items() or {}
--             local itemLabel = itemNames[suggestion.ingredient] and itemNames[suggestion.ingredient].label or suggestion.ingredient
            
--             local description = string.format(
--                 "%s **Order %d units**\n📦 Current: %d units (%.1f days left)\n📈 Daily usage: %.1f units",
--                 priorityIcon,
--                 suggestion.suggestedOrder,
--                 suggestion.currentStock,
--                 suggestion.daysOfStock,
--                 suggestion.dailyUsage
--             )
            
--             table.insert(options, {
--                 title = itemLabel,
--                 description = description,
--                 metadata = {
--                     ["Current Stock"] = suggestion.currentStock .. " units",
--                     ["Suggested Order"] = suggestion.suggestedOrder .. " units", 
--                     ["Days Remaining"] = string.format("%.1f days", suggestion.daysOfStock),
--                     ["Daily Usage"] = string.format("%.1f units", suggestion.dailyUsage),
--                     ["Priority"] = suggestion.priority:gsub("^%l", string.upper)
--                 },
--                 onSelect = function()
--                     -- Could add auto-order functionality here
--                     lib.notify({
--                         title = "Restock Suggestion",
--                         description = string.format("Consider ordering **%d %s** to maintain optimal stock levels", suggestion.suggestedOrder, itemLabel),
--                         type = "info",
--                         duration = 10000,
--                         position = Config.UI.notificationPosition,
--                         markdown = Config.UI.enableMarkdown
--                     })
--                 end
--             })
--         end
--     end
    
--     lib.registerContext({
--         id = "restock_suggestions",
--         title = "📦 AI Restock Suggestions",
--         options = options
--     })
--     lib.showContext("restock_suggestions")
-- end)

-- Real-time stock alert notifications (these come automatically from server)
RegisterNetEvent("stockalerts:urgentAlert")
AddEventHandler("stockalerts:urgentAlert", function(alertData)
    -- Play sound for critical alerts
    if alertData.alertLevel == "critical" then
        PlaySoundFrontend(-1, "CHECKPOINT_PERFECT", "HUD_MINI_GAME_SOUNDSET", true)
    end
    
    lib.alertDialog({
        header = "🚨 URGENT STOCK ALERT",
        content = string.format(
            "**%s** is critically low!\n\nCurrent Stock: %d units\nEstimated Days Remaining: %.1f\n\nImmediate action required!",
            alertData.itemLabel,
            alertData.currentStock,
            alertData.daysUntilStockout or 0
        ),
        centered = true,
        cancel = false,
        size = 'md'
    })
end)

-- -- Predictive analytics display
-- RegisterNetEvent("stockalerts:showPredictions")
-- AddEventHandler("stockalerts:showPredictions", function()
--     -- This would show advanced prediction charts and analytics
--     lib.notify({
--         title = "🔮 Predictive Analytics",
--         description = "Advanced forecasting dashboard coming soon! Currently analyzing usage patterns in real-time.",
--         type = "info",
--         duration = 8000,
--         position = Config.UI.notificationPosition,
--         markdown = Config.UI.enableMarkdown
--     })
-- end)

-- RegisterNetEvent("stockalerts:showUsageTrends")
-- AddEventHandler("stockalerts:showUsageTrends", function(trends)
--     local options = {
--         {
--             title = "← Back to Dashboard",
--             icon = "fas fa-arrow-left",
--             onSelect = function()
--                 TriggerEvent("stockalerts:openDashboard")
--             end
--         }
--     }
    
--     if not trends or #trends == 0 then
--         table.insert(options, {
--             title = "No Trend Data",
--             description = "Not enough historical data for analysis",
--             disabled = true
--         })
--     else
--         for _, trend in ipairs(trends) do
--             local trendIcon = getTrendIcon(trend.trend)
            
--             table.insert(options, {
--                 title = trend.label,
--                 description = string.format(
--                     "%s %s trend\n📊 Avg: %.1f/day • Peak: %.1f • Min: %.1f\n📈 %d data points",
--                     trendIcon,
--                     trend.trend:gsub("^%l", string.upper),
--                     trend.avgUsage,
--                     trend.peakUsage,
--                     trend.minUsage,
--                     trend.dataPoints
--                 ),
--                 disabled = true
--             })
--         end
--     end
    
--     lib.registerContext({
--         id = "usage_trends",
--         title = "📈 Usage Trends",
--         options = options
--     })
--     lib.showContext("usage_trends")
-- end)