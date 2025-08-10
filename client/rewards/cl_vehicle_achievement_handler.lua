local QBCore = exports['qb-core']:GetCoreObject()

-- Team vehicle coordination handler
RegisterNetEvent("team:coordinateVehicles")
AddEventHandler("team:coordinateVehicles", function(teamData)
    -- This event is handled by the hybrid system now
    -- Vehicles are spawned through team:spawnDeliveryVehicle in cl_team_deliveries.lua
    print("[TEAM] Vehicle coordination handled by hybrid system")
end)

-- Share vehicle keys for duo teams
RegisterNetEvent("team:shareVehicleKeys") 
AddEventHandler("team:shareVehicleKeys", function(plate, teamMembers)
    -- Handled by main team delivery system
    print("[TEAM] Key sharing handled by main system")
end)

-- Vehicle damage tracking
RegisterNetEvent("team:trackVehicleDamage")
AddEventHandler("team:trackVehicleDamage", function(vehicle)
    if not DoesEntityExist(vehicle) then return end
    
    local vehicleHealth = GetEntityHealth(vehicle)
    local engineHealth = GetVehicleEngineHealth(vehicle)
    local bodyHealth = GetVehicleBodyHealth(vehicle)
    
    -- Consider damaged if any health is below 90%
    local isDamaged = vehicleHealth < 900 or engineHealth < 900 or bodyHealth < 900
    
    return isDamaged
end)