local QBCore = exports['qb-core']:GetCoreObject()

-- Leaderboard display
RegisterNetEvent('team:showLeaderboard')
AddEventHandler('team:showLeaderboard', function(teams, timeframe)
    local options = {}
    
    -- SESSION 36 FIX: Ensure teams is a table
    teams = teams or {}
    timeframe = timeframe or "alltime"
    
    -- Header
    local timeframeText = timeframe == "daily" and "Today's" or timeframe == "weekly" and "This Week's" or "All-Time"
    table.insert(options, {
        title = string.format("🏆 %s Team Champions", timeframeText),
        description = timeframe == "weekly" and "Resets every Monday at midnight" or "",
        disabled = true
    })
    
    -- Display teams
    if #teams == 0 then
        table.insert(options, {
            title = "No teams yet!",
            description = "Be the first to complete a team delivery",
            disabled = true
        })
    else
        for _, team in ipairs(teams) do
            -- SESSION 36 FIX: Add nil checks for all team properties
            if team then
                local description = ""
                
                if timeframe == "daily" then
                    description = string.format("📦 %d boxes | 🚚 %d deliveries | 📊 Avg: %d boxes/run", 
                        team.score or 0, team.deliveries or 0, team.avgBoxes or 0)
                elseif timeframe == "weekly" then
                    description = string.format("📦 %d boxes | 🚚 %d deliveries | ⚡ %d perfect syncs", 
                        team.score or 0, team.deliveries or 0, team.perfectSyncs or 0)
                else -- all-time
                    description = string.format("⚡ %d perfect syncs | 🚚 %d total | ⏱️ Best: %s", 
                        team.score or 0, team.deliveries or 0, team.bestTime or "N/A")
                end
                
                table.insert(options, {
                    title = string.format("%s %s", team.rankEmoji or "#?", team.teamDisplay or "Unknown Team"),
                    description = description,
                    disabled = true
                })
            end
        end
    end
    
    -- Add challenges section for weekly
    if timeframe == "weekly" and Config.TeamDeliveries and Config.TeamDeliveries.competitive and Config.TeamDeliveries.competitive.challenges then
        table.insert(options, {
            title = "═══ Weekly Challenges ═══",
            disabled = true
        })
        
        local challenges = Config.TeamDeliveries.competitive.challenges.weekly
        if challenges then
            for _, challenge in ipairs(challenges) do
                if challenge then
                    table.insert(options, {
                        title = string.format("🎯 %s", challenge.name or "Challenge"),
                        description = string.format("Deliver %d boxes as a team | 💰 Reward: $%d", 
                            challenge.boxes or 0, challenge.reward or 0),
                        icon = "fas fa-trophy",
                        disabled = true
                    })
                end
            end
        end
    end
    
    -- Navigation options
    table.insert(options, {
        title = "📊 View Different Timeframe",
        icon = "fas fa-calendar",
        onSelect = function()
            TriggerEvent("team:openLeaderboardMenu")
        end
    })
    
    table.insert(options, {
        title = "← Back",
        icon = "fas fa-arrow-left",
        onSelect = function()
            if currentTeam then
                TriggerEvent("team:showRecruitmentMenu", currentTeam)
            else
                TriggerEvent("warehouse:openTeamMenu")
            end
        end
    })
    
    lib.registerContext({
        id = "team_leaderboard_display",
        title = "🏆 Team Leaderboard",
        options = options
    })
    lib.showContext("team_leaderboard_display")
end)

-- Leaderboard menu selector
RegisterNetEvent('team:openLeaderboardMenu')
AddEventHandler('team:openLeaderboardMenu', function()
    local options = {
        {
            title = "📅 Today's Leaders",
            description = "See today's top performing teams",
            icon = "fas fa-calendar-day",
            onSelect = function()
                TriggerServerEvent("team:getLeaderboard", "daily")
            end
        },
        {
            title = "📆 Weekly Champions",
            description = "This week's leaderboard (resets Monday)",
            icon = "fas fa-calendar-week",
            onSelect = function()
                TriggerServerEvent("team:getLeaderboard", "weekly")
            end
        },
        {
            title = "🏛️ Hall of Fame",
            description = "All-time legendary teams",
            icon = "fas fa-crown",
            onSelect = function()
                TriggerServerEvent("team:getLeaderboard", "alltime")
            end
        },
        {
            title = "← Back",
            icon = "fas fa-arrow-left",
            onSelect = function()
                if currentTeam then
                    TriggerEvent("team:showRecruitmentMenu", currentTeam)
                else
                    TriggerEvent("warehouse:openTeamMenu")
                end
            end
        }
    }
    
    lib.registerContext({
        id = "team_leaderboard_menu",
        title = "🏆 Team Rankings",
        options = options
    })
    lib.showContext("team_leaderboard_menu")
end)

-- Performance tips display
RegisterNetEvent('team:showPerformanceTips')
AddEventHandler('team:showPerformanceTips', function()
    -- SESSION 36 FIX: Safe config access
    local maxBonus = 35 -- default
    if Config.TeamDeliveries and Config.TeamDeliveries.teamBonuses and Config.TeamDeliveries.teamBonuses[6] then
        maxBonus = (Config.TeamDeliveries.teamBonuses[6].multiplier - 1) * 100
    end
    
    local options = {
        {
            title = "⚡ Perfect Sync Strategy",
            description = "Coordinate arrival within 15 seconds with no vehicle damage",
            icon = "fas fa-bolt",
            disabled = true
        },
        {
            title = "🚐 Duo Efficiency",
            description = "2-player teams share one vehicle for faster coordination",
            icon = "fas fa-users",
            disabled = true
        },
        {
            title = "📱 Communication is Key",
            description = "Use voice chat to coordinate timing and routes",
            icon = "fas fa-headset",
            disabled = true
        },
        {
            title = "🗺️ Route Planning",
            description = "Team leader should set waypoints for optimal paths",
            icon = "fas fa-route",
            disabled = true
        },
        {
            title = "💰 Bonus Breakdown",
            description = string.format("Team Size: Up to %.0f%%\nPerfect Sync: +$100/member\nWeekly Top 3: $1500-5000", maxBonus),
            icon = "fas fa-coins",
            disabled = true
        },
        {
            title = "← Back",
            icon = "fas fa-arrow-left",
            onSelect = function()
                TriggerEvent("team:showRecruitmentMenu", currentTeam)
            end
        }
    }
    
    lib.registerContext({
        id = "team_performance_tips",
        title = "📊 Team Performance Guide",
        options = options
    })
    lib.showContext("team_performance_tips")
end)

-- Team rejoin prompt (for persistence)
RegisterNetEvent('team:promptRejoinTeam')
AddEventHandler('team:promptRejoinTeam', function(teamData)
    -- SESSION 36 FIX: Add nil checks for teamData
    if not teamData then
        print("[TEAM_LEADERBOARD] Error: No team data provided to promptRejoinTeam")
        return
    end
    
    -- Ensure all required fields exist with defaults
    local members = teamData.members or {}
    local memberNames = #members > 0 and table.concat(members, ", ") or "Unknown team"
    local deliveryCount = teamData.deliveryCount or 0
    local onlineCount = teamData.onlineCount or 0
    
    lib.alertDialog({
        header = "👥 Previous Team Available",
        content = string.format(
            "Your team is back online!\n\n**Members**: %s\n**Deliveries Together**: %d\n**Online Now**: %d members\n\nWould you like to rejoin?",
            memberNames,
            deliveryCount,
            onlineCount
        ),
        centered = true,
        cancel = true,
        labels = {
            cancel = "Find New Team",
            confirm = "Rejoin Team"
        }
    }, function(response)
        if response == "confirm" then
            -- SESSION 36 FIX: Ensure teamKey exists
            if teamData.teamKey then
                TriggerServerEvent("team:rejoinPersistentTeam", teamData.teamKey)
            else
                print("[TEAM_LEADERBOARD] Error: No teamKey provided for rejoin")
                TriggerServerEvent("warehouse:getPendingOrders")
            end
        else
            TriggerServerEvent("warehouse:getPendingOrders")
        end
    end)
end)