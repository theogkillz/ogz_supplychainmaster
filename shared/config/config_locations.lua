Config = Config or {}

Config.Restaurants = {
    [1] = {
        name = "Vespucci Burgershot",
        job = "burgershot",
        position = vector3(-1178.0913085938, -896.11010742188, 14.108023834229),
        heading = 118.0,
        delivery = vector3(-1173.53, -892.72, 13.86),
        deliveryBox = vector3(-1177.39, -890.98, 12.79),
    },
    [2] = {
        name = "Sandy Burgershot",
        job = "sandyburgershot",
        position = vector3(1596.85, 3757.66, 34.44), -- vector4(1596.85, 3757.66, 34.44, 283.6)
        heading = 283.6,
        delivery = vector3(1596.33, 3767.03, 34.43),
        deliveryBox = vector3(1596.36, 3763.79, 33.43),
    },
    -- New Restaurants
}

Config.WarehousesLocation = {
    [1] = {
        position = vector3(-80.3, 6525.98, 30.49),
        heading = 43.09,
        pedhash = 's_m_y_construct_02',
        name = "Main Warehouse"
    },
    [2] = {
        position = vector3(1181.47, -3280.73, 5.03), -- vector4(1181.47, -3280.73, 6.03, 97.63)
        heading = 97.63,
        pedhash = 's_m_m_dockwork_01', -- Dock worker model for import center
        name = "Import Distribution Center"
    },
}

Config.Warehouses = {
    [1] = {
        name = "Main Warehouse",
        active = true,
        vehicle = {
            model = 'speedo',
            position = vector4(-85.97, 6559.03, 31.23, 223.13)
        },
        boxPositions = {
            vector3(-84.26, 6542.03, 31.49),
            vector3(-83.76, 6541.53, 31.49),
            vector3(-84.76, 6542.53, 31.49)
        },
        heading = 224.0426,
        -- SESSION 36 FIX: Added convoy spawn points to prevent vehicle collisions
        convoySpawnPoints = {
            -- Primary spawn (leader)
            {position = vector4(-85.97, 6559.03, 31.23, 223.13), occupied = false, priority = 1},
            -- Line formation along the road (4-5 unit spacing)
            {position = vector4(-83.26, 6561.48, 31.23, 222.38), occupied = false, priority = 2},
            {position = vector4(-80.68, 6563.84, 31.23, 221.13), occupied = false, priority = 3},
            {position = vector4(-78.01, 6566.43, 31.23, 222.36), occupied = false, priority = 4},
            {position = vector4(-75.25, 6568.71, 31.23, 221.13), occupied = false, priority = 5},
            -- Second row (parallel parking style)
            {position = vector4(-63.51, 6564.24, 31.49, 135.6), occupied = false, priority = 6},
            {position = vector4(-61.24, 6561.92, 31.49, 139.01), occupied = false, priority = 7},
            {position = vector4(-58.96, 6559.27, 31.49, 133.57), occupied = false, priority = 8},
            -- Side positions
            {position = vector4(-56.86, 6556.58, 31.49, 134.83), occupied = false, priority = 9},
            {position = vector4(-54.27, 6554.25, 31.49, 135.13), occupied = false, priority = 10},
            -- Overflow positions
            {position = vector4(-51.35, 6551.88, 31.49, 138.82), occupied = false, priority = 11},
            {position = vector4(-48.89, 6549.02, 31.49, 131.7), occupied = false, priority = 12}
        }
    },
    [2] = {
        name = "Import Distribution Center",
        active = true,
        vehicle = {
            model = 'speedo',
            position = vector4(1150.8, -3297.1, 5.9, 94.21)
        },
        boxPositions = {
            vector3(1179.0, -3304.08, 6.03),
            vector3(1178.82, -3307.21, 6.03),
            vector3(1178.29, -3319.26, 6.03)
        },
        heading = 94.91,
        -- SESSION 36 FIX: Added convoy spawn points to prevent vehicle collisions
        convoySpawnPoints = {
            -- Primary spawn (leader)
            {position = vector4(1150.8, -3297.1, 5.9, 94.21), occupied = false, priority = 1},
            -- Line formation along the road (4-5 unit spacing)
            {position = vector4(1150.73, -3292.81, 5.9, 85.63), occupied = false, priority = 2},
            {position = vector4(1150.56, -3286.68, 5.9, 85.94), occupied = false, priority = 3},
            {position = vector4(1150.47, -3281.33, 5.9, 87.11), occupied = false, priority = 4},
            {position = vector4(1151.0, -3276.31, 5.9, 94.53), occupied = false, priority = 5},
            -- Second row (parallel parking style)
            {position = vector4(1151.0, -3270.36, 5.9, 77.18), occupied = false, priority = 6},
            {position = vector4(1150.96, -3264.07, 5.9, 84.26), occupied = false, priority = 7},
            {position = vector4(1151.17, -3257.95, 5.9, 88.21), occupied = false, priority = 8},
            -- Side positions
            {position = vector4(1151.01, -3252.04, 5.9, 92.4), occupied = false, priority = 9},
            {position = vector4(1143.97, -3245.22, 5.9, 180.0), occupied = false, priority = 10},
            -- Overflow positions
            {position = vector4(1140.15, -3244.79, 5.9, 181.56), occupied = false, priority = 11},
            {position = vector4(1135.89, -3244.89, 5.9, 175.5), occupied = false, priority = 12}
        }
    }
}

Config.PedModel = "a_m_m_farmer_01"
Config.Location = {
    coords = vector3(-86.59, 6494.08, 31.51),
    heading = 221.43
}
Config.SellerBlip = {
    label = 'Ingredient Distributor',
    coords = vector3(-86.59, 6494.08, 31.51),
    blipSprite = 1,
    blipColor = 1,
    blipScale = 0.6
}