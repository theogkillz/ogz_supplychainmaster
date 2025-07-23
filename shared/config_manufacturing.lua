-- ============================================
-- MANUFACTURING SYSTEM CONFIGURATION
-- Professional ingredient creation facilities
-- ============================================

Config.Manufacturing = {
    enabled = true,
    
    -- Processing Economics
    processingCosts = {
        baseProcessingFee = 50,        -- Base cost per batch
        electricityCost = 25,          -- Power cost per hour of operation
        maintenanceFee = 15,           -- Equipment maintenance per batch
        qualityBonusCost = 100,        -- Extra cost for premium quality
    },
    
    -- Processing Time Configuration
    timing = {
        baseProcessingTime = 30000,    -- 30 seconds base time
        timePerItem = 2000,            -- 2 seconds per additional item
        qualityProcessingMultiplier = 1.5, -- 50% longer for premium quality
        maxProcessingTime = 300000,    -- 5 minute maximum
    },
    
    -- Container System Integration
    containerSystem = {
        itemsPerContainer = 12,        -- Same as delivery system
        containersPerBox = 5,          -- Same as delivery system
        maxItemsPerBatch = 100,        -- Maximum items in single batch
    },
    
    -- Quality Control System
    qualityControl = {
        enabled = true,
        standardQuality = {
            successRate = 0.95,        -- 95% success rate
            yieldMultiplier = 1.0,     -- Standard yield
            priceMultiplier = 1.0,     -- Standard market price
        },
        premiumQuality = {
            successRate = 0.85,        -- 85% success rate (harder)
            yieldMultiplier = 1.2,     -- 20% more output
            priceMultiplier = 1.5,     -- 50% higher value
            requiredSkill = 25,        -- Manufacturing skill level required
        },
        organicQuality = {
            successRate = 0.80,        -- 80% success rate (hardest)
            yieldMultiplier = 1.1,     -- 10% more output
            priceMultiplier = 2.0,     -- 100% higher value (organic premium)
            requiredSkill = 50,        -- Higher skill required
        }
    }
}

-- ============================================
-- JOB ACCESS CONFIGURATION
-- ============================================

-- Manufacturing job access - ONLY HURST JOB
Config.ManufacturingJobs = {
    authorized = {"hurst"}, -- Only hurst job can access manufacturing
    
    -- Job-specific bonuses for hurst employees
    jobBonuses = {
        ["hurst"] = {
            experienceMultiplier = 1.5,
            speedBonus = 0.10,
            qualityBonus = 0.05
        }
    }
}

-- Universal job validation function
function Config.HasManufacturingAccess(playerJob)
    return playerJob == "hurst"
end

-- Error messages
Config.AccessDeniedMessages = {
    manufacturing = "🚫 Manufacturing access restricted to Hurst Industries employees",
    warehouse = "🚫 Warehouse access restricted to Hurst Industries employees", 
    restaurant = "🚫 Restaurant management requires business ownership"
}

-- ============================================
-- MANUFACTURING FACILITY LOCATIONS
-- ============================================

Config.ManufacturingFacilities = {
    [1] = {
        name = "Grain Processing Plant",
        position = vector3(2433.35, 4969.41, 42.35), -- Sandy Shores Industrial
        heading = 45.0,
        blip = {
            sprite = 566,
            color = 46,
            scale = 0.8,
            label = "Grain Processing"
        },
        ped = {
            model = "s_m_y_factory_01",
            heading = 135.0
        },
        specializations = {"flour", "grain_processing", "baking_ingredients"},
        processingStations = {
            vector3(2435.0, 4967.0, 42.35),
            vector3(2431.0, 4971.0, 42.35)
        }
    },
    
    [2] = {
        name = "Dairy Manufacturing Plant",
        position = vector3(2454.78, 4972.12, 46.81), -- Sandy Shores Industrial
        heading = 90.0,
        blip = {
            sprite = 569,
            color = 0,
            scale = 0.8,
            label = "Dairy Processing"
        },
        ped = {
            model = "s_f_y_factory_01",
            heading = 270.0
        },
        specializations = {"dairy", "cheese_making", "butter_production"},
        processingStations = {
            vector3(2456.0, 4970.0, 46.81),
            vector3(2453.0, 4974.0, 46.81)
        }
    },
    
    [3] = {
        name = "Meat Processing Facility",
        position = vector3(735.28, -1084.73, 22.17), -- Downtown warehouse district
        heading = 180.0,
        blip = {
            sprite = 568,
            color = 6,
            scale = 0.8,
            label = "Meat Processing"
        },
        ped = {
            model = "s_m_m_butcher_01",
            heading = 0.0
        },
        specializations = {"meat_processing", "ground_meat", "protein_preparation"},
        processingStations = {
            vector3(2471.0, 4983.0, 51.77),
            vector3(2467.0, 4988.0, 51.77)
        }
    },
    
    [4] = {
        name = "Vegetable Processing Center",
        position = vector3(1208.73, -1402.74, 35.22), -- Industrial area
        heading = 270.0,
        blip = {
            sprite = 570,
            color = 25,
            scale = 0.8,
            label = "Vegetable Processing"
        },
        ped = {
            model = "s_f_y_factory_01",
            heading = 90.0
        },
        specializations = {"vegetable_processing", "produce_preparation", "sauce_making"},
        processingStations = {
            vector3(2486.0, 4961.0, 44.79),
            vector3(2490.0, 4958.0, 44.79)
        }
    },
    
    [5] = {
        name = "Artisan Food Laboratory",
        position = vector3(285.28, 2843.73, 44.70), -- Near airfield
        heading = 315.0,
        blip = {
            sprite = 567,
            color = 83,
            scale = 0.8,
            label = "Artisan Laboratory"
        },
        ped = {
            model = "s_m_y_chef_01",
            heading = 135.0
        },
        specializations = {"artisan_production", "specialty_items", "gourmet_ingredients"},
        processingStations = {
            vector3(2503.0, 4961.0, 44.58),
            vector3(2500.0, 4965.0, 44.58)
        }
    }
}

-- ============================================
-- MANUFACTURING RECIPES - INGREDIENT CREATION ONLY
-- ============================================

Config.ManufacturingRecipes = {
    
    -- ===========================================
    -- GRAIN & FLOUR PROCESSING
    -- ===========================================
    
    ["basic_flour"] = {
        name = "Basic Flour",
        category = "flour",
        facility_specialization = "flour",
        inputs = {
            ["ogz_wheat_plant"] = 5,
        },
        outputs = {
            ["ogz_flour_basic"] = {quantity = 8, quality = "standard"}
        },
        processingTime = 45, -- seconds
        skillRequired = 0,
        energyCost = 15,
        description = "Process wheat into basic flour for everyday cooking"
    },
    
    ["premium_flour"] = {
        name = "Premium Flour Blend",
        category = "flour",
        facility_specialization = "flour",
        inputs = {
            ["ogz_wheat_plant"] = 4,
            ["ogz_rice_plant"] = 2,
        },
        outputs = {
            ["ogz_flour_premium"] = {quantity = 5, quality = "premium"}
        },
        processingTime = 75,
        skillRequired = 15,
        energyCost = 25,
        description = "Blend wheat and rice for premium flour with superior texture"
    },
    
    ["specialty_flour"] = {
        name = "Specialty Flour",
        category = "flour",
        facility_specialization = "grain_processing",
        inputs = {
            ["ogz_wheat_plant"] = 3,
            ["ogz_barley_plant"] = 2,
            ["ogz_oats_plant"] = 2,
        },
        outputs = {
            ["ogz_flour_specialty"] = {quantity = 6, quality = "organic"}
        },
        processingTime = 120,
        skillRequired = 35,
        energyCost = 40,
        description = "Multi-grain specialty flour for artisan baking"
    },
    
    -- ===========================================
    -- DAIRY PROCESSING
    -- ===========================================
    
    ["basic_cheese"] = {
        name = "Cheese Block",
        category = "dairy",
        facility_specialization = "dairy",
        inputs = {
            ["ogz_milk_cow"] = 10,
            ["ogz_salt_coarse"] = 1,
        },
        outputs = {
            ["ogz_cheese_block"] = {quantity = 4, quality = "standard"}
        },
        processingTime = 90,
        skillRequired = 10,
        energyCost = 20,
        description = "Transform fresh milk into solid cheese blocks"
    },
    
    ["artisan_cheese"] = {
        name = "Artisan Cheese",
        category = "dairy",
        facility_specialization = "cheese_making",
        inputs = {
            ["ogz_milk_cow"] = 15,
            ["ogz_cultures_cheese"] = 1,
            ["ogz_salt_coarse"] = 2,
        },
        outputs = {
            ["ogz_cheese_artisan"] = {quantity = 3, quality = "premium"}
        },
        processingTime = 150,
        skillRequired = 30,
        energyCost = 35,
        description = "Craft premium artisan cheese with live cultures"
    },
    
    ["fresh_butter"] = {
        name = "Fresh Butter",
        category = "dairy",
        facility_specialization = "butter_production",
        inputs = {
            ["ogz_milk_cow"] = 20,
        },
        outputs = {
            ["ogz_butter_fresh"] = {quantity = 6, quality = "standard"}
        },
        processingTime = 60,
        skillRequired = 5,
        energyCost = 15,
        description = "Churn fresh milk into creamy butter"
    },
    
    -- ===========================================
    -- MEAT PROCESSING
    -- ===========================================
    
    ["ground_beef"] = {
        name = "Ground Beef",
        category = "meat",
        facility_specialization = "meat_processing",
        inputs = {
            ["slaughter_ground_meat"] = 5,
        },
        outputs = {
            ["ogz_ground_beef"] = {quantity = 4, quality = "standard"}
        },
        processingTime = 30,
        skillRequired = 0,
        energyCost = 10,
        description = "Process raw meat into ground beef"
    },
    
    ["ground_chicken"] = {
        name = "Ground Chicken",
        category = "meat",
        facility_specialization = "meat_processing",
        inputs = {
            ["butcher_ground_chicken"] = 5,
        },
        outputs = {
            ["ogz_ground_chicken"] = {quantity = 4, quality = "standard"}
        },
        processingTime = 30,
        skillRequired = 0,
        energyCost = 10,
        description = "Process raw chicken into ground chicken"
    },
    
    ["premium_ground_blend"] = {
        name = "Premium Ground Blend",
        category = "meat",
        facility_specialization = "protein_preparation",
        inputs = {
            ["ogz_packed_groundmeat"] = 3,
            ["ogz_packed_groundchicken"] = 2,
        },
        outputs = {
            ["ogz_ground_blend"] = {quantity = 4, quality = "premium"}
        },
        processingTime = 90,
        skillRequired = 25,
        energyCost = 25,
        description = "Blend multiple meats for gourmet recipes"
    },
    
    -- ===========================================
    -- VEGETABLE PROCESSING
    -- ===========================================
    
    ["tomato_paste"] = {
        name = "Tomato Paste",
        category = "vegetable",
        facility_specialization = "vegetable_processing",
        inputs = {
            ["ogz_tomato"] = 10,
        },
        outputs = {
            ["ogz_tomato_paste"] = {quantity = 6, quality = "standard"}
        },
        processingTime = 60,
        skillRequired = 10,
        energyCost = 20,
        description = "Concentrate fresh tomatoes into rich paste"
    },
    
    ["diced_onions"] = {
        name = "Diced Onions",
        category = "vegetable",
        facility_specialization = "produce_preparation",
        inputs = {
            ["ogz_onion"] = 8,
        },
        outputs = {
            ["ogz_onion_diced"] = {quantity = 6, quality = "standard"}
        },
        processingTime = 45,
        skillRequired = 5,
        energyCost = 10,
        description = "Precisely dice onions for commercial kitchens"
    },
    
    ["potato_fries"] = {
        name = "Pre-cut Fries",
        category = "vegetable",
        facility_specialization = "produce_preparation",
        inputs = {
            ["ogz_potato"] = 12,
        },
        outputs = {
            ["ogz_potato_fries"] = {quantity = 10, quality = "standard"}
        },
        processingTime = 75,
        skillRequired = 15,
        energyCost = 18,
        description = "Cut potatoes into perfect fry shapes"
    },
    
    -- ===========================================
    -- SAUCE MANUFACTURING
    -- ===========================================
    
    ["bbq_sauce"] = {
        name = "BBQ Sauce",
        category = "sauce",
        facility_specialization = "sauce_making",
        inputs = {
            ["ogz_tomato_paste"] = 3,
            ["ogz_sugar_powder"] = 2,
            ["ogz_worcestershiresauce"] = 1,
        },
        outputs = {
            ["ogz_sauce_bbq"] = {quantity = 5, quality = "standard"}
        },
        processingTime = 90,
        skillRequired = 20,
        energyCost = 25,
        description = "Blend ingredients into tangy BBQ sauce"
    },
    
    ["ranch_dressing"] = {
        name = "Ranch Dressing",
        category = "sauce",
        facility_specialization = "sauce_making",
        inputs = {
            ["ogz_mayo"] = 3,
            ["ogz_milk_cow"] = 2,
            ["ogz_herbs_mixed"] = 1,
        },
        outputs = {
            ["ogz_sauce_ranch"] = {quantity = 4, quality = "standard"}
        },
        processingTime = 60,
        skillRequired = 15,
        energyCost = 15,
        description = "Create creamy ranch dressing for salads"
    },
    
    ["fresh_mayo"] = {
        name = "Fresh Mayonnaise",
        category = "sauce",
        facility_specialization = "sauce_making",
        inputs = {
            ["ogz_egg_fresh"] = 4,
            ["ogz_oil_vegetable"] = 2,
        },
        outputs = {
            ["ogz_mayo_fresh"] = {quantity = 6, quality = "premium"}
        },
        processingTime = 45,
        skillRequired = 10,
        energyCost = 12,
        description = "Emulsify eggs and oil into fresh mayonnaise"
    },
    
    -- ===========================================
    -- BAKING INGREDIENT MANUFACTURING
    -- ===========================================
    
    ["pizza_dough"] = {
        name = "Pizza Dough",
        category = "baking",
        facility_specialization = "baking_ingredients",
        inputs = {
            ["ogz_flour_basic"] = 3,
            ["ogz_yeast"] = 1,
            ["ogz_oil_olive"] = 1,
        },
        outputs = {
            ["ogz_dough_pizza"] = {quantity = 8, quality = "standard"}
        },
        processingTime = 75,
        skillRequired = 20,
        energyCost = 20,
        description = "Mix flour, yeast and oil into pizza dough"
    },
    
    ["bread_dough"] = {
        name = "Bread Dough",
        category = "baking",
        facility_specialization = "baking_ingredients",
        inputs = {
            ["ogz_flour_premium"] = 2,
            ["ogz_yeast"] = 1,
            ["ogz_milk_cow"] = 1,
        },
        outputs = {
            ["ogz_dough_bread"] = {quantity = 6, quality = "premium"}
        },
        processingTime = 90,
        skillRequired = 25,
        energyCost = 25,
        description = "Create enriched bread dough for bakeries"
    },
    
    ["pancake_batter"] = {
        name = "Pancake Batter",
        category = "baking",
        facility_specialization = "baking_ingredients",
        inputs = {
            ["ogz_flour_basic"] = 2,
            ["ogz_egg_fresh"] = 2,
            ["ogz_milk_cow"] = 3,
        },
        outputs = {
            ["ogz_batter_pancake"] = {quantity = 10, quality = "standard"}
        },
        processingTime = 30,
        skillRequired = 5,
        energyCost = 10,
        description = "Mix batter for fluffy pancakes"
    },
    
    -- ===========================================
    -- ARTISAN SPECIALTY PRODUCTION
    -- ===========================================
    
    ["prime_beef"] = {
        name = "Prime Grade Beef",
        category = "artisan",
        facility_specialization = "artisan_production",
        inputs = {
            ["slaughter_ribeye"] = 2,
            ["slaughter_tenderloin"] = 1,
        },
        outputs = {
            ["ogz_beef_prime"] = {quantity = 2, quality = "organic"}
        },
        processingTime = 180,
        skillRequired = 50,
        energyCost = 50,
        description = "Process premium cuts into prime grade beef"
    },
    
    ["aged_cheese"] = {
        name = "Aged Cheese",
        category = "artisan",
        facility_specialization = "specialty_items",
        inputs = {
            ["ogz_cheese_artisan"] = 3,
        },
        outputs = {
            ["ogz_cheese_aged"] = {quantity = 2, quality = "organic"}
        },
        processingTime = 240,
        skillRequired = 60,
        energyCost = 35,
        description = "Age artisan cheese for complex flavors"
    },
    
    ["organic_flour"] = {
        name = "Organic Flour",
        category = "artisan",
        facility_specialization = "gourmet_ingredients",
        inputs = {
            ["ogz_wheat_plant"] = 8,
            ["ogz_quinoa_plant"] = 2,
        },
        outputs = {
            ["ogz_flour_organic"] = {quantity = 6, quality = "organic"}
        },
        processingTime = 150,
        skillRequired = 40,
        energyCost = 40,
        description = "Create certified organic flour blend"
    }
}

-- ============================================
-- MANUFACTURING SKILL PROGRESSION
-- ============================================

Config.ManufacturingSkills = {
    enabled = true,
    
    skillCategories = {
        ["flour"] = {
            name = "Grain Processing",
            maxLevel = 100,
            experienceRate = 1.0
        },
        ["dairy"] = {
            name = "Dairy Production", 
            maxLevel = 100,
            experienceRate = 1.2
        },
        ["meat"] = {
            name = "Meat Processing",
            maxLevel = 100,
            experienceRate = 1.1
        },
        ["vegetable"] = {
            name = "Produce Processing",
            maxLevel = 100,
            experienceRate = 0.9
        },
        ["sauce"] = {
            name = "Sauce Manufacturing",
            maxLevel = 100,
            experienceRate = 1.3
        },
        ["baking"] = {
            name = "Baking Ingredients",
            maxLevel = 100,
            experienceRate = 1.0
        },
        ["artisan"] = {
            name = "Artisan Production",
            maxLevel = 100,
            experienceRate = 2.0
        }
    },
    
    -- Experience rewards per successful batch
    experienceRewards = {
        standard = 10,
        premium = 20,
        organic = 35
    },
    
    -- Skill level bonuses
    levelBonuses = {
        [25] = {yieldBonus = 0.05, speedBonus = 0.10}, -- 5% more yield, 10% faster
        [50] = {yieldBonus = 0.10, speedBonus = 0.15}, -- 10% more yield, 15% faster  
        [75] = {yieldBonus = 0.15, speedBonus = 0.20}, -- 15% more yield, 20% faster
        [100] = {yieldBonus = 0.25, speedBonus = 0.30}, -- 25% more yield, 30% faster
    }
}

-- ============================================
-- MANUFACTURING PROPS & EFFECTS
-- ============================================

Config.ManufacturingProps = {
    processingStationProp = "prop_tool_bench02",
    
    -- Visual effects during processing
    effects = {
        enabled = true,
        
        flour = {
            particleEffect = "core",
            particleName = "ent_anim_dusty_hands",
            soundEffect = "DLC_IE_VV_Gun_Player_Impact_Ammo_Crate_Sawdust"
        },
        
        dairy = {
            particleEffect = "core", 
            particleName = "ent_amb_steam",
            soundEffect = "DLC_IE_VV_Gun_Player_Impact_Meat_01"
        },
        
        meat = {
            particleEffect = "core",
            particleName = "blood_stab",
            soundEffect = "DLC_IE_VV_Gun_Player_Impact_Meat_02"
        },
        
        vegetable = {
            particleEffect = "core",
            particleName = "ent_anim_leaf_blower",
            soundEffect = "DLC_IE_VV_Gun_Player_Impact_Fruit_01"
        }
    }
}

-- ============================================
-- INTEGRATION WITH EXISTING SYSTEMS
-- ============================================

Config.ManufacturingIntegration = {
    
    -- Market pricing integration
    marketPricing = {
        enabled = true,
        fluctuationRange = 0.3, -- ±30% price variation based on demand
        updateInterval = 1800,  -- 30 minutes
    },
    
    -- Warehouse integration  
    warehouseIntegration = {
        enabled = true,
        autoDelivery = true,           -- Auto-deliver to warehouse when complete
        deliveryNotification = true,   -- Notify warehouse of new stock
    },
    
    -- Achievement integration
    achievements = {
        enabled = true,
        trackProduction = true,        -- Track total items manufactured
        trackQuality = true,           -- Track premium/organic production
        trackEfficiency = true,        -- Track processing speed improvements
    },
    
    -- Emergency order integration
    emergencyProduction = {
        enabled = true,
        priorityMultiplier = 2.0,      -- 2x speed for emergency orders
        bonusPayment = 1.5,            -- 50% bonus payment for emergency production
    }
}