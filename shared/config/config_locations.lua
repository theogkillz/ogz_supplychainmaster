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
    [3] = {
        name = "Bean Machine",
        job = "beanmachine",
        position = vector3(118.85, -1045.52, 29.31), -- vector4(118.85, -1045.52, 29.31, 182.64)
        heading = 182.64,
        delivery = vector3(121.81, -1053.64, 29.19),
        deliveryBox = vector3(117.43, -1050.41, 29.2),
    },
    [4] = {
        name = "Lucky Plucker - Little Seoul",
        job = "plucker2",
        position = vector3(-586.93, -883.4, 25.97), -- vector4(-586.93, -883.4, 25.97, 18.52)
        heading = 18.52,
        delivery = vector3(-596.74, -892.7, 25.49),
        deliveryBox = vector3(1596.36, 3763.79, 33.43),
    },
    [5] = {
        name = "Lucky Plucker - Davis",
        job = "plucker2",
        position = vector3(140.46, -1471.46, 29.43), -- vector4(140.46, -1471.46, 29.43, 66.66)
        heading = 66.66,
        delivery = vector3(141.68, -1486.69, 29.13),
        deliveryBox = vector3(-592.58, -892.67, 25.93),
    },
    [6] = {
        name = "Taco Bay",
        job = "tacoboy",
        position = vector3(-1260.78, -1207.64, 5.37), -- vector4(-1260.78, -1207.64, 5.37, 153.49)
        heading = 153.49,
        delivery = vector3(-1268.65, -1218.77, 4.73),
        deliveryBox = vector3(-1263.37, -1222.21, 4.9),
    },
    [7] = {
        name = "Taco Bay",
        job = "tacoboy",
        position = vector3(-1260.78, -1207.64, 5.37), -- vector4(-1260.78, -1207.64, 5.37, 153.49)
        heading = 153.49,
        delivery = vector3(-1268.65, -1218.77, 4.73),
        deliveryBox = vector3(-1263.37, -1222.21, 4.9),
    },
    -- New Restaurants
}

Config.WarehousesLocation = {
    [1] = {
        position = vector3(-80.3, 6525.98, 31.49),
        heading = 43.09,
        pedhash = 's_m_y_construct_02',
        name = "Main Warehouse"
    },
    [2] = {
        position = vector3(1181.47, -3280.73, 6.03), -- vector4(1181.47, -3280.73, 6.03, 97.63)
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

        -- SMART SPAWN POINTS (repurpose convoy points)
        -- We'll only use the first 3-4 for hybrid system
        smartSpawnPoints = {
            -- Primary spawn (vehicle 1)
            {position = vector4(-85.97, 6559.03, 31.23, 223.13), occupied = false, priority = 1},
            -- Secondary spawn (vehicle 2)
            {position = vector4(-83.26, 6561.48, 31.23, 222.38), occupied = false, priority = 2},
            -- Tertiary spawn (vehicle 3)
            {position = vector4(-80.68, 6563.84, 31.23, 221.13), occupied = false, priority = 3},
            -- Overflow (backup)
            {position = vector4(-78.01, 6566.43, 31.23, 222.36), occupied = false, priority = 4}
        },

        -- Convoy spawn points to prevent vehicle collisions
        convoySpawnPoints = {
            {position = vector4(-85.97, 6559.03, 31.23, 223.13), occupied = false, priority = 1},
            {position = vector4(-83.26, 6561.48, 31.23, 222.38), occupied = false, priority = 2},
            {position = vector4(-80.68, 6563.84, 31.23, 221.13), occupied = false, priority = 3},
            {position = vector4(-78.01, 6566.43, 31.23, 222.36), occupied = false, priority = 4},
            {position = vector4(-75.25, 6568.71, 31.23, 221.13), occupied = false, priority = 5},
            {position = vector4(-63.51, 6564.24, 31.49, 135.6), occupied = false, priority = 6},
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

        smartSpawnPoints = {
            -- Primary spawn (vehicle 1)
            {position = vector4(1150.8, -3297.1, 5.9, 94.21), occupied = false, priority = 1},
            -- Secondary spawn (vehicle 2)
            {position = vector4(1150.73, -3292.81, 5.9, 85.63), occupied = false, priority = 2},
            -- Tertiary spawn (vehicle 3)
            {position = vector4(1150.56, -3286.68, 5.9, 85.94), occupied = false, priority = 3},
            -- Overflow (backup)
            {position = vector4(1150.47, -3281.33, 5.9, 87.11), occupied = false, priority = 4}
        },

        convoySpawnPoints = {
            {position = vector4(1150.8, -3297.1, 5.9, 94.21), occupied = false, priority = 1},
            {position = vector4(1150.73, -3292.81, 5.9, 85.63), occupied = false, priority = 2},
            {position = vector4(1150.56, -3286.68, 5.9, 85.94), occupied = false, priority = 3},
            {position = vector4(1150.47, -3281.33, 5.9, 87.11), occupied = false, priority = 4},
            {position = vector4(1151.0, -3276.31, 5.9, 94.53), occupied = false, priority = 5},
            {position = vector4(1151.0, -3270.36, 5.9, 77.18), occupied = false, priority = 6},
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