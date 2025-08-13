local QBCore = exports['qb-core']:GetCoreObject()

-- ===============================================
-- REFINED ADMIN UI SYSTEM
-- ===============================================
-- Streamlined from 50+ options to ~20 essential functions
-- Organized by use case, not feature type
-- ===============================================

local hybridTestVehicles = {} -- Changed from convoyTestVehicles
local showingMarkers = false
local isSpawning = false

-- Cache for ingredient labels
local ingredientLabels = {}

-- Helper function to get ingredient labels with caching
local function getIngredientOptions()
    if #ingredientLabels > 0 then
        return ingredientLabels
    end
    
    -- Create a unique set of ingredients from all sources
    local uniqueIngredients = {}
    local count = 0
    
    -- Get ingredients from Config.Items (restaurant items)
    if Config.Items then
        for restaurant, categories in pairs(Config.Items) do
            for category, items in pairs(categories) do
                for itemName, itemData in pairs(items) do
                    if not uniqueIngredients[itemName] then
                        uniqueIngredients[itemName] = {
                            value = itemName,
                            label = itemData.label or itemName
                        }
                        count = count + 1
                    end
                end
            end
        end
    end
    
    -- Also get ingredients from Config.ItemsFarming
    if Config.ItemsFarming then
        for category, items in pairs(Config.ItemsFarming) do
            for itemName, itemData in pairs(items) do
                if not uniqueIngredients[itemName] then
                    uniqueIngredients[itemName] = {
                        value = itemName,
                        label = itemData.label or itemName
                    }
                    count = count + 1
                end
            end
        end
    end
    
    -- Convert to array for dropdown
    for _, ingredient in pairs(uniqueIngredients) do
        table.insert(ingredientLabels, ingredient)
    end
    
    -- Sort alphabetically by label
    table.sort(ingredientLabels, function(a, b)
        return a.label < b.label
    end)
    
    print(string.format("[ADMIN] Loaded %d ingredients for dropdowns", count))
    
    return ingredientLabels
end

-- ===============================================
-- CLIENT-SIDE JOB RESET (Keep as is - it works!)
-- ===============================================
RegisterNetEvent('supply:forceJobReset')
AddEventHandler('supply:forceJobReset', function()
    local playerPed = PlayerPedId()
    
    -- 1. CLEAR ALL UI ELEMENTS
    lib.hideTextUI()
    lib.hideContext()
    
    -- 2. CLEAR DELIVERY STATES
    ClearPedTasks(playerPed)
    
    -- Remove any attached box props
    local attachedObjects = GetGamePool('CObject')
    for _, obj in pairs(attachedObjects) do
        if IsEntityAttachedToEntity(obj, playerPed) then
            DeleteObject(obj)
        end
    end
    
    -- 3. CLEAR VEHICLE STATES
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    if vehicle ~= 0 then
        local plate = GetVehicleNumberPlateText(vehicle)
        if string.find(plate, "SUPPLY") or string.find(plate, "DELIV") then
            TriggerEvent("vehiclekeys:client:RemoveKeys", plate)
            SetEntityAsMissionEntity(vehicle, true, true)
            DeleteVehicle(vehicle)
        end
    end
    
    -- 4. CLEAR TARGET ZONES
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
    local blips = GetGamePool('CBlip')
    for _, blip in pairs(blips) do
        local blipSprite = GetBlipSprite(blip)
        local blipColor = GetBlipColour(blip)
        
        if blipSprite == 1 or blipSprite == 67 or blipSprite == 501 then
            if blipColor == 2 or blipColor == 3 or blipColor == 5 then
                RemoveBlip(blip)
            end
        end
    end
    
    -- 6. CLEAR PROPS/OBJECTS
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
    SetPlayerInvincible(playerPed, false)
    SetEntityCollision(playerPed, true, true)
    FreezeEntityPosition(playerPed, false)
    
    -- Clear any stuck animations
    RequestAnimDict("move_m@confident")
    while not HasAnimDictLoaded("move_m@confident") do
        Citizen.Wait(0)
    end
    SetPedMovementClipset(playerPed, "move_m@confident", 0.25)
    
    -- 8. CLEAR WAYPOINTS
    SetWaypointOff()
    
    -- 9. NOTIFICATION
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
    
    print("[SUPPLY RESET] Client-side job reset completed")
end)

-- ===============================================
-- REFINED ADMIN MENU SYSTEM
-- ===============================================

-- Main Admin Menu Entry
RegisterNetEvent('supply:openAdminMenu')
AddEventHandler('supply:openAdminMenu', function()
    TriggerServerEvent('supply:requestAdminMenu')
end)

-- Show refined admin menu with system data
RegisterNetEvent('supply:showAdminMenu')
AddEventHandler('supply:showAdminMenu', function(systemData, adminLevel)
    local statusColor = systemData.systemStatus == 'healthy' and '🟢' or systemData.systemStatus == 'warning' and '🟡' or '🔴'
    
    -- Build menu options based on admin level
    local options = {
        {
            title = "📊 System Status",
            description = string.format(
                "%s **Status: %s** | 📋 Pending: %d | ✅ Today: %d | 👥 Active: %d",
                statusColor,
                systemData.systemStatus:gsub("^%l", string.upper),
                systemData.pendingOrders,
                systemData.dailyOrders,
                systemData.activeDrivers
            ),
            disabled = true
        }
    }
    
    -- OPERATIONS MENU (All admins)
    table.insert(options, {
        title = "📊 Operations Center",
        description = "Market events, stock management, emergency orders",
        icon = "fas fa-chart-line",
        iconColor = "#4CAF50",
        onSelect = function()
            TriggerEvent('admin:openOperationsMenu')
        end
    })
    
    -- TROUBLESHOOTING MENU (All admins)
    table.insert(options, {
        title = "🔧 Player Support",
        description = "Fix stuck states, reset jobs, player assistance",
        icon = "fas fa-wrench",
        iconColor = "#2196F3",
        onSelect = function()
            TriggerEvent('admin:openTroubleshootingMenu')
        end
    })
    
    -- ANALYTICS MENU (All admins - READ ONLY)
    table.insert(options, {
        title = "📈 Analytics Dashboard",
        description = "View system performance and statistics",
        icon = "fas fa-chart-bar",
        iconColor = "#FF9800",
        onSelect = function()
            TriggerEvent('admin:openAnalyticsMenu')
        end
    })
    
    -- SYSTEM MENU (Admin+ only)
    if adminLevel == "admin" or adminLevel == "superadmin" then
        table.insert(options, {
            title = "⚙️ System Management",
            description = "Advanced tools and dangerous operations",
            icon = "fas fa-cogs",
            iconColor = "#F44336",
            onSelect = function()
                TriggerEvent('admin:openSystemMenu', adminLevel)
            end
        })
    end
    
    -- DEV TOOLS (Superadmin only)
    if adminLevel == "superadmin" then
        table.insert(options, {
            title = "🛠️ Developer Tools",
            description = "Hybrid testing and debug utilities", -- UPDATED!
            icon = "fas fa-code",
            iconColor = "#9C27B0",
            onSelect = function()
                TriggerEvent('admin:openDevMenu')
            end
        })
    end
    
    -- Refresh button
    table.insert(options, {
        title = "🔄 Refresh",
        icon = "fas fa-sync",
        onSelect = function()
            TriggerServerEvent('supply:requestAdminMenu')
        end
    })
    
    lib.registerContext({
        id = "supply_admin_main",
        title = "🏢 Supply Chain Admin | " .. adminLevel:upper(),
        options = options
    })
    lib.showContext("supply_admin_main")
end)

-- ===============================================
-- OPERATIONS CENTER (Daily Management)
-- ===============================================
RegisterNetEvent('admin:openOperationsMenu')
AddEventHandler('admin:openOperationsMenu', function()
    local options = {
        {
            title = "← Back",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerServerEvent('supply:requestAdminMenu')
            end
        },
        {
            title = "📈 Market Control",
            description = "Create shortage/surplus events",
            icon = "fas fa-chart-line",
            onSelect = function()
                local ingredients = getIngredientOptions()
                
                local input = lib.inputDialog("Market Event", {
                    { 
                        type = "select", 
                        label = "Event Type",
                        options = {
                            { value = "shortage", label = "🔴 Shortage (Price ↑)" },
                            { value = "surplus", label = "🟢 Surplus (Price ↓)" }
                        },
                        required = true 
                    },
                    { 
                        type = "select", 
                        label = "Select Ingredient", 
                        options = ingredients,
                        searchable = true,
                        required = true 
                    }
                })
                if input and input[1] and input[2] then
                    ExecuteCommand('supply market event ' .. input[2] .. ' ' .. input[1])
                end
            end
        },
        {
            title = "📦 Stock Adjustment",
            description = "Manually adjust warehouse stock",
            icon = "fas fa-boxes",
            onSelect = function()
                -- Get warehouse options
                local warehouses = {
                    { value = "main", label = "Main Warehouse" },
                    { value = "import", label = "Import Distribution Center" }
                }
                
                local ingredients = getIngredientOptions()
                
                local input = lib.inputDialog("Stock Adjustment", {
                    {
                        type = "select",
                        label = "Select Warehouse",
                        options = warehouses,
                        default = "main",
                        required = true
                    },
                    { 
                        type = "select", 
                        label = "Select Ingredient", 
                        options = ingredients,
                        searchable = true,
                        required = true 
                    },
                    { 
                        type = "number", 
                        label = "New Quantity", 
                        placeholder = "0-9999", 
                        min = 0, 
                        max = 9999, 
                        required = true 
                    }
                })
                if input and input[1] and input[2] and input[3] then
                    TriggerServerEvent('admin:adjustStock', input[1], input[2], tonumber(input[3]))
                end
            end
        },
        {
            title = "🚨 Emergency Orders",
            description = "Create priority deliveries",
            icon = "fas fa-exclamation-triangle",
            onSelect = function()
                -- Build restaurant list with proper names
                local restaurants = {}
                if Config.Restaurants then
                    for id, data in pairs(Config.Restaurants) do
                        table.insert(restaurants, {
                            value = tostring(id),
                            label = data.name or ("Restaurant " .. id)
                        })
                    end
                end
                
                -- Sort by ID for consistent ordering
                table.sort(restaurants, function(a, b)
                    return tonumber(a.value) < tonumber(b.value)
                end)
                
                local ingredients = getIngredientOptions()
                
                local input = lib.inputDialog("Emergency Order", {
                    { 
                        type = "select", 
                        label = "Priority Level",
                        options = {
                            { value = "critical", label = "🔴 Critical (2x bonus)" },
                            { value = "urgent", label = "🟡 Urgent (1.5x bonus)" },
                            { value = "emergency", label = "🟢 Standard (1.25x bonus)" }
                        },
                        required = true 
                    },
                    { 
                        type = "select", 
                        label = "Restaurant", 
                        options = restaurants,
                        required = true 
                    },
                    { 
                        type = "select", 
                        label = "Ingredient Needed", 
                        options = ingredients,
                        searchable = true,
                        required = true 
                    }
                })
                if input and input[1] and input[2] and input[3] then
                    ExecuteCommand('supply emergency create ' .. input[2] .. ' ' .. input[3] .. ' ' .. input[1])
                end
            end
        },
        {
            title = "📊 Quick Stats",
            description = "View current system metrics",
            icon = "fas fa-info-circle",
            onSelect = function()
                ExecuteCommand('supply stats')
            end
        }
    }
    
    lib.registerContext({
        id = "admin_operations_menu",
        title = "📊 Operations Center",
        options = options
    })
    lib.showContext("admin_operations_menu")
end)

-- ===============================================
-- PLAYER SUPPORT (Troubleshooting)
-- ===============================================
RegisterNetEvent('admin:openTroubleshootingMenu')
AddEventHandler('admin:openTroubleshootingMenu', function()
    local options = {
        {
            title = "← Back",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerServerEvent('supply:requestAdminMenu')
            end
        },
        {
            title = "🔄 Reset My Job",
            description = "Fix your own stuck state",
            icon = "fas fa-user",
            onSelect = function()
                ExecuteCommand('supplyjobreset')
            end
        },
        {
            title = "🎯 Reset Player Job",
            description = "Help a specific player",
            icon = "fas fa-user-friends",
            onSelect = function()
                local input = lib.inputDialog("Reset Player Job", {
                    { 
                        type = "number", 
                        label = "Player ID", 
                        placeholder = "Server ID", 
                        min = 1, 
                        required = true 
                    }
                })
                if input and input[1] then
                    local confirmed = lib.alertDialog({
                        header = "⚠️ Confirm Reset",
                        content = "Reset supply job for player " .. input[1] .. "?",
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
            title = "📊 Player Stats",
            description = "View player delivery statistics",
            icon = "fas fa-chart-pie",
            onSelect = function()
                local input = lib.inputDialog("Player Statistics", {
                    { 
                        type = "number", 
                        label = "Player ID", 
                        placeholder = "Server ID", 
                        min = 1, 
                        required = true 
                    }
                })
                if input and input[1] then
                    TriggerServerEvent('admin:getPlayerStats', tonumber(input[1]))
                end
            end
        },
        {
            title = "🏆 Grant Achievement",
            description = "Manually award achievements",
            icon = "fas fa-medal",
            onSelect = function()
                local achievements = {
                    { value = "rookie_runner", label = "🥉 Rookie Runner" },
                    { value = "supply_specialist", label = "🥈 Supply Specialist" },
                    { value = "logistics_expert", label = "🥇 Logistics Expert" },
                    { value = "elite_transporter", label = "💎 Elite Transporter" },
                    { value = "speed_demon", label = "⚡ Speed Demon" },
                    { value = "perfectionist", label = "✨ Perfectionist" },
                    { value = "team_player", label = "👥 Team Player" }
                }
                
                local input = lib.inputDialog("Grant Achievement", {
                    { 
                        type = "number", 
                        label = "Player ID", 
                        placeholder = "Server ID", 
                        min = 1, 
                        required = true 
                    },
                    { 
                        type = "select", 
                        label = "Achievement", 
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
        id = "admin_troubleshooting_menu",
        title = "🔧 Player Support",
        options = options
    })
    lib.showContext("admin_troubleshooting_menu")
end)

-- ===============================================
-- ANALYTICS DASHBOARD (View Only)
-- ===============================================
RegisterNetEvent('admin:openAnalyticsMenu')
AddEventHandler('admin:openAnalyticsMenu', function()
    local options = {
        {
            title = "← Back",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerServerEvent('supply:requestAdminMenu')
            end
        },
        {
            title = "📊 System Overview",
            description = "Comprehensive statistics",
            icon = "fas fa-chart-bar",
            onSelect = function()
                TriggerServerEvent('admin:getSystemAnalytics')
            end
        },
        {
            title = "🏆 Top Performers",
            description = "Driver leaderboards",
            icon = "fas fa-trophy",
            onSelect = function()
                TriggerServerEvent('admin:getTopPerformers')
            end
        },
        {
            title = "📈 Market Trends",
            description = "Price and demand analysis",
            icon = "fas fa-chart-line",
            onSelect = function()
                TriggerServerEvent('admin:getMarketTrends')
            end
        },
        {
            title = "🚨 Alert Summary",
            description = "Critical issues overview",
            icon = "fas fa-exclamation-circle",
            onSelect = function()
                TriggerServerEvent('admin:getAlertSummary')
            end
        }
    }
    
    lib.registerContext({
        id = "admin_analytics_menu",
        title = "📈 Analytics Dashboard",
        options = options
    })
    lib.showContext("admin_analytics_menu")
end)

-- ===============================================
-- SYSTEM MANAGEMENT (Admin+ Only)
-- ===============================================
RegisterNetEvent('admin:openSystemMenu')
AddEventHandler('admin:openSystemMenu', function(adminLevel)
    local options = {
        {
            title = "← Back",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerServerEvent('supply:requestAdminMenu')
            end
        },
        {
            title = "🔄 Reload Market System",
            description = "Restart pricing calculations",
            icon = "fas fa-sync",
            iconColor = "#FFA500",
            onSelect = function()
                local confirmed = lib.alertDialog({
                    header = "🔄 Reload Market?",
                    content = "This will restart market pricing. Active orders won't be affected.",
                    centered = true,
                    cancel = true
                })
                if confirmed == 'confirm' then
                    ExecuteCommand('supply market reload')
                end
            end
        },
        {
            title = "📊 Export Data",
            description = "Generate analytics report",
            icon = "fas fa-download",
            onSelect = function()
                ExecuteCommand('supply export analytics')
            end
        }
    }
    
    -- Superadmin only options
    if adminLevel == "superadmin" then
        table.insert(options, {
            title = "⚠️ Database Cleanup",
            description = "Remove old data (30+ days)",
            icon = "fas fa-database",
            iconColor = "#F44336",
            onSelect = function()
                local confirmed = lib.alertDialog({
                    header = "⚠️ Database Cleanup",
                    content = "This will delete data older than 30 days. This CANNOT be undone!",
                    centered = true,
                    cancel = true,
                    labels = {
                        cancel = "Cancel",
                        confirm = "I understand, proceed"
                    }
                })
                if confirmed == 'confirm' then
                    TriggerServerEvent('admin:databaseCleanup')
                end
            end
        })
        
        table.insert(options, {
            title = "🚨 Emergency Restart",
            description = "Full system reset (USE WITH CAUTION)",
            icon = "fas fa-power-off",
            iconColor = "#D32F2F",
            onSelect = function()
                local input = lib.inputDialog("Emergency Restart", {
                    { 
                        type = "input", 
                        label = "Type 'RESTART' to confirm", 
                        placeholder = "RESTART",
                        required = true 
                    }
                })
                if input and input[1] == "RESTART" then
                    ExecuteCommand('supplyemergencyrestart')
                else
                    lib.notify({
                        title = 'Cancelled',
                        description = 'Emergency restart cancelled',
                        type = 'error',
                        duration = 3000
                    })
                end
            end
        })
    end
    
    lib.registerContext({
        id = "admin_system_menu",
        title = "⚙️ System Management",
        options = options
    })
    lib.showContext("admin_system_menu")
end)

-- ===============================================
-- DEVELOPER TOOLS (Superadmin Only) - HYBRID UPDATE!
-- ===============================================
RegisterNetEvent('admin:openDevMenu')
AddEventHandler('admin:openDevMenu', function()
    local options = {
        {
            title = "← Back",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerServerEvent('supply:requestAdminMenu')
            end
        },
        {
            title = "🚛 Hybrid System Testing", -- UPDATED FROM CONVOY!
            description = "Test 1-3 vehicle spawning (Duo/Squad/Large)",
            icon = "fas fa-truck",
            onSelect = function()
                TriggerEvent('admin:openHybridTestMenu') -- UPDATED!
            end
        },
        {
            title = "🔍 Debug Mode",
            description = "Toggle verbose logging",
            icon = "fas fa-bug",
            onSelect = function()
                TriggerServerEvent('admin:toggleDebugMode')
            end
        },
        {
            title = "📝 Test Notifications",
            description = "Test all notification types",
            icon = "fas fa-bell",
            onSelect = function()
                -- Test various notification types
                lib.notify({
                    title = 'Success Test',
                    description = 'This is a success notification',
                    type = 'success',
                    duration = 3000
                })
                Wait(1000)
                lib.notify({
                    title = 'Info Test',
                    description = 'This is an info notification with **markdown**',
                    type = 'info',
                    duration = 3000,
                    markdown = true
                })
                Wait(1000)
                lib.notify({
                    title = 'Warning Test',
                    description = 'This is a warning notification',
                    type = 'warning',
                    duration = 3000
                })
                Wait(1000)
                lib.notify({
                    title = 'Error Test',
                    description = 'This is an error notification',
                    type = 'error',
                    duration = 3000
                })
            end
        }
    }
    
    lib.registerContext({
        id = "admin_dev_menu",
        title = "🛠️ Developer Tools",
        options = options
    })
    lib.showContext("admin_dev_menu")
end)

-- ===============================================
-- HYBRID TESTING SYSTEM (REPLACES CONVOY!)
-- ===============================================
RegisterNetEvent('admin:openHybridTestMenu')
AddEventHandler('admin:openHybridTestMenu', function()
    local warehouses = {}
    for id, _ in ipairs(Config.Warehouses) do
        table.insert(warehouses, {
            value = tostring(id),
            label = "Warehouse " .. id .. (id == 2 and " (Import)" or "")
        })
    end
    
    local options = {
        {
            title = "← Back",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent('admin:openDevMenu')
            end
        },
        {
            title = "🚐 Test Duo Spawn",
            description = "Spawn 1 vehicle for 2 players",
            icon = "fas fa-user-friends",
            onSelect = function()
                local input = lib.inputDialog("Duo Spawn Test", {
                    { 
                        type = "select", 
                        label = "Warehouse", 
                        options = warehouses,
                        required = true 
                    }
                })
                if input and input[1] then
                    TriggerEvent('hybrid:spawnVehicles', tonumber(input[1]), 2) -- 2 players = 1 vehicle
                end
            end
        },
        {
            title = "🚚 Test Squad Spawn",
            description = "Spawn 2 vehicles for 3-4 players",
            icon = "fas fa-users",
            onSelect = function()
                local input = lib.inputDialog("Squad Spawn Test", {
                    { 
                        type = "select", 
                        label = "Warehouse", 
                        options = warehouses,
                        required = true 
                    },
                    { 
                        type = "number", 
                        label = "Team Size (3-4)", 
                        min = 3,
                        max = 4,
                        default = 4,
                        required = true 
                    }
                })
                if input and input[1] and input[2] then
                    TriggerEvent('hybrid:spawnVehicles', tonumber(input[1]), tonumber(input[2]))
                end
            end
        },
        {
            title = "🚛 Test Large Spawn",
            description = "Spawn 3 vehicles for 5-8 players",
            icon = "fas fa-truck-loading",
            onSelect = function()
                local input = lib.inputDialog("Large Team Spawn Test", {
                    { 
                        type = "select", 
                        label = "Warehouse", 
                        options = warehouses,
                        required = true 
                    },
                    { 
                        type = "number", 
                        label = "Team Size (5-8)", 
                        min = 5,
                        max = 8,
                        default = 6,
                        required = true 
                    }
                })
                if input and input[1] and input[2] then
                    TriggerEvent('hybrid:spawnVehicles', tonumber(input[1]), tonumber(input[2]))
                end
            end
        },
        {
            title = "📍 Toggle Spawn Markers",
            description = "Show/hide hybrid spawn positions (1-3)",
            icon = "fas fa-map-marked",
            onSelect = function()
                local input = lib.inputDialog("Toggle Markers", {
                    { 
                        type = "select", 
                        label = "Warehouse", 
                        options = warehouses,
                        required = true 
                    }
                })
                if input and input[1] then
                    TriggerEvent('hybrid:toggleMarkers', tonumber(input[1]))
                end
            end
        },
        {
            title = "🧹 Clear Test Vehicles",
            description = "Remove all test vehicles",
            icon = "fas fa-broom",
            onSelect = function()
                TriggerEvent('hybrid:clearAll')
            end
        }
    }
    
    lib.registerContext({
        id = "admin_hybrid_menu",
        title = "🚛 Hybrid System Testing",
        options = options
    })
    lib.showContext("admin_hybrid_menu")
end)

-- ===============================================
-- HYBRID SPAWN HANDLERS (REPLACES CONVOY!)
-- ===============================================
RegisterNetEvent('hybrid:spawnVehicles')
AddEventHandler('hybrid:spawnVehicles', function(warehouseId, teamSize)
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
    if not warehouse then
        lib.notify({
            title = 'Invalid Warehouse',
            description = 'Warehouse configuration not found',
            type = 'error',
            duration = 5000
        })
        isSpawning = false
        return
    end
    
    -- HYBRID LOGIC: Determine vehicle count based on team size
    local vehicleCount = 1
    local teamType = "DUO"
    
    if teamSize <= 2 then
        vehicleCount = 1
        teamType = "DUO"
    elseif teamSize <= 4 then
        vehicleCount = 2
        teamType = "SQUAD"
    else
        vehicleCount = 3
        teamType = "LARGE"
    end
    
    -- Clear existing vehicles
    TriggerEvent('hybrid:clearAll')
    
    lib.notify({
        title = '🚛 Spawning Hybrid Fleet',
        description = string.format(
            '**%s MODE**\n👥 %d players = 🚛 %d vehicle(s)\nWarehouse: %d',
            teamType, teamSize, vehicleCount, warehouseId
        ),
        type = 'info',
        duration = 8000,
        markdown = true
    })
    
    local vehicleModel = warehouse.vehicle.model
    local model = GetHashKey(vehicleModel)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(10)
    end
    
    -- Use hybrid spawn positions
    local spawnPositions = {}
    
    if Config.HybridSpawnSystem and Config.HybridSpawnSystem.spawning then
        -- Use smart spawn system
        if warehouse.convoySpawnPoints then
            -- Use first 1-3 convoy points for hybrid
            for i = 1, math.min(vehicleCount, 3) do
                if warehouse.convoySpawnPoints[i] then
                    table.insert(spawnPositions, warehouse.convoySpawnPoints[i].position)
                end
            end
        else
            -- Use fallback offsets
            local basePos = warehouse.vehicle.position
            local offsets = Config.HybridSpawnSystem.spawning.fallbackOffsets
            
            for i = 1, vehicleCount do
                local offset = offsets[i] or {x = 0, y = 0}
                table.insert(spawnPositions, vector4(
                    basePos.x + offset.x,
                    basePos.y + offset.y,
                    basePos.z,
                    basePos.w or warehouse.heading
                ))
            end
        end
    end
    
    -- Spawn vehicles
    for i = 1, vehicleCount do
        local spawnPos = spawnPositions[i] or warehouse.vehicle.position
        
        local vehicle = CreateVehicle(model, 
            spawnPos.x, spawnPos.y, spawnPos.z, 
            spawnPos.w or warehouse.heading, 
            true, false)
        
        SetEntityAsMissionEntity(vehicle, true, true)
        SetVehicleOnGroundProperly(vehicle)
        
        -- Color code by team type
        local colors = {
            DUO = {r=255, g=165, b=0},    -- Orange for shared
            SQUAD = {r=0, g=150, b=255},   -- Blue for squad
            LARGE = {r=0, g=255, b=0}      -- Green for large
        }
        
        local color = colors[teamType]
        SetVehicleCustomPrimaryColour(vehicle, color.r, color.g, color.b)
        SetVehicleCustomSecondaryColour(vehicle, color.r, color.g, color.b)
        
        -- Add blip
        local blip = AddBlipForEntity(vehicle)
        SetBlipSprite(blip, 1)
        SetBlipColour(blip, i == 1 and 2 or i == 2 and 3 or 5)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(string.format("%s #%d", teamType, i))
        EndTextCommandSetBlipName(blip)
        
        table.insert(hybridTestVehicles, {
            vehicle = vehicle,
            blip = blip,
            vehicleIndex = i,
            teamType = teamType
        })
    end
    
    isSpawning = false
    
    lib.notify({
        title = '✅ Hybrid Fleet Spawned',
        description = string.format(
            '**%s MODE ACTIVE**\n🚛 %d vehicle(s) spawned\n📦 Ready for team delivery!',
            teamType, vehicleCount
        ),
        type = 'success',
        duration = 8000,
        markdown = true
    })
end)

RegisterNetEvent('hybrid:clearAll')
AddEventHandler('hybrid:clearAll', function()
    local count = 0
    
    for _, data in ipairs(hybridTestVehicles) do
        if DoesEntityExist(data.vehicle) then
            DeleteVehicle(data.vehicle)
            count = count + 1
        end
        if data.blip and DoesBlipExist(data.blip) then
            RemoveBlip(data.blip)
        end
    end
    
    hybridTestVehicles = {}
    
    if count > 0 then
        lib.notify({
            title = 'Vehicles Cleared',
            description = string.format('%d test vehicles removed', count),
            type = 'success',
            duration = 3000
        })
    end
end)

RegisterNetEvent('hybrid:toggleMarkers')
AddEventHandler('hybrid:toggleMarkers', function(warehouseId)
    showingMarkers = not showingMarkers
    
    if showingMarkers then
        local warehouse = Config.Warehouses[warehouseId]
        if not warehouse then
            lib.notify({
                title = 'Invalid Warehouse',
                description = 'Warehouse configuration not found',
                type = 'error',
                duration = 5000
            })
            showingMarkers = false
            return
        end
        
        lib.notify({
            title = 'Markers Enabled',
            description = 'Showing hybrid spawn points (Max 3)',
            type = 'info',
            duration = 3000
        })
        
        Citizen.CreateThread(function()
            while showingMarkers do
                -- Determine spawn positions based on hybrid system
                local spawnPositions = {}
                local maxVehicles = 3 -- Hybrid max
                
                if warehouse.convoySpawnPoints then
                    -- Use first 3 convoy points
                    for i = 1, math.min(maxVehicles, #warehouse.convoySpawnPoints) do
                        table.insert(spawnPositions, {
                            position = warehouse.convoySpawnPoints[i].position,
                            index = i
                        })
                    end
                else
                    -- Use fallback offsets
                    local basePos = warehouse.vehicle.position
                    local offsets = Config.HybridSpawnSystem.spawning.fallbackOffsets
                    
                    for i = 1, maxVehicles do
                        local offset = offsets[i] or {x = 0, y = 0}
                        table.insert(spawnPositions, {
                            position = vector4(
                                basePos.x + offset.x,
                                basePos.y + offset.y,
                                basePos.z,
                                basePos.w
                            ),
                            index = i
                        })
                    end
                end
                
                -- Draw markers for spawn positions
                for _, spawn in ipairs(spawnPositions) do
                    local pos = spawn.position
                    local index = spawn.index
                    
                    -- Color based on vehicle index
                    local r, g, b = 255, 255, 255
                    if index == 1 then
                        r, g, b = 255, 165, 0 -- Orange (DUO/Leader)
                    elseif index == 2 then
                        r, g, b = 0, 150, 255 -- Blue (SQUAD)
                    elseif index == 3 then
                        r, g, b = 0, 255, 0   -- Green (LARGE)
                    end
                    
                    DrawMarker(
                        1,
                        pos.x, pos.y, pos.z - 1.0,
                        0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0,
                        5.0, 5.0, 2.0,
                        r, g, b, 100,
                        false, false, 2, false, nil, nil, false
                    )
                    
                    -- Draw text label
                    local onScreen, _x, _y = World3dToScreen2d(pos.x, pos.y, pos.z + 1.0)
                    if onScreen then
                        local labels = {
                            [1] = "Vehicle 1 (DUO/Leader)",
                            [2] = "Vehicle 2 (SQUAD)",
                            [3] = "Vehicle 3 (LARGE)"
                        }
                        
                        SetTextScale(0.4, 0.4)
                        SetTextFont(4)
                        SetTextProportional(1)
                        SetTextColour(255, 255, 255, 255)
                        SetTextOutline()
                        SetTextEntry("STRING")
                        AddTextComponentString(labels[index])
                        DrawText(_x, _y)
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

-- ===============================================
-- RESULT DISPLAY HANDLERS (Simplified)
-- ===============================================

-- Display system analytics
RegisterNetEvent('admin:displaySystemAnalytics')
AddEventHandler('admin:displaySystemAnalytics', function(data)
    if not data then return end
    
    lib.notify({
        title = '📊 System Analytics',
        description = string.format([[
**Today's Performance**
• Orders: %d completed (%.1f/hr)
• Revenue: $%s
• Active Drivers: %d
• Avg Completion: %.1f mins

**All-Time Stats**
• Total Deliveries: %d
• Total Revenue: $%s
• Registered Drivers: %d]],
            data.todayOrders or 0,
            data.ordersPerHour or 0,
            lib.math.groupdigits(data.todayRevenue or 0),
            data.activeDrivers or 0,
            data.avgCompletionTime or 0,
            data.totalDeliveries or 0,
            lib.math.groupdigits(data.totalRevenue or 0),
            data.totalDrivers or 0
        ),
        type = 'info',
        duration = 20000,
        position = 'top',
        markdown = true
    })
end)

-- Display top performers
RegisterNetEvent('admin:displayTopPerformers')
AddEventHandler('admin:displayTopPerformers', function(data)
    if not data or #data == 0 then
        lib.notify({
            title = '🏆 Top Performers',
            description = 'No delivery data found.',
            type = 'info',
            duration = 5000
        })
        return
    end
    
    local message = "**Today's Top Drivers**\n\n"
    
    for i, driver in ipairs(data) do
        if i <= 5 then
            local medal = i == 1 and "🥇" or i == 2 and "🥈" or i == 3 and "🥉" or "🏅"
            message = message .. string.format(
                "%s **%s** - %d deliveries ($%s)\n",
                medal,
                driver.name,
                driver.deliveries,
                lib.math.groupdigits(driver.earnings)
            )
        end
    end
    
    lib.notify({
        title = '🏆 Leaderboard',
        description = message,
        type = 'info',
        duration = 15000,
        position = 'top',
        markdown = true
    })
end)

-- ===============================================
-- AUTO-RESET & QUICK COMMANDS (Keep as is)
-- ===============================================

-- Auto-reset on resource restart
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        Citizen.SetTimeout(1000, function()
            local playerPed = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(playerPed, false)
            
            if vehicle ~= 0 then
                local plate = GetVehicleNumberPlateText(vehicle)
                if string.find(plate, "SUPPLY") or string.find(plate, "DELIV") or string.find(plate, "TEAM") then
                    print("[SUPPLY RESET] Auto-reset triggered due to resource restart")
                    TriggerEvent('supply:forceJobReset')
                end
            end
        end)
    end
end)

-- Quick commands
RegisterCommand('supplyadmin', function()
    TriggerEvent('supply:openAdminMenu')
end, false)

RegisterCommand('supplyreset', function()
    TriggerEvent('admin:openTroubleshootingMenu')
end, false)