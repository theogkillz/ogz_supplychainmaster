local QBCore = exports['qb-core']:GetCoreObject()

-- Leaderboard display
RegisterNetEvent('team:showLeaderboard')
AddEventHandler('team:showLeaderboard', function(teams, timeframe)
    local options = {}
    
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
            local description = ""
            
            if timeframe == "daily" then
                description = string.format("📦 %d boxes | 🚚 %d deliveries | 📊 Avg: %d boxes/run", 
                    team.score, team.deliveries, team.avgBoxes)
            elseif timeframe == "weekly" then
                description = string.format("📦 %d boxes | 🚚 %d deliveries | ⚡ %d perfect syncs", 
                    team.score, team.deliveries, team.perfectSyncs)
            else -- all-time
                description = string.format("⚡ %d perfect syncs | 🚚 %d total | ⏱️ Best: %s", 
                    team.score, team.deliveries, team.bestTime)
            end
            
            table.insert(options, {
                title = string.format("%s %s", team.rankEmoji, team.teamDisplay),
                description = description,
                disabled = true
            })
        end
    end
    
    -- Add challenges section for weekly
    if timeframe == "weekly" and Config.TeamDeliveries.competitive.challenges then
        table.insert(options, {
            title = "═══ Weekly Challenges ═══",
            disabled = true
        })
        
        for _, challenge in ipairs(Config.TeamDeliveries.competitive.challenges.weekly) do
            table.insert(options, {
                title = string.format("🎯 %s", challenge.name),
                description = string.format("Deliver %d boxes as a team | 💰 Reward: $%d", 
                    challenge.boxes, challenge.reward),
                icon = "fas fa-trophy",
                disabled = true
            })
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
                TriggerEvent("warehouse:openProcessingMenu")
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
                    TriggerEvent("warehouse:openProcessingMenu")
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
            description = string.format("Team Size: Up to %.0f%%\nPerfect Sync: +$100/member\nWeekly Top 3: $1500-5000",
                (Config.TeamDeliveries.teamBonuses[6].multiplier - 1) * 100),
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
    lib.alertDialog({
        header = "👥 Previous Team Available",
        content = string.format(
            "Your team is back online!\n\n**Members**: %s\n**Deliveries Together**: %d\n**Online Now**: %d members\n\nWould you like to rejoin?",
            table.concat(teamData.members, ", "),
            teamData.deliveryCount,
            teamData.onlineCount
        ),
        centered = true,
        cancel = true,
        labels = {
            cancel = "Find New Team",
            confirm = "Rejoin Team"
        }
    }, function(response)
        if response == "confirm" then
            TriggerServerEvent("team:rejoinPersistentTeam", teamData.teamKey)
        else
            TriggerServerEvent("warehouse:getPendingOrders")
        end
    end)
end)