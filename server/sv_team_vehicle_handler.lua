-- Handles vehicle spawning with achievement tiers for teams
local QBCore = exports['qb-core']:GetCoreObject()

-- Get player's achievement tier
local function getPlayerAchievementTier(citizenid)
    -- Check if player has achievement data
    local result = MySQL.Sync.fetchAll([[
        SELECT delivery_count, perfect_deliveries, team_deliveries,
               average_rating, total_earnings
        FROM supply_player_stats
        WHERE citizenid = ?
    ]], {citizenid})
    
    if not result[1] then
        return "rookie"
    end
    
    local stats = result[1]
    local tier = "rookie"
    
    -- Check tier requirements (matching your existing system)
    if stats.delivery_count >= 500 and stats.average_rating >= 95 and stats.team_deliveries >= 50 then
        tier = "legendary"
    elseif stats.delivery_count >= 300 and stats.average_rating >= 90 then
        tier = "elite"
    elseif stats.delivery_count >= 150 and stats.average_rating >= 85 then
        tier = "professional"
    elseif stats.delivery_count >= 50 and stats.average_rating >= 80 then
        tier = "experienced"
    end
    
    return tier
end

-- Enhanced vehicle spawn handler for teams
RegisterNetEvent("team:requestVehicleSpawn")
AddEventHandler("team:requestVehicleSpawn", function(teamData)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    local citizenid = xPlayer.PlayerData.citizenid
    
    -- Get player's achievement tier
    local achievementTier = getPlayerAchievementTier(citizenid)
    
    -- For team deliveries, use special rules
    local vehicleConfig = {
        tier = achievementTier,
        isTeamDelivery = true,
        teamRole = teamData.memberRole,
        isDuo = teamData.isDuo
    }
    
    -- Special vehicle selection for teams
    if teamData.isDuo then
        -- Duos always use the leader's achievement vehicle
        if teamData.memberRole == "leader" then
            vehicleConfig.model = "speedo" -- Can be upgraded based on tier
            vehicleConfig.applyMods = true
        else
            -- Passenger doesn't need vehicle
            vehicleConfig.skipVehicle = true
        end
    else
        -- Regular teams - everyone gets their own vehicle
        if teamData.boxesAssigned > 10 then
            vehicleConfig.model = "mule"
        elseif teamData.boxesAssigned > 5 then
            vehicleConfig.model = "speedo"
        else
            vehicleConfig.model = "speedo" -- Small loads
        end
        vehicleConfig.applyMods = true
    end
    
    -- Team-specific visual modifications
    vehicleConfig.teamVisuals = {
        -- Team color based on role
        primaryColor = teamData.memberRole == "leader" and {0, 255, 0} or {0, 150, 255},
        
        -- Special effects for high-tier team members
        specialEffects = achievementTier == "legendary" or achievementTier == "elite"
    }
    
    -- Send spawn data to client
    TriggerClientEvent("team:spawnAchievementVehicle", src, teamData, vehicleConfig)
end)

-- Track team vehicle damage for coordination bonus
RegisterNetEvent("team:reportVehicleDamage")
AddEventHandler("team:reportVehicleDamage", function(teamId, hasDamage)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    local team = activeTeamDeliveries[teamId]
    if team and team.members[xPlayer.PlayerData.citizenid] then
        team.members[xPlayer.PlayerData.citizenid].vehicleDamaged = hasDamage
    end
end)

-- Export for other scripts
exports('getPlayerAchievementTier', getPlayerAchievementTier)