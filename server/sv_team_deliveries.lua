-- EPIC TEAM DELIVERY SYSTEM

local QBCore = exports['qb-core']:GetCoreObject()

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

-- Active team deliveries
local activeTeamDeliveries = {}
local teamInvites = {}
local startTeamDelivery
local completeTeamDelivery

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
                    completionTime = 0
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
        completionTime = 0
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
end)

-- Ready up for team delivery
RegisterNetEvent('team:setReady')
AddEventHandler('team:setReady', function(teamId, isReady)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    local team = activeTeamDeliveries[teamId]
    if not team or not team.members[xPlayer.PlayerData.citizenid] then return end
    
    team.members[xPlayer.PlayerData.citizenid].ready = isReady
    
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
    
    -- Notify all team members of ready status
    for _, member in pairs(team.members) do
        TriggerClientEvent('team:updateReadyStatus', member.source, teamId, readyCount, totalMembers, allReady)
    end
    
    -- Start delivery if all ready and minimum team size met
    if allReady and totalMembers >= 2 then
        startTeamDelivery(teamId)
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
    
    -- Notify all members and spawn vehicles
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
        
        -- Spawn delivery vehicles for each member
        RegisterNetEvent("team:spawnDeliveryVehicle")
        AddEventHandler("team:spawnDeliveryVehicle", function(teamData)
            local src = source
            local xPlayer = QBCore.Functions.GetPlayer(src)
            if not xPlayer then return end
            
            local citizenid = xPlayer.PlayerData.citizenid
            
            -- Get achievement tier for team leader (or highest in team)
            local achievementTier = "rookie"
            
            if teamData.memberRole == "leader" then
                achievementTier = exports['ogz_supplychain']:getPlayerAchievementTier(citizenid)
            else
                -- For team members, could use leader's tier or individual tier
                achievementTier = exports['ogz_supplychain']:getPlayerAchievementTier(citizenid)
            end
            
            -- Enhanced team data with achievement info
            teamData.achievementTier = achievementTier
            teamData.performanceBonus = Config.AchievementVehicles.performanceTiers[achievementTier].speedMultiplier
            
            TriggerClientEvent("team:spawnAchievementVehicle", src, teamData, achievementTier)
        end)
    
    -- Update order status to accepted
    MySQL.Async.execute('UPDATE supply_orders SET status = ? WHERE order_group_id = ?', 
        {'accepted', team.orderGroupId})
end

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

-- Complete team delivery with coordination bonuses
completeTeamDelivery = function(teamId, completionTimes)
    local team = activeTeamDeliveries[teamId]
    if not team then return end
    
    team.status = 'completed'
    team.completedAt = os.time()
    
    -- Calculate coordination bonus
    table.sort(completionTimes)
    local timeDiff = completionTimes[#completionTimes] - completionTimes[1]
    
    local coordinationBonus = nil
    for _, bonus in pairs(Config.TeamDeliveries.coordinationBonuses) do
        if timeDiff <= bonus.maxTimeDiff then
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
    
    -- Distribute rewards to all team members
    for _, member in pairs(team.members) do
        local basePay = 1000 * member.boxesAssigned -- Base calculation
        
        local totalMultiplier = 1.0
        if teamBonus then totalMultiplier = totalMultiplier * teamBonus.multiplier end
        
        local finalPay = math.floor(basePay * totalMultiplier)
        if coordinationBonus then finalPay = finalPay + coordinationBonus.bonus end
        
        local xPlayer = QBCore.Functions.GetPlayer(member.source)
        if xPlayer then
            xPlayer.Functions.AddMoney('bank', finalPay, "Team delivery payment")
            
            TriggerClientEvent('ox_lib:notify', member.source, {
                title = '🎉 TEAM DELIVERY COMPLETE!',
                description = string.format(
                    '💰 **Total Payment: $%d**\n🤝 %s\n%s\n⏱️ Team Sync: %ds difference',
                    finalPay,
                    teamBonus and teamBonus.name or "Solo work",
                    coordinationBonus and ('🎯 ' .. coordinationBonus.name .. ': +$' .. coordinationBonus.bonus) or "",
                    timeDiff
                ),
                type = 'success',
                duration = 15000,
                position = Config.UI.notificationPosition,
                markdown = Config.UI.enableMarkdown
            })
        end
    end
    
    -- Calculate total payout for logging
local totalPayout = 0
for _, member in pairs(team.members) do
    local basePay = 1000 * member.boxesAssigned
    local totalMultiplier = 1.0
    if teamBonus then totalMultiplier = totalMultiplier * teamBonus.multiplier end
    
    local finalPay = math.floor(basePay * totalMultiplier)
    if coordinationBonus then finalPay = finalPay + coordinationBonus.bonus end
    
    totalPayout = totalPayout + finalPay
end

-- Log team delivery with all required fields
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
    team.leaderId,  -- Already available in team object
    memberCount,
    team.totalBoxes,
    team.deliveryType,  -- Already available in team object
    coordinationBonus and coordinationBonus.bonus or 0.00,
    teamBonus and teamBonus.multiplier or 1.00,
    timeDiff,
    totalPayout
})
    
    -- Clean up
    activeTeamDeliveries[teamId] = nil
end

-- Get available teams for joining
RegisterNetEvent('team:getAvailableTeams')
AddEventHandler('team:getAvailableTeams', function()
    local src = source
    local availableTeams = {}
    local currentTime = os.time() -- Server-side os.time() is fine
    
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
end