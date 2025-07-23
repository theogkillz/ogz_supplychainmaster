-- ============================================
-- NPC DELIVERY SYSTEM - CLIENT INTERFACE
-- Player interface for managing NPC deliveries
-- ============================================

local QBCore = exports['qb-core']:GetCoreObject()

-- Job validation for NPC features
local function hasNPCAccess()
    local PlayerData = QBCore.Functions.GetPlayerData()
    if not PlayerData or not PlayerData.job then
        return false
    end
    
    local playerJob = PlayerData.job.name
    return playerJob == "hurst"
end

-- Client state
local availableSurplusJobs = {}
local activeNPCJobs = {}

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

-- Format time remaining
local function formatTimeRemaining(seconds)
    if seconds <= 0 then
        return "Completing..."
    end
    
    local minutes = math.floor(seconds / 60)
    local secs = seconds % 60
    
    if minutes > 0 then
        return string.format("%dm %ds", minutes, secs)
    else
        return string.format("%ds", secs)
    end
end

-- Get surplus level icon and color
local function getSurplusLevelInfo(surplusLevel)
    local levelInfo = {
        moderate_surplus = {icon = "⚠️", color = "orange", name = "Moderate"},
        high_surplus = {icon = "🔶", color = "yellow", name = "High"},
        critical_surplus = {icon = "🚨", color = "red", name = "Critical"}
    }
    
    return levelInfo[surplusLevel] or {icon = "📦", color = "blue", name = "Unknown"}
end

-- Get item label from ox_inventory
local function getItemLabel(item)
    local itemNames = exports.ox_inventory:Items() or {}
    return itemNames[item] and itemNames[item].label or item
end

-- ============================================
-- MAIN NPC MENU SYSTEM
-- ============================================

-- NPC management menu with validation
RegisterNetEvent("npc:openManagementMenu")
AddEventHandler("npc:openManagementMenu", function()
    if not hasNPCAccess() then
        local PlayerData = QBCore.Functions.GetPlayerData()
        local currentJob = PlayerData and PlayerData.job and PlayerData.job.name or "unemployed"
        
        lib.notify({
            title = "🚫 NPC Access Denied",
            description = "NPC delivery system restricted to Hurst Industries employees. Current job: " .. currentJob,
            type = "error",
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    local options = {
        {
            title = "🤖 Available NPC Jobs",
            description = "Start NPC deliveries for surplus inventory",
            icon = "fas fa-robot",
            onSelect = function()
                TriggerServerEvent("npc:getAvailableJobs")
            end
        },
        {
            title = "📋 Active NPC Jobs",
            description = "Monitor ongoing NPC deliveries",
            icon = "fas fa-tasks",
            onSelect = function()
                TriggerServerEvent("npc:getActiveJobs")
            end
        },
        {
            title = "📊 NPC System Info",
            description = "Learn about the NPC delivery system",
            icon = "fas fa-info-circle",
            onSelect = function()
                TriggerEvent("npc:showSystemInfo")
            end
        },
        {
            title = "← Back to Warehouse",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("warehouse:openProcessingMenu")
            end
        }
    }
    
    lib.registerContext({
        id = "npc_management_menu",
        title = "🤖 NPC Delivery Management",
        options = options
    })
    lib.showContext("npc_management_menu")
end)

-- Show available NPC jobs based on surplus
RegisterNetEvent("npc:showAvailableJobs")
AddEventHandler("npc:showAvailableJobs", function(surplusItems)
    availableSurplusJobs = surplusItems
    
    local options = {
        {
            title = "← Back to NPC Management",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("npc:openManagementMenu")
            end
        }
    }
    
    if #surplusItems == 0 then
        table.insert(options, {
            title = "📦 No Surplus Available",
            description = "NPC jobs are only available when warehouse stock exceeds 80% capacity",
            disabled = true
        })
        
        table.insert(options, {
            title = "💡 How to Enable NPC Jobs",
            description = "Complete regular deliveries to build up warehouse surplus, then return here",
            disabled = true
        })
    else
        -- Group by surplus level
        local groupedSurplus = {}
        for _, item in ipairs(surplusItems) do
            if not groupedSurplus[item.surplusLevel] then
                groupedSurplus[item.surplusLevel] = {}
            end
            table.insert(groupedSurplus[item.surplusLevel], item)
        end
        
        -- Display by surplus level (critical first)
        local levelOrder = {"critical_surplus", "high_surplus", "moderate_surplus"}
        
        for _, level in ipairs(levelOrder) do
            if groupedSurplus[level] then
                local levelInfo = getSurplusLevelInfo(level)
                local threshold = Config.NPCDeliverySystem.surplusThresholds[level]
                
                table.insert(options, {
                    title = string.format("── %s %s Surplus ──", levelInfo.icon, levelInfo.name),
                    description = string.format("Pay Rate: %d%% • Max Jobs: %d • Cooldown: %dm", 
                        threshold.npcPayMultiplier * 100,
                        threshold.maxConcurrentJobs,
                        threshold.cooldownMinutes),
                    disabled = true
                })
                
                for _, item in ipairs(groupedSurplus[level]) do
                    local itemLabel = getItemLabel(item.ingredient)
                    local deliveryQuantity = math.min(50, math.floor(item.quantity * 0.1))
                    
                    table.insert(options, {
                        title = string.format("%s %s", levelInfo.icon, itemLabel),
                        description = string.format(
                            "Stock: %d units (%.1f%% capacity)\nAvailable for NPC delivery: %d units",
                            item.quantity,
                            item.stockPercentage,
                            deliveryQuantity
                        ),
                        metadata = {
                            ["Current Stock"] = item.quantity .. " units",
                            ["Capacity"] = string.format("%.1f%%", item.stockPercentage),
                            ["Surplus Level"] = levelInfo.name,
                            ["NPC Pay Rate"] = string.format("%d%%", threshold.npcPayMultiplier * 100),
                            ["Max Delivery"] = deliveryQuantity .. " units"
                        },
                        onSelect = function()
                            TriggerEvent("npc:selectRestaurantForDelivery", item)
                        end
                    })
                end
            end
        end
    end
    
    lib.registerContext({
        id = "npc_available_jobs",
        title = "🤖 Available NPC Jobs",
        options = options
    })
    lib.showContext("npc_available_jobs")
end)

-- Select restaurant for NPC delivery
RegisterNetEvent("npc:selectRestaurantForDelivery")
AddEventHandler("npc:selectRestaurantForDelivery", function(surplusItem)
    local options = {
        {
            title = "← Back to Available Jobs",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("npc:showAvailableJobs", availableSurplusJobs)
            end
        },
        {
            title = "📦 Delivery Details",
            description = string.format(
                "Item: %s\nQuantity: %d units\nSurplus Level: %s",
                getItemLabel(surplusItem.ingredient),
                math.min(50, math.floor(surplusItem.quantity * 0.1)),
                getSurplusLevelInfo(surplusItem.surplusLevel).name
            ),
            disabled = true
        }
    }
    
    -- Add restaurant options
    for restaurantId, restaurant in pairs(Config.Restaurants) do
        table.insert(options, {
            title = "🏪 " .. restaurant.name,
            description = "Send NPC delivery to this restaurant",
            onSelect = function()
                TriggerEvent("npc:confirmDelivery", surplusItem, restaurantId, restaurant.name)
            end
        })
    end
    
    lib.registerContext({
        id = "npc_restaurant_selection",
        title = "🎯 Select Delivery Destination",
        options = options
    })
    lib.showContext("npc_restaurant_selection")
end)

-- Confirm NPC delivery
RegisterNetEvent("npc:confirmDelivery")
AddEventHandler("npc:confirmDelivery", function(surplusItem, restaurantId, restaurantName)
    local deliveryQuantity = math.min(50, math.floor(surplusItem.quantity * 0.1))
    local threshold = Config.NPCDeliverySystem.surplusThresholds[surplusItem.surplusLevel]
    local estimatedPay = math.floor(deliveryQuantity * 15 * threshold.npcPayMultiplier) -- Rough estimate
    local estimatedTime = math.floor(Config.NPCDeliverySystem.npcBehavior.baseCompletionTime / 60)
    
    lib.alertDialog({
        header = "🤖 Confirm NPC Delivery",
        content = string.format(
            "**Item:** %s\n**Quantity:** %d units\n**Destination:** %s\n**Estimated Time:** %d minutes\n**Estimated Payment:** $%d\n\nThis will dispatch an NPC driver to handle the delivery. You'll receive payment when completed.\n\nConfirm NPC delivery?",
            getItemLabel(surplusItem.ingredient),
            deliveryQuantity,
            restaurantName,
            estimatedTime,
            estimatedPay
        ),
        centered = true,
        cancel = true,
        labels = {
            confirm = "Dispatch NPC",
            cancel = "Cancel"
        }
    }):next(function(confirmed)
        if confirmed then
            TriggerServerEvent("npc:startDeliveryJob", surplusItem, restaurantId)
        end
    end)
end)

-- Show active NPC jobs
RegisterNetEvent("npc:showActiveJobs")
AddEventHandler("npc:showActiveJobs", function(playerJobs)
    activeNPCJobs = playerJobs
    
    local options = {
        {
            title = "← Back to NPC Management",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("npc:openManagementMenu")
            end
        },
        {
            title = "🔄 Refresh Status",
            description = "Update active job information",
            icon = "fas fa-sync",
            onSelect = function()
                TriggerServerEvent("npc:getActiveJobs")
            end
        }
    }
    
    if #playerJobs == 0 then
        table.insert(options, {
            title = "📭 No Active NPC Jobs",
            description = "You have no NPCs currently working",
            disabled = true
        })
        
        table.insert(options, {
            title = "💡 Start NPC Jobs",
            description = "Check available jobs to dispatch NPC drivers",
            onSelect = function()
                TriggerServerEvent("npc:getAvailableJobs")
            end
        })
    else
        for _, job in ipairs(playerJobs) do
            local timeRemaining = formatTimeRemaining(job.timeRemaining)
            local statusIcon = job.timeRemaining > 0 and "🚛" or "✅"
            local itemLabel = getItemLabel(job.ingredient)
            local restaurantName = Config.Restaurants[job.targetRestaurant] and 
                                 Config.Restaurants[job.targetRestaurant].name or "Unknown Restaurant"
            
            table.insert(options, {
                title = statusIcon .. " " .. itemLabel .. " → " .. restaurantName,
                description = string.format(
                    "Quantity: %d units\nStatus: %s\nTime Remaining: %s",
                    job.quantity,
                    job.status == "in_progress" and "In Transit" or "Completed",
                    timeRemaining
                ),
                metadata = {
                    ["Job ID"] = job.jobId:sub(-8), -- Last 8 characters
                    ["Item"] = itemLabel,
                    ["Quantity"] = job.quantity .. " units",
                    ["Destination"] = restaurantName,
                    ["Status"] = job.status == "in_progress" and "In Transit" or "Completed",
                    ["Time Remaining"] = timeRemaining
                }
            })
        end
    end
    
    lib.registerContext({
        id = "npc_active_jobs",
        title = "📋 Active NPC Jobs",
        options = options
    })
    lib.showContext("npc_active_jobs")
end)

-- Show NPC system information
RegisterNetEvent("npc:showSystemInfo")
AddEventHandler("npc:showSystemInfo", function()
    lib.alertDialog({
        header = "🤖 NPC Delivery System",
        content = [[
**How It Works:**
NPC drivers become available when warehouse stock reaches surplus levels (80%+ capacity).

**Surplus Levels:**
• **Moderate (80%+):** 1 NPC job, 70% pay, 30min cooldown
• **High (90%+):** 2 NPC jobs, 80% pay, 20min cooldown  
• **Critical (95%+):** 3 NPC jobs, 90% pay, 15min cooldown

**Key Features:**
• You must manually start all NPC jobs
• NPCs always complete deliveries (no skill factor)
• 5% chance of random delays/failures
• Helps balance market by moving surplus stock
• Cannot be used for passive income

**Requirements:**
• Must be on warehouse duty
• Max 2 NPC jobs per cooldown period
• Only available during surplus conditions
        ]],
        centered = true,
        cancel = true,
        labels = {
            cancel = "Close"
        }
    })
end)

-- Job completion notifications
RegisterNetEvent("npc:jobStarted")
AddEventHandler("npc:jobStarted", function(jobId)
    lib.notify({
        title = '🤖 NPC Dispatched',
        description = 'NPC driver has been sent on delivery. Check active jobs for status updates.',
        type = 'success',
        duration = 8000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })
end)

-- NPC status commands with validation
RegisterCommand('npcstatus', function()
    if not hasNPCAccess() then
        lib.notify({
            title = "🚫 Access Denied",
            description = "NPC system restricted to Hurst Industries employees",
            type = "error",
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    TriggerServerEvent("npc:getActiveJobs")
end)

RegisterCommand('npcjobs', function()
    if not hasNPCAccess() then
        lib.notify({
            title = "🚫 Access Denied",
            description = "NPC job management restricted to Hurst Industries employees",
            type = "error",
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    TriggerServerEvent("npc:getAvailableJobs")
end)