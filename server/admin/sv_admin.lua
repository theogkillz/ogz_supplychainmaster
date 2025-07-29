local QBCore = exports['qb-core']:GetCoreObject()

-- ===============================================
-- REFINED ADMIN SYSTEM - SERVER SIDE
-- ===============================================
-- Streamlined from complex to focused functionality
-- ===============================================

-- Admin list with license2 identifiers
local AdminList = {
    ["license2:02e93de433b665fc9572546e584552674c49978d"] = "superadmin",
    ["license2:7c244f49f115502178c9efc54efa183bc4ddb49d"] = "admin", -- Kat
    ["license2:a374445a04dd4245baa057b5a951f7e73afae6fc"] = "moderator", -- Nuttzie
}

-- Debug mode state
local debugMode = false

-- ===============================================
-- PERMISSION SYSTEM (SIMPLIFIED)
-- ===============================================

local function getAdminLevel(source)
    local xPlayer = QBCore.Functions.GetPlayer(source)
    if not xPlayer then return nil end
    
    -- Get license2 identifier
    local identifiers = GetPlayerIdentifiers(source)
    local license2 = nil
    
    for _, id in pairs(identifiers) do
        if string.sub(id, 1, 9) == "license2:" then
            license2 = id
            break
        end
    end
    
    -- Check admin list first
    if license2 and AdminList[license2] then
        return AdminList[license2]
    end
    
    -- Check Hurst boss
    if xPlayer.PlayerData.job and xPlayer.PlayerData.job.name == "hurst" then
        if xPlayer.PlayerData.job.isboss then
            return "admin"
        elseif xPlayer.PlayerData.job.grade and xPlayer.PlayerData.job.grade.level >= 3 then
            return "moderator"
        end
    end
    
    -- Check QBCore permissions
    if QBCore.Functions.HasPermission then
        if QBCore.Functions.HasPermission(source, "god") then
            return "superadmin"
        elseif QBCore.Functions.HasPermission(source, "admin") then
            return "admin"
        elseif QBCore.Functions.HasPermission(source, "mod") then
            return "moderator"
        end
    end
    
    return nil
end

local function hasAdminPermission(source, requiredLevel)
    local adminLevel = getAdminLevel(source)
    
    -- Debug logging
    if debugMode or true then -- Always log during testing
        print(string.format("[ADMIN DEBUG] Player %s - Admin Level: %s - Required: %s", 
            GetPlayerName(source), 
            adminLevel or "none", 
            requiredLevel))
    end
    
    if not adminLevel then return false end
    
    if requiredLevel == "moderator" then
        return true -- Any admin level
    elseif requiredLevel == "admin" then
        return adminLevel == "admin" or adminLevel == "superadmin"
    elseif requiredLevel == "superadmin" then
        return adminLevel == "superadmin"
    end
    
    return false
end

-- ===============================================
-- MAIN ADMIN MENU REQUEST
-- ===============================================

RegisterNetEvent('supply:requestAdminMenu')
AddEventHandler('supply:requestAdminMenu', function()
    local src = source
    local adminLevel = getAdminLevel(src)
    
    print(string.format("[ADMIN] Menu requested by %s (ID: %d) - Level: %s", 
        GetPlayerName(src), src, adminLevel or "none"))
    
    if not adminLevel then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Access Denied',
            description = 'Admin permissions required\nUse /supplytest to check your access',
            type = 'error',
            duration = 8000
        })
        return
    end
    
    print("[ADMIN] Fetching system data for admin menu...")
    
    -- Initialize data
    local data = {
        pendingOrders = 0,
        dailyOrders = 0,
        activeDrivers = 0,
        criticalAlerts = 0,
        systemStatus = 'healthy'
    }
    
    -- Use simple separate queries for reliability
    local queriesCompleted = 0
    local totalQueries = 4
    local menuSent = false
    
    local function sendMenu()
        if menuSent then return end
        menuSent = true
        
        -- Determine system status
        if data.criticalAlerts > 0 then
            data.systemStatus = 'critical'
        elseif data.pendingOrders > 20 then
            data.systemStatus = 'warning'
        end
        
        print(string.format("[ADMIN] Sending menu to %s with data: pending=%d, daily=%d, drivers=%d", 
            GetPlayerName(src), data.pendingOrders, data.dailyOrders, data.activeDrivers))
        
        TriggerClientEvent('supply:showAdminMenu', src, data, adminLevel)
    end
    
    local function checkComplete()
        queriesCompleted = queriesCompleted + 1
        if queriesCompleted == totalQueries then
            sendMenu()
        end
    end
    
    -- Timeout fallback (2 seconds)
    SetTimeout(2000, function()
        if not menuSent then
            print("[ADMIN WARNING] Query timeout - sending menu with partial data")
            sendMenu()
        end
    end)
    
    -- Query 1: Pending orders
    MySQL.Async.fetchScalar("SELECT COUNT(*) FROM supply_orders WHERE status = 'pending'", {}, function(count)
        data.pendingOrders = count or 0
        checkComplete()
    end)
    
    -- Query 2: Daily completed orders
    MySQL.Async.fetchScalar("SELECT COUNT(*) FROM supply_orders WHERE status = 'completed' AND DATE(created_at) = CURDATE()", {}, function(count)
        data.dailyOrders = count or 0
        checkComplete()
    end)
    
    -- Query 3: Active drivers today
    MySQL.Async.fetchScalar("SELECT COUNT(DISTINCT citizenid) FROM supply_driver_stats WHERE DATE(delivery_date) = CURDATE()", {}, function(count)
        data.activeDrivers = count or 0
        checkComplete()
    end)
    
    -- Query 4: Critical alerts (simplified)
    MySQL.Async.fetchScalar("SELECT COUNT(*) FROM supply_stock_alerts WHERE alert_type = 'critical'", {}, function(count)
        data.criticalAlerts = count or 0
        checkComplete()
    end)
end)

-- ===============================================
-- OPERATIONS HANDLERS
-- ===============================================

-- Stock adjustment (fixed to check proper permission)
RegisterNetEvent('admin:adjustStock')
AddEventHandler('admin:adjustStock', function(ingredient, newQuantity)
    local src = source
    
    if not hasAdminPermission(src, 'moderator') then 
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Access Denied',
            description = 'Admin permissions required',
            type = 'error',
            duration = 5000
        })
        return 
    end
    
    MySQL.Async.execute([[
        INSERT INTO supply_warehouse_stock (ingredient, quantity) 
        VALUES (?, ?) 
        ON DUPLICATE KEY UPDATE quantity = ?
    ]], {ingredient, newQuantity, newQuantity}, function(success)
        if success then
            -- Get item label from config
            local itemLabel = ingredient
            if Config.Ingredients and Config.Ingredients[ingredient] then
                itemLabel = Config.Ingredients[ingredient].label or ingredient
            end
            
            TriggerClientEvent('ox_lib:notify', src, {
                title = '✅ Stock Adjusted',
                description = string.format('%s set to %d units', itemLabel, newQuantity),
                type = 'success',
                duration = 8000
            })
            
            -- Log the action
            print(string.format("[ADMIN] %s adjusted %s stock to %d", GetPlayerName(src), ingredient, newQuantity))
        end
    end)
end)

-- ===============================================
-- ANALYTICS HANDLERS
-- ===============================================

RegisterNetEvent('admin:getSystemAnalytics')
AddEventHandler('admin:getSystemAnalytics', function()
    local src = source
    
    if not hasAdminPermission(src, 'moderator') then return end
    
    MySQL.Async.fetchAll([[
        SELECT 
            (SELECT COUNT(*) FROM supply_orders WHERE status = 'completed' AND DATE(created_at) = CURDATE()) as today_orders,
            (SELECT SUM(total_cost) FROM supply_orders WHERE status = 'completed' AND DATE(created_at) = CURDATE()) as today_revenue,
            (SELECT COUNT(DISTINCT citizenid) FROM supply_driver_stats WHERE DATE(delivery_date) = CURDATE()) as active_drivers,
            (SELECT AVG(TIMESTAMPDIFF(MINUTE, created_at, updated_at)) FROM supply_orders WHERE status = 'completed' AND DATE(created_at) = CURDATE()) as avg_completion,
            (SELECT COUNT(*) FROM supply_orders WHERE status = 'completed') as total_deliveries,
            (SELECT SUM(total_cost) FROM supply_orders WHERE status = 'completed') as total_revenue,
            (SELECT COUNT(DISTINCT citizenid) FROM supply_driver_stats) as total_drivers
    ]], {}, function(result)
        if result and result[1] then
            local data = result[1]
            
            -- Calculate orders per hour
            local hoursElapsed = tonumber(os.date("%H")) + (tonumber(os.date("%M")) / 60)
            data.ordersPerHour = hoursElapsed > 0 and (data.today_orders / hoursElapsed) or 0
            
            TriggerClientEvent('admin:displaySystemAnalytics', src, {
                todayOrders = data.today_orders or 0,
                todayRevenue = data.today_revenue or 0,
                activeDrivers = data.active_drivers or 0,
                avgCompletionTime = data.avg_completion or 0,
                totalDeliveries = data.total_deliveries or 0,
                totalRevenue = data.total_revenue or 0,
                totalDrivers = data.total_drivers or 0,
                ordersPerHour = data.ordersPerHour
            })
        end
    end)
end)

RegisterNetEvent('admin:getTopPerformers')
AddEventHandler('admin:getTopPerformers', function()
    local src = source
    
    if not hasAdminPermission(src, 'moderator') then return end
    
    MySQL.Async.fetchAll([[
        SELECT 
            ds.citizenid,
            p.charinfo,
            COUNT(*) as deliveries,
            SUM(ds.total_earned) as earnings
        FROM supply_driver_stats ds
        JOIN players p ON p.citizenid = ds.citizenid
        WHERE DATE(ds.delivery_date) = CURDATE()
        GROUP BY ds.citizenid
        ORDER BY deliveries DESC
        LIMIT 10
    ]], {}, function(results)
        local performers = {}
        
        for _, row in ipairs(results or {}) do
            local charinfo = json.decode(row.charinfo)
            table.insert(performers, {
                name = charinfo.firstname .. ' ' .. charinfo.lastname,
                deliveries = row.deliveries,
                earnings = row.earnings
            })
        end
        
        TriggerClientEvent('admin:displayTopPerformers', src, performers)
    end)
end)

RegisterNetEvent('admin:getMarketTrends')
AddEventHandler('admin:getMarketTrends', function()
    local src = source
    
    if not hasAdminPermission(src, 'moderator') then return end
    
    -- Get current market state
    local marketData = {}
    
    MySQL.Async.fetchAll([[
        SELECT 
            mp.ingredient,
            mp.base_price,
            mp.current_price,
            mp.multiplier,
            ws.quantity as stock
        FROM supply_market_prices mp
        LEFT JOIN supply_warehouse_stock ws ON ws.ingredient = mp.ingredient
    ]], {}, function(results)
        for _, item in ipairs(results or {}) do
            local label = Config.Ingredients[item.ingredient] and Config.Ingredients[item.ingredient].label or item.ingredient
            
            marketData[item.ingredient] = {
                label = label,
                basePrice = item.base_price,
                currentPrice = item.current_price,
                multiplier = item.multiplier,
                stock = item.stock or 0,
                trend = item.multiplier > 1.2 and "📈 High Demand" or item.multiplier < 0.8 and "📉 Surplus" or "➡️ Stable"
            }
        end
        
        TriggerClientEvent('admin:displayMarketOverview', src, marketData)
    end)
end)

RegisterNetEvent('admin:getAlertSummary')
AddEventHandler('admin:getAlertSummary', function()
    local src = source
    
    if not hasAdminPermission(src, 'moderator') then return end
    
    MySQL.Async.fetchAll([[
        SELECT 
            ingredient,
            alert_type,
            message,
            created_at
        FROM supply_stock_alerts
        ORDER BY 
            CASE alert_type 
                WHEN 'critical' THEN 1
                WHEN 'low' THEN 2
                ELSE 3
            END,
            created_at DESC
        LIMIT 10
    ]], {}, function(results)
        if not results or #results == 0 then
            TriggerClientEvent('ox_lib:notify', src, {
                title = '✅ No Active Alerts',
                description = 'All systems operating normally',
                type = 'success',
                duration = 5000
            })
            return
        end
        
        local message = "**Active Alerts**\n\n"
        
        for _, alert in ipairs(results) do
            local emoji = alert.alert_type == 'critical' and '🚨' or alert.alert_type == 'low' and '⚠️' or 'ℹ️'
            local label = Config.Ingredients[alert.ingredient] and Config.Ingredients[alert.ingredient].label or alert.ingredient
            
            message = message .. string.format(
                "%s **%s** - %s\n",
                emoji,
                label,
                alert.message
            )
        end
        
        TriggerClientEvent('ox_lib:notify', src, {
            title = '🚨 Alert Summary',
            description = message,
            type = 'warning',
            duration = 15000,
            position = 'top',
            markdown = true
        })
    end)
end)

-- ===============================================
-- PLAYER SUPPORT HANDLERS
-- ===============================================

RegisterNetEvent('admin:getPlayerStats')
AddEventHandler('admin:getPlayerStats', function(targetId)
    local src = source
    
    if not hasAdminPermission(src, 'moderator') then return end
    
    local xPlayer = QBCore.Functions.GetPlayer(targetId)
    if not xPlayer then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Player Not Found',
            description = 'Invalid player ID',
            type = 'error',
            duration = 5000
        })
        return
    end
    
    local citizenid = xPlayer.PlayerData.citizenid
    local name = xPlayer.PlayerData.charinfo.firstname .. ' ' .. xPlayer.PlayerData.charinfo.lastname
    
    MySQL.Async.fetchAll([[
        SELECT 
            COUNT(*) as total_deliveries,
            SUM(total_earned) as total_earnings,
            AVG(completion_time) as avg_time,
            MAX(delivery_date) as last_delivery
        FROM supply_driver_stats
        WHERE citizenid = ?
    ]], {citizenid}, function(result)
        if result and result[1] then
            local stats = result[1]
            
            TriggerClientEvent('ox_lib:notify', src, {
                title = '📊 Player Statistics',
                description = string.format([[
**Player:** %s
**Total Deliveries:** %d
**Total Earnings:** $%s
**Avg Completion:** %.1f mins
**Last Delivery:** %s]],
                    name,
                    stats.total_deliveries or 0,
                    lib.math.groupdigits(stats.total_earnings or 0),
                    stats.avg_time or 0,
                    stats.last_delivery or 'Never'
                ),
                type = 'info',
                duration = 15000,
                position = 'top',
                markdown = true
            })
        end
    end)
end)

RegisterNetEvent('admin:grantAchievement')
AddEventHandler('admin:grantAchievement', function(targetId, achievement)
    local src = source
    
    if not hasAdminPermission(src, 'moderator') then return end
    
    local xPlayer = QBCore.Functions.GetPlayer(targetId)
    if not xPlayer then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Player Not Found',
            description = 'Invalid player ID',
            type = 'error',
            duration = 5000
        })
        return
    end
    
    -- Grant achievement (implement based on your achievement system)
    TriggerClientEvent('supply:grantAchievement', targetId, achievement)
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = '✅ Achievement Granted',
        description = string.format('Granted %s to %s', achievement, GetPlayerName(targetId)),
        type = 'success',
        duration = 8000
    })
end)

-- ===============================================
-- SYSTEM MANAGEMENT HANDLERS
-- ===============================================

RegisterNetEvent('admin:databaseCleanup')
AddEventHandler('admin:databaseCleanup', function()
    local src = source
    
    if not hasAdminPermission(src, 'superadmin') then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Access Denied',
            description = 'Superadmin required',
            type = 'error',
            duration = 5000
        })
        return
    end
    
    -- Clean up old data (30+ days)
    local queries = {
        "DELETE FROM supply_orders WHERE status = 'completed' AND created_at < DATE_SUB(NOW(), INTERVAL 30 DAY)",
        "DELETE FROM supply_driver_stats WHERE delivery_date < DATE_SUB(NOW(), INTERVAL 30 DAY)",
        "DELETE FROM supply_stock_alerts WHERE created_at < DATE_SUB(NOW(), INTERVAL 30 DAY)",
        "DELETE FROM supply_market_history WHERE timestamp < DATE_SUB(NOW(), INTERVAL 30 DAY)"
    }
    
    local cleaned = 0
    
    for _, query in ipairs(queries) do
        MySQL.Async.execute(query, {}, function(affected)
            cleaned = cleaned + (affected or 0)
        end)
    end
    
    Wait(1000) -- Wait for queries to complete
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = '✅ Database Cleaned',
        description = string.format('Removed %d old records', cleaned),
        type = 'success',
        duration = 8000
    })
    
    print(string.format("[ADMIN] %s performed database cleanup - %d records removed", GetPlayerName(src), cleaned))
end)

RegisterNetEvent('admin:toggleDebugMode')
AddEventHandler('admin:toggleDebugMode', function()
    local src = source
    
    if not hasAdminPermission(src, 'superadmin') then return end
    
    debugMode = not debugMode
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = debugMode and '🔍 Debug Mode ON' or '🔍 Debug Mode OFF',
        description = debugMode and 'Verbose logging enabled' or 'Verbose logging disabled',
        type = 'info',
        duration = 5000
    })
    
    print(string.format("[ADMIN] Debug mode %s by %s", debugMode and "ENABLED" or "DISABLED", GetPlayerName(src)))
end)

-- ===============================================
-- COMMAND HANDLERS (SIMPLIFIED)
-- ===============================================

-- Main admin command - CONSOLIDATED
RegisterCommand('supply', function(source, args, rawCommand)
    if source == 0 then
        -- Console commands
        local action = args[1] and args[1]:lower()
        
        if action == 'stats' then
            MySQL.Async.fetchAll([[
                SELECT 
                    (SELECT COUNT(*) FROM supply_orders WHERE status = 'pending') as pending,
                    (SELECT COUNT(*) FROM supply_orders WHERE status = 'completed' AND DATE(created_at) = CURDATE()) as completed,
                    (SELECT COUNT(DISTINCT citizenid) FROM supply_driver_stats WHERE DATE(delivery_date) = CURDATE()) as drivers
            ]], {}, function(results)
                if results and results[1] then
                    print('=== SUPPLY CHAIN STATS ===')
                    print('Pending: ' .. results[1].pending)
                    print('Completed Today: ' .. results[1].completed)
                    print('Active Drivers: ' .. results[1].drivers)
                    print('========================')
                end
            end)
        elseif action == 'help' then
            print('=== SUPPLY ADMIN COMMANDS ===')
            print('supply stats - Show statistics')
            print('supply help - Show this menu')
            print('============================')
        else
            print('Use: supply help')
        end
        return
    end
    
    -- In-game command handling
    local action = args[1] and args[1]:lower()
    local subaction = args[2] and args[2]:lower()
    
    -- No arguments = open menu
    if not action then
        print("[ADMIN] Player " .. GetPlayerName(source) .. " opening admin menu")
        TriggerClientEvent('supply:openAdminMenu', source)
        return
    end
    
    -- Check permissions for sub-commands
    if not hasAdminPermission(source, 'moderator') then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Access Denied',
            description = 'Admin permissions required',
            type = 'error',
            duration = 5000
        })
        return
    end
    
    -- Handle sub-commands
    if action == 'stats' then
        -- Quick stats command
        MySQL.Async.fetchAll([[
            SELECT 
                (SELECT COUNT(*) FROM supply_orders WHERE status = 'pending') as pending,
                (SELECT COUNT(*) FROM supply_orders WHERE status = 'completed' AND DATE(created_at) = CURDATE()) as completed,
                (SELECT COUNT(DISTINCT citizenid) FROM supply_driver_stats WHERE DATE(delivery_date) = CURDATE()) as drivers
        ]], {}, function(results)
            if results and results[1] then
                TriggerClientEvent('ox_lib:notify', source, {
                    title = '📊 Quick Stats',
                    description = string.format(
                        '📋 Pending: %d\n✅ Completed Today: %d\n👥 Active Drivers: %d',
                        results[1].pending,
                        results[1].completed,
                        results[1].drivers
                    ),
                    type = 'info',
                    duration = 10000,
                    markdown = true
                })
            end
        end)
        
    elseif action == 'market' then
        if subaction == 'event' then
            local ingredient = args[3]
            local eventType = args[4]
            
            if ingredient and eventType then
                -- Trigger market event
                TriggerEvent('supply:createMarketEvent', ingredient, eventType)
                
                TriggerClientEvent('ox_lib:notify', source, {
                    title = '✅ Market Event Created',
                    description = string.format('%s event for %s', eventType, ingredient),
                    type = 'success',
                    duration = 8000
                })
            end
        elseif subaction == 'reload' then
            -- Reload market system
            TriggerEvent('supply:reloadMarketSystem')
            
            TriggerClientEvent('ox_lib:notify', source, {
                title = '✅ Market Reloaded',
                description = 'Pricing system reinitialized',
                type = 'success',
                duration = 5000
            })
        end
        
    elseif action == 'emergency' then
        if subaction == 'create' then
            local restaurantId = tonumber(args[3])
            local ingredient = args[4]
            local priority = args[5] or 'emergency'
            
            if restaurantId and ingredient then
                -- Create emergency order
                TriggerEvent('supply:createEmergencyOrder', {
                    restaurantId = restaurantId,
                    ingredient = ingredient,
                    priority = priority,
                    quantity = 50
                })
                
                TriggerClientEvent('ox_lib:notify', source, {
                    title = '✅ Emergency Created',
                    description = string.format('%s priority order created', priority),
                    type = 'success',
                    duration = 8000
                })
            end
        end
        
    elseif action == 'export' then
        if subaction == 'analytics' then
            -- Export analytics (implement as needed)
            TriggerClientEvent('ox_lib:notify', source, {
                title = '📊 Export Started',
                description = 'Analytics export initiated',
                type = 'info',
                duration = 5000
            })
        end
    else
        -- Unknown sub-command, open menu instead
        TriggerClientEvent('supply:openAdminMenu', source)
    end
end, false)

-- Job reset command
RegisterCommand('supplyjobreset', function(source, args, rawCommand)
    local src = source
    local targetId = tonumber(args[1]) or src
    
    if src ~= 0 and not hasAdminPermission(src, 'moderator') then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Access Denied',
            description = 'Admin permissions required',
            type = 'error',
            duration = 5000
        })
        return
    end
    
    local xPlayer = QBCore.Functions.GetPlayer(targetId)
    if not xPlayer then
        if src == 0 then
            print('[SUPPLY] Player not found: ' .. targetId)
        else
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Player Not Found',
                description = 'Invalid player ID',
                type = 'error',
                duration = 5000
            })
        end
        return
    end
    
    local targetName = xPlayer.PlayerData.charinfo.firstname .. ' ' .. xPlayer.PlayerData.charinfo.lastname
    local citizenid = xPlayer.PlayerData.citizenid
    
    -- Trigger client reset
    TriggerClientEvent('supply:forceJobReset', targetId)
    
    -- Server-side cleanup
    MySQL.Async.execute([[
        UPDATE supply_orders 
        SET status = 'pending' 
        WHERE status = 'accepted' AND order_group_id IN (
            SELECT order_group_id FROM supply_orders WHERE owner_id = ?
        )
    ]], {targetId})
    
    -- Remove from teams
    MySQL.Async.execute('DELETE FROM supply_team_members WHERE citizenid = ?', {citizenid})
    
    -- Notify
    if src == 0 then
        print('[SUPPLY] Job reset for: ' .. targetName)
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = '✅ Job Reset',
            description = 'Reset complete for ' .. targetName,
            type = 'success',
            duration = 8000
        })
    end
    
    TriggerClientEvent('ox_lib:notify', targetId, {
        title = '🔄 Job Reset',
        description = 'Your job has been reset by an admin',
        type = 'info',
        duration = 8000
    })
end, false)

-- Test command
RegisterCommand('supplytest', function(source, args, rawCommand)
    if source == 0 then
        print("Use this command in-game")
        return
    end
    
    local adminLevel = getAdminLevel(source)
    local xPlayer = QBCore.Functions.GetPlayer(source)
    
    if not xPlayer then return end
    
    local identifiers = GetPlayerIdentifiers(source)
    local license2 = nil
    
    for _, id in pairs(identifiers) do
        if string.sub(id, 1, 9) == "license2:" then
            license2 = id
            break
        end
    end
    
    TriggerClientEvent('ox_lib:notify', source, {
        title = '🔍 Permission Test',
        description = string.format([[
**Your Admin Level:** %s
**License2:** %s
**Job:** %s (Grade %s)

To add yourself as admin:
`["%s"] = "admin",`]],
            adminLevel or "None",
            license2 and "Found" or "Not Found",
            xPlayer.PlayerData.job.name,
            xPlayer.PlayerData.job.grade.level,
            license2 or "N/A"
        ),
        type = 'info',
        duration = 20000,
        position = 'top',
        markdown = true
    })
    
    if license2 then
        print(string.format('[ADMIN] %s license2: %s', GetPlayerName(source), license2))
    end
end, false)

-- Direct admin check command
RegisterCommand('supplyadmincheck', function(source, args, rawCommand)
    if source == 0 then
        print("Use this command in-game")
        return
    end
    
    local adminLevel = getAdminLevel(source)
    local hasPerm = hasAdminPermission(source, 'moderator')
    
    print(string.format('[ADMIN CHECK] Player: %s | Level: %s | Has Permission: %s',
        GetPlayerName(source),
        adminLevel or 'none',
        hasPerm and 'YES' or 'NO'
    ))
    
    TriggerClientEvent('ox_lib:notify', source, {
        title = '🔍 Admin Check',
        description = string.format(
            '**Admin Level:** %s\n**Has Permission:** %s\n\nCheck server console for details.',
            adminLevel or 'None',
            hasPerm and '✅ YES' or '❌ NO'
        ),
        type = hasPerm and 'success' or 'error',
        duration = 10000,
        markdown = true
    })
end, false)

-- Emergency restart (superadmin only)
RegisterCommand('supplyemergencyrestart', function(source, args, rawCommand)
    if source ~= 0 and not hasAdminPermission(source, 'superadmin') then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Access Denied',
            description = 'Superadmin required',
            type = 'error',
            duration = 5000
        })
        return
    end
    
    print('[ADMIN] EMERGENCY RESTART INITIATED')
    
    -- Reset all active orders
    MySQL.Async.execute("UPDATE supply_orders SET status = 'pending' WHERE status = 'accepted'", {})
    
    -- Clear all teams
    MySQL.Async.execute("DELETE FROM supply_team_members", {})
    MySQL.Async.execute("DELETE FROM supply_team_deliveries WHERE status = 'active'", {})
    
    -- Force reset all online players
    local players = QBCore.Functions.GetPlayers()
    for _, playerId in ipairs(players) do
        TriggerClientEvent('supply:forceJobReset', playerId)
    end
    
    -- Notify
    TriggerClientEvent('ox_lib:notify', -1, {
        title = '🚨 System Restart',
        description = 'Supply chain system has been restarted',
        type = 'warning',
        duration = 10000
    })
    
    print('[ADMIN] Emergency restart completed')
end, false)

-- ===============================================
-- INITIALIZATION
-- ===============================================

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print('================================================')
        print('[ADMIN] Supply Chain Admin System v2.0.1 REFINED')
        print('[ADMIN] Database Fix Applied - No acknowledged column required')
        print('[ADMIN] Commands: /supply, /supplyjobreset, /supplytest')
        print('[ADMIN] Quick Access: /supplyadmin, /supplyreset')
        print('[ADMIN] Debug Mode: ' .. (debugMode and 'ON' or 'OFF'))
        print('================================================')
    end
end)

-- Command suggestions
TriggerEvent('chat:addSuggestion', '/supply', 'Supply Chain Admin Menu')
TriggerEvent('chat:addSuggestion', '/supplyjobreset', 'Reset player job', {
    { name = 'playerid', help = 'Player ID (optional)' }
})
TriggerEvent('chat:addSuggestion', '/supplytest', 'Test admin permissions')
TriggerEvent('chat:addSuggestion', '/supplyadmincheck', 'Direct admin permission check')
TriggerEvent('chat:addSuggestion', '/supplyadmin', 'Quick admin menu access')
TriggerEvent('chat:addSuggestion', '/supplyreset', 'Quick troubleshooting menu')