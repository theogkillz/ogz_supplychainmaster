local QBCore = exports['qb-core']:GetCoreObject()

local convoyTestVehicles = {}
local spawnMarkers = {}
local showingMarkers = false
local isSpawning = false
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
            title = "🚛 Convoy Testing Tools",
            description = "Test convoy vehicle spawn positions",
            icon = "fas fa-truck-moving",
            onSelect = function()
                TriggerEvent('admin:openConvoyTestMenu')
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
                local confirmed = lib.alertDialog({
                    header = "🔄 Reset Your Job",
                    content = "This will reset your supply chain job state. Continue?",
                    centered = true,
                    cancel = true
                })
                if confirmed == 'confirm' then
                    ExecuteCommand('supplyjobreset')
                end
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
                    local confirmed = lib.alertDialog({
                        header = "⚠️ Confirm Job Reset",
                        content = "This will reset the supply chain job for player ID: " .. input[1],
                        centered = true,
                        cancel = true
                    })
                    if confirmed == 'confirm' then
                        ExecuteCommand('supplyjobreset ' .. input[1])
                    end
                end
            end
        },
        {
            title = "🌐 Mass Reset All Players",
            description = "Reset ALL online players (SUPERADMIN ONLY)",
            icon = "fas fa-users-cog",
            onSelect = function()
                local confirmed = lib.alertDialog({
                    header = "⚠️ MASS RESET WARNING",
                    content = "This will reset the supply chain job for ALL online players. This action cannot be undone!",
                    centered = true,
                    cancel = true
                })
                if confirmed == 'confirm' then
                    ExecuteCommand('supplyjobmassreset')
                end
            end
        },
        {
            title = "🚨 Emergency System Restart",
            description = "Full system restart (SUPERADMIN ONLY)",
            icon = "fas fa-exclamation-triangle",
            onSelect = function()
                local confirmed = lib.alertDialog({
                    header = "🚨 EMERGENCY RESTART WARNING",
                    content = "This will restart the entire supply chain system for all players. Use only if system is completely broken!",
                    centered = true,
                    cancel = true
                })
                if confirmed == 'confirm' then
                    ExecuteCommand('supplyemergencyrestart')
                end
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
                TriggerServerEvent('admin:getMarketOverview')
            end
        },
        {
            title = "🚨 Create Shortage Event",
            description = "Trigger a shortage for specific ingredient",
            icon = "fas fa-exclamation-triangle",
            onSelect = function()
                -- Get available ingredients from config
                local ingredients = {}
                if Config.Ingredients then
                    for name, data in pairs(Config.Ingredients) do
                        table.insert(ingredients, {
                            value = name,
                            label = data.label or name
                        })
                    end
                end
                
                local input = lib.inputDialog("Create Shortage Event", {
                    { 
                        type = "select", 
                        label = "Select Ingredient", 
                        options = ingredients,
                        required = true 
                    }
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
                -- Get available ingredients from config
                local ingredients = {}
                if Config.Ingredients then
                    for name, data in pairs(Config.Ingredients) do
                        table.insert(ingredients, {
                            value = name,
                            label = data.label or name
                        })
                    end
                end
                
                local input = lib.inputDialog("Create Surplus Event", {
                    { 
                        type = "select", 
                        label = "Select Ingredient", 
                        options = ingredients,
                        required = true 
                    }
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
                local confirmed = lib.alertDialog({
                    header = "⚠️ Confirm Market Reset",
                    content = "This will reset ALL market prices to base values. This action cannot be undone.",
                    centered = true,
                    cancel = true
                })
                if confirmed == 'confirm' then
                    ExecuteCommand('supply market reset')
                end
            end
        },
        {
            title = "📈 Price History",
            description = "View historical pricing data",
            icon = "fas fa-history",
            onSelect = function()
                -- Get available ingredients from config
                local ingredients = {}
                if Config.Ingredients then
                    for name, data in pairs(Config.Ingredients) do
                        table.insert(ingredients, {
                            value = name,
                            label = data.label or name
                        })
                    end
                end
                
                local input = lib.inputDialog("View Price History", {
                    { 
                        type = "select", 
                        label = "Select Ingredient", 
                        options = ingredients,
                        required = true 
                    }
                })
                if input and input[1] then
                    TriggerServerEvent('admin:getPriceHistory', input[1])
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
                TriggerServerEvent('admin:getStockOverview')
            end
        },
        {
            title = "🚨 Critical Alerts Only",
            description = "Show only critical stock situations",
            icon = "fas fa-exclamation-circle",
            onSelect = function()
                TriggerServerEvent('admin:getCriticalAlerts')
            end
        },
        {
            title = "📈 Usage Trends",
            description = "Analyze consumption patterns",
            icon = "fas fa-trending-up",
            onSelect = function()
                TriggerServerEvent('admin:getUsageTrends')
            end
        },
        {
            title = "📦 Manual Stock Adjustment",
            description = "Manually adjust warehouse stock",
            icon = "fas fa-edit",
            onSelect = function()
                -- Get available ingredients from config
                local ingredients = {}
                if Config.Ingredients then
                    for name, data in pairs(Config.Ingredients) do
                        table.insert(ingredients, {
                            value = name,
                            label = data.label or name
                        })
                    end
                end
                
                local input = lib.inputDialog("Manual Stock Adjustment", {
                    { 
                        type = "select", 
                        label = "Select Ingredient", 
                        options = ingredients,
                        required = true 
                    },
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
                TriggerServerEvent('admin:getDriverLeaderboards')
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
                    local confirmed = lib.alertDialog({
                        header = "⚠️ Confirm Stats Reset",
                        content = "This will permanently delete all statistics for this player. This action cannot be undone.",
                        centered = true,
                        cancel = true
                    })
                    if confirmed == 'confirm' then
                        ExecuteCommand('supply reset stats ' .. input[1])
                    end
                end
            end
        },
        {
            title = "🏅 Grant Achievement",
            description = "Manually grant achievement to player",
            icon = "fas fa-medal",
            onSelect = function()
                -- Get achievement options from config
                local achievements = {
                    { value = "rookie_runner", label = "Rookie Runner (10 deliveries)" },
                    { value = "supply_specialist", label = "Supply Specialist (50 deliveries)" },
                    { value = "logistics_expert", label = "Logistics Expert (250 deliveries)" },
                    { value = "elite_transporter", label = "Elite Transporter (1000 deliveries)" },
                    { value = "speed_demon", label = "Speed Demon (Fast deliveries)" },
                    { value = "perfectionist", label = "Perfectionist (Perfect deliveries)" },
                    { value = "team_player", label = "Team Player (Team deliveries)" },
                    { value = "money_maker", label = "Money Maker (High earnings)" }
                }
                
                local input = lib.inputDialog("Grant Achievement", {
                    { type = "number", label = "Player ID", placeholder = "Enter player server ID", min = 1, required = true },
                    { 
                        type = "select", 
                        label = "Select Achievement", 
                        options = achievements,
                        required = true 
                    }
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
    -- Get available ingredients from config
    local ingredients = {}
    if Config.Ingredients then
        for name, data in pairs(Config.Ingredients) do
            table.insert(ingredients, {
                value = name,
                label = data.label or name
            })
        end
    end
    
    -- Get restaurant options
    local restaurants = {}
    if Config.Restaurants then
        for id, data in pairs(Config.Restaurants) do
            table.insert(restaurants, {
                value = tostring(id),
                label = data.label or ("Restaurant " .. id)
            })
        end
    end
    
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
                    { 
                        type = "select", 
                        label = "Select Restaurant", 
                        options = restaurants,
                        required = true 
                    },
                    { 
                        type = "select", 
                        label = "Select Ingredient", 
                        options = ingredients,
                        required = true 
                    }
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
                    { 
                        type = "select", 
                        label = "Select Restaurant", 
                        options = restaurants,
                        required = true 
                    },
                    { 
                        type = "select", 
                        label = "Select Ingredient", 
                        options = ingredients,
                        required = true 
                    }
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
                    { 
                        type = "select", 
                        label = "Select Restaurant", 
                        options = restaurants,
                        required = true 
                    },
                    { 
                        type = "select", 
                        label = "Select Ingredient", 
                        options = ingredients,
                        required = true 
                    }
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
                local confirmed = lib.alertDialog({
                    header = "⚠️ Clear All Emergency Orders",
                    content = "This will clear ALL active emergency orders. Are you sure?",
                    centered = true,
                    cancel = true
                })
                if confirmed == 'confirm' then
                    ExecuteCommand('supply emergency clear')
                end
            end
        },
        {
            title = "📋 View Active Emergencies",
            description = "See all current emergency orders",
            icon = "fas fa-list",
            onSelect = function()
                TriggerServerEvent('admin:getActiveEmergencies')
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
                local confirmed = lib.alertDialog({
                    header = "🔄 Reload Systems",
                    content = "This will restart the market pricing and stock alert systems. Continue?",
                    centered = true,
                    cancel = true
                })
                if confirmed == 'confirm' then
                    ExecuteCommand('supply reload')
                end
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
                local confirmed = lib.alertDialog({
                    header = "⚠️ Reset Leaderboards",
                    content = "This will permanently delete ALL leaderboard data. This action cannot be undone.",
                    centered = true,
                    cancel = true
                })
                if confirmed == 'confirm' then
                    ExecuteCommand('supply reset leaderboard')
                end
            end
        },
        {
            title = "📈 Reset Market Data",
            description = "Clear all market history and pricing",
            icon = "fas fa-chart-line",
            onSelect = function()
                local confirmed = lib.alertDialog({
                    header = "⚠️ Reset Market Data",
                    content = "This will permanently delete ALL market history and reset prices. This action cannot be undone.",
                    centered = true,
                    cancel = true
                })
                if confirmed == 'confirm' then
                    ExecuteCommand('supply reset market')
                end
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
-- CONVOY TESTING MENU
-- ===============================================
RegisterNetEvent('admin:openConvoyTestMenu')
AddEventHandler('admin:openConvoyTestMenu', function()
    local options = {
        {
            title = "← Back to Admin Panel",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerServerEvent('supply:requestAdminMenu')
            end
        },
        {
            title = "🚛 Spawn All Vehicles",
            description = "Spawn all convoy vehicles at once",
            icon = "fas fa-truck-loading",
            onSelect = function()
                local warehouses = {}
                for id, _ in ipairs(Config.Warehouses) do
                    table.insert(warehouses, {
                        value = tostring(id),
                        label = "Warehouse " .. id .. (id == 2 and " (Import Center)" or "")
                    })
                end
                
                local input = lib.inputDialog("Spawn All Convoy Vehicles", {
                    { 
                        type = "select", 
                        label = "Select Warehouse", 
                        options = warehouses,
                        required = true 
                    }
                })
                if input and input[1] then
                    TriggerEvent('convoy:spawnAll', tonumber(input[1]))
                end
            end
        },
        {
            title = "⏱️ Sequential Spawn",
            description = "Spawn vehicles one by one with delay",
            icon = "fas fa-stopwatch",
            onSelect = function()
                local warehouses = {}
                for id, _ in ipairs(Config.Warehouses) do
                    table.insert(warehouses, {
                        value = tostring(id),
                        label = "Warehouse " .. id .. (id == 2 and " (Import Center)" or "")
                    })
                end
                
                local input = lib.inputDialog("Sequential Convoy Spawn", {
                    { 
                        type = "select", 
                        label = "Select Warehouse", 
                        options = warehouses,
                        required = true 
                    },
                    { 
                        type = "number", 
                        label = "Delay (milliseconds)", 
                        placeholder = "2000",
                        default = 2000,
                        min = 500,
                        max = 10000,
                        required = true 
                    }
                })
                if input and input[1] and input[2] then
                    TriggerEvent('convoy:spawnSequential', tonumber(input[1]), tonumber(input[2]))
                end
            end
        },
        {
            title = "🎯 Spawn Single Vehicle",
            description = "Test specific spawn point",
            icon = "fas fa-map-pin",
            onSelect = function()
                local warehouses = {}
                for id, _ in ipairs(Config.Warehouses) do
                    table.insert(warehouses, {
                        value = tostring(id),
                        label = "Warehouse " .. id
                    })
                end
                
                local input = lib.inputDialog("Spawn Single Vehicle", {
                    { 
                        type = "select", 
                        label = "Select Warehouse", 
                        options = warehouses,
                        required = true 
                    },
                    { 
                        type = "number", 
                        label = "Spawn Point Number", 
                        placeholder = "1-12",
                        min = 1,
                        max = 20,
                        required = true 
                    }
                })
                if input and input[1] and input[2] then
                    TriggerEvent('convoy:spawnSingle', tonumber(input[1]), tonumber(input[2]))
                end
            end
        },
        {
            title = "📍 Toggle Spawn Markers",
            description = "Show/hide 3D markers at spawn points",
            icon = "fas fa-map-marked-alt",
            onSelect = function()
                local warehouses = {}
                for id, _ in ipairs(Config.Warehouses) do
                    table.insert(warehouses, {
                        value = tostring(id),
                        label = "Warehouse " .. id
                    })
                end
                
                local input = lib.inputDialog("Toggle Spawn Markers", {
                    { 
                        type = "select", 
                        label = "Select Warehouse", 
                        options = warehouses,
                        required = true 
                    }
                })
                if input and input[1] then
                    TriggerEvent('convoy:toggleMarkers', tonumber(input[1]))
                end
            end
        },
        {
            title = "🧹 Clear All Vehicles",
            description = "Remove all test convoy vehicles",
            icon = "fas fa-broom",
            onSelect = function()
                local confirmed = lib.alertDialog({
                    header = "Clear Test Vehicles",
                    content = "Remove all spawned test vehicles?",
                    centered = true,
                    cancel = true
                })
                if confirmed == 'confirm' then
                    TriggerEvent('convoy:clearAll')
                end
            end
        },
        {
            title = "📊 Show Spawn Info",
            description = "Print spawn point details to console",
            icon = "fas fa-info-circle",
            onSelect = function()
                local warehouses = {}
                for id, _ in ipairs(Config.Warehouses) do
                    table.insert(warehouses, {
                        value = tostring(id),
                        label = "Warehouse " .. id
                    })
                end
                
                local input = lib.inputDialog("Show Spawn Info", {
                    { 
                        type = "select", 
                        label = "Select Warehouse", 
                        options = warehouses,
                        required = true 
                    }
                })
                if input and input[1] then
                    TriggerEvent('convoy:showInfo', tonumber(input[1]))
                end
            end
        }
    }
    
    lib.registerContext({
        id = "admin_convoy_test_menu",
        title = "🚛 Convoy Testing Tools",
        options = options
    })
    lib.showContext("admin_convoy_test_menu")
end)

-- ===============================================
-- RESULT DISPLAY HANDLERS
-- ===============================================

-- Display market overview
RegisterNetEvent('admin:displayMarketOverview')
AddEventHandler('admin:displayMarketOverview', function(data)
    if not data then return end
    
    local message = "📈 **Market Overview**\n\n"
    
    for ingredient, info in pairs(data) do
        message = message .. string.format(
            "**%s**\n• Base: $%.2f\n• Current: $%.2f (%.1fx)\n• Stock: %d units\n• Trend: %s\n\n",
            info.label or ingredient,
            info.basePrice or 0,
            info.currentPrice or 0,
            info.multiplier or 1.0,
            info.stock or 0,
            info.trend or "stable"
        )
    end
    
    lib.notify({
        title = '📊 Market Overview',
        description = message,
        type = 'info',
        duration = 20000,
        position = 'top',
        markdown = true
    })
end)

-- Display stock overview
RegisterNetEvent('admin:displayStockOverview')
AddEventHandler('admin:displayStockOverview', function(data)
    if not data then return end
    
    local message = "📦 **Stock Overview**\n\n"
    
    for ingredient, info in pairs(data) do
        local alertEmoji = info.critical and "🚨" or info.low and "⚠️" or "✅"
        message = message .. string.format(
            "%s **%s**\n• Warehouse: %d units\n• Restaurant Total: %d units\n• Daily Usage: %.1f units\n• Days Remaining: %.1f\n\n",
            alertEmoji,
            info.label or ingredient,
            info.warehouseStock or 0,
            info.restaurantStock or 0,
            info.dailyUsage or 0,
            info.daysRemaining or 999
        )
    end
    
    lib.notify({
        title = '📦 Stock Overview',
        description = message,
        type = 'info',
        duration = 20000,
        position = 'top',
        markdown = true
    })
end)

-- Display driver analytics
RegisterNetEvent('admin:displayDriverAnalytics')
AddEventHandler('admin:displayDriverAnalytics', function(data)
    if not data then return end
    
    local message = string.format(
        "👥 **Driver Analytics**\n\n**Today's Performance:**\n• Active Drivers: %d\n• Total Deliveries: %d\n• Average Per Driver: %.1f\n• Total Revenue: $%s\n\n**All-Time Stats:**\n• Total Drivers: %d\n• Total Deliveries: %d\n• Perfect Deliveries: %d\n• Team Deliveries: %d",
        data.todayActive or 0,
        data.todayDeliveries or 0,
        data.todayAverage or 0,
        lib.math.groupdigits(data.todayRevenue or 0),
        data.totalDrivers or 0,
        data.totalDeliveries or 0,
        data.perfectDeliveries or 0,
        data.teamDeliveries or 0
    )
    
    lib.notify({
        title = '📊 Driver Analytics',
        description = message,
        type = 'info',
        duration = 20000,
        position = 'top',
        markdown = true
    })
end)

-- Display active emergencies
RegisterNetEvent('admin:displayActiveEmergencies')
AddEventHandler('admin:displayActiveEmergencies', function(data)
    if not data or #data == 0 then
        lib.notify({
            title = '📋 Active Emergencies',
            description = 'No active emergency orders.',
            type = 'info',
            duration = 5000
        })
        return
    end
    
    local message = "🚨 **Active Emergency Orders**\n\n"
    
    for _, emergency in ipairs(data) do
        local priorityEmoji = emergency.priority == "critical" and "🔴" or emergency.priority == "urgent" and "🟡" or "🟢"
        message = message .. string.format(
            "%s **%s** - %s\n• Restaurant: %s\n• Quantity: %d units\n• Bonus: %.1fx\n• Time Remaining: %d mins\n\n",
            priorityEmoji,
            emergency.priority:upper(),
            emergency.ingredient,
            emergency.restaurant,
            emergency.quantity,
            emergency.bonus,
            emergency.timeRemaining
        )
    end
    
    lib.notify({
        title = '🚛 Active Emergencies',
        description = message,
        type = 'info',
        duration = 15000,
        position = 'top',
        markdown = true
    })
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

-- Spawn all convoy vehicles at once
RegisterNetEvent('convoy:spawnAll')
AddEventHandler('convoy:spawnAll', function(warehouseId)
    if isSpawning then
        lib.notify({
            title = 'Already Spawning',
            description = 'Wait for current spawn to complete',
            type = 'error',
            duration = 3000
        })
        return
    end
    
    isSpawning = true
    local warehouse = Config.Warehouses[warehouseId]
    if not warehouse or not warehouse.convoySpawnPoints then
        lib.notify({
            title = 'Invalid Warehouse',
            description = 'Warehouse configuration not found',
            type = 'error',
            duration = 5000
        })
        isSpawning = false
        return
    end
    
    local spawnPoints = warehouse.convoySpawnPoints
    local vehicleModel = warehouse.vehicle.model
    
    -- Clear existing vehicles first
    TriggerEvent('convoy:clearAll')
    
    lib.notify({
        title = 'Spawning Convoy',
        description = string.format('Spawning %d vehicles at Warehouse %d', #spawnPoints, warehouseId),
        type = 'info',
        duration = 5000
    })
    
    -- Request model
    local model = GetHashKey(vehicleModel)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(10)
    end
    
    -- Spawn at each point
    for i, point in ipairs(spawnPoints) do
        if point.position then
            local vehicle = CreateVehicle(model, 
                point.position.x, point.position.y, point.position.z, 
                point.position.w or warehouse.heading, 
                true, false)
            
            SetEntityAsMissionEntity(vehicle, true, true)
            SetVehicleOnGroundProperly(vehicle)
            
            -- Color code by priority
            local colors = {
                [1] = {r=255, g=0, b=0},      -- Red for priority 1
                [2] = {r=255, g=165, b=0},    -- Orange for priority 2
                [3] = {r=255, g=255, b=0},    -- Yellow for priority 3
                [4] = {r=0, g=255, b=0},      -- Green for priority 4
                [5] = {r=0, g=255, b=255},    -- Cyan for priority 5
            }
            
            local color = colors[math.min(point.priority or 1, 5)] or colors[5]
            SetVehicleCustomPrimaryColour(vehicle, color.r, color.g, color.b)
            SetVehicleCustomSecondaryColour(vehicle, color.r, color.g, color.b)
            
            -- Add text above vehicle
            local blip = AddBlipForEntity(vehicle)
            SetBlipSprite(blip, 1)
            SetBlipColour(blip, point.priority <= 5 and point.priority or 5)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString("P" .. point.priority .. " #" .. i)
            EndTextCommandSetBlipName(blip)
            
            table.insert(convoyTestVehicles, {
                vehicle = vehicle,
                blip = blip,
                point = i,
                priority = point.priority
            })
        end
    end
    
    isSpawning = false
    
    lib.notify({
        title = 'Convoy Spawned',
        description = string.format('%d vehicles spawned successfully', #convoyTestVehicles),
        type = 'success',
        duration = 5000
    })
    
    -- Log action
    TriggerServerEvent('convoy:logAction', 'spawn_all', {
        warehouseId = warehouseId,
        vehicleCount = #convoyTestVehicles
    })
end)

-- Spawn vehicles sequentially
RegisterNetEvent('convoy:spawnSequential')
AddEventHandler('convoy:spawnSequential', function(warehouseId, delay)
    if isSpawning then
        lib.notify({
            title = 'Already Spawning',
            description = 'Wait for current spawn to complete',
            type = 'error',
            duration = 3000
        })
        return
    end
    
    isSpawning = true
    local warehouse = Config.Warehouses[warehouseId]
    if not warehouse or not warehouse.convoySpawnPoints then
        lib.notify({
            title = 'Invalid Warehouse',
            description = 'Warehouse configuration not found',
            type = 'error',
            duration = 5000
        })
        isSpawning = false
        return
    end
    
    local spawnPoints = warehouse.convoySpawnPoints
    local vehicleModel = warehouse.vehicle.model
    
    -- Clear existing vehicles first
    TriggerEvent('convoy:clearAll')
    
    lib.notify({
        title = 'Sequential Spawn',
        description = string.format('Spawning %d vehicles with %dms delay', #spawnPoints, delay),
        type = 'info',
        duration = 5000
    })
    
    -- Request model
    local model = GetHashKey(vehicleModel)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(10)
    end
    
    -- Spawn sequentially
    Citizen.CreateThread(function()
        for i, point in ipairs(spawnPoints) do
            if point.position then
                -- Show which point is being spawned
                lib.notify({
                    title = string.format('Spawning #%d', i),
                    description = string.format('Priority %d vehicle at point %d', point.priority, i),
                    type = 'info',
                    duration = 2000
                })
                
                local vehicle = CreateVehicle(model, 
                    point.position.x, point.position.y, point.position.z, 
                    point.position.w or warehouse.heading, 
                    true, false)
                
                SetEntityAsMissionEntity(vehicle, true, true)
                SetVehicleOnGroundProperly(vehicle)
                
                -- Flash the vehicle
                SetVehicleIndicatorLights(vehicle, 1, true)
                SetVehicleIndicatorLights(vehicle, 0, true)
                
                -- Color by priority
                local colors = {
                    [1] = {r=255, g=0, b=0},
                    [2] = {r=255, g=165, b=0},
                    [3] = {r=255, g=255, b=0},
                    [4] = {r=0, g=255, b=0},
                    [5] = {r=0, g=255, b=255},
                }
                
                local color = colors[math.min(point.priority or 1, 5)] or colors[5]
                SetVehicleCustomPrimaryColour(vehicle, color.r, color.g, color.b)
                
                local blip = AddBlipForEntity(vehicle)
                SetBlipSprite(blip, 1)
                SetBlipColour(blip, point.priority <= 5 and point.priority or 5)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString("P" .. point.priority .. " #" .. i)
                EndTextCommandSetBlipName(blip)
                
                table.insert(convoyTestVehicles, {
                    vehicle = vehicle,
                    blip = blip,
                    point = i,
                    priority = point.priority
                })
                
                -- Wait before next spawn
                Wait(delay)
                
                -- Turn off indicators
                SetVehicleIndicatorLights(vehicle, 1, false)
                SetVehicleIndicatorLights(vehicle, 0, false)
            end
        end
        
        isSpawning = false
        
        lib.notify({
            title = 'Sequential Spawn Complete',
            description = string.format('%d vehicles spawned', #convoyTestVehicles),
            type = 'success',
            duration = 5000
        })
    end)
end)

-- Clear all test vehicles
RegisterNetEvent('convoy:clearAll')
AddEventHandler('convoy:clearAll', function()
    local count = 0
    
    for _, data in ipairs(convoyTestVehicles) do
        if DoesEntityExist(data.vehicle) then
            DeleteVehicle(data.vehicle)
            count = count + 1
        end
        if data.blip and DoesBlipExist(data.blip) then
            RemoveBlip(data.blip)
        end
    end
    
    convoyTestVehicles = {}
    
    if count > 0 then
        lib.notify({
            title = 'Vehicles Cleared',
            description = string.format('%d test vehicles removed', count),
            type = 'success',
            duration = 3000
        })
    end
end)

-- Toggle spawn point markers
RegisterNetEvent('convoy:toggleMarkers')
AddEventHandler('convoy:toggleMarkers', function(warehouseId)
    showingMarkers = not showingMarkers
    
    if showingMarkers then
        local warehouse = Config.Warehouses[warehouseId]
        if not warehouse or not warehouse.convoySpawnPoints then
            lib.notify({
                title = 'Invalid Warehouse',
                description = 'Warehouse configuration not found',
                type = 'error',
                duration = 5000
            })
            showingMarkers = false
            return
        end
        
        local spawnPoints = warehouse.convoySpawnPoints
        
        lib.notify({
            title = 'Markers Enabled',
            description = 'Showing spawn point markers',
            type = 'info',
            duration = 3000
        })
        
        -- Create marker thread
        Citizen.CreateThread(function()
            while showingMarkers do
                for i, point in ipairs(spawnPoints) do
                    if point.position then
                        -- Color by priority
                        local r, g, b = 255, 255, 255
                        if point.priority == 1 then
                            r, g, b = 255, 0, 0
                        elseif point.priority == 2 then
                            r, g, b = 255, 165, 0
                        elseif point.priority == 3 then
                            r, g, b = 255, 255, 0
                        elseif point.priority == 4 then
                            r, g, b = 0, 255, 0
                        elseif point.priority == 5 then
                            r, g, b = 0, 255, 255
                        end
                        
                        DrawMarker(
                            1, -- Type
                            point.position.x, point.position.y, point.position.z - 1.0,
                            0.0, 0.0, 0.0, -- Direction
                            0.0, 0.0, 0.0, -- Rotation
                            5.0, 5.0, 2.0, -- Scale
                            r, g, b, 100, -- Color
                            false, false, 2, false, nil, nil, false
                        )
                        
                        -- Draw text
                        local onScreen, _x, _y = World3dToScreen2d(point.position.x, point.position.y, point.position.z + 1.0)
                        if onScreen then
                            SetTextScale(0.4, 0.4)
                            SetTextFont(4)
                            SetTextProportional(1)
                            SetTextColour(255, 255, 255, 255)
                            SetTextOutline()
                            SetTextEntry("STRING")
                            AddTextComponentString(string.format("P%d #%d", point.priority, i))
                            DrawText(_x, _y)
                        end
                    end
                end
                Wait(0)
            end
        end)
    else
        lib.notify({
            title = 'Markers Disabled',
            description = 'Spawn point markers hidden',
            type = 'info',
            duration = 3000
        })
    end
end)

-- Show spawn point info
RegisterNetEvent('convoy:showInfo')
AddEventHandler('convoy:showInfo', function(warehouseId)
    local warehouse = Config.Warehouses[warehouseId]
    if not warehouse or not warehouse.convoySpawnPoints then
        lib.notify({
            title = 'Invalid Warehouse',
            description = 'Warehouse configuration not found',
            type = 'error',
            duration = 5000
        })
        return
    end
    
    local spawnPoints = warehouse.convoySpawnPoints
    
    print("\n=== CONVOY SPAWN POINTS - WAREHOUSE " .. warehouseId .. " ===")
    print("Total Points: " .. #spawnPoints)
    print("Vehicle Model: " .. warehouse.vehicle.model)
    print("\nPoint Details:")
    
    for i, point in ipairs(spawnPoints) do
        print(string.format("#%d - Priority: %d - Pos: %.2f, %.2f, %.2f, %.2f", 
            i, 
            point.priority,
            point.position.x,
            point.position.y,
            point.position.z,
            point.position.w or warehouse.heading
        ))
    end
    
    print("=====================================\n")
    
    lib.notify({
        title = 'Info Printed',
        description = 'Check F8 console for spawn point details',
        type = 'info',
        duration = 5000
    })
end)

-- Spawn single vehicle at specific point
RegisterNetEvent('convoy:spawnSingle')
AddEventHandler('convoy:spawnSingle', function(warehouseId, pointId)
    local warehouse = Config.Warehouses[warehouseId]
    if not warehouse or not warehouse.convoySpawnPoints then
        lib.notify({
            title = 'Invalid Warehouse',
            description = 'Warehouse configuration not found',
            type = 'error',
            duration = 5000
        })
        return
    end
    
    local spawnPoints = warehouse.convoySpawnPoints
    
    if not spawnPoints[pointId] then
        lib.notify({
            title = 'Invalid Point',
            description = string.format('Point %d does not exist', pointId),
            type = 'error',
            duration = 3000
        })
        return
    end
    
    local point = spawnPoints[pointId]
    local vehicleModel = warehouse.vehicle.model
    
    -- Request model
    local model = GetHashKey(vehicleModel)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(10)
    end
    
    -- Spawn vehicle
    local vehicle = CreateVehicle(model, 
        point.position.x, point.position.y, point.position.z, 
        point.position.w or warehouse.heading, 
        true, false)
    
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleOnGroundProperly(vehicle)
    
    -- Flash to indicate spawn
    for i = 1, 3 do
        SetVehicleIndicatorLights(vehicle, 1, true)
        SetVehicleIndicatorLights(vehicle, 0, true)
        Wait(500)
        SetVehicleIndicatorLights(vehicle, 1, false)
        SetVehicleIndicatorLights(vehicle, 0, false)
        Wait(500)
    end
    
    lib.notify({
        title = 'Vehicle Spawned',
        description = string.format('Spawned at point %d (Priority %d)', pointId, point.priority),
        type = 'success',
        duration = 5000
    })
end)

-- ===============================================
-- SERVER SIDE ADDITIONS
-- Add to: server/admin/sv_admin.lua
-- ===============================================

-- Add this event handler (after the other admin events, around line 450):

-- Log convoy test actions
RegisterNetEvent('convoy:logAction')
AddEventHandler('convoy:logAction', function(action, details)
    local src = source
    
    -- Verify admin permission
    if not hasAdminPermission(src, 'moderator') then
        return
    end
    
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    print(string.format("[CONVOY TEST] %s performed: %s - %s", 
        GetPlayerName(src), action, json.encode(details)))
    
    -- Optional: Log to database if you have admin logging enabled
    if Config.AdminSystem and Config.AdminSystem.logging then
        MySQL.Async.execute([[
            INSERT INTO supply_admin_logs (admin_id, admin_name, action, details, timestamp)
            VALUES (?, ?, ?, ?, NOW())
        ]], {
            xPlayer.PlayerData.citizenid,
            GetPlayerName(src),
            "convoy_test_" .. action,
            json.encode(details)
        })
    end
end)

-- Add this command handler (after the other commands, around line 300):

-- Quick convoy test command
RegisterCommand('testconvoy', function(source, args, rawCommand)
    if source == 0 then
        print("This command must be run in-game")
        return
    end
    
    if not hasAdminPermission(source, 'moderator') then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Access Denied',
            description = 'Admin only command',
            type = 'error',
            duration = 5000
        })
        return
    end
    
    -- Open convoy test menu directly
    TriggerClientEvent('admin:openConvoyTestMenu', source)
end, false)

-- Add command suggestion
TriggerEvent('chat:addSuggestion', '/testconvoy', 'Open convoy spawn testing menu')

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