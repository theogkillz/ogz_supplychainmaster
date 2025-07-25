-- Handles vehicle spawning with achievement tiers for teams

local QBCore = exports['qb-core']:GetCoreObject()

-- Get player's achievement tier using correct column names
local function getPlayerAchievementTier(citizenid)
    -- Get player stats with the actual column names
    local result = MySQL.Sync.fetchAll([[
        SELECT 
            total_deliveries,
            team_deliveries,
            perfect_deliveries,
            average_rating,
            level
        FROM supply_player_stats
        WHERE citizenid = ?
    ]], {citizenid})
    
    if not result[1] then
        -- Create new player record
        MySQL.Sync.execute([[
            INSERT IGNORE INTO supply_player_stats (
                citizenid, experience, level, total_deliveries, 
                solo_deliveries, team_deliveries, perfect_deliveries,
                perfect_syncs, team_earnings, average_rating, total_earnings
            ) VALUES (?, 0, 1, 0, 0, 0, 0, 0, 0.00, 0.00, 0.00)
        ]], {citizenid})
        
        return "rookie"
    end
    
    local stats = result[1]
    local tier = "rookie"
    
    -- Determine tier based on achievements
    -- You can also incorporate level into this calculation
    if stats.total_deliveries >= 500 and stats.average_rating >= 95 and stats.team_deliveries >= 50 then
        tier = "legendary"
    elseif stats.total_deliveries >= 300 and stats.average_rating >= 90 then
        tier = "elite"
    elseif stats.total_deliveries >= 150 and stats.average_rating >= 85 then
        tier = "professional"
    elseif stats.total_deliveries >= 50 and stats.average_rating >= 80 then
        tier = "experienced"
    elseif stats.total_deliveries >= 10 then
        tier = "rookie"
    end
    
    -- Alternative: Use level-based tiers
    -- if stats.level >= 50 then tier = "legendary"
    -- elseif stats.level >= 40 then tier = "elite"
    -- elseif stats.level >= 30 then tier = "professional"
    -- elseif stats.level >= 20 then tier = "experienced"
    -- elseif stats.level >= 10 then tier = "rookie"
    -- end
    
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
    
    -- Access team data via export
    if exports['ogz_supplychainmaster'] and exports['ogz_supplychainmaster']['getActiveTeamDelivery'] then
        local team = exports['ogz_supplychainmaster']:getActiveTeamDelivery(teamId)
        if team and team.members[xPlayer.PlayerData.citizenid] then
            team.members[xPlayer.PlayerData.citizenid].vehicleDamaged = hasDamage
        end
    end
end)

-- Update player stats after delivery completion
local function updatePlayerStats(citizenid, deliveryData)
    -- Update delivery counts and earnings
    MySQL.Async.execute([[
        UPDATE supply_player_stats 
        SET 
            total_deliveries = total_deliveries + 1,
            team_deliveries = team_deliveries + ?,
            solo_deliveries = solo_deliveries + ?,
            perfect_deliveries = perfect_deliveries + ?,
            perfect_syncs = perfect_syncs + ?,
            team_earnings = team_earnings + ?,
            total_earnings = total_earnings + ?,
            last_activity = NOW(),
            experience = experience + ?
        WHERE citizenid = ?
    ]], {
        deliveryData.isTeam and 1 or 0,
        deliveryData.isTeam and 0 or 1,
        deliveryData.isPerfect and 1 or 0,
        deliveryData.perfectSync and 1 or 0,
        deliveryData.isTeam and deliveryData.earnings or 0,
        deliveryData.earnings,
        deliveryData.experience or 10,
        citizenid
    })
    
    -- Check for level up
    MySQL.Async.fetchAll('SELECT experience, level FROM supply_player_stats WHERE citizenid = ?', {citizenid}, function(result)
        if result[1] then
            local currentExp = result[1].experience
            local currentLevel = result[1].level
            local nextLevel = currentLevel + 1
            local expNeeded = nextLevel * 100 -- Simple formula: level * 100 exp needed
            
            if currentExp >= expNeeded then
                MySQL.Async.execute('UPDATE supply_player_stats SET level = ? WHERE citizenid = ?', {nextLevel, citizenid})
                
                -- Notify player of level up
                local xPlayer = QBCore.Functions.GetPlayerByCitizenId(citizenid)
                if xPlayer then
                    TriggerClientEvent('ox_lib:notify', xPlayer.PlayerData.source, {
                        title = '🎉 LEVEL UP!',
                        description = string.format('You reached level %d!', nextLevel),
                        type = 'success',
                        duration = 10000,
                        position = Config.UI.notificationPosition,
                        markdown = Config.UI.enableMarkdown
                    })
                end
            end
        end
    end)
end

-- Export functions
exports('getPlayerAchievementTier', getPlayerAchievementTier)
exports('updatePlayerStats', updatePlayerStats)