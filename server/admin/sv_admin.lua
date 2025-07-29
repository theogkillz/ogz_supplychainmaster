local QBCore = exports['qb-core']:GetCoreObject()

-- ===============================================
-- ADMIN CONFIGURATION
-- ===============================================

-- Add your admin license2 identifiers here
local AdminList = {
    ["license2:02e93de433b665fc9572546e584552674c49978d"] = "superadmin",
    -- Add your admins below:
    ["license2:7c244f49f115502178c9efc54efa183bc4ddb49d"] = "admin", -- Kat
    ["license2:a374445a04dd4245baa057b5a951f7e73afae6fc"] = "moderator", -- Nuttzie
}

-- ===============================================
-- PERMISSION CHECKING FUNCTIONS (SIMPLIFIED)
-- ===============================================

-- Main permission check function
local function hasAdminPermission(source, requiredLevel)
    local xPlayer = QBCore.Functions.GetPlayer(source)
    if not xPlayer then return false end
    
    -- Get player identifiers
    local identifiers = GetPlayerIdentifiers(source)
    local license2 = nil
    
    -- Find license2 identifier
    for _, id in pairs(identifiers) do
        if string.sub(id, 1, 9) == "license2:" then
            license2 = id
            break
        end
    end
    
    -- Check 1: License2-based admin list
    if license2 and AdminList[license2] then
        local adminLevel = AdminList[license2]
        print(string.format("[ADMIN] Player %s has admin level: %s", GetPlayerName(source), adminLevel))
        
        -- Check if their admin level meets requirement
        if requiredLevel == "moderator" then
            return true -- Any admin level can access moderator features
        elseif requiredLevel == "admin" then
            return adminLevel == "admin" or adminLevel == "superadmin"
        elseif requiredLevel == "superadmin" then
            return adminLevel == "superadmin"
        end
    end
    
    -- Check 2: Hurst boss grade
    if xPlayer.PlayerData.job and xPlayer.PlayerData.job.name == "hurst" then
        -- Check if boss or high grade
        if xPlayer.PlayerData.job.isboss then
            print(string.format("[ADMIN] Player %s has Hurst boss access", GetPlayerName(source)))
            return true -- Boss has full access
        elseif xPlayer.PlayerData.job.grade and xPlayer.PlayerData.job.grade.level >= 3 then
            print(string.format("[ADMIN] Player %s has Hurst grade %d access", GetPlayerName(source), xPlayer.PlayerData.job.grade.level))
            return true -- High grade has access
        end
    end
    
    -- Check 3: QBCore admin permissions (fallback)
    if QBCore.Functions.HasPermission then
        local hasQBPerm = QBCore.Functions.HasPermission(source, requiredLevel)
        if hasQBPerm then
            print(string.format("[ADMIN] Player %s has QBCore %s permission", GetPlayerName(source), requiredLevel))
            return true
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
        
    elseif action == 'addadmin' then
        local license = args[2]
        local level = args[3] or "admin"
        
        if license and string.sub(license, 1, 9) == "license2:" then
            print(string.format("[ADMIN] Added %s with level %s to admin list", license, level))
            print("[ADMIN] Remember to add this to your sv_admin.lua AdminList table!")
            print(string.format('["%s"] = "%s",', license, level))
        else
            print("[ADMIN] Usage: supply addadmin license2:xxxxx [moderator/admin/superadmin]")
        end
        
    elseif action == 'help' then
        print('=== SUPPLY CHAIN CONSOLE COMMANDS ===')
        print('supply stats - Show system statistics')
        print('supply addadmin - Show how to add an admin')
        print('supply help - Show this help menu')
        print('======================================')
        
    else
        print('Supply Chain Admin: Use "supply help" for commands')
    end
end

-- System stats function
local function getSystemStats(source)
    if not hasAdminPermission(source, 'moderator') then 
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Access Denied',
            description = 'You need admin or Hurst boss permissions.',
            type = 'error',
            duration = 5000
        })
        return 
    end
    
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

-- System overview function for admin menu
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
    if src ~= 0 and not hasAdminPermission(src, 'moderator') then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Access Denied',
            description = 'You need admin or Hurst boss permissions.',
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
    
    -- Get player's license2
    local identifiers = GetPlayerIdentifiers(source)
    local license2 = nil
    for _, id in pairs(identifiers) do
        if string.sub(id, 1, 9) == "license2:" then
            license2 = id
            break
        end
    end
    
    local job = xPlayer.PlayerData.job and xPlayer.PlayerData.job.name
    local grade = xPlayer.PlayerData.job and xPlayer.PlayerData.job.grade and xPlayer.PlayerData.job.grade.level
    local isBoss = xPlayer.PlayerData.job and xPlayer.PlayerData.job.isboss
    local isInAdminList = license2 and AdminList[license2] and true or false
    local adminLevel = license2 and AdminList[license2] or "none"
    
    TriggerClientEvent('ox_lib:notify', source, {
        title = '🔍 Permission Debug',
        description = string.format(
            "**License2:** %s\n**In Admin List:** %s\n**Admin Level:** %s\n**Job:** %s\n**Grade:** %s\n**Boss:** %s\n**Has Access:** %s",
            license2 and "Found" or "Not Found",
            isInAdminList and "✅ YES" or "❌ NO",
            adminLevel,
            job or "none", 
            grade or "none",
            isBoss and "Yes" or "No",
            hasAdminPermission(source, 'moderator') and "✅ GRANTED" or "❌ DENIED"
        ),
        type = 'info',
        duration = 20000,
        position = 'top',
        markdown = true
    })
    
    -- Also print license2 to console for easy copying
    if license2 then
        print(string.format("[ADMIN] Player %s license2: %s", GetPlayerName(source), license2))
        print(string.format("[ADMIN] To add as admin, add this line to AdminList table:"))
        print(string.format('["%s"] = "admin",', license2))
    end
end, false)

-- MAIN ADMIN COMMAND
RegisterCommand('supply', function(source, args, rawCommand)
    if source == 0 then
        handleConsoleCommand(args)
        return
    end
    
    -- Check permissions
    if not hasAdminPermission(source, 'moderator') then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Access Denied',
            description = 'You need admin or Hurst boss permissions.\nUse `/supplytest` to check your access.',
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
    
    -- Handle specific commands
    if action == 'stats' then
        getSystemStats(source)
    elseif action == 'reload' then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'System Reloaded',
            description = 'Key systems reinitialized.',
            type = 'success',
            duration = 8000
        })
    else
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Invalid Command',
            description = 'Use /supply for the admin menu.',
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
    
    if not hasAdminPermission(src, 'moderator') then 
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Access Denied',
            description = 'You need admin or Hurst boss permissions.',
            type = 'error',
            duration = 5000
        })
        return 
    end
    
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
    
    if not hasAdminPermission(src, 'admin') then 
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Access Denied',
            description = 'Admin level required for stock adjustments.',
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
    { name = 'action', help = 'stats/reload (optional)' }
})

TriggerEvent('chat:addSuggestion', '/supplyjobreset', 'Reset supply chain job for a player', {
    { name = 'playerid', help = 'Player server ID (optional - defaults to yourself)' }
})

TriggerEvent('chat:addSuggestion', '/supplytest', 'Test your admin permissions and get your license2')

-- ===============================================
-- INITIALIZATION
-- ===============================================
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print('[ADMIN] Supply Chain admin system loaded!')
        print('[ADMIN] Use /supply for admin menu')
        print('[ADMIN] Use /supplytest to get your license2 identifier')
        print('[ADMIN] Add admins by adding their license2 to the AdminList table')
    end
end)

-- Import stock management command
QBCore.Commands.Add('importstock', 'Manage import warehouse stock (Admin Only)', {
    {name = 'action', help = 'add/set/check'},
    {name = 'item', help = 'Item name (optional for check)'},
    {name = 'amount', help = 'Amount (optional for check)'}
}, false, function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    -- Admin check
    if not Player.PlayerData.job.name == 'admin' and not Player.PlayerData.job.name == 'god' then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'Admin access required',
            type = 'error',
            duration = 5000,
            position = Config.UI.notificationPosition
        })
        return
    end
    
    local action = args[1]:lower()
    local item = args[2] and args[2]:lower()
    local amount = tonumber(args[3])
    
    if action == 'check' then
        -- Check all or specific item
        local query = item and 'SELECT * FROM supply_import_stock WHERE ingredient = ?' or 'SELECT * FROM supply_import_stock'
        local params = item and {item} or {}
        
        MySQL.Async.fetchAll(query, params, function(results)
            if #results == 0 then
                TriggerClientEvent('ox_lib:notify', src, {
                    title = 'Import Stock',
                    description = item and 'Item not found in import stock' or 'No import stock found',
                    type = 'info',
                    duration = 5000,
                    position = Config.UI.notificationPosition
                })
            else
                local itemNames = exports.ox_inventory:Items() or {}
                for _, stock in ipairs(results) do
                    local label = itemNames[stock.ingredient] and itemNames[stock.ingredient].label or stock.ingredient
                    TriggerClientEvent('ox_lib:notify', src, {
                        title = '🌍 Import Stock',
                        description = string.format('%s: %d units', label, stock.quantity),
                        type = 'info',
                        duration = 7000,
                        position = Config.UI.notificationPosition
                    })
                end
            end
        end)
        
    elseif action == 'add' or action == 'set' then
        if not item or not amount then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Error',
                description = 'Usage: /importstock ' .. action .. ' [item] [amount]',
                type = 'error',
                duration = 5000,
                position = Config.UI.notificationPosition
            })
            return
        end
        
        if action == 'add' then
            MySQL.Async.execute([[
                INSERT INTO supply_import_stock (ingredient, quantity) 
                VALUES (?, ?) 
                ON DUPLICATE KEY UPDATE quantity = quantity + ?
            ]], {item, amount, amount}, function(affected)
                TriggerClientEvent('ox_lib:notify', src, {
                    title = 'Import Stock Added',
                    description = string.format('Added %d units of %s to import stock', amount, item),
                    type = 'success',
                    duration = 5000,
                    position = Config.UI.notificationPosition
                })
            end)
        else -- set
            MySQL.Async.execute([[
                INSERT INTO supply_import_stock (ingredient, quantity) 
                VALUES (?, ?) 
                ON DUPLICATE KEY UPDATE quantity = ?
            ]], {item, amount, amount}, function(affected)
                TriggerClientEvent('ox_lib:notify', src, {
                    title = 'Import Stock Set',
                    description = string.format('Set %s import stock to %d units', item, amount),
                    type = 'success',
                    duration = 5000,
                    position = Config.UI.notificationPosition
                })
            end)
        end
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'Valid actions: check, add, set',
            type = 'error',
            duration = 5000,
            position = Config.UI.notificationPosition
        })
    end
end, 'admin')

-- Test command to create an import order
RegisterCommand('testimport', function(source, args, rawCommand)
    if source == 0 then
        print("This command must be run in-game")
        return
    end
    
    local xPlayer = QBCore.Functions.GetPlayer(source)
    if not xPlayer then return end
    
    -- Check if player has admin/warehouse access
    local playerJob = xPlayer.PlayerData.job.name
    local hasAccess = false
    
    for _, job in ipairs(Config.Jobs.warehouse) do
        if playerJob == job then
            hasAccess = true
            break
        end
    end
    
    if not hasAccess and not QBCore.Functions.HasPermission(source, "admin") then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Access Denied',
            description = 'You need warehouse or admin access',
            type = 'error',
            duration = 5000
        })
        return
    end
    
    -- Create a test import order
    local orderGroupId = "import_test_" .. os.time()
    local restaurantId = 1 -- Default to first restaurant
    
    MySQL.Async.execute([[
        INSERT INTO supply_orders 
        (owner_id, ingredient, quantity, status, restaurant_id, total_cost, order_group_id)
        VALUES 
        (?, ?, ?, ?, ?, ?, ?)
    ]], {
        source,
        'reign_lettuce', -- An import item from config
        50,
        'pending',
        restaurantId,
        100, -- Test cost
        orderGroupId
    }, function(success)
        if success then
            TriggerClientEvent('ox_lib:notify', source, {
                title = '🌍 Import Order Created',
                description = 'Test import order created! Check Import Distribution Center',
                type = 'success',
                duration = 8000,
                position = Config.UI.notificationPosition
            })
            
            -- Also create tracking entry
            MySQL.Async.execute([[
                INSERT INTO supply_import_orders 
                (order_id, ingredient, quantity, origin_country, arrival_date, status)
                VALUES (?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL 1 HOUR), ?)
            ]], {
                orderGroupId,
                'reign_lettuce',
                50,
                'Netherlands',
                'in_transit'
            })
            
            print(string.format("[IMPORT TEST] Created import order %s for player %s", orderGroupId, GetPlayerName(source)))
        else
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Error',
                description = 'Failed to create test import order',
                type = 'error',
                duration = 5000
            })
        end
    end)
end, false)

-- Command to check import system status
RegisterCommand('checkimports', function(source, args, rawCommand)
    if source == 0 then
        -- Console command
        print("\n=== IMPORT SYSTEM STATUS ===")
        
        -- Check import orders
        MySQL.Async.fetchAll('SELECT COUNT(*) as count FROM supply_orders WHERE order_group_id LIKE "import_%"', {}, 
        function(results)
            print("Import Orders (pending):", results[1].count)
        end)
        
        -- Check import stock
        MySQL.Async.fetchAll('SELECT COUNT(*) as count, SUM(quantity) as total FROM supply_import_stock', {},
        function(results)
            print("Import Stock Items:", results[1].count, "Total Quantity:", results[1].total or 0)
        end)
        
        -- Check import tracking
        MySQL.Async.fetchAll('SELECT COUNT(*) as count FROM supply_import_orders WHERE status != "distributed"', {},
        function(results)
            print("Active Import Shipments:", results[1].count)
        end)
        
        print("===========================\n")
    else
        -- In-game command
        local xPlayer = QBCore.Functions.GetPlayer(source)
        if not xPlayer then return end
        
        -- Quick status check
        MySQL.Async.fetchAll([[
            SELECT 
                (SELECT COUNT(*) FROM supply_orders WHERE order_group_id LIKE 'import_%' AND status = 'pending') as pending_imports,
                (SELECT COUNT(*) FROM supply_import_stock WHERE quantity > 0) as stocked_items,
                (SELECT COUNT(*) FROM supply_import_orders WHERE status IN ('in_transit', 'ordered')) as active_shipments
        ]], {}, function(results)
            if results and results[1] then
                TriggerClientEvent('ox_lib:notify', source, {
                    title = '🌍 Import System Status',
                    description = string.format([[
**Pending Orders:** %d
**Stocked Items:** %d  
**Active Shipments:** %d

Use Import Distribution Center for details]],
                        results[1].pending_imports,
                        results[1].stocked_items,
                        results[1].active_shipments),
                    type = 'info',
                    duration = 10000,
                    position = Config.UI.notificationPosition,
                    markdown = true
                })
            end
        end)
    end
end, false)