-- ============================================
-- SERVER-SIDE NPC SURPLUS DETECTION
-- ============================================

-- Add to server/sv_npc_surplus.lua (new file)

local QBCore = exports['qb-core']:GetCoreObject()

-- Validate NPC system access
local function hasNPCAccess(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    
    local playerJob = Player.PlayerData.job.name
    return playerJob == "hurst"
end

-- Active NPC jobs tracking
local activeNPCJobs = {}
local playerNPCCooldowns = {}
local surplusCache = {}
local lastSurplusCheck = 0

-- Get available NPC jobs with validation
RegisterNetEvent('npc:getAvailableJobs')
AddEventHandler('npc:getAvailableJobs', function()
    local src = source
    
    -- Validate job access
    if not hasNPCAccess(src) then
        local Player = QBCore.Functions.GetPlayer(src)
        local currentJob = Player and Player.PlayerData.job.name or "unemployed"
        
        TriggerClientEvent('ox_lib:notify', src, {
            title = '🚫 NPC Access Denied',
            description = 'NPC delivery system restricted to Hurst Industries employees. Current job: ' .. currentJob,
            type = 'error',
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    -- Continue with NPC job logic...
end)

-- Start NPC delivery with validation
RegisterNetEvent('npc:startDeliveryJob')
AddEventHandler('npc:startDeliveryJob', function(ingredientData, restaurantId)
    local src = source
    
    if not hasNPCAccess(src) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = '🚫 NPC Job Access Denied',
            description = 'Only Hurst Industries employees can manage NPC deliveries',
            type = 'error',
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    -- Continue with NPC delivery logic...
end)

-- Get active NPC jobs with validation
RegisterNetEvent('npc:getActiveJobs')
AddEventHandler('npc:getActiveJobs', function()
    local src = source
    
    if not hasNPCAccess(src) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = '🚫 NPC Status Access Denied',
            description = 'NPC job monitoring restricted to Hurst Industries employees',
            type = 'error',
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    -- Continue with active jobs logic...
end)

-- Check current surplus conditions
local function checkSurplusConditions()
    local currentTime = os.time()
    
    -- Cache surplus checks for 5 minutes
    if currentTime - lastSurplusCheck < 300 and next(surplusCache) then
        return surplusCache
    end
    
    local surplusItems = {}
    
    MySQL.Async.fetchAll('SELECT ingredient, quantity FROM supply_warehouse_stock', {}, function(stockData)
        for _, stock in ipairs(stockData) do
            local ingredient = stock.ingredient
            local quantity = stock.quantity
            
            -- Get max stock for this ingredient (default 500 if not configured)
            local maxStock = Config.StockAlerts and Config.StockAlerts.maxStock and 
                           Config.StockAlerts.maxStock[ingredient] or 500
            
            local stockPercentage = (quantity / maxStock) * 100
            
            -- Check which surplus tier this ingredient qualifies for
            local surplusLevel = nil
            if stockPercentage >= Config.NPCDeliverySystem.surplusThresholds.critical_surplus.stockPercentage then
                surplusLevel = "critical_surplus"
            elseif stockPercentage >= Config.NPCDeliverySystem.surplusThresholds.high_surplus.stockPercentage then
                surplusLevel = "high_surplus"
            elseif stockPercentage >= Config.NPCDeliverySystem.surplusThresholds.moderate_surplus.stockPercentage then
                surplusLevel = "moderate_surplus"
            end
            
            if surplusLevel then
                table.insert(surplusItems, {
                    ingredient = ingredient,
                    quantity = quantity,
                    maxStock = maxStock,
                    stockPercentage = stockPercentage,
                    surplusLevel = surplusLevel,
                    threshold = Config.NPCDeliverySystem.surplusThresholds[surplusLevel]
                })
            end
        end
        
        surplusCache = surplusItems
        lastSurplusCheck = currentTime
    end)
    
    return surplusItems
end

-- Check if player can initiate NPC job
local function canPlayerInitiateNPCJob(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false, "Player not found" end
    
    -- Check job access
    if Player.PlayerData.job.name ~= "hurst" then
        return false, "Only Hurst Industries employees can manage NPC deliveries"
    end
    
    local citizenid = Player.PlayerData.citizenid
    
    -- Check player cooldown
    if playerNPCCooldowns[citizenid] and playerNPCCooldowns[citizenid] > os.time() then
        local remainingTime = playerNPCCooldowns[citizenid] - os.time()
        return false, string.format("NPC job cooldown: %d minutes remaining", math.ceil(remainingTime / 60))
    end
    
    -- Check concurrent NPC job limits
    local playerActiveJobs = 0
    for jobId, jobData in pairs(activeNPCJobs) do
        if jobData.initiatedBy == citizenid then
            playerActiveJobs = playerActiveJobs + 1
        end
    end
    
    if playerActiveJobs >= Config.NPCDeliverySystem.playerRequirements.limitPerPlayer then
        return false, "Maximum concurrent NPC jobs reached"
    end
    
    return true, "Can initiate NPC job"
end

-- Start NPC delivery job
local function startNPCDeliveryJob(source, surplusItem, targetRestaurant)
    local Player = QBCore.Functions.GetPlayer(source)
    local citizenid = Player.PlayerData.citizenid
    
    -- Calculate delivery details
    local ingredient = surplusItem.ingredient
    local deliveryQuantity = math.min(50, math.floor(surplusItem.quantity * 0.1)) -- 10% of surplus, max 50
    local threshold = surplusItem.threshold
    
    -- Calculate delivery payment for NPC jobs
local function calculateDeliveryPayment(quantity, restaurantId)
    -- Base payment calculation
    local basePayment = quantity * 5 -- $5 per item base rate
    
    -- Restaurant distance multiplier (if available in config)
    local distanceMultiplier = 1.0
    if Config.Restaurants and Config.Restaurants[restaurantId] and Config.Restaurants[restaurantId].deliveryMultiplier then
        distanceMultiplier = Config.Restaurants[restaurantId].deliveryMultiplier
    end
    
    -- Apply NPC delivery rate (lower than player deliveries)
    local npcRate = Config.NPCDeliverySystem and Config.NPCDeliverySystem.paymentRates and 
                   Config.NPCDeliverySystem.paymentRates.baseRate or 0.7
    
    return math.floor(basePayment * distanceMultiplier * npcRate)
end

    -- Calculate NPC payment
    local basePayment = calculateDeliveryPayment(deliveryQuantity, targetRestaurant)
    local npcPayment = math.floor(basePayment * threshold.npcPayMultiplier)
    
    -- Calculate completion time with variation
    local baseTime = Config.NPCDeliverySystem.npcBehavior.baseCompletionTime
    local variation = Config.NPCDeliverySystem.npcBehavior.timeVariation
    local completionTime = baseTime + math.random(-variation, variation)
    
    -- Create NPC job
    local jobId = "npc_" .. citizenid .. "_" .. os.time()
    activeNPCJobs[jobId] = {
        jobId = jobId,
        initiatedBy = citizenid,
        playerSource = source,
        ingredient = ingredient,
        quantity = deliveryQuantity,
        targetRestaurant = targetRestaurant,
        surplusLevel = surplusItem.surplusLevel,
        startTime = os.time(),
        completionTime = os.time() + completionTime,
        npcPayment = npcPayment,
        status = "in_progress"
    }
    
    -- Remove items from warehouse
    MySQL.Async.execute([[
        UPDATE supply_warehouse_stock 
        SET quantity = quantity - ? 
        WHERE ingredient = ?
    ]], {deliveryQuantity, ingredient})
    
    -- Set player cooldown
    local cooldownTime = threshold.cooldownMinutes * 60
    playerNPCCooldowns[citizenid] = os.time() + cooldownTime
    
    -- Notify player
    TriggerClientEvent('ox_lib:notify', source, {
        title = '🤖 NPC Delivery Started',
        description = string.format(
            'NPC driver dispatched with %d %s\nEstimated completion: %d minutes\nPayment: $%d',
            deliveryQuantity,
            exports.ox_inventory:Items()[ingredient] and exports.ox_inventory:Items()[ingredient].label or ingredient,
            math.floor(completionTime / 60),
            npcPayment
        ),
        type = 'info',
        duration = 12000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })
    
    

-- Complete NPC delivery
local function completeNPCDelivery(jobId)
    local jobData = activeNPCJobs[jobId]
    if not jobData then return end
    
    -- Check for random failure
    local failureRoll = math.random()
    if failureRoll <= Config.NPCDeliverySystem.npcBehavior.randomFailureChance then
        -- NPC delivery failed - return items to warehouse
        MySQL.Async.execute([[
            UPDATE supply_warehouse_stock 
            SET quantity = quantity + ? 
            WHERE ingredient = ?
        ]], {jobData.quantity, jobData.ingredient})
        
        -- Notify player of failure
        if jobData.playerSource then
            TriggerClientEvent('ox_lib:notify', jobData.playerSource, {
                title = '❌ NPC Delivery Failed',
                description = 'NPC driver encountered issues - items returned to warehouse',
                type = 'error',
                duration = 10000,
                position = Config.UI.notificationPosition,
                markdown = Config.UI.enableMarkdown
            })
        end
        
        activeNPCJobs[jobId] = nil
        return
    end
    
    -- Schedule completion
    Citizen.SetTimeout(completionTime * 1000, function()
        completeNPCDelivery(jobId)
    end)
    
    return true, jobId
end

    -- Successful delivery - update restaurant stock
    MySQL.Async.execute([[
        INSERT INTO supply_restaurant_stock (restaurant_id, ingredient, quantity)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE
            quantity = quantity + VALUES(quantity)
    ]], {jobData.targetRestaurant, jobData.ingredient, jobData.quantity})
    
    -- Pay the player (NPC "driver" payment)
    local Player = QBCore.Functions.GetPlayer(jobData.playerSource)
    if Player then
        Player.Functions.AddMoney('cash', jobData.npcPayment, "NPC delivery completion")
        
        TriggerClientEvent('ox_lib:notify', jobData.playerSource, {
            title = '✅ NPC Delivery Complete',
            description = string.format(
                'Delivery completed successfully!\nReceived: $%d\nItems delivered to restaurant',
                jobData.npcPayment
            ),
            type = 'success',
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
    end
    
    -- Apply market effects if enabled
    if Config.NPCDeliverySystem.marketIntegration.reducesPrices then
        TriggerEvent('market:applyNPCDeliveryEffect', jobData.ingredient, jobData.quantity)
    end
    
    -- Log the NPC delivery
    MySQL.Async.execute([[
        INSERT INTO supply_delivery_logs (
            citizenid, restaurant_id, delivery_method, items_delivered, 
            payment_amount, delivery_time, delivery_status
        ) VALUES (?, ?, 'npc_delivery', ?, ?, ?, 'completed')
    ]], {
        jobData.initiatedBy, jobData.targetRestaurant, jobData.quantity,
        jobData.npcPayment, os.time()
    })
    
    -- Clean up
    activeNPCJobs[jobId] = nil
end

-- ============================================
-- EVENT HANDLERS
-- ============================================

-- Get available NPC jobs for player
RegisterNetEvent('npc:getAvailableJobs')
AddEventHandler('npc:getAvailableJobs', function()
    local src = source
    
    -- Check if player can initiate NPC jobs
    local canInitiate, message = canPlayerInitiateNPCJob(src)
    if not canInitiate then
        TriggerClientEvent('ox_lib:notify', src, {
            title = '🚫 NPC Jobs Unavailable',
            description = message,
            type = 'error',
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    -- Get current surplus conditions
    local surplusItems = checkSurplusConditions()
    
    if #surplusItems == 0 then
        TriggerClientEvent('ox_lib:notify', src, {
            title = '📦 No Surplus Available',
            description = 'NPC deliveries only available when warehouse has surplus stock (80%+ capacity)',
            type = 'info',
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    TriggerClientEvent('npc:showAvailableJobs', src, surplusItems)
end)

-- Start NPC delivery job
RegisterNetEvent('npc:startDeliveryJob')
AddEventHandler('npc:startDeliveryJob', function(ingredientData, restaurantId)
    local src = source
    
    local canInitiate, message = canPlayerInitiateNPCJob(src)
    if not canInitiate then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Cannot Start NPC Job',
            description = message,
            type = 'error',
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    local success, jobId = startNPCDeliveryJob(src, ingredientData, restaurantId)
    if success then
        TriggerClientEvent('npc:jobStarted', src, jobId)
    end
end)

-- Get active NPC jobs for player
RegisterNetEvent('npc:getActiveJobs')
AddEventHandler('npc:getActiveJobs', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    local playerJobs = {}
    
    for jobId, jobData in pairs(activeNPCJobs) do
        if jobData.initiatedBy == citizenid then
            table.insert(playerJobs, {
                jobId = jobId,
                ingredient = jobData.ingredient,
                quantity = jobData.quantity,
                targetRestaurant = jobData.targetRestaurant,
                timeRemaining = jobData.completionTime - os.time(),
                status = jobData.status
            })
        end
    end
    
    TriggerClientEvent('npc:showActiveJobs', src, playerJobs)
end)

-- Initialize NPC system
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print('[NPC SYSTEM] Market-dynamic NPC delivery system initialized')
        
        -- Clean up any stuck NPC jobs on restart
        activeNPCJobs = {}
        playerNPCCooldowns = {}
        
        -- Periodic surplus checking
        Citizen.CreateThread(function()
            while true do
                Citizen.Wait(300000) -- Check every 5 minutes
                checkSurplusConditions()
            end
        end)
    end
end)

-- Export functions
exports('checkSurplusConditions', checkSurplusConditions)
exports('getActiveNPCJobs', function() return activeNPCJobs end)

print("[NPC SYSTEM] Server logic initialized")