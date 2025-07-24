local QBCore = exports['qb-core']:GetCoreObject()

-- Stock Alerts Menu Display
RegisterNetEvent("stockalerts:showAlerts")
AddEventHandler("stockalerts:showAlerts", function(alerts)
    local options = {}
    
    if not alerts or #alerts == 0 then
        table.insert(options, {
            title = "✅ All Stock Levels Healthy",
            description = "No stock alerts at this time",
            icon = "fas fa-check-circle",
            disabled = true
        })
    else
        -- Group alerts by severity
        local critical = {}
        local low = {}
        local moderate = {}
        
        for _, alert in ipairs(alerts) do
            if alert.alert_level == "critical" then
                table.insert(critical, alert)
            elseif alert.alert_level == "low" then
                table.insert(low, alert)
            else
                table.insert(moderate, alert)
            end
        end
        
        -- Add critical alerts first
        if #critical > 0 then
            table.insert(options, {
                title = "🚨 CRITICAL ALERTS",
                description = "Immediate action required",
                disabled = true
            })
            
            for _, alert in ipairs(critical) do
                table.insert(options, {
                    title = string.format("🔴 %s - %d units left", alert.ingredient, alert.current_stock),
                    description = string.format("%.1f%% of maximum stock", alert.threshold_percentage),
                    icon = "fas fa-exclamation-triangle",
                    metadata = {
                        ["Current Stock"] = tostring(alert.current_stock),
                        ["Threshold"] = string.format("%.1f%%", alert.threshold_percentage),
                        ["Status"] = "CRITICAL"
                    },
                    disabled = true
                })
            end
        end
        
        -- Add low alerts
        if #low > 0 then
            table.insert(options, {
                title = "⚠️ LOW STOCK WARNINGS",
                description = "Restock recommended soon",
                disabled = true
            })
            
            for _, alert in ipairs(low) do
                table.insert(options, {
                    title = string.format("🟡 %s - %d units left", alert.ingredient, alert.current_stock),
                    description = string.format("%.1f%% of maximum stock", alert.threshold_percentage),
                    icon = "fas fa-exclamation",
                    metadata = {
                        ["Current Stock"] = tostring(alert.current_stock),
                        ["Threshold"] = string.format("%.1f%%", alert.threshold_percentage),
                        ["Status"] = "LOW"
                    },
                    disabled = true
                })
            end
        end
        
        -- Add moderate alerts
        if #moderate > 0 then
            table.insert(options, {
                title = "📊 MODERATE STOCK LEVELS",
                description = "Monitor these items",
                disabled = true
            })
            
            for _, alert in ipairs(moderate) do
                table.insert(options, {
                    title = string.format("🔵 %s - %d units left", alert.ingredient, alert.current_stock),
                    description = string.format("%.1f%% of maximum stock", alert.threshold_percentage),
                    icon = "fas fa-info-circle",
                    metadata = {
                        ["Current Stock"] = tostring(alert.current_stock),
                        ["Threshold"] = string.format("%.1f%%", alert.threshold_percentage),
                        ["Status"] = "MODERATE"
                    },
                    disabled = true
                })
            end
        end
    end
    
    -- Add back button
    table.insert(options, 1, {
        title = "← Back to Main Menu",
        icon = "fas fa-arrow-left",
        onSelect = function()
            TriggerEvent("warehouse:openProcessingMenu")
        end
    })
    
    lib.registerContext({
        id = "stock_alerts_menu",
        title = "🚨 Stock Alert Dashboard",
        options = options
    })
    lib.showContext("stock_alerts_menu")
end)