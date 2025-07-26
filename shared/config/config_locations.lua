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
        heading = 224.0426
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
        heading = 226.1908
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