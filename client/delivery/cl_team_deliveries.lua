local QBCore = exports['qb-core']:GetCoreObject()

-- Team delivery variables
local currentTeam = nil
local teamDeliveryData = nil
local isReady = false
local allMembersReady = false -- Track if all members are ready
local currentWarehouseId = nil

-- Shared delivery tracking (same as solo)
local deliveryBoxesRemaining = 0
local totalDeliveryBoxes = 0

-- Calculate delivery requirements
local function calculateDeliveryBoxes(orders)
    local totalItems = 0
    local itemsList = {}
    
    -- Handle both single orders and order groups
    if orders[1] and orders[1].items then
        -- Order group format
        for _, orderGroup in ipairs(orders) do
            for _, item in ipairs(orderGroup.items) do
                totalItems = totalItems + item.quantity
                table.insert(itemsList, item.quantity .. "x " .. item.itemName)
            end
        end
    else
        -- Single order format
        for _, order in ipairs(orders) do
            totalItems = totalItems + order.quantity
            table.insert(itemsList, order.quantity .. "x " .. (order.itemName or order.ingredient))
        end
    end
    
    local itemsPerContainer = (Config.ContainerSystem and Config.ContainerSystem.itemsPerContainer) or 12
    local containersPerBox = (Config.ContainerSystem and Config.ContainerSystem.containersPerBox) or 5
    
    local containersNeeded = math.ceil(totalItems / itemsPerContainer)
    local boxesNeeded = math.ceil(containersNeeded / containersPerBox)
    
    return boxesNeeded, containersNeeded, totalItems, itemsList
end

-- Enhanced warehouse order details to include team option
RegisterNetEvent("warehouse:showOrderDetails")
AddEventHandler("warehouse:showOrderDetails", function(orders)
    if not orders or #orders == 0 then
        lib.notify({
            title = "No Orders",
            description = "There are no active orders at the moment.",
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end

    local options = {}
    local itemNames = exports.ox_inventory:Items()
    
    for _, orderGroup in ipairs(orders) do
        local restaurantId = orderGroup.restaurantId
        local restaurantData = Config.Restaurants[restaurantId]
        local restaurantName = restaurantData and restaurantData.name or "Unknown Business"
        
        -- Calculate delivery info for this order
        local boxesNeeded, containersNeeded, totalItems = calculateDeliveryBoxes({orderGroup})
        
        -- Create description with all items in the order
        local itemList = {}
        for _, item in ipairs(orderGroup.items) do
            local itemLabel = itemNames[item.itemName:lower()] and itemNames[item.itemName:lower()].label or item.itemName
            table.insert(itemList, item.quantity .. "x " .. itemLabel)
        end
        
        table.insert(options, {
            title = "Order: " .. orderGroup.orderGroupId,
            description = string.format("📦 %d boxes (%d containers)\n🏪 %s\n📋 %s\n💰 $%d", 
                boxesNeeded,
                containersNeeded,
                restaurantName, 
                table.concat(itemList, ", "), 
                orderGroup.totalCost),
            onSelect = function()
                -- Show order action menu with team option for large orders
                local actionOptions = {
                    { 
                        title = "✅ Solo Delivery", 
                        description = "Accept and complete alone",
                        icon = "fas fa-user",
                        onSelect = function() 
                            TriggerServerEvent("warehouse:acceptOrder", orderGroup.orderGroupId, restaurantId) 
                        end 
                    }
                }
                
                -- Add team delivery options for orders with 5+ boxes
                if boxesNeeded >= (Config.TeamDeliveries and Config.TeamDeliveries.minBoxesForTeam or 5) then
                    table.insert(actionOptions, {
                        title = "🚛 Create Team Delivery",
                        description = "Start a team delivery for this large order",
                        icon = "fas fa-users",
                        onSelect = function()
                            TriggerEvent("team:showDeliveryTypeMenu", orderGroup.orderGroupId, restaurantId, boxesNeeded)
                        end
                    })
                    
                    table.insert(actionOptions, {
                        title = "👥 Join Existing Team",
                        description = "Look for teams needing drivers",
                        icon = "fas fa-user-plus",
                        onSelect = function()
                            TriggerServerEvent("team:getAvailableTeams")
                        end
                    })
                end
                
                table.insert(actionOptions, {
                    title = "❌ Deny Order", 
                    description = "Reject this order",
                    icon = "fas fa-times",
                    onSelect = function() 
                        TriggerServerEvent("warehouse:denyOrder", orderGroup.orderGroupId) 
                    end 
                })
                
                lib.registerContext({
                    id = "order_action_menu",
                    title = "Order Actions",
                    options = actionOptions
                })
                lib.showContext("order_action_menu")
            end
        })
    end
    
    lib.registerContext({
        id = "order_menu",
        title = "Active Orders",
        options = options
    })
    lib.showContext("order_menu")
end)

-- Team delivery type selection
RegisterNetEvent("team:showDeliveryTypeMenu")
AddEventHandler("team:showDeliveryTypeMenu", function(orderGroupId, restaurantId, boxesNeeded)
    local options = {}
    
    if Config.TeamDeliveries and Config.TeamDeliveries.deliveryTypes then
        for typeId, deliveryType in pairs(Config.TeamDeliveries.deliveryTypes) do
            if boxesNeeded >= deliveryType.minBoxes and boxesNeeded <= deliveryType.maxBoxes then
                table.insert(options, {
                    title = deliveryType.name,
                    description = string.format("%s\n📦 %d boxes needed\n👥 %d-%d players required", 
                        deliveryType.description, 
                        boxesNeeded,
                        deliveryType.requiredMembers, 
                        deliveryType.maxMembers),
                    icon = typeId == "duo" and "fas fa-user-friends" or typeId == "squad" and "fas fa-users" or "fas fa-truck",
                    onSelect = function()
                        TriggerServerEvent("team:createDelivery", orderGroupId, restaurantId, typeId)
                    end
                })
            end
        end
    end
    
    table.insert(options, {
        title = "← Back to Order",
        icon = "fas fa-arrow-left",
        onSelect = function()
            TriggerServerEvent("warehouse:getPendingOrders")
        end
    })
    
    lib.registerContext({
        id = "team_delivery_types",
        title = "🚛 Select Delivery Type",
        options = options
    })
    lib.showContext("team_delivery_types")
end)

-- Show recruitment menu for team leader (FIXED WITH ACCEPT ORDER BUTTON)
RegisterNetEvent("team:showRecruitmentMenu")
AddEventHandler("team:showRecruitmentMenu", function(teamId, teamData)
    currentTeam = teamId
    
    -- Update state from teamData if provided
    local isLeader = false
    if teamData then
        allMembersReady = teamData.allReady
        isLeader = teamData.isLeader
    end
    
    local options = {
        {
            title = string.format("📋 Team ID: %s", teamId),
            description = "Share this ID with other drivers to join",
            icon = "fas fa-clipboard",
            metadata = {
                ["Team ID"] = teamId,
                ["Your Role"] = isLeader and "👑 Team Leader" or "👥 Team Member"
            },
            onSelect = function()
                -- Copy to clipboard functionality
                lib.setClipboard(teamId)
                lib.notify({
                    title = "📋 Copied!",
                    description = "Team ID copied to clipboard",
                    type = "success",
                    duration = 3000,
                    position = Config.UI.notificationPosition
                })
            end
        },
        {
            title = "👥 Team Status",
            description = "View members and coordination stats",
            icon = "fas fa-users",
            onSelect = function()
                TriggerServerEvent("team:getTeamStatus", teamId)
            end
        },
        {
            title = isReady and "✅ Ready" or "⏸️ Not Ready",
            description = isReady and "Click to unready" or "Mark yourself ready to start",
            icon = isReady and "fas fa-check-circle" or "fas fa-pause-circle",
            iconColor = isReady and "#4CAF50" or "#FFA726",
            onSelect = function()
                isReady = not isReady
                TriggerServerEvent("team:setReady", teamId, isReady)
                
                -- Refresh menu after short delay
                Citizen.SetTimeout(500, function()
                    TriggerServerEvent("team:getTeamData", teamId)
                end)
            end
        }
    }
    
    -- FIXED: Accept Order Button with proper alertDialog syntax
    if allMembersReady and isLeader then
        table.insert(options, 4, {
            title = '🚚 Accept Team Order',
            description = '✅ All members ready! Start the delivery!',
            icon = 'fas fa-truck-fast',
            iconColor = '#4CAF50',
            onSelect = function()
                -- FIXED: Use proper ox_lib alertDialog syntax (no callback)
                local alert = lib.alertDialog({
                    header = "Start Team Delivery?",
                    content = "This will start the delivery for all team members. Make sure everyone is ready!",
                    centered = true,
                    cancel = true,
                    labels = {
                        cancel = "Wait",
                        confirm = "Start Delivery"
                    }
                })
                
                -- Check response directly
                if alert == "confirm" then
                    -- Close the menu
                    lib.hideContext()
                    
                    -- Visual feedback
                    lib.notify({
                        title = '📦 Starting Team Delivery',
                        description = 'Accepting order for your team...',
                        type = 'info',
                        duration = 5000,
                        position = Config.UI.notificationPosition
                    })
                    
                    -- Trigger server event
                    TriggerServerEvent('supply:teams:acceptOrder', teamId)
                end
            end
        })
    elseif isLeader and not allMembersReady then
        -- Show waiting message for leader
        table.insert(options, 4, {
            title = '⏳ Waiting for Team',
            description = 'All members must be ready before starting',
            icon = 'fas fa-hourglass-half',
            iconColor = '#FFA726',
            disabled = true
        })
    elseif not isLeader and allMembersReady then
        -- Show waiting message for members
        table.insert(options, 4, {
            title = '⏳ Waiting for Leader',
            description = 'Team leader will start the delivery',
            icon = 'fas fa-hourglass-half',
            iconColor = '#03A9F4',
            disabled = true
        })
    end
    
    -- Performance tracking
    table.insert(options, {
        title = "🏆 Team Leaderboard",
        description = "Check team rankings and challenges",
        icon = "fas fa-trophy",
        onSelect = function()
            TriggerEvent("team:openLeaderboardMenu")
        end
    })
    
    table.insert(options, {
        title = "📊 Performance Tips",
        description = "Learn coordination strategies",
        icon = "fas fa-chart-line",
        onSelect = function()
            TriggerEvent("team:showPerformanceTips")
        end
    })
    
    -- Communication helper
    table.insert(options, {
        title = "💬 Team Communication",
        description = "Tips for better coordination",
        icon = "fas fa-comments",
        onSelect = function()
            lib.notify({
                title = "💬 Communication Tips",
                description = [[
**Voice Chat:**
• Use /teamspeak or Discord
• Count down before leaving
• Call out your position

**Text Chat:**
• /team [message] for team chat
• Use quick callouts
• Coordinate parking spots]],
                type = "info",
                duration = 12000,
                position = Config.UI.notificationPosition,
                markdown = true
            })
        end
    })
    
    -- FIXED: Leave team option with proper alertDialog
    table.insert(options, {
        title = "🚪 Leave Team",
        description = "Exit and find another team",
        icon = "fas fa-door-open",
        iconColor = "#F44336",
        onSelect = function()
            -- FIXED: Use proper ox_lib alertDialog syntax
            local alert = lib.alertDialog({
                header = "Leave Team?",
                content = "Are you sure you want to leave this team? You'll need to join or create a new one.",
                centered = true,
                cancel = true,
                labels = {
                    cancel = "Stay",
                    confirm = "Leave Team"
                }
            })
            
            -- Check response directly
            if alert == "confirm" then
                currentTeam = nil
                isReady = false
                allMembersReady = false
                TriggerServerEvent("team:leaveDelivery", teamId)
                
                lib.notify({
                    title = "👥 Left Team",
                    description = "You have left the delivery team",
                    type = "info",
                    duration = 5000,
                    position = Config.UI.notificationPosition
                })
            end
        end
    })
    
    lib.registerContext({
        id = "team_recruitment",
        title = "🚛 Team Coordination Hub",
        options = options
    })
    lib.showContext("team_recruitment")
end)

-- Team status display
RegisterNetEvent("team:showTeamStatus")
AddEventHandler("team:showTeamStatus", function(teamData)
    local options = {}
    
    -- Team composition header
    table.insert(options, {
        title = string.format("👥 Team Size: %d/%d", #teamData.members, Config.TeamDeliveries.maxTeamSize),
        description = string.format("Delivery Type: %s", teamData.deliveryTypeName),
        disabled = true
    })
    
    -- Member list with ready status
    for i, member in ipairs(teamData.members) do
        local roleIcon = member.isLeader and "👑" or "👤"
        local readyIcon = member.ready and "✅" or "⏳"
        
        table.insert(options, {
            title = string.format("%s %s %s", roleIcon, member.name, readyIcon),
            description = string.format("Boxes: %d | %s", 
                member.boxesAssigned, 
                member.ready and "Ready" or "Not Ready"),
            disabled = true
        })
    end
    
    -- Team bonus preview
    local teamBonus = Config.TeamDeliveries.teamBonuses[#teamData.members] or {multiplier = 1.0, name = "No bonus"}
    table.insert(options, {
        title = "💰 Team Bonus Preview",
        description = string.format("%s - %.1fx multiplier", teamBonus.name, teamBonus.multiplier),
        icon = "fas fa-coins",
        disabled = true
    })
    
    -- Coordination tips
    table.insert(options, {
        title = "💡 Coordination Tip",
        description = "Arrive within 15 seconds for Perfect Sync bonus!",
        icon = "fas fa-lightbulb",
        disabled = true
    })
    
    table.insert(options, {
        title = "← Back",
        icon = "fas fa-arrow-left",
        onSelect = function()
            TriggerEvent("team:showRecruitmentMenu", currentTeam)
        end
    })
    
    lib.registerContext({
        id = "team_status",
        title = "📊 Team Status",
        options = options
    })
    lib.showContext("team_status")
end)

-- Main Team Delivery Menu
RegisterNetEvent("warehouse:openTeamMenu")
AddEventHandler("warehouse:openTeamMenu", function(warehouseId)
    currentWarehouseId = warehouseId -- Store it!
    local options = {
        {
            title = "🚛 Create Team Delivery",
            description = "Start a new team for large orders (5+ boxes)",
            icon = "fas fa-plus-circle",
            metadata = {
                ["Requirements"] = "5+ box orders",
                ["Team Size"] = "2-8 players",
                ["Bonus"] = "Up to 2.0x multiplier"
            },
            onSelect = function()
                -- Get orders that qualify for team delivery
                TriggerServerEvent("warehouse:getPendingOrdersForTeam")
            end
        },
        {
            title = "👀 Browse Available Teams",
            description = "See teams currently recruiting drivers",
            icon = "fas fa-search",
            onSelect = function()
                TriggerServerEvent("team:getAvailableTeams")
            end
        },
        {
            title = "🆔 Join Team by ID",
            description = "Enter a specific team ID to join",
            icon = "fas fa-keyboard",
            onSelect = function()
                local input = lib.inputDialog("Join Team", {
                    { 
                        type = "input", 
                        label = "Team ID", 
                        placeholder = "Enter team ID (e.g., team_1234)", 
                        required = true,
                        min = 10,
                        max = 20
                    }
                })
                if input and input[1] then
                    TriggerServerEvent("team:joinDelivery", input[1])
                end
            end
        },
        {
            title = "🏆 Team Leaderboards",
            description = "View top performing delivery teams",
            icon = "fas fa-trophy",
            metadata = {
                ["Categories"] = "Daily, Weekly, All-Time",
                ["Metrics"] = "Deliveries, Sync Bonus, Earnings"
            },
            onSelect = function()
                TriggerEvent("team:openLeaderboardMenu")
            end
        },
        {
            title = "📊 My Team Stats",
            description = "View your team delivery performance",
            icon = "fas fa-chart-line",
            onSelect = function()
                TriggerServerEvent("team:getPersonalTeamStats")
            end
        },
        {
            title = "💡 Team Strategies",
            description = "Learn coordination tips and tricks",
            icon = "fas fa-lightbulb",
            onSelect = function()
                TriggerEvent("team:showPerformanceTips")
            end
        },
        {
            title = "👥 Recent Teams",
            description = "Rejoin teams you've worked with before",
            icon = "fas fa-history",
            onSelect = function()
                TriggerServerEvent("team:checkPersistentTeam")
            end
        },
        {
            title = "← Back to Main Menu",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("warehouse:openMainMenu", warehouseId)
            end
        }
    }
    
    lib.registerContext({
        id = "team_delivery_menu",
        title = "👥 Team Delivery System",
        options = options
    })
    lib.showContext("team_delivery_menu")
end)

-- Team Performance Tips
RegisterNetEvent("team:showPerformanceTips")
AddEventHandler("team:showPerformanceTips", function()
    local options = {
        {
            title = "🎯 Perfect Sync Strategy",
            description = "Arrive within 15 seconds for maximum bonus",
            icon = "fas fa-sync",
            onSelect = function()
                lib.notify({
                    title = "🎯 Perfect Sync Tips",
                    description = [[
**Coordination is KEY!**
• Use voice chat or text
• Count down before leaving
• Follow the same route
• Park together at delivery

**Requirements:**
✅ All arrive within 15s
✅ No vehicle damage
✅ Complete all boxes

**Reward:** +$1000 bonus!]],
                    type = "info",
                    duration = 15000,
                    position = Config.UI.notificationPosition,
                    markdown = true
                })
            end
        },
        {
            title = "🚛 Vehicle Convoy Tips",
            description = "How to drive as a team effectively",
            icon = "fas fa-truck",
            onSelect = function()
                lib.notify({
                    title = "🚛 Convoy Driving",
                    description = [[
**Formation Tips:**
• Leader sets the pace
• Maintain 2-3 car gap
• Use hazards for stops
• Wait at intersections

**Communication:**
• Call out turns early
• Warn about obstacles
• Coordinate parking]],
                    type = "info",
                    duration = 12000,
                    position = Config.UI.notificationPosition,
                    markdown = true
                })
            end
        },
        {
            title = "💰 Maximizing Team Earnings",
            description = "Get the most from team deliveries",
            icon = "fas fa-dollar-sign",
            onSelect = function()
                lib.notify({
                    title = "💰 Team Earnings Guide",
                    description = [[
**Team Size Bonuses:**
👥 2 players: 1.2x
👥 3-4 players: 1.5x
👥 5-6 players: 1.75x
👥 7-8 players: 2.0x

**Stack These Bonuses:**
⚡ Speed bonus
🎯 Perfect sync
📦 Volume bonus
🏆 No damage bonus]],
                    type = "info",
                    duration = 12000,
                    position = Config.UI.notificationPosition,
                    markdown = true
                })
            end
        },
        {
            title = "🎭 Role Strategies",
            description = "Leader vs Member responsibilities",
            icon = "fas fa-users-cog",
            onSelect = function()
                lib.notify({
                    title = "🎭 Team Roles",
                    description = [[
**Team Leader:**
• Creates delivery
• Sets the pace
• Coordinates team
• Gets leader vehicle

**Team Members:**
• Follow leader's pace
• Communicate issues
• Help with navigation
• Support the team]],
                    type = "info",
                    duration = 10000,
                    position = Config.UI.notificationPosition,
                    markdown = true
                })
            end
        },
        {
            title = "← Back to Team Menu",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("warehouse:openTeamMenu")
            end
        }
    }
    
    lib.registerContext({
        id = "team_performance_tips",
        title = "💡 Team Performance Guide",
        options = options
    })
    lib.showContext("team_performance_tips")
end)

-- Personal Team Stats Display
RegisterNetEvent("team:showPersonalStats")
AddEventHandler("team:showPersonalStats", function(stats)
    local options = {
        {
            title = "📊 Team Delivery Overview",
            description = string.format(
                "Total Team Deliveries: %d\nPerfect Syncs: %d\nTeam Earnings: $%s",
                stats.team_deliveries or 0,
                stats.perfect_syncs or 0,
                string.format("%.0f", stats.team_earnings or 0)
            ),
            disabled = true
        },
        {
            title = "🏆 Best Team Performance",
            description = stats.best_team and string.format(
                "Team: %s\nDeliveries Together: %d\nBest Sync Time: %ds",
                stats.best_team.members,
                stats.best_team.deliveries,
                stats.best_team.sync_time
            ) or "No team data yet",
            disabled = true
        },
        {
            title = "⚡ Sync Bonus Rate",
            description = string.format(
                "Perfect Syncs: %.1f%%\nAverage Sync Time: %ds\nTotal Sync Bonuses: $%d",
                (stats.perfect_syncs / math.max(stats.team_deliveries, 1)) * 100,
                stats.avg_sync_time or 0,
                stats.total_sync_bonuses or 0
            ),
            disabled = true
        },
        {
            title = "👥 Favorite Teammates",
            description = "Players you work best with",
            icon = "fas fa-user-friends",
            onSelect = function()
                if stats.favorite_teammates and #stats.favorite_teammates > 0 then
                    local teammates = {}
                    for _, teammate in ipairs(stats.favorite_teammates) do
                        table.insert(teammates, string.format(
                            "%s - %d deliveries",
                            teammate.name,
                            teammate.count
                        ))
                    end
                    lib.notify({
                        title = "👥 Favorite Teammates",
                        description = table.concat(teammates, "\n"),
                        type = "info",
                        duration = 10000,
                        position = Config.UI.notificationPosition
                    })
                else
                    lib.notify({
                        title = "No Data",
                        description = "Complete team deliveries to see teammates",
                        type = "info",
                        duration = 5000,
                        position = Config.UI.notificationPosition
                    })
                end
            end
        },
        {
            title = "← Back to Team Menu",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("warehouse:openTeamMenu")
            end
        }
    }
    
    lib.registerContext({
        id = "team_personal_stats",
        title = "📊 My Team Performance",
        options = options
    })
    lib.showContext("team_personal_stats")
end)

-- Recent Teams Display
RegisterNetEvent("team:showRecentTeams")
AddEventHandler("team:showRecentTeams", function(recentTeams)
    local options = {
        {
            title = "🔄 Refresh",
            description = "Check for online teammates",
            icon = "fas fa-sync",
            onSelect = function()
                TriggerServerEvent("team:checkPersistentTeam")
            end
        }
    }
    
    if #recentTeams == 0 then
        table.insert(options, {
            title = "No Recent Teams",
            description = "Complete team deliveries to see history",
            disabled = true
        })
    else
        for _, team in ipairs(recentTeams) do
            local onlineText = team.onlineCount > 1 and 
                string.format("🟢 %d/%d online", team.onlineCount, #team.members) or
                "🔴 Not enough online"
            
            table.insert(options, {
                title = string.format("👥 %s", table.concat(team.memberNames, ", ")),
                description = string.format(
                    "%s\nDeliveries Together: %d\nLast Active: %s",
                    onlineText,
                    team.deliveryCount,
                    team.lastActiveText
                ),
                disabled = team.onlineCount < 2,
                onSelect = function()
                    if team.onlineCount >= 2 then
                        TriggerServerEvent("team:rejoinPersistentTeam", team.teamKey)
                    end
                end
            })
        end
    end
    
    table.insert(options, {
        title = "← Back to Team Menu",
        icon = "fas fa-arrow-left",
        onSelect = function()
            TriggerEvent("warehouse:openTeamMenu")
        end
    })
    
    lib.registerContext({
        id = "recent_teams_menu",
        title = "👥 Recent Team History",
        options = options
    })
    lib.showContext("recent_teams_menu")
end)

-- Show available teams to join
RegisterNetEvent("team:showAvailableTeams")
AddEventHandler("team:showAvailableTeams", function(teams)
    local options = {
        {
            title = "🔄 Refresh List",
            description = "Check for new teams",
            icon = "fas fa-sync",
            onSelect = function()
                TriggerServerEvent("team:getAvailableTeams")
            end
        },
        {
            title = "🆔 Join by Team ID", 
            description = "Enter a team ID directly",
            icon = "fas fa-keyboard",
            onSelect = function()
                local input = lib.inputDialog("Join Team", {
                    { type = "input", label = "Team ID", placeholder = "Enter team ID", required = true }
                })
                if input and input[1] then
                    TriggerServerEvent("team:joinDelivery", input[1])
                end
            end
        }
    }
    
    if #teams == 0 then
        table.insert(options, {
            title = "No Teams Available",
            description = "No teams are currently recruiting",
            disabled = true
        })
    else
        for _, team in ipairs(teams) do
            -- Use the timeText provided by server instead of calculating client-side
            local timeText = team.timeText or "Recently"
            
            table.insert(options, {
                title = string.format("🚛 %s's Team", team.leaderName),
                description = string.format(
                    "%s\n📦 %d boxes • 👥 %d/%d members\n⏰ Created %s",
                    team.deliveryType and Config.TeamDeliveries.deliveryTypes[team.deliveryType] and Config.TeamDeliveries.deliveryTypes[team.deliveryType].name or "Team Delivery",
                    team.totalBoxes,
                    team.memberCount,
                    team.maxMembers,
                    timeText
                ),
                onSelect = function()
                    TriggerServerEvent("team:joinDelivery", team.teamId)
                end
            })
        end
    end
    
    table.insert(options, {
        title = "← Back to Orders",
        icon = "fas fa-arrow-left", 
        onSelect = function()
            TriggerServerEvent("warehouse:getPendingOrders")
        end
    })
    
    lib.registerContext({
        id = "available_teams",
        title = "👥 Available Teams",
        options = options
    })
    lib.showContext("available_teams")
end)

-- Update team member list
RegisterNetEvent("team:updateMemberList")
AddEventHandler("team:updateMemberList", function(team)
    -- Update UI to show current team members
    -- This can trigger notifications or update displays
end)

-- Update ready status display (FIXED TO TRACK ALL READY STATE)
RegisterNetEvent("team:updateReadyStatus")
AddEventHandler("team:updateReadyStatus", function(teamId, readyCount, totalMembers, allReady, isLeader)
    if currentTeam == teamId then
        allMembersReady = allReady -- Store the all ready state
        
        if allReady and totalMembers >= 2 then
            if isLeader then
                lib.notify({
                    title = "🚀 TEAM READY!",
                    description = "All team members ready! Click 'Accept Team Order' to start delivery!",
                    type = "success",
                    duration = 8000,
                    position = Config.UI.notificationPosition,
                    markdown = Config.UI.enableMarkdown
                })
                
                -- Refresh menu to show accept button
                TriggerServerEvent("team:getTeamData", teamId)
            else
                lib.notify({
                    title = "🚀 TEAM READY!",
                    description = "All team members ready! Waiting for leader to accept order...",
                    type = "success",
                    duration = 8000,
                    position = Config.UI.notificationPosition,
                    markdown = Config.UI.enableMarkdown
                })
            end
        else
            lib.notify({
                title = "👥 Team Status",
                description = string.format("Ready: %d/%d members", readyCount, totalMembers),
                type = "info",
                duration = 5000,
                position = Config.UI.notificationPosition,
                markdown = Config.UI.enableMarkdown
            })
        end
    end
end)

-- Spawn team delivery vehicle with sequential spawn check
RegisterNetEvent("team:spawnDeliveryVehicle")
AddEventHandler("team:spawnDeliveryVehicle", function(teamData)
    teamDeliveryData = teamData
    
    local warehouseConfig = Config.Warehouses[1]
    if not warehouseConfig then
        lib.notify({
            title = "Error",
            description = "No warehouse configuration found.",
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end

    -- NO SCREEN FADE (removed for immersion)
    Citizen.Wait(1000)

    local playerPed = PlayerPedId()
    local vehicleModel = GetHashKey("speedo")
    
    -- Leaders get bigger vehicles for convoy deliveries
    if teamData.memberRole == "leader" and teamData.boxesAssigned > 5 then
        vehicleModel = GetHashKey("mule")
    end
    
    RequestModel(vehicleModel)
    while not HasModelLoaded(vehicleModel) do
        Citizen.Wait(100)
    end

    -- Spawn vehicle at convoy position
    local van = CreateVehicle(vehicleModel, spawnPos.x, spawnPos.y, spawnPos.z, spawnPos.w, true, false)
    
    SetEntityAsMissionEntity(van, true, true)
    SetVehicleHasBeenOwnedByPlayer(van, true)
    SetVehicleNeedsToBeHotwired(van, false)
    SetVehRadioStation(van, "OFF")
    SetVehicleEngineOn(van, true, true, false)
    SetEntityCleanupByEngine(van, false)
    
    -- Apply achievement mods if enabled
    if Config.AchievementVehicles and Config.AchievementVehicles.enabled then
        TriggerServerEvent("achievements:applyVehicleMods", NetworkGetNetworkIdFromEntity(van))
    end
    
    -- Give keys to the driver
    local vanPlate = GetVehicleNumberPlateText(van)
    TriggerEvent("vehiclekeys:client:SetOwner", vanPlate)
    
    -- For duo deliveries, give keys to both players
    if teamData.isDuo then
        TriggerServerEvent("team:shareVehicleKeys", teamData.teamId, vanPlate)
    end

    -- Visual distinction for team vehicles
    if teamData.memberRole == "leader" then
        SetVehicleCustomPrimaryColour(van, 0, 255, 0)    -- Green for leader
    else
        SetVehicleCustomPrimaryColour(van, 0, 150, 255)  -- Blue for members
    end

    lib.notify({
        title = "🚛 Team Vehicle Ready",
        description = string.format("Load %d boxes for your part of the team delivery!", teamData.boxesAssigned),
        type = "success",
        duration = 10000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })

    -- NO TELEPORT (removed for immersion)
    
    -- Use enhanced team pallet loading system
    TriggerEvent("team:loadTeamBoxesPallet", warehouseConfig, van, teamData)
    
    -- Notify server that spawn is complete
    TriggerServerEvent("team:vehicleSpawnComplete", teamData.teamId)
end)

-- Enhanced Team Pallet Loading System (matching solo system)
RegisterNetEvent("team:loadTeamBoxesPallet")
AddEventHandler("team:loadTeamBoxesPallet", function(warehouseConfig, van, teamData)
    local playerPed = PlayerPedId()
    local boxesLoaded = 0
    local maxBoxes = teamData.boxesAssigned
    local hasBox = false
    local boxProp = nil
    local palletBlip = nil
    local palletEntity = nil
    local targetZones = {}
    local vanTargetName = "team_van_load_" .. tostring(van)
    local palletZoneName = "team_pallet_pickup_" .. tostring(GetGameTimer())

    -- Load both props
    local boxModel = GetHashKey(Config.DeliveryProps.boxProp)
    local palletModel = GetHashKey(Config.DeliveryProps.palletProp)
    
    RequestModel(boxModel)
    RequestModel(palletModel)
    while not HasModelLoaded(boxModel) or not HasModelLoaded(palletModel) do
        Citizen.Wait(100)
    end

    local boxPositions = warehouseConfig.boxPositions
    if not boxPositions or #boxPositions == 0 then
        print("[ERROR] No boxPositions defined")
        return
    end

    -- Create SHARED pallet prop (spread out positions to avoid collisions)
    local palletOffset = (teamData.memberRole == "leader") and 0 or 10  -- Leaders at base, members offset
    local palletPos = vector3(
        boxPositions[1].x + palletOffset,
        boxPositions[1].y + math.random(-3, 3), -- Small random offset
        boxPositions[1].z
    )
    
    palletEntity = CreateObject(palletModel, palletPos.x, palletPos.y, palletPos.z, true, true, true)
    if DoesEntityExist(palletEntity) then
        PlaceObjectOnGroundProperly(palletEntity)
        
        -- Team-colored light effect
        Citizen.CreateThread(function()
            while DoesEntityExist(palletEntity) and boxesLoaded < maxBoxes do
                local lightColor = teamData.memberRole == "leader" and {r = 0, g = 255, b = 0} or {r = 0, g = 150, b = 255}
                DrawLightWithRange(palletPos.x, palletPos.y, palletPos.z + 1.0, 
                    lightColor.r, lightColor.g, lightColor.b, 3.0, 1.5)
                Citizen.Wait(0)
            end
        end)
    end

    -- Create blip for pallet
    palletBlip = AddBlipForCoord(palletPos.x, palletPos.y, palletPos.z)
    SetBlipSprite(palletBlip, 1)
    SetBlipDisplay(palletBlip, 4)
    SetBlipScale(palletBlip, 0.8)
    SetBlipColour(palletBlip, teamData.memberRole == "leader" and 2 or 3)
    SetBlipAsShortRange(palletBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(string.format("Team Pallet (%d boxes)", maxBoxes))
    EndTextCommandSetBlipName(palletBlip)

    -- Helper function to update pallet zone
    local function updatePalletZone()
        exports.ox_target:removeZone(palletZoneName)
        exports.ox_target:addBoxZone({
            coords = vector3(palletPos.x, palletPos.y, palletPos.z),
            size = vector3(3.0, 3.0, 2.0),
            rotation = 0,
            debug = false,
            name = palletZoneName,
            options = {
                {
                    label = string.format("Grab Box (%d/%d loaded)", boxesLoaded, maxBoxes),
                    icon = "fas fa-box",
                    disabled = hasBox or boxesLoaded >= maxBoxes,
                    onSelect = function()
                        if hasBox then
                            lib.notify({
                                title = "Error",
                                description = "You are already carrying a box.",
                                type = "error",
                                duration = 5000,
                                position = Config.UI.notificationPosition,
                                markdown = Config.UI.enableMarkdown
                            })
                            return
                        end
                        
                        if boxesLoaded == 0 and teamData.memberRole == "leader" then
                            lib.notify({
                                title = "📦 Team Loading Phase",
                                description = string.format("Load %d boxes. Your team is counting on you!", maxBoxes),
                                type = "info",
                                duration = 10000,
                                position = Config.UI.notificationPosition,
                                markdown = Config.UI.enableMarkdown
                            })
                        end
                        
                        if lib.progressBar({
                            duration = 2500,
                            position = "bottom",
                            label = "Grabbing box from pallet...",
                            canCancel = false,
                            disable = { move = true, car = true, combat = true, sprint = true },
                            anim = { dict = "mini@repair", clip = "fixing_a_ped" }
                        }) then
                            -- Create box in player's hands
                            local playerCoords = GetEntityCoords(playerPed)
                            boxProp = CreateObject(boxModel, playerCoords.x, playerCoords.y, playerCoords.z, true, true, true)
                            AttachEntityToEntity(boxProp, playerPed, GetPedBoneIndex(playerPed, 60309),
                                0.1, 0.2, 0.25, -90.0, 0.0, 0.0, true, true, false, true, 1, true)

                            hasBox = true
                            local animDict = "anim@heists@box_carry@"
                            RequestAnimDict(animDict)
                            while not HasAnimDictLoaded(animDict) do
                                Citizen.Wait(0)
                            end
                            TaskPlayAnim(playerPed, animDict, "idle", 8.0, -8.0, -1, 50, 0, false, false, false)

                        end
                    end
                }
            }
        })
    end

    -- Initial pallet zone setup
    updatePalletZone()
    table.insert(targetZones, palletZoneName)

    -- Van loading with progress tracking
    local function updateVanTargetZone()
        while DoesEntityExist(van) and boxesLoaded < maxBoxes do
            local vanPos = GetEntityCoords(van)
            local vanHeading = GetEntityHeading(van)
            local vanBackPosition = vector3(
                vanPos.x + math.sin(math.rad(vanHeading)) * 3.0,
                vanPos.y - math.cos(math.rad(vanHeading)) * 3.0,
                vanPos.z + 0.5
            )

            exports.ox_target:removeZone(vanTargetName)
            exports.ox_target:addBoxZone({
                coords = vanBackPosition,
                size = vector3(3.0, 3.0, 2.0),
                rotation = vanHeading,
                debug = false,
                name = vanTargetName,
                options = {
                    {
                        label = string.format("Load Box (%d/%d)", boxesLoaded + 1, maxBoxes),
                        icon = "fas fa-truck-loading",
                        onSelect = function()
                            if not hasBox then
                                lib.notify({
                                    title = "Error",
                                    description = "You need to grab a box from the pallet first.",
                                    type = "error",
                                    duration = 5000,
                                    position = Config.UI.notificationPosition,
                                    markdown = Config.UI.enableMarkdown
                                })
                                return
                            end
                            
                            if lib.progressBar({
                                duration = 3000,
                                position = "bottom",
                                label = string.format("Loading box %d/%d...", boxesLoaded + 1, maxBoxes),
                                canCancel = false,
                                disable = { move = true, car = true, combat = true, sprint = true },
                                anim = { dict = "mini@repair", clip = "fixing_a_ped" }
                            }) then
                                if boxProp and DoesEntityExist(boxProp) then
                                    DeleteObject(boxProp)
                                    boxProp = nil
                                end
                                hasBox = false
                                boxesLoaded = boxesLoaded + 1
                                ClearPedTasks(playerPed)
                                
                                -- Update pallet zone
                                updatePalletZone()
                                
                                if boxesLoaded >= maxBoxes then
                                    -- All boxes loaded!
                                    lib.notify({
                                        title = "✅ Loading Complete",
                                        description = string.format("All %d boxes loaded! Coordinate with your team for delivery!", maxBoxes),
                                        type = "success",
                                        duration = 10000,
                                        position = Config.UI.notificationPosition,
                                        markdown = Config.UI.enableMarkdown
                                    })
                                    
                                    -- Clean up
                                    if palletBlip then RemoveBlip(palletBlip) end
                                    if DoesEntityExist(palletEntity) then DeleteObject(palletEntity) end
                                    
                                    for _, zone in ipairs(targetZones) do
                                        exports.ox_target:removeZone(zone)
                                    end
                                    exports.ox_target:removeZone(vanTargetName)
                                    
                                    -- Start team delivery coordination
                                    TriggerEvent("team:startCoordinatedDelivery", teamData.restaurantId, van, teamData)
                                else
                                    lib.notify({
                                        title = "Box Loaded",
                                        description = string.format("%d boxes remaining", maxBoxes - boxesLoaded),
                                        type = "success",
                                        duration = 5000,
                                        position = Config.UI.notificationPosition,
                                        markdown = Config.UI.enableMarkdown
                                    })
                                end
                            end
                        end
                    }
                }
            })
            Citizen.Wait(1000)
        end
    end

    Citizen.CreateThread(updateVanTargetZone)

    lib.notify({
        title = "🚛 Team Loading Phase",
        description = string.format("Role: %s | Load %d boxes from shared pallet", 
            teamData.memberRole == "leader" and "Team Leader" or "Team Member", 
            maxBoxes),
        type = "info",
        duration = 15000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })
end)

-- Start coordinated team delivery
RegisterNetEvent("team:startCoordinatedDelivery")
AddEventHandler("team:startCoordinatedDelivery", function(restaurantId, van, teamData)
    local deliveryStartTime = GetGameTimer()
    
    -- Set tracking variables
    deliveryBoxesRemaining = teamData.boxesAssigned
    totalDeliveryBoxes = teamData.boxesAssigned
    
    lib.alertDialog({
        header = "🚛 Team Delivery Active",
        content = "Coordinate with your team! Drive to the restaurant and deliver together for maximum bonuses!",
        centered = true,
        cancel = true
    })

    local deliveryPosition = Config.Restaurants[restaurantId].delivery
    SetNewWaypoint(deliveryPosition.x, deliveryPosition.y)
    
    local blip = AddBlipForCoord(deliveryPosition.x, deliveryPosition.y, deliveryPosition.z)
    SetBlipSprite(blip, 1)
    SetBlipScale(blip, 0.8)
    SetBlipColour(blip, teamData.memberRole == "leader" and 2 or 3)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Team Delivery Location")
    EndTextCommandSetBlipName(blip)

    lib.notify({
        title = "🚛 Team Delivery Started",
        description = string.format("Role: %s\nCoordinate with team for sync bonuses!", 
            teamData.memberRole == "leader" and "🏆 TEAM LEADER" or "👥 TEAM MEMBER"),
        type = "success",
        duration = 10000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })

    -- Monitor arrival at delivery location
    Citizen.CreateThread(function()
        local isTextUIShown = false
        while DoesEntityExist(van) do
            local playerPed = PlayerPedId()
            local vanPos = GetEntityCoords(van)
            local distance = #(vanPos - vector3(deliveryPosition.x, deliveryPosition.y, deliveryPosition.z))
            
            if distance < 10.0 and IsPedInVehicle(playerPed, van, false) then
                if not isTextUIShown then
                    lib.showTextUI("[E] Park Van & Start Team Delivery", {
                        icon = "fas fa-users"
                    })
                    isTextUIShown = true
                end
                if IsControlJustPressed(0, 38) then -- E key
                    if distance < 10.0 then
                        lib.hideTextUI()
                        isTextUIShown = false
                        
                        -- Store delivery time for coordination bonus
                        teamData.arrivalTime = GetGameTimer()
                        teamData.deliveryTime = math.floor((teamData.arrivalTime - deliveryStartTime) / 1000)
                        
                        RemoveBlip(blip)
                        
                        -- Start team delivery process (same as solo)
                        TriggerEvent("team:setupDeliveryZone", restaurantId, van, teamData)
                        break
                    end
                end
            else
                if isTextUIShown then
                    lib.hideTextUI()
                    isTextUIShown = false
                end
            end
            Citizen.Wait(0)
        end
        if isTextUIShown then
            lib.hideTextUI()
        end
        RemoveBlip(blip)
    end)
end)

-- Setup team delivery zone (matches solo system)
RegisterNetEvent("team:setupDeliveryZone")
AddEventHandler("team:setupDeliveryZone", function(restaurantId, van, teamData)
    local deliverBoxPosition = Config.Restaurants[restaurantId] and Config.Restaurants[restaurantId].deliveryBox
    if not deliverBoxPosition then
        deliverBoxPosition = vector3(-1177.39, -890.98, 12.79) -- Fallback
    end

    -- Start the delivery loop (same as solo)
    TriggerEvent("team:startDeliveryLoop", restaurantId, van, teamData, deliverBoxPosition)
end)

-- Team delivery loop (one by one, any member can deliver)
RegisterNetEvent("team:startDeliveryLoop")
AddEventHandler("team:startDeliveryLoop", function(restaurantId, van, teamData, deliverBoxPosition)
    if deliveryBoxesRemaining == totalDeliveryBoxes then
        lib.notify({
            title = "📦 Team Delivery Instructions", 
            description = string.format("Any team member can deliver! Take %d boxes to business door", totalDeliveryBoxes),
            type = "info",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
    end
    
    -- Start with grabbing box from van
    TriggerEvent("team:grabBoxFromVan", restaurantId, van, teamData, deliverBoxPosition)
end)

-- Team grab box from van (same mechanics as solo)
RegisterNetEvent("team:grabBoxFromVan")
AddEventHandler("team:grabBoxFromVan", function(restaurantId, van, teamData, deliverBoxPosition)
    if not DoesEntityExist(van) then
        lib.notify({
            title = "Error",
            description = "Delivery van not found.",
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end

    local playerPed = PlayerPedId()
    local hasBox = false
    local boxProp = nil
    local vanTargetName = "team_van_grab_" .. tostring(van)
    local propName = Config.DeliveryProps.boxProp
    local model = GetHashKey(propName)

    RequestModel(model)
    while not HasModelLoaded(model) do
        Citizen.Wait(100)
    end

    local function updateGrabBoxZone()
        while DoesEntityExist(van) and not hasBox do
            local vanPos = GetEntityCoords(van)
            local vanHeading = GetEntityHeading(van)
            local vanBackPosition = vector3(
                vanPos.x + math.sin(math.rad(vanHeading)) * 3.0,
                vanPos.y - math.cos(math.rad(vanHeading)) * 3.0,
                vanPos.z + 0.5
            )

            exports.ox_target:removeZone(vanTargetName)
            exports.ox_target:addBoxZone({
                coords = vanBackPosition,
                size = vector3(3.0, 3.0, 2.0),
                rotation = vanHeading,
                debug = false,
                name = vanTargetName,
                options = {
                    {
                        label = string.format("Grab Box (%d/%d)", totalDeliveryBoxes - deliveryBoxesRemaining + 1, totalDeliveryBoxes),
                        icon = "fas fa-box",
                        onSelect = function()
                            if hasBox then
                                lib.notify({
                                    title = "Error",
                                    description = "You are already carrying a box.",
                                    type = "error",
                                    duration = 10000,
                                    position = Config.UI.notificationPosition,
                                    markdown = Config.UI.enableMarkdown
                                })
                                return
                            end
                            if lib.progressBar({
                                duration = 3000,
                                position = "bottom",
                                label = string.format("Grabbing box %d/%d...", totalDeliveryBoxes - deliveryBoxesRemaining + 1, totalDeliveryBoxes),
                                canCancel = false,
                                disable = { move = true, car = true, combat = true, sprint = true },
                                anim = { dict = "mini@repair", clip = "fixing_a_ped" }
                            }) then
                                local playerCoords = GetEntityCoords(playerPed)
                                boxProp = CreateObject(model, playerCoords.x, playerCoords.y, playerCoords.z, true, true, true)
                                AttachEntityToEntity(boxProp, playerPed, GetPedBoneIndex(playerPed, 60309),
                                    0.1, 0.2, 0.25, -90.0, 0.0, 0.0, true, true, false, true, 1, true)

                                hasBox = true
                                local animDict = "anim@heists@box_carry@"
                                RequestAnimDict(animDict)
                                while not HasAnimDictLoaded(animDict) do
                                    Citizen.Wait(0)
                                end
                                TaskPlayAnim(playerPed, animDict, "idle", 8.0, -8.0, -1, 50, 0, false, false, false)

                                exports.ox_target:removeZone(vanTargetName)
                                TriggerEvent("team:deliverBoxWithMarker", restaurantId, van, teamData, boxProp, deliverBoxPosition)
                            end
                        end
                    }
                }
            })
            Citizen.Wait(1000)
        end
    end

    Citizen.CreateThread(updateGrabBoxZone)
end)

-- Team deliver box with ground marker (same as solo)
RegisterNetEvent("team:deliverBoxWithMarker")
AddEventHandler("team:deliverBoxWithMarker", function(restaurantId, van, teamData, boxProp, deliverBoxPosition)
    if not boxProp or not DoesEntityExist(boxProp) then
        lib.notify({
            title = "Error",
            description = "You are not carrying a box.",
            type = "error",
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end

    local playerPed = PlayerPedId()
    local targetName = "team_delivery_zone_" .. restaurantId .. "_" .. tostring(GetGameTimer())

    -- Create visual marker at delivery location
    Citizen.CreateThread(function()
        while DoesEntityExist(boxProp) do
            DrawMarker(
                Config.DeliveryProps.deliveryMarker.type,
                deliverBoxPosition.x, deliverBoxPosition.y, deliverBoxPosition.z,
                0.0, 0.0, 0.0,
                0.0, 0.0, 0.0,
                Config.DeliveryProps.deliveryMarker.size.x,
                Config.DeliveryProps.deliveryMarker.size.y,
                Config.DeliveryProps.deliveryMarker.size.z,
                Config.DeliveryProps.deliveryMarker.color.r,
                Config.DeliveryProps.deliveryMarker.color.g,
                Config.DeliveryProps.deliveryMarker.color.b,
                Config.DeliveryProps.deliveryMarker.color.a,
                Config.DeliveryProps.deliveryMarker.bobUpAndDown,
                Config.DeliveryProps.deliveryMarker.faceCamera,
                2,
                Config.DeliveryProps.deliveryMarker.rotate,
                nil, nil, false
            )
            Citizen.Wait(0)
        end
    end)

    -- Create delivery target zone
    exports.ox_target:addBoxZone({
        coords = vector3(deliverBoxPosition.x, deliverBoxPosition.y, deliverBoxPosition.z + 0.5),
        size = vector3(4.0, 4.0, 3.0),
        rotation = 0,
        debug = false,
        name = targetName,
        options = {
            {
                label = string.format("Deliver Box (%d/%d)", totalDeliveryBoxes - deliveryBoxesRemaining + 1, totalDeliveryBoxes),
                icon = "fas fa-box",
                onSelect = function()
                    if not boxProp or not DoesEntityExist(boxProp) then
                        lib.notify({
                            title = "Error",
                            description = "You are not carrying a box.",
                            type = "error",
                            duration = 10000,
                            position = Config.UI.notificationPosition,
                            markdown = Config.UI.enableMarkdown
                        })
                        return
                    end
                    if lib.progressBar({
                        duration = 3000,
                        position = "bottom",
                        label = string.format("Delivering box %d/%d...", totalDeliveryBoxes - deliveryBoxesRemaining + 1, totalDeliveryBoxes),
                        canCancel = false,
                        disable = { move = true, car = true, combat = true, sprint = true },
                        anim = { dict = "mini@repair", clip = "fixing_a_ped" }
                    }) then
                        DeleteObject(boxProp)
                        ClearPedTasks(playerPed)
                        exports.ox_target:removeZone(targetName)
                        
                        deliveryBoxesRemaining = deliveryBoxesRemaining - 1
                        
                        if deliveryBoxesRemaining > 0 then
                            -- Continue delivery loop
                            TriggerEvent("team:startDeliveryLoop", restaurantId, van, teamData, deliverBoxPosition)
                        else
                            -- All boxes delivered!
                            lib.notify({
                                title = "✅ Your Part Complete!", 
                                description = "All your boxes delivered! Wait for team to finish.",
                                type = "success",
                                duration = 10000,
                                position = Config.UI.notificationPosition,
                                markdown = Config.UI.enableMarkdown
                            })
                            
                            -- Report vehicle damage for coordination bonus
                            local vehicleHealth = GetEntityHealth(van)
                            local hasDamage = vehicleHealth < 990
                            TriggerServerEvent("team:reportVehicleDamage", teamData.teamId, hasDamage)
                            
                            -- Complete member delivery
                            TriggerServerEvent("team:completeMemberDelivery", teamData.teamId, teamData.deliveryTime)
                            
                            -- Don't delete vehicle - other team members might still be using it
                        end
                    end
                end
            }
        }
    })

    lib.notify({
        title = "Delivery Zone Active",
        description = string.format("Drop Box %d/%d at business door", totalDeliveryBoxes - deliveryBoxesRemaining + 1, totalDeliveryBoxes),
        type = "success",
        duration = 10000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })
end)

-- Handle vehicle keys for duo teams
RegisterNetEvent("team:receiveVehicleKeys")
AddEventHandler("team:receiveVehicleKeys", function(plate)
    TriggerEvent("vehiclekeys:client:SetOwner", plate)
    lib.notify({
        title = "🗝️ Vehicle Keys",
        description = "You received keys to the team vehicle",
        type = "success",
        duration = 5000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })
end)