Config = Config or {}

-- Enhanced Item Categories (example structure)
Config.Items = {
    ["burgershot"] = {
        Meats = {
            ["reign_packed_groundchicken"] = { label = "Ground Chicken", price = 6, size = "medium_items" },
            ["reign_packed_groundmeat"] = { label = "Ground Beef", price = 6, size = "medium_items" },
        },
        Vegetables = {
            ["reign_lettuce"] = { label = "Lettuce", price = 2, size = "small_items", import = true },
            -- ["farm_tomatoes"] = { label = "Tomatoes", price = 3, size = "medium_items" },
            -- ["farm_onions"] = { label = "Onions", price = 2, size = "small_items" }
        },
        Fruits = {
            -- ["farm_apples"] = { label = "Apples", price = 4, size = "medium_items" },
            -- ["farm_oranges"] = { label = "Oranges", price = 4, size = "medium_items" }
        },
        Dairy = {
            -- ["dairy_milk"] = { label = "Milk", price = 3, size = "large_items" },
            -- ["dairy_cheese"] = { label = "Cheese", price = 5, size = "medium_items" }
        },
        DryGoods = {
            -- ["bakery_flour"] = { label = "Flour", price = 2, size = "medium_items" },
            -- ["spice_salt"] = { label = "Salt", price = 1, size = "small_items" }
        }
    }
}

Config.ItemsFarming = {
    Meats = {
        ['reign_packed_groundchicken'] = { label = 'Ground Chicken', price = 4 },
        ['reign_packed_chkdrumsticks'] = { label = 'Chicken Drumsticks', price = 4 },
        ['reign_packed_chkbreast'] = { label = 'Chicken Breasts', price = 4 },
        ['reign_packed_chkthighs'] = { label = 'Chicken Thighs', price = 4 },
        ['reign_packed_chkwings'] = { label = 'Chicken Wings', price = 4 },
        ['reign_packed_brisket'] = { label = 'Beef Ribeye', price = 4 },
        ['reign_packed_sirloin'] = { label = 'Beef Sirloin', price = 4 },
        ['reign_packed_ribeye'] = { label = 'Beef Brisket', price = 4 },
        ['reign_packed_groundmeat'] = { label = 'Ground Beef', price = 4 }
    },
    Vegetables = {
        ['reign_lettuce'] = { label = 'Lettuce', price = 2 }
    },
    Fruits = {}
}

-- Container Supply Stations (where workers grab empty containers)
Config.ContainerStations = {
    {
        name = "Butcher Container Station",
        position = vector3(-80.26, 6542.03, 31.49), -- Example coords
        containerTypes = {"reign_cooler", "reign_box_fruit", "reign_box_vegetable"}
    },
    {
        name = "Farm Container Station", 
        position = vector3(-85.34, 6558.45, 31.49), -- Example coords
        containerTypes = {"reign_cooler", "reign_box_fruit", "reign_box_vegetable"}
    }
}

-- Enhanced fruit seller with container materials
Config.ContainerMaterials = {
    ["reign_cooler"] = { label = "Meat Cooler", price = 1 },
    ["reign_box_fruit"] = { label = "Fruit Box", price = 1 },
    ["reign_box_vegetable"] = { label = "Veggie Box", price = 1 },
}