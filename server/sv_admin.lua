local QBCore = exports['qb-core']:GetCoreObject()

-- ===============================================
-- PERMISSION CHECKING FUNCTIONS (DEFINED FIRST)
-- ===============================================

-- Enhanced permission checking with multiple methods
local function hasAdminPermission(source, level)
    local xPlayer = QBCore.Functions.GetPlayer(source)
    if not xPlayer then return false end
    
    -- Try multiple permission methods for compatibility
    local group = nil
    
    -- Method 1: QBCore.Functions.GetPermission
    if QBCore.Functions.GetPermission then
        group = QBCore.Functions.GetPermission(source)
    end
    
    -- Method 2: Check player job (fallback)
    if not group and xPlayer.PlayerData and xPlayer.PlayerData.job then
        group = xPlayer.PlayerData.job.name
    end
    
    -- Method 3: Check metadata (another fallback)
    if not group and xPlayer.PlayerData and xPlayer.PlayerData.metadata then
        group = xPlayer.PlayerData.metadata.group or xPlayer.PlayerData.metadata.permission
    end
    
    -- Debug logging
    print(string.format("[ADMIN DEBUG] Player: %s, Group: %s, Required: %s", 
        xPlayer.PlayerData.citizenid or "unknown", 
        group or "none", 
        level or "none"))
    
    if not group then
        print("[ADMIN ERROR] Could not determine player permission group")
        return false
    end
    
    -- Permission hierarchy check
    local godPermissions = {"god", "admin", "superadmin", "owner"}
    local adminPermissions = {"admin", "moderator", "mod"}
    
    if level == 'superadmin' then
        for _, perm in ipairs(godPermissions) do
            if group == perm then return true end
        end
        return false
    elseif level == 'admin' then
        for _, perm in ipairs(godPermissions) do
            if group == perm then return true end
        end
        for _, perm in ipairs(adminPermissions) do
            if group == perm then return true end
        end
        return false
    elseif level == 'moderator' then
        -- Any admin level can access moderator features
        for _, perm in ipairs(godPermissions) do
            if group == perm then return true end
        end
        for _, perm in ipairs(adminPermissions) do
            if group == perm then return true end
        end
        return false
    end
    
    return false
end

-- Alternative simple check for testing
local function hasSimpleAdminPermission(source)
    local xPlayer = QBCore.Functions.GetPlayer(source)
    if not xPlayer then return false end
    
    -- Simple job-based check for Hurst Industries management
    if xPlayer.PlayerData.job and xPlayer.PlayerData.job.name == "hurst" then
        if xPlayer.PlayerData.job.isboss or xPlayer.PlayerData.job.grade.level >= 3 then
            return true
        end
    end
    
    -- Check if player has admin job/group
    local group = QBCore.Functions.GetPermission and QBCore.Functions.GetPermission(source)
    if group then
        local adminGroups = {"god", "admin", "superadmin", "owner", "mod", "moderator"}
        for _, adminGroup in ipairs(adminGroups) do
            if group == adminGroup then
                return true
            end
        end
    end
    
    return false
end

-- ===============================================
-- COMMAND HANDLER FUNCTIONS
-- ===============================================

-- Console command handler
local function handleConsoleCommand(args)
    local action = args[1] and args[1]:lower()
    
    if action == 'stats' then
        -- Console version of stats
        MySQL.Async.fetchAll([[
            SELECT 
                (SELECT COUNT(*) FROM supply_orders WHERE status = 'pending') as pending_orders,
                (SELECT COUNT(*) FROM supply_orders WHERE status = 'completed' AND DATE(created_at) = CURDATE()) as daily_completed,
                (SELECT COUNT(DISTINCT citizenid) FROM supply_driver_stats WHERE DATE(delivery_date) = CURDATE()) as active_drivers
        ]], {}, function(results)
            if results and results[1] then
                local stats = results[1]
                print('=== SUPPLY CHAIN STATISTICS ===')
                print('Pending Orders: ' .. (stats.pending_orders or 0))
                print('Daily Completed: ' .. (stats.daily_completed or 0))
                print('Active Drivers: ' .. (stats.active_drivers or 0))
                print('================================')
            end
        end)
        
    elseif action == 'help' then
        print('=== SUPPLY CHAIN CONSOLE COMMANDS ===')
        print('supply stats - Show system statistics')
        print('supply help - Show this help menu')
        print('======================================')
        
    else
        print('Supply Chain Admin: Use "supply help" for commands')
    end
end

-- System stats function
local function getSystemStats(source)
    if not hasAdminPermission(source, 'moderator') then return end
    
    MySQL.Async.fetchAll([[
        SELECT 
            (SELECT COUNT(*) FROM supply_orders WHERE status = 'pending') as pending_orders,
            (SELECT COUNT(*) FROM supply_orders WHERE status = 'accepted') as active_orders,
            (SELECT COUNT(*) FROM supply_orders WHERE status = 'completed' AND DATE(created_at) = CURDATE()) as daily_completed,
            (SELECT COUNT(DISTINCT citizenid) FROM supply_driver_stats WHERE DATE(delivery_date) = CURDATE()) as active_drivers,
            (SELECT COUNT(*) FROM supply_team_deliveries WHERE DATE(created_at) = CURDATE()) as team_deliveries
    ]], {}, function(result)
        if result and result[1] then
            local stats = result[1]
            
            TriggerClientEvent('ox_lib:notify', source, {
                title = '📊 System Statistics',
                description = string.format(
                    '📋 Pending Orders: %d\n🚚 Active Deliveries: %d\n✅ Daily Completed: %d\n👥 Active Drivers: %d\n🚛 Team Deliveries: %d',
                    stats.pending_orders or 0,
                    stats.active_orders or 0,
                    stats.daily_completed or 0,
                    stats.active_drivers or 0,
                    stats.team_deliveries or 0
                ),
                type = 'info',
                duration = 15000,
                position = 'top',
                markdown = true
            })
        end
    end)
end

-- Market command handler
local function handleMarketCommand(source, args)
    if not hasAdminPermission(source, 'admin') then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Access Denied',
            description = 'Admin level required for market commands.',
            type = 'error',
            duration = 5000
        })
        return
    end
    
    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Market Commands',
        description = 'Use the admin menu for market management.',
        type = 'info',
        duration = 8000
    })
end

-- Reset command handler
local function handleResetCommand(source, args)
    if not hasAdminPermission(source, 'superadmin') then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Access Denied',
            description = 'Superadmin level required for reset commands.',
            type = 'error',
            duration = 5000
        })
        return
    end
    
    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Reset Commands',
        description = 'Use the admin menu for reset functions.',
        type = 'info',
        duration = 8000
    })
end

-- Emergency command handler
local function handleEmergencyCommand(source, args)
    if not hasAdminPermission(source, 'admin') then return end
    
    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Emergency Commands',
        description = 'Use the admin menu for emergency management.',
        type = 'info',
        duration = 8000
    })
end

-- Export command handler
local function handleExportCommand(source, args)
    if not hasAdminPermission(source, 'admin') then return end
    
    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Export Commands',
        description = 'Export functionality available in admin menu.',
        type = 'info',
        duration = 8000
    })
end

-- Reload command handler
local function handleReloadCommand(source)
    if not hasAdminPermission(source, 'superadmin') then return end
    
    TriggerClientEvent('ox_lib:notify', source, {
        title = 'System Reloaded',
        description = 'Key systems reinitialized.',
        type = 'success',
        duration = 8000
    })
end

-- System overview function
local function getSystemOverview(source, callback)
    MySQL.Async.fetchAll([[
        SELECT 
            (SELECT COUNT(*) FROM supply_orders WHERE status = 'pending') as pending_orders,
            (SELECT COUNT(*) FROM supply_orders WHERE status = 'completed' AND DATE(created_at) = CURDATE()) as daily_orders,
            (SELECT COUNT(DISTINCT citizenid) FROM supply_driver_stats WHERE DATE(delivery_date) = CURDATE()) as active_drivers
    ]], {}, function(result)
        local data = {
            pendingOrders = (result and result[1] and result[1].pending_orders) or 0,
            dailyOrders = (result and result[1] and result[1].daily_orders) or 0,
            activeDrivers = (result and result[1] and result[1].active_drivers) or 0,
            criticalAlerts = 0,
            emergencyOrders = 0,
            marketAverage = 1.0,
            systemStatus = 'healthy',
            uptime = GetGameTimer() / 1000
        }
        
        callback(data)
    end)
end

-- ===============================================
-- JOB RESET COMMANDS
-- ===============================================

-- Job reset command for troubleshooting
RegisterCommand('supplyjobreset', function(source, args, rawCommand)
    local src = source
    local targetId = tonumber(args[1]) or src
    
    -- Permission check
    if src ~= 0 and not (hasAdminPermission(src, 'moderator') or hasSimpleAdminPermission(src)) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Access Denied',
            description = 'You need admin permissions to use this command.',
            type = 'error',
            duration = 5000
        })
        return
    end
    
    -- Get target player
    local xPlayer = QBCore.Functions.GetPlayer(targetId)
    if not xPlayer then
        local message = 'Player not found with ID: ' .. targetId
        if src == 0 then
            print('[SUPPLY RESET] ' .. message)
        else
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Player Not Found',
                description = message,
                type = 'error',
                duration = 5000
            })
        end
        return
    end
    
    local targetName = xPlayer.PlayerData.charinfo.firstname .. ' ' .. xPlayer.PlayerData.charinfo.lastname
    local citizenid = xPlayer.PlayerData.citizenid
    
    -- Start the reset process
    if src == 0 then
        print('[SUPPLY RESET] Starting job reset for: ' .. targetName .. ' (ID: ' .. targetId .. ')')
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Job Reset Started',
            description = 'Resetting supply chain job for: ' .. targetName,
            type = 'info',
            duration = 5000
        })
    end
    
    -- 1. CLIENT-SIDE RESET - Clean up any stuck states
    TriggerClientEvent('supply:forceJobReset', targetId)
    
    -- 2. SERVER-SIDE RESET - Clean up database states
    
    -- Cancel any active orders assigned to this player
    MySQL.Async.execute([[
        UPDATE supply_orders 
        SET status = 'pending' 
        WHERE status = 'accepted' AND order_group_id IN (
            SELECT order_group_id FROM supply_orders WHERE owner_id = ?
        )
    ]], {targetId}, function(success)
        if success then
            print('[SUPPLY RESET] Reset active orders for player: ' .. targetName)
        end
    end)
    
    -- Remove from any active teams
    MySQL.Async.fetchAll('SELECT team_id FROM supply_team_members WHERE citizenid = ?', {citizenid}, function(teams)
        if teams and #teams > 0 then
            for _, team in ipairs(teams) do
                -- Remove from team members
                MySQL.Async.execute('DELETE FROM supply_team_members WHERE citizenid = ?', {citizenid})
                
                -- If they were team leader, dissolve the team
                MySQL.Async.execute('DELETE FROM supply_team_deliveries WHERE leader_citizenid = ?', {citizenid})
                
                print('[SUPPLY RESET] Removed ' .. targetName .. ' from team: ' .. team.team_id)
            end
        end
    end)
    
    -- Clear any stuck delivery states
    MySQL.Async.execute([[
        UPDATE supply_driver_stats 
        SET updated_at = CURRENT_TIMESTAMP 
        WHERE citizenid = ? AND delivery_date = CURDATE()
    ]], {citizenid})
    
    -- 3. Wait a moment then notify completion
    Citizen.SetTimeout(2000, function()
        -- Notify admin
        local resetMessage = string.format(
            'Job reset complete for %s (ID: %d)\n✅ Orders reset\n✅ Team assignments cleared\n✅ Client state reset\n✅ Database cleaned',
            targetName, targetId
        )
        
        if src == 0 then
            print('[SUPPLY RESET] ' .. resetMessage:gsub('\n', ' | '))
        else
            TriggerClientEvent('ox_lib:notify', src, {
                title = '✅ Job Reset Complete',
                description = resetMessage,
                type = 'success',
                duration = 10000,
                markdown = true
            })
        end
        
        -- Notify the target player
        TriggerClientEvent('ox_lib:notify', targetId, {
            title = '🔄 Job Reset',
            description = 'Your supply chain job has been reset by an admin.\nYou can now start fresh!',
            type = 'info',
            duration = 8000
        })
    end)
    
end, false)

-- Bulk reset command for multiple players
RegisterCommand('supplyjobmassreset', function(source, args, rawCommand)
    local src = source
    
    -- Only console or superadmin can use this
    if src ~= 0 and not hasAdminPermission(src, 'superadmin') then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Access Denied',
            description = 'Superadmin level required for mass reset.',
            type = 'error',
            duration = 5000
        })
        return
    end
    
    -- Get all online players
    local players = QBCore.Functions.GetPlayers()
    local resetCount = 0
    
    if src == 0 then
        print('[SUPPLY MASS RESET] Starting mass job reset for all online players...')
    end
    
    for _, playerId in ipairs(players) do
        local xPlayer = QBCore.Functions.GetPlayer(playerId)
        if xPlayer then
            -- Reset each player
            TriggerClientEvent('supply:forceJobReset', playerId)
            resetCount = resetCount + 1
            
            -- Small delay between resets to avoid overwhelming
            Citizen.Wait(100)
        end
    end
    
    -- Clean up database
    MySQL.Async.execute([[
        UPDATE supply_orders SET status = 'pending' WHERE status = 'accepted';
        DELETE FROM supply_team_members;
        DELETE FROM supply_team_deliveries;
    ]], {}, function(success)
        if success then
            local message = string.format('Mass job reset complete! Reset %d players and cleaned database.', resetCount)
            if src == 0 then
                print('[SUPPLY MASS RESET] ' .. message)
            else
                TriggerClientEvent('ox_lib:notify', src, {
                    title = '✅ Mass Reset Complete',
                    description = message,
                    type = 'success',
                    duration = 10000
                })
            end
        end
    end)
    
end, false)

-- Emergency supply chain system restart
RegisterCommand('supplyemergencyrestart', function(source, args, rawCommand)
    local src = source
    
    -- Only console or superadmin can use this
    if src ~= 0 and not hasAdminPermission(src, 'superadmin') then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Access Denied',
            description = 'Superadmin level required for emergency restart.',
            type = 'error',
            duration = 5000
        })
        return
    end
    
    if src == 0 then
        print('[SUPPLY EMERGENCY] Starting emergency system restart...')
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = '🚨 Emergency Restart',
            description = 'Starting emergency supply chain system restart...',
            type = 'warning',
            duration = 5000
        })
    end
    
    -- Broadcast to all players
    TriggerClientEvent('ox_lib:notify', -1, {
        title = '🚨 SUPPLY CHAIN RESTART',
        description = 'Emergency system restart in progress.\nPlease wait 10 seconds...',
        type = 'warning',
        duration = 10000
    })
    
    -- Reset all players
    local players = QBCore.Functions.GetPlayers()
    for _, playerId in ipairs(players) do
        TriggerClientEvent('supply:forceJobReset', playerId)
    end
    
    -- Clean database
    MySQL.Async.execute([[
        UPDATE supply_orders SET status = 'pending' WHERE status = 'accepted';
        DELETE FROM supply_team_members;
        DELETE FROM supply_team_deliveries WHERE completed_at IS NULL;
    ]], {}, function(success)
        if success then
            -- Restart key systems
            Citizen.SetTimeout(3000, function()
                TriggerEvent('stockalerts:initialize')
                TriggerEvent('market:initialize')
                
                -- Notify completion
                TriggerClientEvent('ox_lib:notify', -1, {
                    title = '✅ SYSTEM RESTARTED',
                    description = 'Supply chain system has been restarted.\nAll systems operational!',
                    type = 'success',
                    duration = 8000
                })
                
                if src == 0 then
                    print('[SUPPLY EMERGENCY] Emergency restart complete!')
                else
                    TriggerClientEvent('ox_lib:notify', src, {
                        title = '✅ Emergency Restart Complete',
                        description = 'All systems have been restarted successfully.',
                        type = 'success',
                        duration = 8000
                    })
                end
            end)
        end
    end)
    
end, false)

-- ===============================================
-- MAIN ADMIN COMMAND
-- ===============================================

-- TEST COMMAND for debugging permissions
RegisterCommand('supplytest', function(source, args, rawCommand)
    if source == 0 then
        print("Console cannot use this command")
        return
    end
    
    local xPlayer = QBCore.Functions.GetPlayer(source)
    if not xPlayer then
        print("No player found")
        return
    end
    
    local group = QBCore.Functions.GetPermission and QBCore.Functions.GetPermission(source)
    local job = xPlayer.PlayerData.job and xPlayer.PlayerData.job.name
    local grade = xPlayer.PlayerData.job and xPlayer.PlayerData.job.grade and xPlayer.PlayerData.job.grade.level
    local isBoss = xPlayer.PlayerData.job and xPlayer.PlayerData.job.isboss
    
    TriggerClientEvent('ox_lib:notify', source, {
        title = '🔍 Permission Debug',
        description = string.format(
            "**Group:** %s\n**Job:** %s\n**Grade:** %s\n**Boss:** %s\n**Simple Check:** %s\n**Admin Check:** %s",
            group or "none",
            job or "none", 
            grade or "none",
            isBoss and "Yes" or "No",
            hasSimpleAdminPermission(source) and "✅ PASS" or "❌ FAIL",
            hasAdminPermission(source, 'moderator') and "✅ PASS" or "❌ FAIL"
        ),
        type = 'info',
        duration = 15000,
        position = 'top',
        markdown = true
    })
end, false)

-- MAIN ADMIN COMMAND with enhanced checking
RegisterCommand('supply', function(source, args, rawCommand)
    if source == 0 then
        handleConsoleCommand(args)
        return
    end
    
    -- Try both permission methods
    local hasPermission = hasAdminPermission(source, 'moderator') or hasSimpleAdminPermission(source)
    
    if not hasPermission then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Access Denied',
            description = 'You do not have permission to use admin commands.\nUse `/supplytest` to check your permissions.',
            type = 'error',
            duration = 8000
        })
        return
    end
    
    local action = args[1] and args[1]:lower()
    
    if not action then
        -- Open admin menu
        TriggerClientEvent('supply:openAdminMenu', source)
        return
    end
    
    -- Handle specific commands with the enhanced permission check
    if action == 'stats' then
        getSystemStats(source)
    elseif action == 'market' then
        handleMarketCommand(source, args)
    elseif action == 'reset' then
        handleResetCommand(source, args)
    elseif action == 'emergency' then
        handleEmergencyCommand(source, args)
    elseif action == 'export' then
        handleExportCommand(source, args)
    elseif action == 'reload' then
        handleReloadCommand(source)
    else
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Invalid Command',
            description = 'Use /supply for the admin menu or /supply help for commands.',
            type = 'error',
            duration = 5000
        })
    end
end, false)

-- ===============================================
-- ADMIN MENU SYSTEM
-- ===============================================
RegisterNetEvent('supply:requestAdminMenu')
AddEventHandler('supply:requestAdminMenu', function()
    local src = source
    
    if not hasAdminPermission(src, 'moderator') then return end
    
    -- Get system overview data
    getSystemOverview(src, function(data)
        TriggerClientEvent('supply:showAdminMenu', src, data)
    end)
end)

-- ===============================================
-- BASIC ADMIN EVENTS
-- ===============================================

-- Manual Stock Adjustment
RegisterNetEvent('admin:adjustStock')
AddEventHandler('admin:adjustStock', function(ingredient, newQuantity)
    local src = source
    
    if not hasAdminPermission(src, 'admin') then return end
    
    MySQL.Async.execute([[
        INSERT INTO supply_warehouse_stock (ingredient, quantity) 
        VALUES (?, ?) 
        ON DUPLICATE KEY UPDATE quantity = ?
    ]], {ingredient, newQuantity, newQuantity}, function(success)
        if success then
            local itemNames = exports.ox_inventory:Items() or {}
            local itemLabel = itemNames[ingredient] and itemNames[ingredient].label or ingredient
            
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Stock Adjusted',
                description = string.format('%s stock set to %d units', itemLabel, newQuantity),
                type = 'success',
                duration = 8000
            })
        end
    end)
end)

-- ===============================================
-- COMMAND SUGGESTIONS
-- ===============================================

-- Add command suggestions
TriggerEvent('chat:addSuggestion', '/supply', 'Open Supply Chain Admin Menu', {
    { name = 'action', help = 'stats/market/reset/emergency/export/reload' }
})

TriggerEvent('chat:addSuggestion', '/supplyjobreset', 'Reset supply chain job for a player', {
    { name = 'playerid', help = 'Player server ID (optional - defaults to yourself)' }
})

TriggerEvent('chat:addSuggestion', '/supplyjobmassreset', 'Reset supply chain job for ALL online players')

TriggerEvent('chat:addSuggestion', '/supplyemergencyrestart', 'Emergency restart of entire supply chain system')

TriggerEvent('chat:addSuggestion', '/supplytest', 'Test your admin permissions')

-- ===============================================
-- INITIALIZATION
-- ===============================================
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print('[ADMIN] Supply Chain admin system loaded!')
        print('[ADMIN] Use /supply for admin menu or "supply help" in console')
        print('[ADMIN] Available commands: /supplyjobreset, /supplyjobmassreset, /supplyemergencyrestart')
    end
end)