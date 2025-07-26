local QBCore = exports['qb-core']:GetCoreObject()

local deliveryTeams = {}

RegisterNetEvent('warehouse:inviteToTeam')
AddEventHandler('warehouse:inviteToTeam', function(targetId, orderGroupId)
    local sourceId = source
    local xPlayer = QBCore.Functions.GetPlayer(sourceId)
    if not deliveryTeams[orderGroupId] then
        deliveryTeams[orderGroupId] = { leader = sourceId, members = {}, vehicle = nil }
    end
    if deliveryTeams[orderGroupId].leader == sourceId then
        if #deliveryTeams[orderGroupId].members >= Config.TeamDeliveries.maxTeamSize then
            TriggerClientEvent('ox_lib:notify', sourceId, {
                title = 'Error',
                description = 'Team is full (' .. Config.Teams.maxMembers .. ' members).',
                type = 'error',
                duration = 10000,
                position = Config.UI.notificationPosition,
                markdown = Config.UI.enableMarkdown
            })
            return
        end
        TriggerClientEvent('warehouse:receiveTeamInvite', targetId, xPlayer.PlayerData.name, orderGroupId)
        TriggerClientEvent('ox_lib:notify', sourceId, {
            title = 'Invite Sent',
            description = 'Invite sent to player.',
            type = 'success',
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
    else
        TriggerClientEvent('ox_lib:notify', sourceId, {
            title = 'Error',
            description = 'Only the team leader can invite players.',
            type = 'error',
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
    end
end)

RegisterNetEvent('warehouse:joinTeam')
AddEventHandler('warehouse:joinTeam', function(orderGroupId)
    local sourceId = source
    if deliveryTeams[orderGroupId] then
        if #deliveryTeams[orderGroupId].members >= Config.Teams.maxMembers then
            TriggerClientEvent('ox_lib:notify', sourceId, {
                title = 'Error',
                description = 'Team is full (' .. Config.Teams.maxMembers .. ' members).',
                type = 'error',
                duration = 10000,
                position = Config.UI.notificationPosition,
                markdown = Config.UI.enableMarkdown
            })
            return
        end
        table.insert(deliveryTeams[orderGroupId].members, sourceId)
        TriggerClientEvent('ox_lib:notify', sourceId, {
            title = 'Joined Team',
            description = 'You joined the delivery team.',
            type = 'success',
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        for _, memberId in ipairs(deliveryTeams[orderGroupId].members) do
            TriggerClientEvent('ox_lib:notify', memberId, {
                title = 'Team Update',
                description = 'A new player joined the delivery team.',
                type = 'inform',
                duration = 10000,
                position = Config.UI.notificationPosition,
                markdown = Config.UI.enableMarkdown
            })
        end
        TriggerClientEvent('ox_lib:notify', deliveryTeams[orderGroupId].leader, {
            title = 'Team Update',
            description = 'A new player joined your delivery team.',
            type = 'inform',
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
    else
        TriggerClientEvent('ox_lib:notify', sourceId, {
            title = 'Error',
            description = 'Invalid team or order.',
            type = 'error',
            duration = 10000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
    end
end)