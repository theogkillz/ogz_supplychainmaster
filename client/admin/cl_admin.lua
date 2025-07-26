-- ===============================================
-- CLIENT-SIDE JOB RESET FUNCTIONS
-- ===============================================

-- Force job reset - cleans up all client states
RegisterNetEvent('supply:forceJobReset')
AddEventHandler('supply:forceJobReset', function()
    local playerPed = PlayerPedId()
    
    -- 1. CLEAR ALL UI ELEMENTS
    lib.hideTextUI()
    lib.hideContext()
    
    -- Clear any progress bars
    if lib.progressActive then
        lib.progressCancel()
    end
    
    -- 2. CLEAR DELIVERY STATES
    
    -- Clear any carrying animations
    ClearPedTasks(playerPed)
    
    -- Remove any attached box props
    local attachedObjects = GetGamePool('CObject')
    for _, obj in pairs(attachedObjects) do
        if IsEntityAttachedToEntity(obj, playerPed) then
            DeleteObject(obj)
        end
    end
    
    -- 3. CLEAR VEHICLE STATES
    
    -- Get current vehicle
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    if vehicle ~= 0 then
        -- Check if it's a delivery vehicle (has delivery plate pattern)
        local plate = GetVehicleNumberPlateText(vehicle)
        if string.find(plate, "SUPPLY") or string.find(plate, "DELIV") then
            -- Remove vehicle keys
            local vanPlate = GetVehicleNumberPlateText(vehicle)
            TriggerEvent("vehiclekeys:client:RemoveKeys", vanPlate)
            
            -- Delete the vehicle
            SetEntityAsMissionEntity(vehicle, true, true)
            DeleteVehicle(vehicle)
        end
    end
    
    -- 4. CLEAR TARGET ZONES
    
    -- Remove any ox_target zones that might be stuck
    local commonZones = {
        "warehouse_npc_interaction",
        "box_pickup_zone",
        "van_load_zone",
        "delivery_zone",
        "team_box_pickup",
        "team_van_load"
    }
    
    for _, zoneName in ipairs(commonZones) do
        exports.ox_target:removeZone(zoneName)
    end
    
    -- 5. CLEAR BLIPS
    
    -- Remove common delivery blips
    local blips = GetGamePool('CBlip')
    for _, blip in pairs(blips) do
        local blipSprite = GetBlipSprite(blip)
        local blipColor = GetBlipColour(blip)
        
        -- Remove delivery-related blips (adjust sprites as needed)
        if blipSprite == 1 or blipSprite == 67 or blipSprite == 501 then
            if blipColor == 2 or blipColor == 3 or blipColor == 5 then
                RemoveBlip(blip)
            end
        end
    end
    
    -- 6. CLEAR PROPS/OBJECTS
    
    -- Remove any delivery box props in the area
    local playerCoords = GetEntityCoords(playerPed)
    local objects = GetGamePool('CObject')
    for _, obj in pairs(objects) do
        local objCoords = GetEntityCoords(obj)
        local distance = #(playerCoords - objCoords)
        
        if distance < 50.0 then
            local objModel = GetEntityModel(obj)
            local boxModel = GetHashKey(Config.CarryBoxProp or "ng_proc_box_01a")
            local palletModel = GetHashKey(Config.DeliveryProps and Config.DeliveryProps.palletProp or "prop_boxpile_06b")
            
            if objModel == boxModel or objModel == palletModel then
                DeleteObject(obj)
            end
        end
    end
    
    -- 7. RESET PLAYER STATE
    
    -- Remove any special player states
    SetPlayerInvincible(playerPed, false)
    SetEntityCollision(playerPed, true, true)
    FreezeEntityPosition(playerPed, false)
    
    -- Clear any stuck animations
    RequestAnimDict("move_m@confident")
    while not HasAnimDictLoaded("move_m@confident") do
        Citizen.Wait(0)
    end
    SetPedMovementClipset(playerPed, "move_m@confident", 0.25)
    
    -- 8. RESET WAYPOINTS
    
    -- Clear any active waypoints
    SetWaypointOff()
    
    -- 9. CLEAR NOTIFICATIONS
    
    -- Send a clean slate notification
    Citizen.SetTimeout(1000, function()
        lib.notify({
            title = '🔄 Job Reset Complete',
            description = 'Your supply chain job has been reset.\nAll states cleared, you can start fresh!',
            type = 'success',
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
    end)
    
    -- 10. FORCE REFRESH MENUS
    
    -- Close any open menus and refresh warehouse access
    Citizen.SetTimeout(2000, function()
        -- Check if player has warehouse access and refresh
        local xPlayer = QBCore.Functions.GetPlayerData()
        if xPlayer and xPlayer.job then
            local hasAccess = false
            for _, job in ipairs(Config.Jobs.warehouse) do
                if xPlayer.job.name == job then
                    hasAccess = true
                    break
                end
            end
            
            if hasAccess then
                lib.notify({
                    title = '✅ Warehouse Access Restored',
                    description = 'You can now access the warehouse menu normally.',
                    type = 'info',
                    duration = 5000,
                    position = Config.UI.notificationPosition
                })
            end
        end
    end)
    
    print("[SUPPLY RESET] Client-side job reset completed")
end)

-- Debug command to manually trigger client reset
RegisterCommand('supplyclientreset', function(source, args, rawCommand)
    TriggerEvent('supply:forceJobReset')
end, false)

-- ===============================================
-- ADMIN MENU SYSTEM
-- ===============================================

-- Open admin menu
RegisterNetEvent('supply:openAdminMenu')
AddEventHandler('supply:openAdminMenu', function()
    TriggerServerEvent('supply:requestAdminMenu')
end)

-- Show admin menu with system data
RegisterNetEvent('supply:showAdminMenu')
AddEventHandler('supply:showAdminMenu', function(systemData)
    local statusColor = systemData.systemStatus == 'healthy' and '🟢' or systemData.systemStatus == 'warning' and '🟡' or '🔴'
    
    local options = {
        {
            title = "📊 System Overview",
            description = string.format(
                "%s **System Status: %s**\n📋 Pending Orders: %d\n✅ Daily Completed: %d\n👥 Active Drivers: %d\n🚨 Critical Alerts: %d\n⚡ Emergency Orders: %d\n📈 Market Average: %.2fx",
                statusColor,
                systemData.systemStatus:gsub("^%l", string.upper),
                systemData.pendingOrders,
                systemData.dailyOrders,
                systemData.activeDrivers,
                systemData.criticalAlerts,
                systemData.emergencyOrders,
                systemData.marketAverage
            ),
            disabled = true
        },
        {
            title = "📈 Market Management",
            description = "Control market events and pricing",
            icon = "fas fa-chart-line",
            onSelect = function()
                TriggerEvent('admin:openMarketMenu')
            end
        },
        {
            title = "🚨 Stock Monitoring",
            description = "View and manage stock alerts",
            icon = "fas fa-warehouse",
            onSelect = function()
                TriggerEvent('admin:openStockMenu')
            end
        },
        {
            title = "👥 Driver Management",
            description = "Manage drivers and statistics",
            icon = "fas fa-users",
            onSelect = function()
                TriggerEvent('admin:openDriverMenu')
            end
        },
        {
            title = "🚛 Emergency Orders",
            description = "Create and manage emergency deliveries",
            icon = "fas fa-exclamation-triangle",
            onSelect = function()
                TriggerEvent('admin:openEmergencyMenu')
            end
        },
        {
            title = "🔧 Job Reset Tools",
            description = "Reset player jobs and fix stuck states",
            icon = "fas fa-wrench",
            onSelect = function()
                TriggerEvent('admin:openJobResetMenu')
            end
        },
        {
            title = "📊 Analytics Dashboard",
            description = "View detailed system analytics",
            icon = "fas fa-chart-bar",
            onSelect = function()
                TriggerEvent('admin:openAnalyticsMenu')
            end
        },
        {
            title = "⚙️ System Tools",
            description = "Reset, export, and reload functions",
            icon = "fas fa-cogs",
            onSelect = function()
                TriggerEvent('admin:openSystemMenu')
            end
        },
        {
            title = "🔄 Refresh Data",
            description = "Update system information",
            icon = "fas fa-sync",
            onSelect = function()
                TriggerServerEvent('supply:requestAdminMenu')
            end
        }
    }
    
    lib.registerContext({
        id = "supply_admin_main",
        title = "🏢 Supply Chain Admin Panel",
        options = options
    })
    lib.showContext("supply_admin_main")
end)

-- ===============================================
-- JOB RESET MENU
-- ===============================================
RegisterNetEvent('admin:openJobResetMenu')
AddEventHandler('admin:openJobResetMenu', function()
    local options = {
        {
            title = "← Back to Admin Panel",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerServerEvent('supply:requestAdminMenu')
            end
        },
        {
            title = "🔄 Reset My Job",
            description = "Reset your own supply chain job",
            icon = "fas fa-user-cog",
            onSelect = function()
                lib.alertDialog({
                    header = "🔄 Reset Your Job",
                    content = "This will reset your supply chain job state. Continue?",
                    centered = true,
                    cancel = true,
                    labels = {
                        confirm = "Reset My Job",
                        cancel = "Cancel"
                    }
                }):next(function(confirmed)
                    if confirmed then
                        ExecuteCommand('supplyjobreset')
                    end
                end)
            end
        },
        {
            title = "🎯 Reset Player Job",
            description = "Reset a specific player's job",
            icon = "fas fa-user-times",
            onSelect = function()
                local input = lib.inputDialog("Reset Player Job", {
                    { type = "number", label = "Player ID", placeholder = "Enter player server ID", min = 1, required = true }
                })
                if input and input[1] then
                    lib.alertDialog({
                        header = "⚠️ Confirm Job Reset",
                        content = "This will reset the supply chain job for player ID: " .. input[1],
                        centered = true,
                        cancel = true,
                        labels = {
                            confirm = "Reset Job",
                            cancel = "Cancel"
                        }
                    }):next(function(confirmed)
                        if confirmed then
                            ExecuteCommand('supplyjobreset ' .. input[1])
                        end
                    end)
                end
            end
        },
        {
            title = "🌐 Mass Reset All Players",
            description = "Reset ALL online players (SUPERADMIN ONLY)",
            icon = "fas fa-users-cog",
            onSelect = function()
                lib.alertDialog({
                    header = "⚠️ MASS RESET WARNING",
                    content = "This will reset the supply chain job for ALL online players. This action cannot be undone!",
                    centered = true,
                    cancel = true,
                    labels = {
                        confirm = "MASS RESET",
                        cancel = "Cancel"
                    }
                }):next(function(confirmed)
                    if confirmed then
                        ExecuteCommand('supplyjobmassreset')
                    end
                end)
            end
        },
        {
            title = "🚨 Emergency System Restart",
            description = "Full system restart (SUPERADMIN ONLY)",
            icon = "fas fa-exclamation-triangle",
            onSelect = function()
                lib.alertDialog({
                    header = "🚨 EMERGENCY RESTART WARNING",
                    content = "This will restart the entire supply chain system for all players. Use only if system is completely broken!",
                    centered = true,
                    cancel = true,
                    labels = {
                        confirm = "EMERGENCY RESTART",
                        cancel = "Cancel"
                    }
                }):next(function(confirmed)
                    if confirmed then
                        ExecuteCommand('supplyemergencyrestart')
                    end
                end)
            end
        }
    }
    
    lib.registerContext({
        id = "admin_job_reset_menu",
        title = "🔧 Job Reset Tools",
        options = options
    })
    lib.showContext("admin_job_reset_menu")
end)

-- ===============================================
-- MARKET MANAGEMENT MENU
-- ===============================================
RegisterNetEvent('admin:openMarketMenu')
AddEventHandler('admin:openMarketMenu', function()
    local options = {
        {
            title = "← Back to Admin Panel",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerServerEvent('supply:requestAdminMenu')
            end
        },
        {
            title = "📊 Market Overview",
            description = "View current market conditions",
            icon = "fas fa-chart-pie",
            onSelect = function()
                TriggerServerEvent('market:getOverview')
            end
        },
        {
            title = "🚨 Create Shortage Event",
            description = "Trigger a shortage for specific ingredient",
            icon = "fas fa-exclamation-triangle",
            onSelect = function()
                local input = lib.inputDialog("Create Shortage Event", {
                    { type = "input", label = "Ingredient Name", placeholder = "e.g., reign_packed_groundchicken", required = true }
                })
                if input and input[1] then
                    ExecuteCommand('supply market event ' .. input[1] .. ' shortage')
                end
            end
        },
        {
            title = "💰 Create Surplus Event",
            description = "Trigger a surplus for specific ingredient",
            icon = "fas fa-plus-circle",
            onSelect = function()
                local input = lib.inputDialog("Create Surplus Event", {
                    { type = "input", label = "Ingredient Name", placeholder = "e.g., reign_packed_groundchicken", required = true }
                })
                if input and input[1] then
                    ExecuteCommand('supply market event ' .. input[1] .. ' surplus')
                end
            end
        },
        {
            title = "🔄 Reset Market Prices",
            description = "Reset all prices to base values",
            icon = "fas fa-undo",
            onSelect = function()
                lib.alertDialog({
                    header = "⚠️ Confirm Market Reset",
                    content = "This will reset ALL market prices to base values. This action cannot be undone.",
                    centered = true,
                    cancel = true,
                    labels = {
                        confirm = "Reset Market",
                        cancel = "Cancel"
                    }
                }):next(function(confirmed)
                    if confirmed then
                        ExecuteCommand('supply market reset')
                    end
                end)
            end
        },
        {
            title = "📈 Price History",
            description = "View historical pricing data",
            icon = "fas fa-history",
            onSelect = function()
                local input = lib.inputDialog("View Price History", {
                    { type = "input", label = "Ingredient Name", placeholder = "e.g., reign_packed_groundchicken", required = true }
                })
                if input and input[1] then
                    TriggerServerEvent('market:getPriceHistory', input[1])
                end
            end
        }
    }
    
    lib.registerContext({
        id = "admin_market_menu",
        title = "📈 Market Management",
        options = options
    })
    lib.showContext("admin_market_menu")
end)

-- ===============================================
-- STOCK MONITORING MENU
-- ===============================================
RegisterNetEvent('admin:openStockMenu')
AddEventHandler('admin:openStockMenu', function()
    local options = {
        {
            title = "← Back to Admin Panel",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerServerEvent('supply:requestAdminMenu')
            end
        },
        {
            title = "📊 Stock Overview",
            description = "View all inventory levels",
            icon = "fas fa-chart-bar",
            onSelect = function()
                TriggerServerEvent('stockalerts:getOverview')
            end
        },
        {
            title = "🚨 Critical Alerts Only",
            description = "Show only critical stock situations",
            icon = "fas fa-exclamation-circle",
            onSelect = function()
                TriggerServerEvent('stockalerts:getCriticalAlerts')
            end
        },
        {
            title = "📈 Usage Trends",
            description = "Analyze consumption patterns",
            icon = "fas fa-trending-up",
            onSelect = function()
                TriggerServerEvent('stockalerts:getUsageTrends')
            end
        },
        {
            title = "🔮 AI Predictions",
            description = "View predictive analytics",
            icon = "fas fa-magic",
            onSelect = function()
                TriggerServerEvent('stockalerts:getSuggestions')
            end
        },
        {
            title = "📦 Manual Stock Adjustment",
            description = "Manually adjust warehouse stock",
            icon = "fas fa-edit",
            onSelect = function()
                local input = lib.inputDialog("Manual Stock Adjustment", {
                    { type = "input", label = "Ingredient Name", placeholder = "e.g., reign_packed_groundchicken", required = true },
                    { type = "number", label = "New Quantity", placeholder = "Enter amount", min = 0, max = 9999, required = true }
                })
                if input and input[1] and input[2] then
                    TriggerServerEvent('admin:adjustStock', input[1], tonumber(input[2]))
                end
            end
        }
    }
    
    lib.registerContext({
        id = "admin_stock_menu",
        title = "📦 Stock Monitoring",
        options = options
    })
    lib.showContext("admin_stock_menu")
end)

-- ===============================================
-- DRIVER MANAGEMENT MENU
-- ===============================================
RegisterNetEvent('admin:openDriverMenu')
AddEventHandler('admin:openDriverMenu', function()
    local options = {
        {
            title = "← Back to Admin Panel",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerServerEvent('supply:requestAdminMenu')
            end
        },
        {
            title = "🏆 Driver Leaderboards",
            description = "View top performing drivers",
            icon = "fas fa-trophy",
            onSelect = function()
                TriggerServerEvent('leaderboard:getDriverStats', 'all_time')
            end
        },
        {
            title = "📊 Driver Analytics",
            description = "Detailed driver performance data",
            icon = "fas fa-chart-line",
            onSelect = function()
                TriggerServerEvent('admin:getDriverAnalytics')
            end
        },
        {
            title = "🎯 Reset Player Stats",
            description = "Reset specific player's statistics",
            icon = "fas fa-user-times",
            onSelect = function()
                local input = lib.inputDialog("Reset Player Stats", {
                    { type = "number", label = "Player ID", placeholder = "Enter player server ID", min = 1, required = true }
                })
                if input and input[1] then
                    lib.alertDialog({
                        header = "⚠️ Confirm Stats Reset",
                        content = "This will permanently delete all statistics for this player. This action cannot be undone.",
                        centered = true,
                        cancel = true,
                        labels = {
                            confirm = "Reset Stats",
                            cancel = "Cancel"
                        }
                    }):next(function(confirmed)
                        if confirmed then
                            ExecuteCommand('supply reset stats ' .. input[1])
                        end
                    end)
                end
            end
        },
        {
            title = "🏅 Grant Achievement",
            description = "Manually grant achievement to player",
            icon = "fas fa-medal",
            onSelect = function()
                local input = lib.inputDialog("Grant Achievement", {
                    { type = "number", label = "Player ID", placeholder = "Enter player server ID", min = 1, required = true },
                    { type = "input", label = "Achievement ID", placeholder = "e.g., speed_demon", required = true }
                })
                if input and input[1] and input[2] then
                    TriggerServerEvent('admin:grantAchievement', tonumber(input[1]), input[2])
                end
            end
        }
    }
    
    lib.registerContext({
        id = "admin_driver_menu",
        title = "👥 Driver Management",
        options = options
    })
    lib.showContext("admin_driver_menu")
end)

-- ===============================================
-- EMERGENCY ORDERS MENU
-- ===============================================
RegisterNetEvent('admin:openEmergencyMenu')
AddEventHandler('admin:openEmergencyMenu', function()
    local options = {
        {
            title = "← Back to Admin Panel",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerServerEvent('supply:requestAdminMenu')
            end
        },
        {
            title = "🚨 Create Critical Emergency",
            description = "Create highest priority emergency order",
            icon = "fas fa-exclamation-triangle",
            onSelect = function()
                local input = lib.inputDialog("Create Critical Emergency", {
                    { type = "number", label = "Restaurant ID", placeholder = "Enter restaurant ID", min = 1, required = true },
                    { type = "input", label = "Ingredient", placeholder = "e.g., reign_packed_groundchicken", required = true }
                })
                if input and input[1] and input[2] then
                    ExecuteCommand('supply emergency create ' .. input[1] .. ' ' .. input[2] .. ' critical')
                end
            end
        },
        {
            title = "⚠️ Create Urgent Emergency",
            description = "Create medium priority emergency order",
            icon = "fas fa-exclamation",
            onSelect = function()
                local input = lib.inputDialog("Create Urgent Emergency", {
                    { type = "number", label = "Restaurant ID", placeholder = "Enter restaurant ID", min = 1, required = true },
                    { type = "input", label = "Ingredient", placeholder = "e.g., reign_packed_groundchicken", required = true }
                })
                if input and input[1] and input[2] then
                    ExecuteCommand('supply emergency create ' .. input[1] .. ' ' .. input[2] .. ' urgent')
                end
            end
        },
        {
            title = "📦 Create Standard Emergency",
            description = "Create standard priority emergency order",
            icon = "fas fa-box",
            onSelect = function()
                local input = lib.inputDialog("Create Standard Emergency", {
                    { type = "number", label = "Restaurant ID", placeholder = "Enter restaurant ID", min = 1, required = true },
                    { type = "input", label = "Ingredient", placeholder = "e.g., reign_packed_groundchicken", required = true }
                })
                if input and input[1] and input[2] then
                    ExecuteCommand('supply emergency create ' .. input[1] .. ' ' .. input[2] .. ' emergency')
                end
            end
        },
        {
            title = "🗑️ Clear All Emergency Orders",
            description = "Remove all active emergency orders",
            icon = "fas fa-trash",
            onSelect = function()
                lib.alertDialog({
                    header = "⚠️ Clear All Emergency Orders",
                    content = "This will clear ALL active emergency orders. Are you sure?",
                    centered = true,
                    cancel = true,
                    labels = {
                        confirm = "Clear All",
                        cancel = "Cancel"
                    }
                }):next(function(confirmed)
                    if confirmed then
                        ExecuteCommand('supply emergency clear')
                    end
                end)
            end
        },
        {
            title = "📋 View Active Emergencies",
            description = "See all current emergency orders",
            icon = "fas fa-list",
            onSelect = function()
                TriggerServerEvent('emergency:getActiveOrders')
            end
        }
    }
    
    lib.registerContext({
        id = "admin_emergency_menu",
        title = "🚛 Emergency Management",
        options = options
    })
    lib.showContext("admin_emergency_menu")
end)

-- ===============================================
-- SYSTEM TOOLS MENU
-- ===============================================
RegisterNetEvent('admin:openSystemMenu')
AddEventHandler('admin:openSystemMenu', function()
    local options = {
        {
            title = "← Back to Admin Panel",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerServerEvent('supply:requestAdminMenu')
            end
        },
        {
            title = "🔄 Reload Systems",
            description = "Restart market and alert systems",
            icon = "fas fa-sync",
            onSelect = function()
                lib.alertDialog({
                    header = "🔄 Reload Systems",
                    content = "This will restart the market pricing and stock alert systems. Continue?",
                    centered = true,
                    cancel = true,
                    labels = {
                        confirm = "Reload",
                        cancel = "Cancel"
                    }
                }):next(function(confirmed)
                    if confirmed then
                        ExecuteCommand('supply reload')
                    end
                end)
            end
        },
        {
            title = "📊 Export Analytics",
            description = "Export system data for analysis",
            icon = "fas fa-download",
            onSelect = function()
                ExecuteCommand('supply export analytics')
            end
        },
        {
            title = "🗑️ Reset Leaderboards",
            description = "Clear all leaderboard data",
            icon = "fas fa-eraser",
            onSelect = function()
                lib.alertDialog({
                    header = "⚠️ Reset Leaderboards",
                    content = "This will permanently delete ALL leaderboard data. This action cannot be undone.",
                    centered = true,
                    cancel = true,
                    labels = {
                        confirm = "Reset All",
                        cancel = "Cancel"
                    }
                }):next(function(confirmed)
                    if confirmed then
                        ExecuteCommand('supply reset leaderboard')
                    end
                end)
            end
        },
        {
            title = "📈 Reset Market Data",
            description = "Clear all market history and pricing",
            icon = "fas fa-chart-line",
            onSelect = function()
                lib.alertDialog({
                    header = "⚠️ Reset Market Data",
                    content = "This will permanently delete ALL market history and reset prices. This action cannot be undone.",
                    centered = true,
                    cancel = true,
                    labels = {
                        confirm = "Reset Market",
                        cancel = "Cancel"
                    }
                }):next(function(confirmed)
                    if confirmed then
                        ExecuteCommand('supply reset market')
                    end
                end)
            end
        },
        {
            title = "🛠️ Database Maintenance",
            description = "Optimize database performance",
            icon = "fas fa-database",
            onSelect = function()
                TriggerServerEvent('admin:databaseMaintenance')
            end
        }
    }
    
    lib.registerContext({
        id = "admin_system_menu",
        title = "⚙️ System Tools",
        options = options
    })
    lib.showContext("admin_system_menu")
end)

-- ===============================================
-- ANALYTICS MENU
-- ===============================================
RegisterNetEvent('admin:openAnalyticsMenu')
AddEventHandler('admin:openAnalyticsMenu', function()
    local options = {
        {
            title = "← Back to Admin Panel",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerServerEvent('supply:requestAdminMenu')
            end
        },
        {
            title = "📊 System Statistics",
            description = "View comprehensive system stats",
            icon = "fas fa-chart-bar",
            onSelect = function()
                ExecuteCommand('supply stats')
            end
        },
        {
            title = "💰 Revenue Analytics",
            description = "View financial performance data",
            icon = "fas fa-dollar-sign",
            onSelect = function()
                TriggerServerEvent('admin:getRevenueAnalytics')
            end
        },
        {
            title = "🚛 Delivery Performance",
            description = "Analyze delivery efficiency metrics",
            icon = "fas fa-truck",
            onSelect = function()
                TriggerServerEvent('admin:getDeliveryAnalytics')
            end
        },
        {
            title = "👥 Player Engagement",
            description = "View player activity and retention",
            icon = "fas fa-users",
            onSelect = function()
                TriggerServerEvent('admin:getEngagementAnalytics')
            end
        },
        {
            title = "📈 Market Performance",
            description = "Analyze market dynamics and trends",
            icon = "fas fa-chart-line",
            onSelect = function()
                TriggerServerEvent('admin:getMarketAnalytics')
            end
        }
    }
    
    lib.registerContext({
        id = "admin_analytics_menu",
        title = "📊 Analytics Dashboard",
        options = options
    })
    lib.showContext("admin_analytics_menu")
end)

-- ===============================================
-- AUTO-RESET FUNCTIONS
-- ===============================================

-- Auto-reset on resource restart
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        -- Small delay to ensure everything is loaded
        Citizen.SetTimeout(1000, function()
            -- Check if player was in middle of delivery and auto-reset
            local playerPed = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(playerPed, false)
            
            if vehicle ~= 0 then
                local plate = GetVehicleNumberPlateText(vehicle)
                if string.find(plate, "SUPPLY") or string.find(plate, "DELIV") then
                    -- Player was in delivery vehicle, auto-reset
                    print("[SUPPLY RESET] Auto-reset triggered due to resource restart")
                    TriggerEvent('supply:forceJobReset')
                end
            end
        end)
    end
end)

-- Reset on job change (if player changes jobs while in delivery)
RegisterNetEvent('QBCore:Client:OnJobUpdate')
AddEventHandler('QBCore:Client:OnJobUpdate', function(JobInfo)
    -- Check if player left warehouse job
    local hasWarehouseAccess = false
    for _, job in ipairs(Config.Jobs.warehouse) do
        if JobInfo.name == job then
            hasWarehouseAccess = true
            break
        end
    end
    
    if not hasWarehouseAccess then
        -- Player left warehouse job, clean up any delivery state
        local playerPed = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        
        if vehicle ~= 0 then
            local plate = GetVehicleNumberPlateText(vehicle)
            if string.find(plate, "SUPPLY") or string.find(plate, "DELIV") then
                print("[SUPPLY RESET] Auto-reset triggered due to job change")
                TriggerEvent('supply:forceJobReset')
            end
        end
    end
end)

-- ===============================================
-- QUICK ADMIN COMMANDS
-- ===============================================

-- Quick admin access
RegisterCommand('supplyadmin', function()
    TriggerEvent('supply:openAdminMenu')
end, false)

-- Quick job reset menu
RegisterCommand('supplyreset', function()
    TriggerEvent('admin:openJobResetMenu')
end, false)

-- Optional keybind for quick admin access
-- RegisterKeyMapping('supplyadmin', 'Open Supply Chain Admin', 'keyboard', 'F12')