-- TEAM UI FEATURES: Performance Tips & Leaderboard Integration
local QBCore = exports['qb-core']:GetCoreObject()
local currentWarehouseId = nil

-- Show performance tips for team coordination
RegisterNetEvent("team:showPerformanceTips")
AddEventHandler("team:showPerformanceTips", function()
    local options = {
        {
            title = "⚡ Perfect Sync Strategy",
            description = "All team members must arrive within **15 seconds** AND have **no vehicle damage**\n💰 Reward: **$100 per member**",
            icon = "fas fa-lightbulb",
            disabled = true
        },
        {
            title = "🎯 Coordination Tips",
            description = "• Use voice chat for timing\n• Leader sets the pace\n• Call out ETAs\n• Avoid collisions",
            icon = "fas fa-info-circle",
            disabled = true
        },
        {
            title = "🚛 Duo Delivery Tips",
            description = "• One drives, one navigates\n• Share the loading work\n• Both get full payment\n• Keys shared automatically",
            icon = "fas fa-user-friends",
            disabled = true
        },
        {
            title = "📦 Loading Efficiency",
            description = "• Use shared pallet area\n• Don't block teammates\n• Communicate who's loading\n• Help slower members",
            icon = "fas fa-boxes",
            disabled = true
        },
        {
            title = "💰 Maximizing Earnings",
            description = string.format("• Duo: **+15%%** bonus\n• Squad: **+20%%** bonus\n• Full Convoy: **+35%%** bonus\n• Perfect Sync: **+$100**"),
            icon = "fas fa-coins",
            disabled = true
        },
        {
            title = "🏆 Team Challenges",
            description = "• Daily: 25 boxes = $200 bonus\n• Daily: 50 boxes = $500 bonus\n• Weekly: 200 boxes = $2000 bonus",
            icon = "fas fa-trophy",
            disabled = true
        },
        {
            title = "← Back",
            icon = "fas fa-arrow-left",
            onSelect = function()
                if currentTeam then
                    TriggerEvent("team:showRecruitmentMenu", currentTeam)
                else
                    -- Go back to main menu
                    TriggerEvent("warehouse:openProcessingMenu")
                end
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

-- Team Leaderboard Menu
RegisterNetEvent("team:openLeaderboardMenu")
AddEventHandler("team:openLeaderboardMenu", function()
    local options = {
        {
            title = "📊 Today's Top Teams",
            description = "Best performing teams today",
            icon = "fas fa-calendar-day",
            onSelect = function()
                TriggerServerEvent("team:getLeaderboard", "daily")
            end
        },
        {
            title = "📅 This Week's Champions",
            description = "Weekly team leaderboard (resets Monday)",
            icon = "fas fa-calendar-week",
            onSelect = function()
                TriggerServerEvent("team:getLeaderboard", "weekly")
            end
        },
        {
            title = "🏆 All-Time Legends",
            description = "Hall of fame teams",
            icon = "fas fa-crown",
            onSelect = function()
                TriggerServerEvent("team:getLeaderboard", "alltime")
            end
        },
        {
            title = "🎯 Active Challenges",
            description = "View team challenges and progress",
            icon = "fas fa-tasks",
            onSelect = function()
                TriggerServerEvent("team:getChallenges")
            end
        },
        {
            title = "📈 My Team Stats",
            description = "View your team's performance",
            icon = "fas fa-chart-line",
            onSelect = function()
                TriggerServerEvent("team:getMyTeamStats")
            end
        },
        {
            title = "← Back",
            icon = "fas fa-arrow-left",
            onSelect = function()
                if currentTeam then
                    TriggerEvent("team:showRecruitmentMenu", currentTeam)
                else
                    TriggerEvent("warehouse:openTeamMenu", currentWarehouseId or 1)
                end
            end
        }
    }
    
    lib.registerContext({
        id = "team_leaderboard_menu",
        title = "🏆 Team Leaderboards",
        options = options
    })
    lib.showContext("team_leaderboard_menu")
end)

-- Display team leaderboard
RegisterNetEvent("team:showLeaderboard")
AddEventHandler("team:showLeaderboard", function(leaderboardData, timeframe)
    local options = {}
    local timeframeText = timeframe == "daily" and "Today" or timeframe == "weekly" and "This Week" or "All-Time"
    
    if #leaderboardData == 0 then
        table.insert(options, {
            title = "No Teams Yet",
            description = "Be the first to complete a team delivery!",
            disabled = true
        })
    else
        for i, entry in ipairs(leaderboardData) do
            local medal = i == 1 and "🥇" or i == 2 and "🥈" or i == 3 and "🥉" or "🏅"
            
            table.insert(options, {
                title = string.format("%s #%d: %s", medal, i, entry.teamName),
                description = string.format(
                    "👥 **Members**: %s\n📦 **Deliveries**: %d\n💰 **Earnings**: $%s\n⚡ **Avg Sync**: %ds\n🎯 **Perfect Syncs**: %d",
                    table.concat(entry.memberNames, ", "),
                    entry.deliveryCount,
                    lib.math.groupdigits(entry.totalEarnings),
                    entry.avgSyncTime,
                    entry.perfectSyncs
                ),
                icon = i <= 3 and "fas fa-trophy" or "fas fa-medal",
                metadata = {
                    ["Team Size"] = tostring(#entry.memberNames),
                    ["Best Sync"] = entry.bestSyncTime .. "s",
                    ["Completion Rate"] = entry.completionRate .. "%"
                },
                disabled = true
            })
        end
    end
    
    table.insert(options, {
        title = "← Back to Leaderboards",
        icon = "fas fa-arrow-left",
        onSelect = function()
            TriggerEvent("team:openLeaderboardMenu")
        end
    })
    
    lib.registerContext({
        id = "team_leaderboard_display",
        title = string.format("🏆 %s Team Leaderboard", timeframeText),
        options = options
    })
    lib.showContext("team_leaderboard_display")
end)

-- Display team challenges
RegisterNetEvent("team:showChallenges")
AddEventHandler("team:showChallenges", function(challenges)
    local options = {}
    
    -- Daily Challenges
    table.insert(options, {
        title = "📅 Daily Team Challenges",
        description = "Reset at midnight",
        disabled = true
    })
    
    for _, challenge in ipairs(challenges.daily) do
        local progress = math.min(challenge.progress, challenge.requirement)
        local percentage = math.floor((progress / challenge.requirement) * 100)
        local isComplete = progress >= challenge.requirement
        
        table.insert(options, {
            title = string.format("%s %s", isComplete and "✅" or "⏳", challenge.name),
            description = string.format(
                "%s\n**Progress**: %d/%d boxes (%d%%)\n**Reward**: $%d %s",
                challenge.description,
                progress,
                challenge.requirement,
                percentage,
                challenge.reward,
                isComplete and "✅ COMPLETE" or ""
            ),
            icon = isComplete and "fas fa-check-circle" or "fas fa-circle-notch",
            progress = percentage,
            disabled = true
        })
    end
    
    -- Weekly Challenges
    table.insert(options, {
        title = "📊 Weekly Team Challenges",
        description = "Reset Monday at midnight",
        disabled = true
    })
    
    for _, challenge in ipairs(challenges.weekly) do
        local progress = math.min(challenge.progress, challenge.requirement)
        local percentage = math.floor((progress / challenge.requirement) * 100)
        local isComplete = progress >= challenge.requirement
        
        table.insert(options, {
            title = string.format("%s %s", isComplete and "✅" or "⏳", challenge.name),
            description = string.format(
                "%s\n**Progress**: %d/%d boxes (%d%%)\n**Reward**: $%d %s",
                challenge.description,
                progress,
                challenge.requirement,
                percentage,
                challenge.reward,
                isComplete and "✅ COMPLETE" or ""
            ),
            icon = isComplete and "fas fa-check-circle" or "fas fa-circle-notch",
            progress = percentage,
            disabled = true
        })
    end
    
    table.insert(options, {
        title = "← Back",
        icon = "fas fa-arrow-left",
        onSelect = function()
            TriggerEvent("team:openLeaderboardMenu")
        end
    })
    
    lib.registerContext({
        id = "team_challenges",
        title = "🎯 Team Challenges",
        options = options
    })
    lib.showContext("team_challenges")
end)

-- Display personal team stats
RegisterNetEvent("team:showMyTeamStats")
AddEventHandler("team:showMyTeamStats", function(stats)
    local options = {}
    
    if not stats or stats.totalDeliveries == 0 then
        table.insert(options, {
            title = "📊 No Team Stats Yet",
            description = "Complete team deliveries to see your statistics!",
            disabled = true
        })
    else
        -- Overview
        table.insert(options, {
            title = "📈 Team Performance Overview",
            description = string.format(
                "**Total Team Deliveries**: %d\n**Total Earnings**: $%s\n**Average Team Size**: %.1f players\n**Favorite Partner**: %s",
                stats.totalDeliveries,
                lib.math.groupdigits(stats.totalEarnings),
                stats.avgTeamSize,
                stats.favoritePartner or "None yet"
            ),
            icon = "fas fa-chart-pie",
            disabled = true
        })
        
        -- Coordination Stats
        table.insert(options, {
            title = "⚡ Coordination Performance",
            description = string.format(
                "**Perfect Syncs**: %d (%.1f%%)\n**Average Sync Time**: %ds\n**Best Sync Time**: %ds\n**Coordination Rating**: %s",
                stats.perfectSyncs,
                (stats.perfectSyncs / stats.totalDeliveries) * 100,
                stats.avgSyncTime,
                stats.bestSyncTime,
                stats.coordinationRating
            ),
            icon = "fas fa-sync",
            disabled = true
        })
        
        -- Team Roles
        table.insert(options, {
            title = "👥 Team Role Statistics",
            description = string.format(
                "**Times as Leader**: %d\n**Times as Member**: %d\n**Leadership Rating**: %s\n**Team Player Score**: %d/100",
                stats.timesAsLeader,
                stats.timesAsMember,
                stats.leadershipRating,
                stats.teamPlayerScore
            ),
            icon = "fas fa-users-cog",
            disabled = true
        })
        
        -- Records
        table.insert(options, {
            title = "🏆 Personal Team Records",
            description = string.format(
                "**Largest Team Led**: %d players\n**Most Boxes (Team)**: %d boxes\n**Highest Team Earning**: $%s\n**Longest Streak**: %d deliveries",
                stats.largestTeamLed,
                stats.mostBoxesTeam,
                lib.math.groupdigits(stats.highestTeamEarning),
                stats.longestTeamStreak
            ),
            icon = "fas fa-trophy",
            disabled = true
        })
        
        -- Recent Partners
        if stats.recentPartners and #stats.recentPartners > 0 then
            local partnerList = {}
            for i, partner in ipairs(stats.recentPartners) do
                if i <= 5 then -- Show top 5
                    table.insert(partnerList, string.format("%s (%dx)", partner.name, partner.count))
                end
            end
            
            table.insert(options, {
                title = "🤝 Frequent Team Partners",
                description = table.concat(partnerList, "\n"),
                icon = "fas fa-handshake",
                disabled = true
            })
        end
    end
    
    table.insert(options, {
        title = "← Back",
        icon = "fas fa-arrow-left",
        onSelect = function()
            TriggerEvent("team:openLeaderboardMenu")
        end
    })
    
    lib.registerContext({
        id = "team_personal_stats",
        title = "📊 My Team Statistics",
        options = options
    })
    lib.showContext("team_personal_stats")
end)

-- Export to check if player is in a team
exports('isInTeam', function()
    return currentTeam ~= nil
end)

exports('getCurrentTeam', function()
    return currentTeam
end)