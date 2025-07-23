-- Job validation for vehicle ownership
local function hasVehicleOwnershipAccess()
    local PlayerData = QBCore.Functions.GetPlayerData()
    if not PlayerData or not PlayerData.job then
        return false
    end
    
    local playerJob = PlayerData.job.name
    return playerJob == "hurst"
end

-- Vehicle dealership access with validation
RegisterNetEvent("vehicles:openDealership")
AddEventHandler("vehicles:openDealership", function()
    if not hasVehicleOwnershipAccess() then
        local PlayerData = QBCore.Functions.GetPlayerData()
        local currentJob = PlayerData and PlayerData.job and PlayerData.job.name or "unemployed"
        
        lib.notify({
            title = "🚫 Dealership Access Denied",
            description = "Vehicle dealership restricted to Hurst Industries employees. Current job: " .. currentJob,
            type = "error",
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    -- Continue with dealership logic...
end)

-- Personal garage access with validation
RegisterNetEvent("vehicles:openPersonalGarage")
AddEventHandler("vehicles:openPersonalGarage", function()
    if not hasVehicleOwnershipAccess() then
        lib.notify({
            title = "🚫 Garage Access Denied",
            description = "Personal garage restricted to Hurst Industries employees",
            type = "error",
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    TriggerServerEvent("vehicles:getPersonalFleet")
end)

-- Vehicle commands with validation
RegisterCommand('myfleet', function()
    if not hasVehicleOwnershipAccess() then
        lib.notify({
            title = "🚫 Access Denied",
            description = "Fleet management restricted to Hurst Industries employees",
            type = "error",
            duration = 8000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
        return
    end
    
    TriggerEvent("vehicles:openPersonalGarage")
end)