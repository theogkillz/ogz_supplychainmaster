local QBCore = exports['qb-core']:GetCoreObject()

-- Team delivery variables
local currentTeam = nil
local teamDeliveryData = nil

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
            if boxesNeeded >= deliveryType.minBoxes then
                table.insert(options, {
                    title = deliveryType.name,
                    description = deliveryType.description .. "\nMinimum: " .. deliveryType.minBoxes .. " boxes",
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

-- Show recruitment menu for team leader
RegisterNetEvent("team:showRecruitmentMenu")
AddEventHandler("team:showRecruitmentMenu", function(teamId)
    currentTeam = teamId
    
    local options = {
        {
            title = string.format("📋 Team ID: %s", teamId),
            description = "Share this ID with other drivers to join",
            icon = "fas fa-clipboard",
            disabled = true  -- Just for display
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
            description = isReady and "Click to unready" or "Click when ready to start",
            icon = isReady and "fas fa-check-circle" or "fas fa-pause-circle",
            onSelect = function()
                isReady = not isReady
                TriggerServerEvent("team:setReady", teamId, isReady)
            end
        },
        {
            title = "🏆 Team Leaderboard",
            description = "Check team rankings and challenges",
            icon = "fas fa-trophy",
            onSelect = function()
                TriggerEvent("team:openLeaderboardMenu")
            end
        },
        {
            title = "📊 Performance Tips",
            description = "Learn coordination strategies",
            icon = "fas fa-chart-line",
            onSelect = function()
                TriggerEvent("team:showPerformanceTips")
            end
        },
        {
            title = "🚪 Leave Team",
            description = "Exit and find another team",
            icon = "fas fa-door-open",
            onSelect = function()
                lib.alertDialog({
                    header = "Leave Team?",
                    content = "Are you sure you want to leave this team?",
                    centered = true,
                    cancel = true,
                    labels = {
                        cancel = "Stay",
                        confirm = "Leave"
                    }
                }, function(response)
                    if response == "confirm" then
                        currentTeam = nil
                        isReady = false
                        TriggerServerEvent("team:leaveDelivery", teamId)
                    end
                end)
            end
        }
    }
    
    lib.registerContext({
        id = "team_recruitment",
        title = "🚛 Team Coordination",
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

-- Update ready status display
RegisterNetEvent("team:updateReadyStatus")
AddEventHandler("team:updateReadyStatus", function(teamId, readyCount, totalMembers, allReady)
    if currentTeam == teamId then
        if allReady and totalMembers >= 2 then
            lib.notify({
                title = "🚀 TEAM READY!",
                description = "All team members ready! Starting delivery...",
                type = "success",
                duration = 8000,
                position = Config.UI.notificationPosition,
                markdown = Config.UI.enableMarkdown
            })
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

-- Spawn team delivery vehicle
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

    DoScreenFadeOut(2500)
    Citizen.Wait(2500)

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

    -- Spawn vehicle with slight offset for multiple team members
    local spawnOffset = (teamData.memberRole == "leader") and 0 or math.random(-5, 5)
    local van = CreateVehicle(vehicleModel, 
        warehouseConfig.vehicle.position.x + spawnOffset, 
        warehouseConfig.vehicle.position.y + spawnOffset, 
        warehouseConfig.vehicle.position.z, 
        warehouseConfig.vehicle.position.w, 
        true, false)
    
    SetEntityAsMissionEntity(van, true, true)
    SetVehicleHasBeenOwnedByPlayer(van, true)
    SetVehicleNeedsToBeHotwired(van, false)
    SetVehRadioStation(van, "OFF")
    SetVehicleEngineOn(van, true, true, false)
    SetEntityCleanupByEngine(van, false)
    
    local vanPlate = GetVehicleNumberPlateText(van)
    TriggerEvent("vehiclekeys:client:SetOwner", vanPlate)

    DoScreenFadeIn(2500)

    lib.notify({
        title = "🚛 Team Vehicle Ready",
        description = string.format("Load %d boxes for your part of the team delivery!", teamData.boxesAssigned),
        type = "success",
        duration = 10000,
        position = Config.UI.notificationPosition,
        markdown = Config.UI.enableMarkdown
    })

    -- SetEntityCoords(playerPed, warehouseConfig.vehicle.position.x + 2.0, warehouseConfig.vehicle.position.y, warehouseConfig.vehicle.position.z, false, false, false, true)
    
    -- Use team-specific loading system
    TriggerEvent("team:loadTeamBoxes", warehouseConfig, van, teamData)
end)

-- Team box loading system
RegisterNetEvent("team:loadTeamBoxes")
AddEventHandler("team:loadTeamBoxes", function(warehouseConfig, van, teamData)
    local playerPed = PlayerPedId()
    local boxesLoaded = 0
    local maxBoxes = teamData.boxesAssigned
    local hasBox = false
    local boxProp = nil
    local boxBlips = {}
    local boxEntities = {}
    local targetZones = {}
    local vanTargetName = "team_van_load"

    local propName = Config.CarryBoxProp
    local model = GetHashKey(propName)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Citizen.Wait(100)
    end

    local boxPositions = warehouseConfig.boxPositions
    if not boxPositions or #boxPositions == 0 then
        return
    end

    -- Create boxes for this team member's portion
    for i = 1, maxBoxes do
        local pos = boxPositions[1]
        
        -- Offset boxes for team members
        if teamData.memberRole ~= "leader" then
            pos = vector3(boxPositions[1].x + (i * 2), boxPositions[1].y + math.random(-2, 2), boxPositions[1].z)
        else
            pos = vector3(boxPositions[1].x + (i * 2), boxPositions[1].y, boxPositions[1].z)
        end
        
        local box = CreateObject(model, pos.x, pos.y, pos.z, true, true, true)
        if DoesEntityExist(box) then
            PlaceObjectOnGroundProperly(box)
            table.insert(boxEntities, { entity = box, position = pos, loaded = false })
            
            -- Team-colored light effects
            Citizen.CreateThread(function()
                while DoesEntityExist(box) do
                    local lightColor = teamData.memberRole == "leader" and {r = 0, g = 255, b = 0} or {r = 0, g = 150, b = 255}
                    DrawLightWithRange(pos.x, pos.y, pos.z + 0.5, lightColor.r, lightColor.g, lightColor.b, 2.0, 1.0)
                    Citizen.Wait(0)
                end
            end)
        end

        -- Create blip
        local blip = AddBlipForCoord(pos.x, pos.y, pos.z)
        SetBlipSprite(blip, 1)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.7)
        SetBlipColour(blip, teamData.memberRole == "leader" and 2 or 3)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Team Box " .. i .. "/" .. maxBoxes)
        EndTextCommandSetBlipName(blip)
        table.insert(boxBlips, blip)

        -- Create target zone
        local zoneName = "team_box_pickup_" .. i
        exports.ox_target:addBoxZone({
            coords = vector3(pos.x, pos.y, pos.z),
            size = vector3(2.0, 2.0, 2.0),
            rotation = 0,
            debug = false,
            name = zoneName,
            options = {
                {
                    label = "Pick Up Team Box " .. i .. "/" .. maxBoxes,
                    icon = "fas fa-box",
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
                        
                        if lib.progressBar({
                            duration = 3000,
                            position = "bottom",
                            label = "Picking Up Team Box " .. i .. "/" .. maxBoxes .. "...",
                            canCancel = false,
                            disable = { move = true, car = true, combat = true, sprint = true },
                            anim = { dict = "mini@repair", clip = "fixing_a_ped" }
                        }) then
                            DeleteObject(box)
                            
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

                            lib.notify({
                                title = "Team Box " .. i .. " Picked Up",
                                description = "Load into your team vehicle (" .. (boxesLoaded + 1) .. "/" .. maxBoxes .. ")",
                                type = "success",
                                duration = 5000,
                                position = Config.UI.notificationPosition,
                                markdown = Config.UI.enableMarkdown
                            })
                            
                            exports.ox_target:removeZone(zoneName)
                        end
                    end
                }
            }
        })
        table.insert(targetZones, zoneName)
    end

    -- Team van loading system
    local function updateTeamVanTargetZone()
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
                        label = "Load Team Box (" .. (boxesLoaded + 1) .. "/" .. maxBoxes .. ")",
                        icon = "fas fa-truck-loading",
                        onSelect = function()
                            if not hasBox then
                                lib.notify({
                                    title = "Error",
                                    description = "You need to pick up a box first.",
                                    type = "error",
                                    duration = 5000,
                                    position = Config.UI.notificationPosition,
                                    markdown = Config.UI.enableMarkdown
                                })
                                return
                            end
                            
                            if lib.progressBar({
                                duration = 4000,
                                position = "bottom",
                                label = "Loading Team Box " .. (boxesLoaded + 1) .. "/" .. maxBoxes .. "...",
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
                                
                                if boxesLoaded >= maxBoxes then
                                    -- All team boxes loaded!
                                    lib.notify({
                                        title = "🎉 Team Boxes Loaded!",
                                        description = string.format("All %d boxes loaded! Coordinate with your team for delivery!", maxBoxes),
                                        type = "success",
                                        duration = 10000,
                                        position = Config.UI.notificationPosition,
                                        markdown = Config.UI.enableMarkdown
                                    })
                                    
                                    -- Clean up
                                    for _, blip in ipairs(boxBlips) do
                                        RemoveBlip(blip)
                                    end
                                    for _, zone in ipairs(targetZones) do
                                        exports.ox_target:removeZone(zone)
                                    end
                                    exports.ox_target:removeZone(vanTargetName)
                                    for _, boxData in ipairs(boxEntities) do
                                        if DoesEntityExist(boxData.entity) then
                                            DeleteObject(boxData.entity)
                                        end
                                    end
                                    
                                    -- Start team delivery coordination
                                    TriggerEvent("team:startCoordinatedDelivery", teamData.restaurantId, van, teamData)
                                else
                                    lib.notify({
                                        title = "Team Box " .. boxesLoaded .. " Loaded",
                                        description = (maxBoxes - boxesLoaded) .. " boxes remaining for your vehicle",
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

    Citizen.CreateThread(updateTeamVanTargetZone)

    lib.notify({
        title = "🚛 Team Loading Phase",
        description = string.format("Load %d boxes for your part of the team delivery!", maxBoxes),
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

    -- Complete team delivery when arrived
    Citizen.CreateThread(function()
        local isTextUIShown = false
        while DoesEntityExist(van) do
            local playerPed = PlayerPedId()
            local vanPos = GetEntityCoords(van)
            local distance = #(vanPos - vector3(deliveryPosition.x, deliveryPosition.y, deliveryPosition.z))
            
            if distance < 10.0 and IsPedInVehicle(playerPed, van, false) then
                if not isTextUIShown then
                    lib.showTextUI("[E] Complete Team Delivery", {
                        icon = "fas fa-users"
                    })
                    isTextUIShown = true
                end
                if IsControlJustPressed(0, 38) then -- E key
                    if distance < 10.0 then
                        lib.hideTextUI()
                        isTextUIShown = false
                        
                        local deliveryEndTime = GetGameTimer()
                        local totalDeliveryTime = math.floor((deliveryEndTime - deliveryStartTime) / 1000)
                        
                        RemoveBlip(blip)
                        DeleteVehicle(van)
                        
                        lib.notify({
                            title = "🎉 Team Member Complete!",
                            description = "Waiting for other team members to finish...",
                            type = "success",
                            duration = 8000,
                            position = Config.UI.notificationPosition,
                            markdown = Config.UI.enableMarkdown
                        })
                        
                        TriggerServerEvent("team:completeMemberDelivery", teamData.teamId, totalDeliveryTime)
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