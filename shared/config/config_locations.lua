Config = Config or {}

Config.Restaurants = {
    [1] = {
        name = "Burgershot",
        job = "burgershot",
        position = vector3(-1178.0913085938, -896.11010742188, 14.108023834229),
        heading = 118.0,
        delivery = vector3(-1173.53, -892.72, 13.86),
        deliveryBox = vector3(-1177.39, -890.98, 12.79),
    },
    -- New Restaurants
}

Config.WarehousesLocation = {
    {
        position = vector3(-80.3, 6525.98, 30.49),
        heading = 43.09,
        pedhash = 's_m_y_construct_02'
    }
}

Config.Warehouses = {
    {
        active = true,
        vehicle = {
            model = 'speedo',
            position = vector4(-51.2647, 6550.9014, 31.4908, 224.0426)
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
            {position = vector4(-51.2647, 6550.9014, 31.4908, 224.0426), occupied = false, priority = 1},
            -- Line formation along the road (4-5 unit spacing)
            {position = vector4(-54.8647, 6547.3014, 31.4908, 224.0426), occupied = false, priority = 2},
            {position = vector4(-58.4647, 6543.7014, 31.4908, 224.0426), occupied = false, priority = 3},
            {position = vector4(-62.0647, 6540.1014, 31.4908, 224.0426), occupied = false, priority = 4},
            {position = vector4(-65.6647, 6536.5014, 31.4908, 224.0426), occupied = false, priority = 5},
            -- Second row (parallel parking style)
            {position = vector4(-47.6647, 6554.5014, 31.4908, 224.0426), occupied = false, priority = 6},
            {position = vector4(-44.0647, 6558.1014, 31.4908, 224.0426), occupied = false, priority = 7},
            {position = vector4(-40.4647, 6561.7014, 31.4908, 224.0426), occupied = false, priority = 8},
            -- Side positions
            {position = vector4(-55.2647, 6554.9014, 31.4908, 224.0426), occupied = false, priority = 9},
            {position = vector4(-59.2647, 6551.9014, 31.4908, 224.0426), occupied = false, priority = 10},
            -- Overflow positions
            {position = vector4(-68.2647, 6533.9014, 31.4908, 224.0426), occupied = false, priority = 11},
            {position = vector4(-71.2647, 6530.9014, 31.4908, 224.0426), occupied = false, priority = 12}
        }
    },
    {
        active = true,
        vehicle = {
            model = 'speedo',
            position = vector4(-57.5422, 6534.3442, 31.4908, 226.1908)
        },
        boxPositions = {
            vector3(-85.34, 6558.45, 31.49),
            vector3(-84.84, 6557.95, 31.49),
            vector3(-85.84, 6558.95, 31.49)
        },
        heading = 226.1908,
        -- SESSION 36 FIX: Added convoy spawn points for warehouse 2
        convoySpawnPoints = {
            -- Primary spawn (leader)
            {position = vector4(-57.5422, 6534.3442, 31.4908, 226.1908), occupied = false, priority = 1},
            -- Line formation
            {position = vector4(-61.1422, 6530.7442, 31.4908, 226.1908), occupied = false, priority = 2},
            {position = vector4(-64.7422, 6527.1442, 31.4908, 226.1908), occupied = false, priority = 3},
            {position = vector4(-68.3422, 6523.5442, 31.4908, 226.1908), occupied = false, priority = 4},
            {position = vector4(-71.9422, 6519.9442, 31.4908, 226.1908), occupied = false, priority = 5},
            -- Second row
            {position = vector4(-53.9422, 6537.9442, 31.4908, 226.1908), occupied = false, priority = 6},
            {position = vector4(-50.3422, 6541.5442, 31.4908, 226.1908), occupied = false, priority = 7},
            {position = vector4(-46.7422, 6545.1442, 31.4908, 226.1908), occupied = false, priority = 8},
            -- Side positions
            {position = vector4(-61.5422, 6538.3442, 31.4908, 226.1908), occupied = false, priority = 9},
            {position = vector4(-65.5422, 6534.3442, 31.4908, 226.1908), occupied = false, priority = 10},
            -- Overflow
            {position = vector4(-75.5422, 6516.3442, 31.4908, 226.1908), occupied = false, priority = 11},
            {position = vector4(-79.1422, 6512.7442, 31.4908, 226.1908), occupied = false, priority = 12}
        }
    }
}

Config.PedModel = "a_m_m_farmer_01"
Config.Location = {
    coords = vector3(-86.59, 6494.08, 31.51),
    heading = 221.43
}
Config.SellerBlip = {
    label = 'Distributor',
    coords = vector3(-88.4297, 6493.5161, 30.1007),
    blipSprite = 1,
    blipColor = 1,
    blipScale = 0.6
}