-- ============================================
-- DYNAMIC CONTAINER SYSTEM - CONFIGURATION
-- Advanced container logistics configuration
-- ============================================

Config.DynamicContainers = {
    enabled = true,
    
    -- Core container system settings
    system = {
        maxItemsPerContainer = 12,  -- NEVER mix items in containers
        qualityDegradationEnabled = true,
        temperatureTrackingEnabled = true,
        expirationSystem = true,
        qualityAlertThreshold = 30.0,  -- Alert when quality drops below 30%
        
        -- Container ID generation
        containerIdPrefix = "HURST_",
        useTimestampInId = true,
        
        -- Quality degradation rates (per hour)
        degradationRates = {
            base = 0.02,           -- 2% per hour base rate
            temperature = 0.15,    -- 15% per hour if temperature breaks
            handling = 0.05,       -- 5% per hour for rough handling
            transport = 0.01,      -- 1% per hour during transport
            time = 0.03           -- 3% per hour just from aging
        }
    },
    
    -- Container type definitions
    containerTypes = {
        ["ogz_cooler"] = {
            name = "Professional Cooling Container",
            description = "Temperature-controlled container for perishables",
            item = "ogz_cooler",  -- Must match inventory item
            
            -- Capacity and specifications
            maxCapacity = 12,
            cost = 25,
            
            -- What items can go in this container
            suitableCategories = {
                "meat", "dairy", "frozen", "seafood", "cheese", "eggs"
            },
            suitableItems = {
                -- Meat products
                "slaughter_meat", "slaughter_ground_meat", "slaughter_chicken", 
                "slaughter_pork", "slaughter_beef", "packaged_meat",
                
                -- Dairy products
                "milk", "cream", "butter", "cheese", "yogurt",
                
                -- Frozen items
                "frozen_vegetables", "ice_cream", "frozen_fruit"
            },
            
            -- Container bonuses and properties
            preservationMultiplier = 1.5,   -- 50% longer freshness
            temperatureControlled = true,
            requiresRefrigeration = true,
            qualityRetention = 0.95,        -- Retains 95% quality per hour
            
            -- Special properties
            properties = {
                waterproof = true,
                shockResistant = true,
                temperatureRange = {-18, 4},  -- -18°C to 4°C
                humidityControlled = true
            },
            
            -- Visual and audio
            icon = "fas fa-snowflake",
            color = "#87CEEB",  -- Sky blue
            sound = "container_cooler_open"
        },
        
        ["ogz_crate"] = {
            name = "Standard Storage Crate",
            description = "Multi-purpose container for dry goods",
            item = "ogz_crate",
            
            maxCapacity = 12,
            cost = 15,
            
            suitableCategories = {
                "vegetables", "fruits", "dry_goods", "spices", "grains"
            },
            suitableItems = {
                -- Vegetables
                "tomato", "lettuce", "onion", "potato", "carrot", "bell_pepper",
                
                -- Fruits  
                "apple", "orange", "banana", "strawberry", "grapes",
                
                -- Dry goods
                "flour", "sugar", "salt", "rice", "pasta", "bread",
                
                -- Spices and seasonings
                "black_pepper", "garlic", "herbs", "spices"
            },
            
            preservationMultiplier = 1.0,   -- Standard preservation
            temperatureControlled = false,
            requiresRefrigeration = false,
            qualityRetention = 0.92,        -- 92% quality retention per hour
            
            properties = {
                waterproof = false,
                shockResistant = true,
                ventilated = true,
                stackable = true
            },
            
            icon = "fas fa-box",
            color = "#DEB887",  -- Burlywood
            sound = "container_crate_open"
        },
        
        ["ogz_thermal"] = {
            name = "Thermal Insulation Container",
            description = "Keeps hot items hot and maintains temperature",
            item = "ogz_thermal",
            
            maxCapacity = 12,
            cost = 35,
            
            suitableCategories = {
                "hot_food", "cooked_items", "prepared_meals", "beverages"
            },
            suitableItems = {
                -- Hot prepared items
                "cooked_burger", "hot_pizza", "grilled_chicken", "fried_food",
                "soup", "hot_coffee", "tea", "hot_chocolate",
                
                -- Prepared ingredients that need heat retention
                "cooked_meat", "steamed_vegetables", "hot_sauce"
            },
            
            preservationMultiplier = 2.0,   -- Double preservation for hot items
            temperatureControlled = true,
            requiresRefrigeration = false,
            qualityRetention = 0.98,        -- 98% quality retention (excellent for hot items)
            
            properties = {
                waterproof = true,
                shockResistant = true,
                temperatureRange = {60, 85},  -- 60°C to 85°C
                insulated = true,
                heatRetention = true
            },
            
            icon = "fas fa-fire",
            color = "#FF6347",  -- Tomato red
            sound = "container_thermal_open"
        },
        
        ["ogz_freezer"] = {
            name = "Deep Freeze Container",
            description = "Ultra-low temperature for frozen goods",
            item = "ogz_freezer",
            
            maxCapacity = 12,
            cost = 45,
            
            suitableCategories = {
                "frozen_goods", "ice_cream", "frozen_meat", "frozen_seafood"
            },
            suitableItems = {
                "frozen_beef", "frozen_chicken", "frozen_fish", "frozen_shrimp",
                "ice_cream", "frozen_vegetables", "frozen_fruit", "ice"
            },
            
            preservationMultiplier = 3.0,   -- Triple preservation
            temperatureControlled = true,
            requiresRefrigeration = true,
            qualityRetention = 0.99,        -- 99% quality retention
            
            properties = {
                waterproof = true,
                shockResistant = true,
                temperatureRange = {-25, -18}, -- Deep freeze temperatures
                doubleInsulated = true,
                backup_cooling = true
            },
            
            icon = "fas fa-icicles",
            color = "#B0E0E6",  -- Powder blue
            sound = "container_freezer_open"
        },
        
        ["ogz_produce"] = {
            name = "Fresh Produce Container",
            description = "Specialized container for fresh fruits and vegetables",
            item = "ogz_produce",
            
            maxCapacity = 12,
            cost = 18,
            
            suitableCategories = {
                "fresh_vegetables", "fresh_fruits", "herbs", "organic_produce"
            },
            suitableItems = {
                -- Fresh vegetables
                "fresh_lettuce", "fresh_tomato", "fresh_cucumber", "fresh_herbs",
                "organic_carrot", "organic_potato", "fresh_spinach",
                
                -- Fresh fruits
                "fresh_apple", "fresh_orange", "fresh_berries", "organic_banana"
            },
            
            preservationMultiplier = 1.25,  -- 25% better preservation
            temperatureControlled = false,
            requiresRefrigeration = false,
            qualityRetention = 0.94,        -- 94% quality retention
            
            properties = {
                waterproof = false,
                shockResistant = false,
                ventilated = true,
                humidityControlled = true,
                ethyleneFiltering = true  -- Prevents over-ripening
            },
            
            icon = "fas fa-seedling",
            color = "#98FB98",  -- Pale green
            sound = "container_produce_open"
        },
        
        ["ogz_bulk"] = {
            name = "Bulk Storage Container",
            description = "Large capacity container for bulk dry goods",
            item = "ogz_bulk",
            
            maxCapacity = 12,  -- Still limited to 12 items per container rule
            cost = 12,
            
            suitableCategories = {
                "grains", "flour", "sugar", "bulk_items", "non_perishables"
            },
            suitableItems = {
                "flour", "sugar", "salt", "rice", "wheat", "oats",
                "bulk_spices", "baking_soda", "cornstarch"
            },
            
            preservationMultiplier = 0.8,   -- Less preservation (bulk items don't need much)
            temperatureControlled = false,
            requiresRefrigeration = false,
            qualityRetention = 0.90,        -- 90% quality retention
            
            properties = {
                waterproof = true,
                shockResistant = true,
                dustProof = true,
                largeBin = true
            },
            
            icon = "fas fa-weight",
            color = "#D2B48C",  -- Tan
            sound = "container_bulk_open"
        }
    },
    
    -- Automatic container selection logic
    autoSelection = {
        enabled = true,
        
        -- Priority order for container selection
        priorities = {
            temperatureRequired = 1,    -- Temperature-controlled items get priority
            categoryMatch = 2,          -- Category-specific containers
            costEfficiency = 3,         -- Cheapest suitable container
            availability = 4            -- Most available container type
        },
        
        -- Fallback container if specific type unavailable
        fallbackContainer = "ogz_crate",
        
        -- Cost optimization
        costOptimization = {
            enabled = true,
            maxCostDifference = 10,     -- Don't spend more than $10 extra for optimization
            preferenceMultiplier = 1.2   -- Prefer specialized containers by 20%
        }
    },
    
    -- Quality management system
    qualityManagement = {
        enabled = true,
        
        -- Quality grades and effects
        qualityGrades = {
            excellent = { min = 90, multiplier = 1.1, label = "Excellent", color = "#00FF00", icon = "⭐⭐⭐" },
            good = { min = 70, multiplier = 1.0, label = "Good", color = "#FFFF00", icon = "⭐⭐" },
            fair = { min = 50, multiplier = 0.9, label = "Fair", color = "#FFA500", icon = "⭐" },
            poor = { min = 30, multiplier = 0.7, label = "Poor", color = "#FF4500", icon = "⚠️" },
            spoiled = { min = 0, multiplier = 0.3, label = "Spoiled", color = "#FF0000", icon = "❌" }
        },
        
        -- Factors affecting quality degradation
        degradationFactors = {
            temperature_breach = {
                rate = 0.15,            -- 15% per hour
                description = "Temperature control failure",
                preventable = true
            },
            rough_handling = {
                rate = 0.08,            -- 8% per occurrence
                description = "Improper handling during transport",
                preventable = true
            },
            time_aging = {
                rate = 0.02,            -- 2% per hour (natural aging)
                description = "Natural aging process",
                preventable = false
            },
            contamination = {
                rate = 0.25,            -- 25% immediate loss
                description = "Container contamination",
                preventable = true
            }
        },
        
        -- Quality alerts
        alerts = {
            warningThreshold = 50,      -- Warn when quality drops below 50%
            criticalThreshold = 30,     -- Critical alert below 30%
            
            notifications = {
                enabled = true,
                methods = {
                    ingame = true,
                    discord = true,
                    phone = false
                }
            }
        }
    },
    
    -- Container inventory management
    inventory = {
        reorderThresholds = {
            ogz_cooler = 20,        -- Reorder when below 20
            ogz_crate = 30,         -- Reorder when below 30
            ogz_thermal = 15,       -- Reorder when below 15
            ogz_freezer = 10,       -- Reorder when below 10
            ogz_produce = 25,       -- Reorder when below 25
            ogz_bulk = 20           -- Reorder when below 20
        },
        
        reorderQuantities = {
            ogz_cooler = 50,        -- Reorder 50 at a time
            ogz_crate = 100,        -- Reorder 100 at a time
            ogz_thermal = 30,       -- Reorder 30 at a time
            ogz_freezer = 25,       -- Reorder 25 at a time
            ogz_produce = 75,       -- Reorder 75 at a time
            ogz_bulk = 50           -- Reorder 50 at a time
        },
        
        automaticReordering = {
            enabled = true,
            checkInterval = 3600,   -- Check every hour
            maxCostPerReorder = 5000 -- Don't spend more than $5000 per automatic reorder
        }
    },
    
    -- Integration with existing systems
    integration = {
        -- Reward system integration
        rewards = {
            qualityBonuses = {
                excellent = 1.15,      -- 15% bonus for excellent quality
                good = 1.05,           -- 5% bonus for good quality
                fair = 1.0,            -- No bonus for fair
                poor = 0.9,            -- 10% penalty for poor
                spoiled = 0.5          -- 50% penalty for spoiled
            },
            
            containerEfficiencyBonus = {
                enabled = true,
                maxBonus = 200,        -- Maximum $200 bonus
                perfectContainerMatch = 100, -- $100 for perfect container selection
                temperatureControlMaintained = 50 -- $50 for maintaining temperature
            }
        },
        
        -- Market system integration
        market = {
            qualityPriceMultipliers = {
                excellent = 1.1,       -- 10% higher value for excellent quality
                good = 1.0,            -- Standard value for good quality
                fair = 0.95,           -- 5% lower value for fair quality
                poor = 0.8,            -- 20% lower value for poor quality
                spoiled = 0.3          -- 70% value loss for spoiled items
            },
            
            containerDemand = {
                enabled = true,
                scarceContainerPremium = 1.2, -- 20% premium when containers are scarce
                abundantContainerDiscount = 0.95 -- 5% discount when containers are abundant
            }
        },
        
        -- Stock alert integration
        stockAlerts = {
            containerShortageAlert = true,
            qualityDegradationAlert = true,
            expirationWarnings = true,
            
            alertLevels = {
                containerShortage = {
                    warning = 20,       -- Warn when containers below 20
                    critical = 5        -- Critical when below 5
                }
            }
        }
    },
    
    -- Advanced features
    advanced = {
        tracking = {
            enableGPS = true,           -- GPS tracking of containers in transit
            enableTemperatureLog = true, -- Log temperature throughout journey
            enableQualityCheckpoints = true, -- Quality checks at key points
            
            checkpoints = {
                "warehouse_loaded",
                "vehicle_loaded", 
                "in_transit",
                "arrived_destination",
                "delivered_to_restaurant"
            }
        },
        
        analytics = {
            enabled = true,
            trackingMetrics = {
                "average_delivery_time",
                "quality_retention_rate",
                "container_utilization",
                "cost_efficiency",
                "customer_satisfaction"
            },
            
            reports = {
                daily = true,
                weekly = true,
                monthly = true
            }
        },
        
        ai = {
            predictiveRestocking = {
                enabled = true,
                predictionWindow = 7,   -- Predict 7 days ahead
                confidenceThreshold = 0.8, -- 80% confidence required
                emergencyThreshold = 0.9   -- 90% confidence for emergency orders
            },
            
            containerOptimization = {
                enabled = true,
                learning = true,        -- Learn from past decisions
                adaptToSeasons = true,  -- Adapt to seasonal demand patterns
                
                optimizationGoals = {
                    costMinimization = 0.3,     -- 30% weight on cost
                    qualityMaximization = 0.4,  -- 40% weight on quality
                    speedOptimization = 0.3     -- 30% weight on speed
                }
            }
        }
    }
}

-- Export for other scripts
return Config.DynamicContainers