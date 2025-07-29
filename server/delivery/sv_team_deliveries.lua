-- EPIC TEAM DELIVERY SYSTEM (Enhanced Version)
local QBCore = exports['qb-core']:GetCoreObject()

-- System variables
local activeTeamDeliveries = {}
local teamInvites = {}
local persistentTeams = {}
local vehicleSpawnQueue = {}
local isSpawning = false

-- Forward declarations
local startTeamDelivery
local completeTeamDelivery
local processVehicleSpawnQueue

-- Utility Functions
local function hasWarehouseAccess(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    
    local playerJob = Player.PlayerData.job.name
    for _, authorizedJob in ipairs(Config.Jobs.warehouse) do
        if playerJob == authorizedJob then
            return true
        end
    end
    
    return false
end

-- Generate unique team ID
local function generateTeamId()
    return "team_" .. os.time() .. "_" .. math.random(1000, 9999)
end

-- Create team delivery
RegisterNetEvent('team:createDelivery')
AddEventHandler('team:createDelivery', function(orderGroupId, restaurantId, deliveryType)
    local src = source
    if not hasWarehouseAccess(src) then
        return -- Silently reject unauthorized access
    end
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    local teamId = generateTeamId()
    
    if not orderGroupId or not restaurantId or not deliveryType then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Team Delivery Error',
            description = 'Missing required parameters.',
            type = 'error',
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    -- Get order details to validate team delivery eligibility
    MySQL.Async.fetchAll('SELECT * FROM supply_orders WHERE order_group_id = ?', {orderGroupId}, function(orders)
        if not orders or #orders == 0 then return end
        
        -- Calculate total boxes needed
        local totalItems = 0
        for _, order in ipairs(orders) do
            totalItems = totalItems + order.quantity
        end
        
        local itemsPerContainer = (Config.ContainerSystem and Config.ContainerSystem.itemsPerContainer) or 12
        local containersPerBox = (Config.ContainerSystem and Config.ContainerSystem.containersPerBox) or 5
        local containersNeeded = math.ceil(totalItems / itemsPerContainer)
        local boxesNeeded = math.ceil(containersNeeded / containersPerBox)
        
        if boxesNeeded < Config.TeamDeliveries.minBoxesForTeam then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Team Delivery Not Available',
                description = 'Order too small for team delivery (minimum ' .. Config.TeamDeliveries.minBoxesForTeam .. ' boxes)',
                type = 'error',
                duration = 8000,
                position = Config.UI.notificationPosition,
                markdown = Config.UI.enableMarkdown
            })
            return
        end
        
        -- Create team delivery
        activeTeamDeliveries[teamId] = {
            teamId = teamId,
            leaderId = xPlayer.PlayerData.citizenid,
            leaderName = xPlayer.PlayerData.charinfo.firstname .. ' ' .. xPlayer.PlayerData.charinfo.lastname,
            leaderSource = src,
            orderGroupId = orderGroupId,
            restaurantId = restaurantId,
            deliveryType = deliveryType,
            totalBoxes = boxesNeeded,
            members = {
                [xPlayer.PlayerData.citizenid] = {
                    citizenid = xPlayer.PlayerData.citizenid,
                    name = xPlayer.PlayerData.charinfo.firstname .. ' ' .. xPlayer.PlayerData.charinfo.lastname,
                    source = src,
                    ready = false,
                    boxesAssigned = 0,
                    completionTime = 0,
                    vehicleDamaged = false
                }
            },
            status = 'recruiting',
            createdAt = os.time(),
            startedAt = 0,
            completedAt = 0
        }
        
        TriggerClientEvent('ox_lib:notify', src, {
            title = '🚛 Team Delivery Created!',
            description = string.format('**%s** ready for %d boxes\nTeam ID: `%s`\nShare this ID to recruit drivers!', 
                Config.TeamDeliveries.deliveryTypes[deliveryType].name, 
                boxesNeeded, 
                teamId),
            type = 'success',
            duration = 15000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        
        TriggerClientEvent('team:showRecruitmentMenu', src, teamId)
    end)
end)

-- Join team delivery
RegisterNetEvent('team:joinDelivery')
AddEventHandler('team:joinDelivery', function(teamId)
    local src = source
    if not hasWarehouseAccess(src) then
        return -- Silently reject unauthorized access
    end
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    local team = activeTeamDeliveries[teamId]
    if not team then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Team Not Found',
            description = 'Invalid team ID or team no longer exists',
            type = 'error',
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    if team.status ~= 'recruiting' then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Team Unavailable',
            description = 'This team is no longer recruiting',
            type = 'error',
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    local memberCount = 0
    for _ in pairs(team.members) do memberCount = memberCount + 1 end
    
    if memberCount >= Config.TeamDeliveries.maxTeamSize then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Team Full',
            description = 'This team is already at maximum capacity',
            type = 'error',
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    if team.members[xPlayer.PlayerData.citizenid] then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Already In Team',
            description = 'You are already part of this team',
            type = 'error',
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    -- Add player to team
    team.members[xPlayer.PlayerData.citizenid] = {
        citizenid = xPlayer.PlayerData.citizenid,
        name = xPlayer.PlayerData.charinfo.firstname .. ' ' .. xPlayer.PlayerData.charinfo.lastname,
        source = src,
        ready = false,
        boxesAssigned = 0,
        completionTime = 0,
        vehicleDamaged = false
    }
    
    -- Notify all team members
    for _, member in pairs(team.members) do
        TriggerClientEvent('ox_lib:notify', member.source, {
            title = '👥 Team Update',
            description = string.format('**%s** joined the team!\n👥 Team Size: %d/%d', 
                xPlayer.PlayerData.charinfo.firstname .. ' ' .. xPlayer.PlayerData.charinfo.lastname,
                memberCount + 1,
                Config.TeamDeliveries.maxTeamSize),
            type = 'success',
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        
        TriggerClientEvent('team:updateMemberList', member.source, team)
    end
    
    TriggerClientEvent('team:showRecruitmentMenu', src, teamId)
end)

-- Enhanced ready system with persistence
RegisterNetEvent('team:setReady')
AddEventHandler('team:setReady', function(teamId, isReady)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    local team = activeTeamDeliveries[teamId]
    if not team or not team.members[xPlayer.PlayerData.citizenid] then return end
    
    -- Update ready status
    team.members[xPlayer.PlayerData.citizenid].ready = isReady
    
    -- Visual feedback for ready status
    local readyEmoji = isReady and "✅" or "⏳"
    local memberName = team.members[xPlayer.PlayerData.citizenid].name
    
    -- Check if all members are ready
    local allReady = true
    local readyCount = 0
    local totalMembers = 0
    
    for _, member in pairs(team.members) do
        totalMembers = totalMembers + 1
        if member.ready then
            readyCount = readyCount + 1
        else
            allReady = false
        end
    end
    
    -- Notify all team members with enhanced UI feedback
    for citizenid, member in pairs(team.members) do
        -- Determine if this member is the leader
        local isLeader = (citizenid == team.leaderId)
        
        -- Send notification
        TriggerClientEvent('ox_lib:notify', member.source, {
            title = '👥 Team Status Update',
            description = string.format('%s %s is %s\n\n**Ready: %d/%d**', 
                readyEmoji,
                memberName, 
                isReady and "ready!" or "not ready",
                readyCount, 
                totalMembers),
            type = isReady and 'success' or 'info',
            duration = 5000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        
        -- Update client-side ready status WITH isLeader flag
        TriggerClientEvent('team:updateReadyStatus', member.source, 
            teamId, 
            readyCount, 
            totalMembers, 
            allReady and totalMembers >= 2, -- Need at least 2 members
            isLeader
        )
    end
    
    -- If all ready and minimum team size met, prepare for delivery
    if allReady and totalMembers >= 2 then
        -- Store team for persistence
        local memberIds = {}
        for citizenid, _ in pairs(team.members) do
            table.insert(memberIds, citizenid)
        end
        table.sort(memberIds) -- Consistent key
        local teamKey = table.concat(memberIds, "_")
        
        persistentTeams[teamKey] = {
            members = team.members,
            lastDelivery = os.time(),
            deliveryCount = (persistentTeams[teamKey] and persistentTeams[teamKey].deliveryCount or 0) + 1
        }
        
        -- Special handling for duo deliveries
        local isDuoDelivery = team.deliveryType == "duo" and totalMembers == 2
        team.isDuo = isDuoDelivery
        
        -- DO NOT automatically start - wait for leader to accept
        -- The leader will see the "Accept Team Order" button in their UI
    end
end)

-- Start team delivery
startTeamDelivery = function(teamId)
    local team = activeTeamDeliveries[teamId]
    if not team then return end
    
    team.status = 'active'
    team.startedAt = os.time()
    
    -- Calculate box distribution
    local memberCount = 0
    for _ in pairs(team.members) do memberCount = memberCount + 1 end
    
    local boxesPerMember = math.floor(team.totalBoxes / memberCount)
    local extraBoxes = team.totalBoxes % memberCount
    
    local memberIndex = 0
    for citizenid, member in pairs(team.members) do
        memberIndex = memberIndex + 1
        member.boxesAssigned = boxesPerMember
        if memberIndex <= extraBoxes then
            member.boxesAssigned = member.boxesAssigned + 1
        end
    end
    
    -- Get team bonus info
    local teamBonus = nil
    for _, bonus in pairs(Config.TeamDeliveries.teamBonuses) do
        if memberCount >= bonus.size then
            teamBonus = bonus
        end
    end
    
    -- Notify all members
    for citizenid, member in pairs(team.members) do
        TriggerClientEvent('ox_lib:notify', member.source, {
            title = '🚛 TEAM DELIVERY STARTING!',
            description = string.format('**%s**\n👥 %d drivers • 📦 %d boxes each\n🎉 %s Bonus: **%.1fx**', 
                Config.TeamDeliveries.deliveryTypes[team.deliveryType].name,
                memberCount,
                member.boxesAssigned,
                teamBonus and teamBonus.name or "No Team",
                teamBonus and teamBonus.multiplier or 1.0),
            type = 'success',
            duration = 12000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
    end
    
    -- Update order status to accepted
    MySQL.Async.execute('UPDATE supply_orders SET status = ? WHERE order_group_id = ?', 
        {'accepted', team.orderGroupId})
    
    -- Start vehicle spawn sequence
    spawnTeamVehicles(teamId)
end

-- Sequential vehicle spawning to prevent collisions
function spawnTeamVehicles(teamId)
    local team = activeTeamDeliveries[teamId]
    if not team then return end
    
    vehicleSpawnQueue[teamId] = {}
    
    -- For duos, only leader gets vehicle
    if team.isDuo then
        for citizenid, member in pairs(team.members) do
            if citizenid == team.leaderId then
                table.insert(vehicleSpawnQueue[teamId], {
                    member = member,
                    isLeader = true,
                    isDuoDriver = true,
                    boxes = team.totalBoxes -- All boxes in one vehicle
                })
            else
                -- Passenger notification
                TriggerClientEvent('ox_lib:notify', member.source, {
                    title = '🚐 Duo Delivery',
                    description = 'You\'ll ride with the team leader. Wait for vehicle spawn.',
                    type = 'info',
                    duration = 8000,
                    position = Config.UI.notificationPosition,
                    markdown = Config.UI.enableMarkdown
                })
            end
        end
    else
        -- Regular team spawning (one vehicle per member)
        for citizenid, member in pairs(team.members) do
            table.insert(vehicleSpawnQueue[teamId], {
                member = member,
                isLeader = (citizenid == team.leaderId),
                boxes = member.boxesAssigned
            })
        end
    end
    
    -- Start spawn sequence
    processVehicleSpawnQueue(teamId)
end

-- Process spawn queue one at a time
processVehicleSpawnQueue = function(teamId)
    if not vehicleSpawnQueue[teamId] or #vehicleSpawnQueue[teamId] == 0 then
        vehicleSpawnQueue[teamId] = nil
        return
    end
    
    local nextSpawn = table.remove(vehicleSpawnQueue[teamId], 1)
    local teamData = activeTeamDeliveries[teamId]
    
    -- Create spawn data
    local spawnData = {
        teamId = teamId,
        memberRole = nextSpawn.isLeader and "leader" or "member",
        boxesAssigned = nextSpawn.boxes,
        restaurantId = teamData.restaurantId,
        deliveryType = teamData.deliveryType,
        isDuo = teamData.isDuo,
        isDuoDriver = nextSpawn.isDuoDriver
    }
    
    -- Trigger client spawn (will use achievement system)
    TriggerClientEvent("team:spawnDeliveryVehicle", nextSpawn.member.source, spawnData)
    
    -- Show queue status to waiting members
    if #vehicleSpawnQueue[teamId] > 0 then
        for i, waiting in ipairs(vehicleSpawnQueue[teamId]) do
            TriggerClientEvent('ox_lib:notify', waiting.member.source, {
                title = '⏳ Vehicle Queue',
                description = string.format('Position in queue: %d\nPlease wait for your turn...', i),
                type = 'info',
                duration = 5000,
                position = Config.UI.notificationPosition,
                markdown = Config.UI.enableMarkdown
            })
        end
    end
end

RegisterNetEvent('supply:teams:acceptOrder')
AddEventHandler('supply:teams:acceptOrder', function(teamId)
    local src = source
    local team = activeTeamDeliveries[teamId]
    
    if not team then
        TriggerClientEvent('ox_lib:notify', src, {
            title = '❌ Error',
            description = 'Team not found',
            type = 'error',
            duration = 5000,
            position = Config.UI.notificationPosition
        })
        return
    end
    
    -- Verify player is team leader
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer or team.leaderId ~= xPlayer.PlayerData.citizenid then
        TriggerClientEvent('ox_lib:notify', src, {
            title = '❌ Error',
            description = 'Only team leader can accept orders',
            type = 'error',
            duration = 5000,
            position = Config.UI.notificationPosition
        })
        return
    end
    
    -- Verify all members are ready
    local allReady = true
    local memberCount = 0
    for _, member in pairs(team.members) do
        memberCount = memberCount + 1
        if not member.ready then
            allReady = false
            break
        end
    end
    
    if not allReady or memberCount < 2 then
        TriggerClientEvent('ox_lib:notify', src, {
            title = '⚠️ Not Ready',
            description = 'All team members must be ready (minimum 2 players)',
            type = 'warning',
            duration = 5000,
            position = Config.UI.notificationPosition
        })
        return
    end
    
    -- Update team status
    team.status = 'active'
    team.startedAt = os.time()
    
    -- Calculate box distribution
    local boxesPerMember = math.floor(team.totalBoxes / memberCount)
    local extraBoxes = team.totalBoxes % memberCount
    
    local memberIndex = 0
    for citizenid, member in pairs(team.members) do
        memberIndex = memberIndex + 1
        member.boxesAssigned = boxesPerMember
        if memberIndex <= extraBoxes then
            member.boxesAssigned = member.boxesAssigned + 1
        end
    end
    
    -- Get team bonus info
    local teamBonus = nil
    for _, bonus in pairs(Config.TeamDeliveries.teamBonuses) do
        if memberCount >= bonus.size then
            teamBonus = bonus
        end
    end
    
    -- Update order status in database
    MySQL.Async.execute('UPDATE supply_orders SET status = ? WHERE order_group_id = ?', 
        {'accepted', team.orderGroupId}, function(rowsChanged)
        if rowsChanged > 0 then
            -- Notify all team members
            for citizenid, member in pairs(team.members) do
                TriggerClientEvent('ox_lib:notify', member.source, {
                    title = '🚛 TEAM DELIVERY STARTING!',
                    description = string.format(
                        '**%s**\n👥 %d drivers • 📦 %d boxes each\n🎉 %s Bonus: **%.1fx**', 
                        Config.TeamDeliveries.deliveryTypes[team.deliveryType].name,
                        memberCount,
                        member.boxesAssigned,
                        teamBonus and teamBonus.name or "No Team",
                        teamBonus and teamBonus.multiplier or 1.0
                    ),
                    type = 'success',
                    duration = 12000,
                    position = Config.UI.notificationPosition,
                    markdown = Config.UI.enableMarkdown
                })
            end
            
            -- Start vehicle spawn sequence
            spawnTeamVehicles(teamId)
        else
            TriggerClientEvent('ox_lib:notify', src, {
                title = '❌ Error',
                description = 'Failed to accept order. It may have been taken.',
                type = 'error',
                duration = 5000,
                position = Config.UI.notificationPosition
            })
        end
    end)
end)

-- Client confirms vehicle is clear of spawn
RegisterNetEvent('team:vehicleSpawnComplete')
AddEventHandler('team:vehicleSpawnComplete', function(teamId)
    -- Process next in queue
    if vehicleSpawnQueue[teamId] then
        Citizen.Wait(2000) -- 2 second buffer
        processVehicleSpawnQueue(teamId)
    end
end)

-- Track vehicle damage for coordination bonus
RegisterNetEvent('team:reportVehicleDamage')
AddEventHandler('team:reportVehicleDamage', function(teamId, hasDamage)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    local team = activeTeamDeliveries[teamId]
    if team and team.members[xPlayer.PlayerData.citizenid] then
        team.members[xPlayer.PlayerData.citizenid].vehicleDamaged = hasDamage
    end
end)

-- Complete team member delivery
RegisterNetEvent('team:completeMemberDelivery')
AddEventHandler('team:completeMemberDelivery', function(teamId, deliveryTime)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    local team = activeTeamDeliveries[teamId]
    if not team or not team.members[xPlayer.PlayerData.citizenid] then return end
    
    team.members[xPlayer.PlayerData.citizenid].completionTime = deliveryTime
    
    -- Check if all members completed
    local allCompleted = true
    local completionTimes = {}
    
    for _, member in pairs(team.members) do
        if member.completionTime == 0 then
            allCompleted = false
        else
            table.insert(completionTimes, member.completionTime)
        end
    end
    
    if allCompleted then
        completeTeamDelivery(teamId, completionTimes)
    else
        -- Notify remaining team members
        local remainingCount = 0
        for _, member in pairs(team.members) do
            if member.completionTime == 0 then
                remainingCount = remainingCount + 1
            else
                TriggerClientEvent('ox_lib:notify', member.source, {
                    title = '👥 Waiting for Team',
                    description = string.format('%d drivers still completing delivery...', remainingCount),
                    type = 'info',
                    duration = 8000,
                    position = Config.UI.notificationPosition,
                    markdown = Config.UI.enableMarkdown
                })
            end
        end
    end
end)

-- Complete team delivery with BALANCED payment system
completeTeamDelivery = function(teamId, completionTimes)
    local team = activeTeamDeliveries[teamId]
    if not team then return end
    
    team.status = 'completed'
    team.completedAt = os.time()
    
    -- Calculate coordination bonus
    table.sort(completionTimes)
    local timeDiff = completionTimes[#completionTimes] - completionTimes[1]
    
    -- Check for vehicle damage (for perfect sync requirement)
    local allNoDamage = true
    for _, member in pairs(team.members) do
        if member.vehicleDamaged then
            allNoDamage = false
            break
        end
    end
    
    local coordinationBonus = nil
    for _, bonus in pairs(Config.TeamDeliveries.coordinationBonuses) do
        -- Perfect sync requires timing AND no damage
        if bonus.requirements and bonus.requirements.noDamage and not allNoDamage then
            -- Skip this bonus if damage requirement not met
        elseif timeDiff <= bonus.maxTimeDiff then
            coordinationBonus = bonus
            break
        end
    end
    
    -- Calculate team size bonus
    local memberCount = 0
    for _ in pairs(team.members) do memberCount = memberCount + 1 end
    
    local teamBonus = nil
    for _, bonus in pairs(Config.TeamDeliveries.teamBonuses) do
        if memberCount >= bonus.size then
            teamBonus = bonus
        end
    end
    
    -- BALANCED PAYMENT CALCULATION
    -- Using the same base pay system as solo deliveries
    local basePayPerBox = Config.EconomyBalance.basePayPerBox -- $75 per box
    
    -- Track team performance for leaderboard
    local teamMembers = {}
    local totalTeamPayout = 0
    
    -- Distribute rewards to all team members
    for citizenid, member in pairs(team.members) do
        -- Base calculation (same as solo)
        local basePay = basePayPerBox * member.boxesAssigned
        
        -- Apply team multiplier (smaller than before)
        local teamMultiplier = teamBonus and teamBonus.multiplier or 1.0
        
        -- Calculate delivery time for speed bonus
        local deliveryTime = member.completionTime
        local speedBonus = 1.0
        
        -- Apply speed bonuses (same as solo deliveries)
        for _, bonus in pairs(Config.DriverRewards.speedBonuses) do
            if deliveryTime <= bonus.maxTime then
                speedBonus = bonus.multiplier
                break
            end
        end
        
        -- Calculate volume bonus (flat amount, not multiplier)
        local volumeBonus = 0
        for _, bonus in pairs(Config.DriverRewards.volumeBonuses) do
            if member.boxesAssigned >= bonus.minBoxes then
                volumeBonus = bonus.bonus
                break
            end
        end
        
        -- Final calculation with all bonuses
        local finalPay = math.floor(basePay * teamMultiplier * speedBonus) + volumeBonus
        
        -- Add coordination bonus (flat amount)
        if coordinationBonus then 
            finalPay = finalPay + coordinationBonus.bonus 
        end
        
        -- Apply min/max limits
        finalPay = math.max(Config.EconomyBalance.minimumDeliveryPay, finalPay)
        finalPay = math.min(Config.EconomyBalance.maximumDeliveryPay, finalPay)
        -- Store the payout for database logging
            member.finalPay = finalPay

            -- Pay the player
            local xPlayer = QBCore.Functions.GetPlayer(member.source)
            if xPlayer then
                xPlayer.Functions.AddMoney('bank', finalPay, "Team delivery payment")
            
            -- Detailed payment breakdown
            local breakdown = {
                base = basePay,
                teamBonus = string.format("%.0f%%", (teamMultiplier - 1) * 100),
                speedBonus = speedBonus > 1 and string.format("%.0f%%", (speedBonus - 1) * 100) or "None",
                volumeBonus = volumeBonus > 0 and ("$" .. volumeBonus) or "None",
                coordinationBonus = coordinationBonus and ("$" .. coordinationBonus.bonus) or "None",
                total = finalPay
            }
            
            TriggerClientEvent('ox_lib:notify', member.source, {
                title = '🎉 TEAM DELIVERY COMPLETE!',
                description = string.format(
                    '💰 **Total Payment: $%d**\n\n**Breakdown:**\n📦 Base: $%d (%d boxes)\n🤝 Team: +%s\n⚡ Speed: %s\n📊 Volume: %s\n🎯 Sync: %s\n\n⏱️ Team Sync: %ds',
                    breakdown.total,
                    breakdown.base,
                    member.boxesAssigned,
                    breakdown.teamBonus,
                    breakdown.speedBonus,
                    breakdown.volumeBonus,
                    breakdown.coordinationBonus,
                    timeDiff
                ),
                type = 'success',
                duration = 20000,
                position = Config.UI.notificationPosition,
                markdown = Config.UI.enableMarkdown
            })
        end
        
        table.insert(teamMembers, citizenid)
        totalTeamPayout = totalTeamPayout + finalPay
        
        -- Update player stats
        if exports['ogz_supplychainmaster'] and exports['ogz_supplychainmaster']['updatePlayerStats'] then
            exports['ogz_supplychainmaster']:updatePlayerStats(citizenid, {
                isTeam = true,
                isPerfect = speedBonus >= 1.4, -- Lightning fast
                perfectSync = coordinationBonus and coordinationBonus.name == "⚡ Perfect Sync",
                earnings = finalPay,
                experience = 10 + (coordinationBonus and 5 or 0) -- Bonus XP for good coordination
            })
        end
    end
    
    -- Update team statistics for leaderboard
    if exports['ogz_supplychain'] and exports['ogz_supplychain']['updateTeamStats'] then
        exports['ogz_supplychain']:updateTeamStats(teamMembers, team.totalBoxes, timeDiff, coordinationBonus)
    end
    
    -- Check for team challenges
    if exports['ogz_supplychain'] and exports['ogz_supplychain']['checkTeamChallenges'] then
        local challengeRewards = exports['ogz_supplychain']:checkTeamChallenges(table.concat(teamMembers, "_"), team.totalBoxes, team.totalBoxes)
        
        -- Award challenge bonuses
        for _, reward in ipairs(challengeRewards) do
            for _, member in pairs(team.members) do
                local xPlayer = QBCore.Functions.GetPlayer(member.source)
                if xPlayer then
                    xPlayer.Functions.AddMoney('bank', reward.reward, "Team challenge reward")
                    TriggerClientEvent('ox_lib:notify', member.source, {
                        title = '🏆 Challenge Complete!',
                        description = string.format('%s\n💰 Bonus: $%d', reward.name, reward.reward),
                        type = 'success',
                        duration = 10000,
                        position = Config.UI.notificationPosition,
                        markdown = Config.UI.enableMarkdown
                    })
                end
            end
        end
    end
    
    -- Log team delivery
    MySQL.Async.execute([[
    INSERT INTO supply_team_deliveries (
        team_id, order_group_id, restaurant_id, leader_citizenid,
        member_count, total_boxes, delivery_type, coordination_bonus, 
        team_multiplier, completion_time, total_payout
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
]], {
    teamId,
    team.orderGroupId,
    team.restaurantId,
    team.leaderId,
    memberCount,
    team.totalBoxes,
    team.deliveryType,
    coordinationBonus and coordinationBonus.bonus or 0.00,
    teamBonus and teamBonus.multiplier or 1.00,
    timeDiff,
    totalTeamPayout
}, function(insertId)
    -- Log each member's participation
    for citizenid, member in pairs(team.members) do
        MySQL.Async.execute([[
            INSERT INTO supply_team_delivery_members (
                team_id, citizenid, role, boxes_assigned, boxes_delivered,
                individual_payout, vehicle_damaged, delivery_time
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            teamId,
            citizenid,
            citizenid == team.leaderId and 'leader' or 'member',
            member.boxesAssigned,
            member.boxesAssigned, -- Assuming all assigned boxes were delivered
            member.finalPay or 0, -- Need to store this during payout calculation
            member.vehicleDamaged and 1 or 0,
            member.completionTime
        })
    end
end)
    
    -- Update order status
    MySQL.Async.execute('UPDATE supply_orders SET status = ? WHERE order_group_id = ?', 
        {'delivered', team.orderGroupId})
    
    -- Clean up
    activeTeamDeliveries[teamId] = nil
end

-- Get available teams for joining
RegisterNetEvent('team:getAvailableTeams')
AddEventHandler('team:getAvailableTeams', function()
    local src = source
    local availableTeams = {}
    local currentTime = os.time()
    
    for teamId, team in pairs(activeTeamDeliveries) do
        if team.status == 'recruiting' then
            local memberCount = 0
            for _ in pairs(team.members) do memberCount = memberCount + 1 end
            
            if memberCount < Config.TeamDeliveries.maxTeamSize then
                -- Calculate time ago on server side
                local timeAgo = currentTime - team.createdAt
                local timeText = timeAgo < 60 and (timeAgo .. "s ago") or (math.floor(timeAgo/60) .. "m ago")
                
                table.insert(availableTeams, {
                    teamId = teamId,
                    leaderName = team.leaderName,
                    deliveryType = team.deliveryType,
                    totalBoxes = team.totalBoxes,
                    memberCount = memberCount,
                    maxMembers = Config.TeamDeliveries.maxTeamSize,
                    timeText = timeText -- Send calculated time to client
                })
            end
        end
    end
    
    TriggerClientEvent('team:showAvailableTeams', src, availableTeams)
end)

-- Get team status for display
RegisterNetEvent('team:getTeamStatus')
AddEventHandler('team:getTeamStatus', function(teamId)
    local src = source
    local team = activeTeamDeliveries[teamId]
    
    if not team then return end
    
    local teamData = {
        teamId = teamId,
        deliveryTypeName = Config.TeamDeliveries.deliveryTypes[team.deliveryType].name,
        members = {}
    }
    
    -- Build member list
    for citizenid, member in pairs(team.members) do
        table.insert(teamData.members, {
            name = member.name,
            isLeader = (citizenid == team.leaderId),
            ready = member.ready,
            boxesAssigned = member.boxesAssigned
        })
    end
    
    TriggerClientEvent('team:showTeamStatus', src, teamData)
end)

-- Check for persistent teams when creating new delivery
RegisterNetEvent('team:checkPersistentTeam')
AddEventHandler('team:checkPersistentTeam', function()
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    local citizenid = xPlayer.PlayerData.citizenid
    
    -- Look for existing team
    for teamKey, teamData in pairs(persistentTeams) do
        if teamData.members[citizenid] and (os.time() - teamData.lastDelivery) < 1800 then -- 30 min timeout
            -- Found recent team
            local memberNames = {}
            local onlineCount = 0
            
            for cid, member in pairs(teamData.members) do
                table.insert(memberNames, member.name)
                -- Check if online
                local memberPlayer = QBCore.Functions.GetPlayerByCitizenId(cid)
                if memberPlayer then
                    onlineCount = onlineCount + 1
                end
            end
            
            if onlineCount >= 2 then
                TriggerClientEvent('team:promptRejoinTeam', src, {
                    teamKey = teamKey,
                    members = memberNames,
                    deliveryCount = teamData.deliveryCount,
                    onlineCount = onlineCount
                })
                return
            end
        end
    end
end)

-- Rejoin persistent team
RegisterNetEvent('team:rejoinPersistentTeam')
AddEventHandler('team:rejoinPersistentTeam', function(teamKey)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    local teamData = persistentTeams[teamKey]
    if not teamData then return end
    
    -- Create notification for online team members
    for cid, member in pairs(teamData.members) do
        local memberPlayer = QBCore.Functions.GetPlayerByCitizenId(cid)
        if memberPlayer then
            TriggerClientEvent('ox_lib:notify', memberPlayer.PlayerData.source, {
                title = '👥 Team Reunited!',
                description = string.format('Your team is back together!\nDeliveries completed together: %d', teamData.deliveryCount),
                type = 'success',
                duration = 10000,
                position = Config.UI.notificationPosition,
                markdown = Config.UI.enableMarkdown
            })
        end
    end
    
    -- Direct to order selection
    TriggerServerEvent("warehouse:getPendingOrders")
end)

-- Leave team delivery
RegisterNetEvent('team:leaveDelivery')
AddEventHandler('team:leaveDelivery', function(teamId)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    local team = activeTeamDeliveries[teamId]
    if not team or not team.members[xPlayer.PlayerData.citizenid] then return end
    
    -- Remove from team
    team.members[xPlayer.PlayerData.citizenid] = nil
    
    -- Notify remaining members
    for _, member in pairs(team.members) do
        TriggerClientEvent('ox_lib:notify', member.source, {
            title = '👥 Team Update',
            description = xPlayer.PlayerData.charinfo.firstname .. ' left the team',
            type = 'warning',
            duration = 5000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
    end
    
    -- Disband if no members left
    local memberCount = 0
    for _ in pairs(team.members) do memberCount = memberCount + 1 end
    
    if memberCount == 0 then
        activeTeamDeliveries[teamId] = nil
    end
end)

-- Get personal team statistics
RegisterNetEvent('team:getPersonalTeamStats')
AddEventHandler('team:getPersonalTeamStats', function()
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    local citizenid = xPlayer.PlayerData.citizenid
    
    -- Get team stats
    MySQL.Async.fetchAll([[
        SELECT 
            COALESCE(ps.team_deliveries, 0) as team_deliveries,
            COALESCE(ps.perfect_syncs, 0) as perfect_syncs,
            COALESCE(ps.team_earnings, 0) as team_earnings,
            COALESCE(ps.average_rating, 0) as average_rating
        FROM supply_player_stats ps
        WHERE ps.citizenid = ?
    ]], {citizenid}, function(playerStats)
        local stats = playerStats[1] or {
            team_deliveries = 0,
            perfect_syncs = 0,
            team_earnings = 0,
            average_rating = 0
        }
        
        -- Get sync time stats
        MySQL.Async.fetchAll([[
            SELECT 
                AVG(completion_time) as avg_sync_time,
                SUM(coordination_bonus) as total_sync_bonuses
            FROM supply_team_deliveries td
            JOIN supply_team_delivery_members tdm ON td.team_id = tdm.team_id
            WHERE tdm.citizenid = ?
        ]], {citizenid}, function(syncStats)
            if syncStats[1] then
                stats.avg_sync_time = math.floor(syncStats[1].avg_sync_time or 0)
                stats.total_sync_bonuses = syncStats[1].total_sync_bonuses or 0
            end
            
            -- Get favorite teammates
            MySQL.Async.fetchAll([[
                SELECT 
                    tdm2.citizenid,
                    COUNT(*) as delivery_count
                FROM supply_team_delivery_members tdm1
                JOIN supply_team_delivery_members tdm2 ON tdm1.team_id = tdm2.team_id
                WHERE tdm1.citizenid = ? AND tdm2.citizenid != ?
                GROUP BY tdm2.citizenid
                ORDER BY delivery_count DESC
                LIMIT 5
            ]], {citizenid, citizenid}, function(teammates)
                stats.favorite_teammates = {}
                
                -- Get names for teammates
                for _, teammate in ipairs(teammates) do
                    local teammatePlayer = QBCore.Functions.GetPlayerByCitizenId(teammate.citizenid)
                    local name = "Unknown"
                    
                    if teammatePlayer then
                        name = teammatePlayer.PlayerData.charinfo.firstname .. ' ' .. teammatePlayer.PlayerData.charinfo.lastname
                    else
                        -- Try to get from database
                        local result = MySQL.Sync.fetchAll('SELECT charinfo FROM players WHERE citizenid = ?', {teammate.citizenid})
                        if result[1] and result[1].charinfo then
                            local charinfo = json.decode(result[1].charinfo)
                            name = charinfo.firstname .. ' ' .. charinfo.lastname
                        end
                    end
                    
                    table.insert(stats.favorite_teammates, {
                        name = name,
                        count = teammate.delivery_count
                    })
                end
                
                -- Get best team performance
                MySQL.Async.fetchAll([[
                    SELECT 
                        td.team_id,
                        td.completion_time,
                        COUNT(DISTINCT tdm.citizenid) as member_count
                    FROM supply_team_deliveries td
                    JOIN supply_team_delivery_members tdm ON td.team_id = tdm.team_id
                    WHERE tdm.team_id IN (
                        SELECT team_id FROM supply_team_delivery_members WHERE citizenid = ?
                    )
                    GROUP BY td.team_id
                    ORDER BY td.completion_time ASC
                    LIMIT 1
                ]], {citizenid}, function(bestTeam)
                    if bestTeam[1] then
                        -- Get all members of best team
                        MySQL.Async.fetchAll([[
                            SELECT citizenid FROM supply_team_delivery_members WHERE team_id = ?
                        ]], {bestTeam[1].team_id}, function(members)
                            local memberNames = {}
                            for _, member in ipairs(members) do
                                local memberPlayer = QBCore.Functions.GetPlayerByCitizenId(member.citizenid)
                                if memberPlayer then
                                    table.insert(memberNames, memberPlayer.PlayerData.charinfo.firstname)
                                end
                            end
                            
                            stats.best_team = {
                                members = table.concat(memberNames, ", "),
                                sync_time = bestTeam[1].completion_time,
                                deliveries = 1 -- Would need more complex query for total deliveries together
                            }
                            
                            TriggerClientEvent('team:showPersonalStats', src, stats)
                        end)
                    else
                        TriggerClientEvent('team:showPersonalStats', src, stats)
                    end
                end)
            end)
        end)
    end)
end)

-- Enhanced check for persistent teams
RegisterNetEvent('team:checkPersistentTeam')
AddEventHandler('team:checkPersistentTeam', function()
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    local citizenid = xPlayer.PlayerData.citizenid
    
    -- Get recent team members (last 7 days)
    MySQL.Async.fetchAll([[
        SELECT 
            tdm2.citizenid,
            COUNT(DISTINCT td.team_id) as delivery_count,
            MAX(td.created_at) as last_delivery
        FROM supply_team_delivery_members tdm1
        JOIN supply_team_delivery_members tdm2 ON tdm1.team_id = tdm2.team_id
        JOIN supply_team_deliveries td ON td.team_id = tdm1.team_id
        WHERE tdm1.citizenid = ? 
        AND tdm2.citizenid != ?
        AND td.created_at > DATE_SUB(NOW(), INTERVAL 7 DAY)
        GROUP BY tdm2.citizenid
        HAVING delivery_count >= 2
        ORDER BY delivery_count DESC, last_delivery DESC
    ]], {citizenid, citizenid}, function(recentTeammates)
        local recentTeams = {}
        local processedGroups = {}
        
        for _, teammate in ipairs(recentTeammates) do
            -- Get all team members who played with both players
            MySQL.Async.fetchAll([[
                SELECT DISTINCT tdm.citizenid
                FROM supply_team_delivery_members tdm
                WHERE tdm.team_id IN (
                    SELECT td.team_id 
                    FROM supply_team_deliveries td
                    JOIN supply_team_delivery_members tdm1 ON td.team_id = tdm1.team_id
                    JOIN supply_team_delivery_members tdm2 ON td.team_id = tdm2.team_id
                    WHERE tdm1.citizenid = ? AND tdm2.citizenid = ?
                    AND td.created_at > DATE_SUB(NOW(), INTERVAL 7 DAY)
                )
            ]], {citizenid, teammate.citizenid}, function(teamMembers)
                local memberIds = {}
                local memberNames = {}
                local onlineCount = 0
                
                for _, member in ipairs(teamMembers) do
                    table.insert(memberIds, member.citizenid)
                    
                    local memberPlayer = QBCore.Functions.GetPlayerByCitizenId(member.citizenid)
                    if memberPlayer then
                        table.insert(memberNames, memberPlayer.PlayerData.charinfo.firstname)
                        onlineCount = onlineCount + 1
                    else
                        -- Get name from database
                        local result = MySQL.Sync.fetchAll('SELECT charinfo FROM players WHERE citizenid = ?', {member.citizenid})
                        if result[1] and result[1].charinfo then
                            local charinfo = json.decode(result[1].charinfo)
                            table.insert(memberNames, charinfo.firstname)
                        end
                    end
                end
                
                -- Create team key
                table.sort(memberIds)
                local teamKey = table.concat(memberIds, "_")
                
                -- Avoid duplicate team groups
                if not processedGroups[teamKey] and #memberNames >= 2 then
                    processedGroups[teamKey] = true
                    
                    -- Calculate time since last active
                    local lastActive = teammate.last_delivery
                    local timeDiff = os.time() - lastActive
                    local lastActiveText = "Unknown"
                    
                    if timeDiff < 3600 then
                        lastActiveText = math.floor(timeDiff / 60) .. " minutes ago"
                    elseif timeDiff < 86400 then
                        lastActiveText = math.floor(timeDiff / 3600) .. " hours ago"
                    else
                        lastActiveText = math.floor(timeDiff / 86400) .. " days ago"
                    end
                    
                    table.insert(recentTeams, {
                        teamKey = teamKey,
                        members = memberIds,
                        memberNames = memberNames,
                        deliveryCount = teammate.delivery_count,
                        onlineCount = onlineCount,
                        lastActiveText = lastActiveText
                    })
                end
            end)
        end
        
        -- Send results after a short delay to ensure all queries complete
        Citizen.SetTimeout(500, function()
            if #recentTeams == 0 then
                TriggerClientEvent('team:showRecentTeams', src, {})
            else
                -- Sort by online count and delivery count
                table.sort(recentTeams, function(a, b)
                    if a.onlineCount == b.onlineCount then
                        return a.deliveryCount > b.deliveryCount
                    end
                    return a.onlineCount > b.onlineCount
                end)
                
                TriggerClientEvent('team:showRecentTeams', src, recentTeams)
            end
        end)
    end)
end)

-- Add to existing sv_team_deliveries.lua for proper team data refresh
RegisterNetEvent('team:getTeamData')
AddEventHandler('team:getTeamData', function(teamId)
    local src = source
    local team = activeTeamDeliveries[teamId]
    
    if not team then return end
    
    -- Check if player is leader
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    local isLeader = team.leaderId == xPlayer.PlayerData.citizenid
    
    -- Check if all ready
    local allReady = true
    local memberCount = 0
    for _, member in pairs(team.members) do
        memberCount = memberCount + 1
        if not member.ready then
            allReady = false
        end
    end
    
    local teamData = {
        isLeader = isLeader,
        allReady = allReady and memberCount >= 2
    }
    
    TriggerClientEvent('team:showRecruitmentMenu', src, teamId, teamData)
end)

-- Export to access active team deliveries from other scripts
exports('getActiveTeamDelivery', function(teamId)
    return activeTeamDeliveries[teamId]
end)