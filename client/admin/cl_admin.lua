local QBCore = exports['qb-core']:GetCoreObject()

-- ===============================================
-- REFINED ADMIN UI SYSTEM
-- ===============================================
-- Streamlined from 50+ options to ~20 essential functions
-- Organized by use case, not feature type
-- ===============================================

local convoyTestVehicles = {}
local showingMarkers = false
local isSpawning = false

-- Cache for ingredient labels
local ingredientLabels = {}

-- Helper function to get ingredient labels with caching
local function getIngredientOptions()
    if #ingredientLabels > 0 then
        return ingredientLabels
    end
    
    -- Build options from Config with proper labels
    if Config.Ingredients then
        for name, data in pairs(Config.Ingredients) do
            table.insert(ingredientLabels, {
                value = name,
                label = data.label or name
            })
        end
    end
    
    -- Sort alphabetically by label
    table.sort(ingredientLabels, function(a, b)
        return a.label < b.label
    end)
    
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
            description = "Convoy testing and debug utilities",
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
                local ingredients = getIngredientOptions()
                
                local input = lib.inputDialog("Stock Adjustment", {
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
                if input and input[1] and input[2] then
                    TriggerServerEvent('admin:adjustStock', input[1], tonumber(input[2]))
                end
            end
        },
        {
            title = "🚨 Emergency Orders",
            description = "Create priority deliveries",
            icon = "fas fa-exclamation-triangle",
            onSelect = function()
                -- Simplified emergency order creation
                local restaurants = {}
                if Config.Restaurants then
                    for id, data in pairs(Config.Restaurants) do
                        table.insert(restaurants, {
                            value = tostring(id),
                            label = data.label or ("Restaurant " .. id)
                        })
                    end
                end
                
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
-- DEVELOPER TOOLS (Superadmin Only)
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
            title = "🚛 Convoy Testing",
            description = "Vehicle spawn position testing",
            icon = "fas fa-truck",
            onSelect = function()
                TriggerEvent('admin:openConvoyTestMenu')
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
-- CONVOY TESTING (Keep existing implementation)
-- ===============================================
RegisterNetEvent('admin:openConvoyTestMenu')
AddEventHandler('admin:openConvoyTestMenu', function()
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
            title = "🚛 Quick Spawn Test",
            description = "Spawn all vehicles at warehouse",
            icon = "fas fa-truck-loading",
            onSelect = function()
                local input = lib.inputDialog("Quick Spawn", {
                    { 
                        type = "select", 
                        label = "Warehouse", 
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
            title = "📍 Toggle Markers",
            description = "Show/hide spawn positions",
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
                    TriggerEvent('convoy:toggleMarkers', tonumber(input[1]))
                end
            end
        },
        {
            title = "🧹 Clear Vehicles",
            description = "Remove test vehicles",
            icon = "fas fa-broom",
            onSelect = function()
                TriggerEvent('convoy:clearAll')
            end
        }
    }
    
    lib.registerContext({
        id = "admin_convoy_menu",
        title = "🚛 Convoy Testing",
        options = options
    })
    lib.showContext("admin_convoy_menu")
end)

-- Keep all convoy event handlers as they are (they work!)
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
    
    TriggerEvent('convoy:clearAll')
    
    lib.notify({
        title = 'Spawning Convoy',
        description = string.format('Spawning %d vehicles at Warehouse %d', #spawnPoints, warehouseId),
        type = 'info',
        duration = 5000
    })
    
    local model = GetHashKey(vehicleModel)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(10)
    end
    
    for i, point in ipairs(spawnPoints) do
        if point.position then
            local vehicle = CreateVehicle(model, 
                point.position.x, point.position.y, point.position.z, 
                point.position.w or warehouse.heading, 
                true, false)
            
            SetEntityAsMissionEntity(vehicle, true, true)
            SetVehicleOnGroundProperly(vehicle)
            
            local colors = {
                [1] = {r=255, g=0, b=0},
                [2] = {r=255, g=165, b=0},
                [3] = {r=255, g=255, b=0},
                [4] = {r=0, g=255, b=0},
                [5] = {r=0, g=255, b=255},
            }
            
            local color = colors[math.min(point.priority or 1, 5)] or colors[5]
            SetVehicleCustomPrimaryColour(vehicle, color.r, color.g, color.b)
            SetVehicleCustomSecondaryColour(vehicle, color.r, color.g, color.b)
            
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
end)

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
        
        Citizen.CreateThread(function()
            while showingMarkers do
                for i, point in ipairs(spawnPoints) do
                    if point.position then
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
                            1,
                            point.position.x, point.position.y, point.position.z - 1.0,
                            0.0, 0.0, 0.0,
                            0.0, 0.0, 0.0,
                            5.0, 5.0, 2.0,
                            r, g, b, 100,
                            false, false, 2, false, nil, nil, false
                        )
                        
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
                if string.find(plate, "SUPPLY") or string.find(plate, "DELIV") then
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