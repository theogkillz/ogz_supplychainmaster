-- Competitive team tracking system
local QBCore = exports['qb-core']:GetCoreObject()

-- Team statistics tracking
local teamStats = {
    daily = {},
    weekly = {},
    allTime = {}
}

-- Track team performance
local function updateTeamStats(teamMembers, boxes, completionTime, coordinationBonus)
    local teamKey = table.concat(teamMembers, "_")
    local today = os.date("%Y-%m-%d")
    local week = os.date("%Y-W%V")
    
    -- Initialize if needed
    if not teamStats.daily[today] then teamStats.daily[today] = {} end
    if not teamStats.weekly[week] then teamStats.weekly[week] = {} end
    if not teamStats.allTime[teamKey] then 
        teamStats.allTime[teamKey] = {
            members = teamMembers,
            totalDeliveries = 0,
            totalBoxes = 0,
            bestTime = 999999,
            perfectSyncs = 0,
            totalEarnings = 0
        }
    end
    
    -- Update daily stats
    if not teamStats.daily[today][teamKey] then
        teamStats.daily[today][teamKey] = {
            members = teamMembers,
            deliveries = 0,
            boxes = 0,
            earnings = 0
        }
    end
    
    teamStats.daily[today][teamKey].deliveries = teamStats.daily[today][teamKey].deliveries + 1
    teamStats.daily[today][teamKey].boxes = teamStats.daily[today][teamKey].boxes + boxes
    
    -- Update all-time stats
    local allTime = teamStats.allTime[teamKey]
    allTime.totalDeliveries = allTime.totalDeliveries + 1
    allTime.totalBoxes = allTime.totalBoxes + boxes
    if completionTime < allTime.bestTime then
        allTime.bestTime = completionTime
    end
    if coordinationBonus and coordinationBonus.name == "⚡ Perfect Sync" then
        allTime.perfectSyncs = allTime.perfectSyncs + 1
    end
end

-- Get team leaderboard with weekly reset
RegisterNetEvent('team:getLeaderboard')
AddEventHandler('team:getLeaderboard', function(timeframe)
    local src = source
    local leaderboard = {}
    
    if timeframe == "daily" then
        local today = os.date("%Y-%m-%d")
        if teamStats.daily[today] then
            for teamKey, stats in pairs(teamStats.daily[today]) do
                -- Get team member names
                local memberNames = {}
                for _, citizenid in ipairs(stats.members) do
                    local memberData = MySQL.Sync.fetchAll('SELECT firstname, lastname FROM players WHERE citizenid = ?', {citizenid})
                    if memberData[1] then
                        table.insert(memberNames, memberData[1].firstname .. " " .. memberData[1].lastname)
                    end
                end
                
                table.insert(leaderboard, {
                    teamDisplay = table.concat(memberNames, " & "),
                    score = stats.boxes,
                    deliveries = stats.deliveries,
                    avgBoxes = math.floor(stats.boxes / stats.deliveries),
                    metric = "boxes delivered"
                })
            end
        end
    elseif timeframe == "weekly" then
        local week = os.date("%Y-W%V")
        if teamStats.weekly[week] then
            for teamKey, stats in pairs(teamStats.weekly[week]) do
                local memberNames = {}
                for _, citizenid in ipairs(stats.members) do
                    local memberData = MySQL.Sync.fetchAll('SELECT firstname, lastname FROM players WHERE citizenid = ?', {citizenid})
                    if memberData[1] then
                        table.insert(memberNames, memberData[1].firstname .. " " .. string.sub(memberData[1].lastname, 1, 1) .. ".")
                    end
                end
                
                table.insert(leaderboard, {
                    teamDisplay = table.concat(memberNames, " & "),
                    score = stats.boxes,
                    deliveries = stats.deliveries,
                    earnings = stats.earnings or 0,
                    perfectSyncs = stats.perfectSyncs or 0,
                    metric = "weekly performance"
                })
            end
        end
    else -- all-time legends
        for teamKey, stats in pairs(teamStats.allTime) do
            local memberNames = {}
            for _, citizenid in ipairs(stats.members) do
                local memberData = MySQL.Sync.fetchAll('SELECT firstname, lastname FROM players WHERE citizenid = ?', {citizenid})
                if memberData[1] then
                    table.insert(memberNames, memberData[1].firstname .. " " .. string.sub(memberData[1].lastname, 1, 1) .. ".")
                end
            end
            
            table.insert(leaderboard, {
                teamDisplay = table.concat(memberNames, " & "),
                score = stats.perfectSyncs,
                deliveries = stats.totalDeliveries,
                boxes = stats.totalBoxes,
                bestTime = stats.bestTime < 999999 and string.format("%d:%02d", math.floor(stats.bestTime/60), stats.bestTime%60) or "N/A",
                metric = "perfect syncs"
            })
        end
    end
    
    -- Sort by score
    table.sort(leaderboard, function(a, b) return a.score > b.score end)
    
    -- Add rankings
    for i, team in ipairs(leaderboard) do
        team.rank = i
        -- Add rank emojis for top 3
        if i == 1 then team.rankEmoji = "🥇"
        elseif i == 2 then team.rankEmoji = "🥈"
        elseif i == 3 then team.rankEmoji = "🥉"
        else team.rankEmoji = "#" .. i
        end
    end
    
    -- Limit to top 10
    local topTeams = {}
    for i = 1, math.min(10, #leaderboard) do
        topTeams[i] = leaderboard[i]
    end
    
    TriggerClientEvent('team:showLeaderboard', src, topTeams, timeframe)
end)

-- Weekly reset function
local function resetWeeklyStats()
    local lastWeek = os.date("%Y-W%V", os.time() - 7*24*60*60)
    
    -- Award weekly champions before reset
    if teamStats.weekly[lastWeek] then
        local weeklyTeams = {}
        for teamKey, stats in pairs(teamStats.weekly[lastWeek]) do
            table.insert(weeklyTeams, {
                teamKey = teamKey,
                members = stats.members,
                score = stats.boxes
            })
        end
        
        table.sort(weeklyTeams, function(a, b) return a.score > b.score end)
        
        -- Award top 3 teams
        for i = 1, math.min(3, #weeklyTeams) do
            local reward = i == 1 and 5000 or i == 2 and 3000 or 1500
            
            for _, citizenid in ipairs(weeklyTeams[i].members) do
                MySQL.Async.execute('UPDATE players SET bank = bank + ? WHERE citizenid = ?', {reward, citizenid})
                
                -- Send notification if online
                local xPlayer = QBCore.Functions.GetPlayerByCitizenId(citizenid)
                if xPlayer then
                    TriggerClientEvent('ox_lib:notify', xPlayer.PlayerData.source, {
                        title = '🏆 Weekly Team Champion!',
                        description = string.format('Your team placed #%d last week!\n💰 Reward: $%d', i, reward),
                        type = 'success',
                        duration = 15000,
                        position = Config.UI.notificationPosition,
                        markdown = Config.UI.enableMarkdown
                    })
                end
            end
        end
    end
    
    -- Clear old weekly data
    teamStats.weekly = {}
end

-- Schedule weekly reset (Mondays at 00:00)
Citizen.CreateThread(function()
    while true do
        local currentTime = os.date("*t")
        
        -- Check if it's Monday at midnight
        if currentTime.wday == 2 and currentTime.hour == 0 and currentTime.min == 0 then
            resetWeeklyStats()
            Citizen.Wait(60000) -- Wait a minute to avoid multiple resets
        end
        
        Citizen.Wait(30000) -- Check every 30 seconds
    end
end)

-- Export for use in team completions
exports('updateTeamStats', updateTeamStats)

-- Team challenges check
local function checkTeamChallenges(teamKey, dailyBoxes, weeklyBoxes)
    local challenges = Config.TeamDeliveries.competitive.challenges
    local rewards = {}
    
    -- Check daily challenges
    for _, challenge in ipairs(challenges.daily) do
        if dailyBoxes >= challenge.boxes then
            table.insert(rewards, {
                type = "daily",
                name = challenge.name,
                reward = challenge.reward
            })
        end
    end
    
    -- Check weekly challenges
    for _, challenge in ipairs(challenges.weekly) do
        if weeklyBoxes >= challenge.boxes then
            table.insert(rewards, {
                type = "weekly", 
                name = challenge.name,
                reward = challenge.reward
            })
        end
    end
    
    return rewards
end

exports('checkTeamChallenges', checkTeamChallenges)