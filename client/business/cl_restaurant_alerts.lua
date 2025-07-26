-- Restaurant Stock Alerts Menu
RegisterNetEvent("restaurant:openStockAlerts")
AddEventHandler("restaurant:openStockAlerts", function(restaurantId)
    TriggerServerEvent("restaurant:getStockAlerts", restaurantId)
end)

-- Display Restaurant Stock Alerts
RegisterNetEvent("restaurant:showStockAlerts")
AddEventHandler("restaurant:showStockAlerts", function(alerts, restaurantId)
    local options = {
        {
            title = "← Back to Restaurant Menu",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("restaurant:openOrderMenu", { restaurantId = restaurantId })
            end
        },
        {
            title = "🔄 Refresh Alerts",
            description = "Update stock alert information",
            icon = "fas fa-sync",
            onSelect = function()
                TriggerServerEvent("restaurant:getStockAlerts", restaurantId)
            end
        }
    }
    
    if not alerts or #alerts == 0 then
        table.insert(options, {
            title = "✅ All Stock Levels Good",
            description = "No alerts for your restaurant ingredients",
            disabled = true
        })
    else
        -- Sort alerts by priority
        table.sort(alerts, function(a, b)
            local priorities = { critical = 4, low = 3, moderate = 2, healthy = 1 }
            return (priorities[a.alertLevel] or 0) > (priorities[b.alertLevel] or 0)
        end)
        
        for _, alert in ipairs(alerts) do
            local alertIcon = getAlertIcon(alert.alertLevel)
            local alertColor = alert.alertLevel
            
            local description = string.format(
                "%s **%d units available** (%.1f%%)",
                alertIcon,
                alert.warehouseStock,
                alert.percentage
            )
            
            if alert.daysUntilStockout then
                description = description .. string.format("\n⏰ **%.1f days** until warehouse stockout", alert.daysUntilStockout)
            end
            
            if alert.restaurantStock then
                description = description .. string.format("\n🏪 Your stock: **%d units**", alert.restaurantStock)
            end
            
            if alert.suggestedOrder then
                description = description .. string.format("\n💡 Suggested order: **%d units**", alert.suggestedOrder)
            end
            
            table.insert(options, {
                title = alert.itemLabel,
                description = description,
                metadata = {
                    ["Alert Level"] = alert.alertLevel:gsub("^%l", string.upper),
                    ["Warehouse Stock"] = alert.warehouseStock .. " units",
                    ["Your Stock"] = (alert.restaurantStock or 0) .. " units",
                    ["Suggested Order"] = (alert.suggestedOrder or 0) .. " units"
                },
                onSelect = function()
                    if alert.suggestedOrder and alert.suggestedOrder > 0 then
                        lib.alertDialog({
                            header = "🛒 Quick Order",
                            content = string.format(
                                "Would you like to order the suggested **%d %s**?\n\nEstimated cost: $%d",
                                alert.suggestedOrder,
                                alert.itemLabel,
                                alert.estimatedCost or (alert.suggestedOrder * (alert.price or 10))
                            ),
                            centered = true,
                            cancel = true,
                            labels = {
                                confirm = "Order Now",
                                cancel = "Maybe Later"
                            }
                        }):next(function(confirmed)
                            if confirmed then
                                TriggerServerEvent("restaurant:quickOrder", restaurantId, alert.ingredient, alert.suggestedOrder)
                            end
                        end)
                    end
                end
            })
        end
    end
    
    lib.registerContext({
        id = "restaurant_stock_alerts",
        title = "🚨 Restaurant Stock Alerts",
        options = options
    })
    lib.showContext("restaurant_stock_alerts")
end)

-- Display Usage Analytics
RegisterNetEvent("restaurant:showUsageAnalytics")
AddEventHandler("restaurant:showUsageAnalytics", function(analytics, restaurantId)
    local options = {
        {
            title = "← Back to Restaurant Menu",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("restaurant:openOrderMenu", { restaurantId = restaurantId })
            end
        }
    }
    
    if not analytics or #analytics == 0 then
        table.insert(options, {
            title = "📊 No Usage Data",
            description = "Not enough order history for analysis",
            disabled = true
        })
    else
        table.insert(options, {
            title = "📈 Usage Trends (Last 7 Days)",
            description = "Based on your ordering patterns",
            disabled = true
        })
        
        for _, item in ipairs(analytics) do
            local trendIcon = getTrendIcon(item.trend)
            
            local description = string.format(
                "📦 **%.1f units/day** average usage\n📈 %s %s trend\n📊 %.0f%% prediction confidence",
                item.avgDailyUsage,
                trendIcon,
                item.trend:gsub("^%l", string.upper),
                item.confidence * 100
            )
            
            if item.peakDay then
                description = description .. string.format("\n🔥 Peak day: **%s** (%.1f units)", item.peakDay, item.peakUsage)
            end
            
            table.insert(options, {
                title = item.itemLabel,
                description = description,
                metadata = {
                    ["Avg Daily Usage"] = string.format("%.1f units", item.avgDailyUsage),
                    ["Trend"] = item.trend:gsub("^%l", string.upper),
                    ["Confidence"] = string.format("%.0f%%", item.confidence * 100),
                    ["Total Orders"] = tostring(item.totalOrders),
                    ["Days Active"] = tostring(item.daysActive)
                }
            })
        end
    end
    
    lib.registerContext({
        id = "restaurant_usage_analytics",
        title = "📊 Usage Analytics",
        options = options
    })
    lib.showContext("restaurant_usage_analytics")
end)

-- Display Smart Reorder Suggestions
RegisterNetEvent("restaurant:showSmartReorder")
AddEventHandler("restaurant:showSmartReorder", function(suggestions, restaurantId)
    local options = {
        {
            title = "← Back to Restaurant Menu",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("restaurant:openOrderMenu", { restaurantId = restaurantId })
            end
        }
    }
    
    if not suggestions or #suggestions == 0 then
        table.insert(options, {
            title = "✅ No Reorder Needed",
            description = "All ingredient levels are optimal",
            disabled = true
        })
    else
        table.insert(options, {
            title = "🤖 AI Recommendations",
            description = "Optimized ordering suggestions for your restaurant",
            disabled = true
        })
        
        local totalCost = 0
        for _, suggestion in ipairs(suggestions) do
            totalCost = totalCost + (suggestion.estimatedCost or 0)
            
            local priorityIcon = suggestion.priority == "high" and "🚨" or 
                               suggestion.priority == "normal" and "📦" or "💡"
            
            local description = string.format(
                "%s **Order %d units** - $%d\n🏪 Your stock: %d units\n⏰ %.1f days remaining",
                priorityIcon,
                suggestion.suggestedQuantity,
                suggestion.estimatedCost or 0,
                suggestion.currentRestaurantStock,
                suggestion.daysRemaining
            )
            
            table.insert(options, {
                title = suggestion.itemLabel,
                description = description,
                metadata = {
                    ["Suggested Quantity"] = suggestion.suggestedQuantity .. " units",
                    ["Estimated Cost"] = "$" .. (suggestion.estimatedCost or 0),
                    ["Priority"] = suggestion.priority:gsub("^%l", string.upper),
                    ["Current Stock"] = suggestion.currentRestaurantStock .. " units",
                    ["Days Remaining"] = string.format("%.1f", suggestion.daysRemaining)
                },
                onSelect = function()
                    lib.alertDialog({
                        header = "🛒 Order Confirmation",
                        content = string.format(
                            "Order **%d %s** for **$%d**?\n\nThis will give you approximately **%.1f days** of stock based on your usage patterns.",
                            suggestion.suggestedQuantity,
                            suggestion.itemLabel,
                            suggestion.estimatedCost or 0,
                            suggestion.projectedDays or 14
                        ),
                        centered = true,
                        cancel = true,
                        labels = {
                            confirm = "Order Now",
                            cancel = "Not Now"
                        }
                    }):next(function(confirmed)
                        if confirmed then
                            TriggerServerEvent("restaurant:smartOrder", restaurantId, suggestion.ingredient, suggestion.suggestedQuantity)
                        end
                    end)
                end
            })
        end
        
        if totalCost > 0 then
            table.insert(options, {
                title = "🛒 Order All Suggestions",
                description = string.format("Order all recommended items for **$%d** total", totalCost),
                icon = "fas fa-shopping-cart",
                onSelect = function()
                    lib.alertDialog({
                        header = "🛒 Bulk Order Confirmation", 
                        content = string.format(
                            "Order all AI-recommended items for **$%d** total?\n\nThis will optimize your inventory for the next 2 weeks.",
                            totalCost
                        ),
                        centered = true,
                        cancel = true,
                        labels = {
                            confirm = "Order All",
                            cancel = "Cancel"
                        }
                    }):next(function(confirmed)
                        if confirmed then
                            TriggerServerEvent("restaurant:bulkSmartOrder", restaurantId, suggestions)
                        end
                    end)
                end
            })
        end
    end
    
    lib.registerContext({
        id = "restaurant_smart_reorder",
        title = "🔮 Smart Reorder",
        options = options
    })
    lib.showContext("restaurant_smart_reorder")
end)

-- Success notifications for orders
RegisterNetEvent("restaurant:orderSuccess")
AddEventHandler("restaurant:orderSuccess", function(message, details)
    lib.notify({
        title = "🛒 Order Successful",
        description = message,
        type = "success",
        duration = 8000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })
end)