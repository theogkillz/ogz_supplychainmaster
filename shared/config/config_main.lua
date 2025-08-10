Config = Config or {}

Config.Core = 'qbox' -- qbcore or qbox
Config.Inventory = 'ox' -- ox_inventory
Config.Target = 'ox' -- ox_target
Config.Progress = 'ox' -- ox_lib
Config.Notify = 'ox' -- ox_lib
Config.Menu = 'ox' -- ox_lib

Config.UI = {
    notificationPosition = 'top-right',
    enableMarkdown = true,
    theme = 'default'
}

-- Admin Configuration
Config.AdminSystem = {
    -- Admin permission levels
    permissions = {
        superadmin = 'god',      -- Full access
        admin = 'admin',         -- Most features
        moderator = 'mod'        -- Basic monitoring
    },
    
    -- Command configuration
    commands = {
        enabled = true,
        prefix = 'supply',       -- /supply [action]
        chatSuggestions = true
    }
}

-- ===================================
-- JOB RESTRICTIONS
-- ===================================
Config.Jobs = {
    -- Authorized warehouse jobs
    warehouse = {"hurst", "admin", "god"},  -- Hurst Industries + admin access
    
    -- Future expansion capability
    delivery = {"hurst", "admin", "god"},   -- Can add more jobs here later
    management = {"admin", "god"}           -- Admin/management only features
}

-- Notification Configuration
Config.Notifications = {
    discord = {
        enabled = false,
        webhookURL = "YOUR_DISCORD_WEBHOOK_URL_HERE", -- Replace with your webhook
        botName = "Supply Chain AI",
        botAvatar = "https://i.imgur.com/your_bot_avatar.png",
        
        -- Channel configuration
        channels = {
            market_events = "YOUR_MARKET_WEBHOOK_URL",
            emergency_orders = "YOUR_EMERGENCY_WEBHOOK_URL", 
            achievements = "YOUR_ACHIEVEMENTS_WEBHOOK_URL",
            system_alerts = "YOUR_SYSTEM_WEBHOOK_URL"
        }
    },
    
    phone = {
        enabled = true,
        resource = "lb-phone", -- Change to your phone resource
        
        -- Notification types
        types = {
            new_orders = true,
            emergency_alerts = true,
            market_changes = true,
            team_invites = true,
            achievement_unlocked = true,
            stock_alerts = true
        }
    }
}

Config.Leaderboard = {
    enabled = true,
    maxEntries = 10 -- Number of leaderboard entries to show
}

Config.LowStock = {
    enabled = true,
    threshold = 25 -- Notify when stock is below this
}

-- Config.maxBoxes = 6 -- Max boxes for team deliveries (2 players)
Config.DriverPayPrec = 0.22 -- Driver payment percentage

-- ===================================
-- DELIVERY PROPS CONFIGURATION
-- ===================================
Config.DeliveryProps = {
    boxProp = "xm3_prop_xm3_box_pharma_01a",              -- Individual box prop
    palletProp = "prop_boxpile_06b",          -- Stacked box pallet prop
    palletOffset = vector3(0, 0, 0),          -- Pallet positioning offset
    deliveryMarker = {
        type = 1,                             -- Marker type (cylinder)
        size = vector3(3.0, 3.0, 1.0),       -- Marker size
        color = {r = 0, g = 255, b = 0, a = 100}, -- Green with transparency
        bobUpAndDown = false,
        faceCamera = false,
        rotate = true
    }
}

-- Maintain backward compatibility
Config.CarryBoxProp = Config.DeliveryProps.boxProp

-- ===================================
-- VEHICLE CONFIGURATION
-- ===================================
Config.VehicleSelection = {
    -- Small deliveries (1-3 boxes)
    small = {
        maxBoxes = 3,
        models = {"speedo"},
        spawnChance = 1.0
    },
    
    -- Medium deliveries (4-7 boxes)  
    medium = {
        maxBoxes = 7,
        models = {"speedo", "mule"},
        spawnChance = 0.8
    },
    
    -- Large deliveries (8+ boxes)
    large = {
        maxBoxes = 15,
        models = {"mule", "pounder"},
        spawnChance = 1.0
    }
}

-- ===================================
-- CONTAINER SYSTEM CONFIGURATION
-- ===================================
Config.ContainerSystem = {
    itemsPerContainer = 12,        -- Items that fit in one container
    containersPerBox = 5,          -- Containers that fit in one delivery box
    maxBoxesPerDelivery = 10       -- Maximum boxes per delivery van
}

-- Calculated values (don't modify)
Config.ItemsPerBox = Config.ContainerSystem.itemsPerContainer * Config.ContainerSystem.containersPerBox -- 60 items per box

-- ===================================
-- DYNAMIC PRICING CONFIGURATION
-- ===================================
Config.DynamicPricing = {
    enabled = true,
    peakThreshold = 20,      -- Player count for peak pricing
    lowThreshold = 5,        -- Player count for low pricing
    minMultiplier = 0.8,     -- Minimum price multiplier
    maxMultiplier = 1.5      -- Maximum price multiplier
}

-- ===================================
-- BALANCED ECONOMY CONFIGURATION
-- ===================================

-- DELIVERY BASE PAY CALCULATION
Config.EconomyBalance = {
    -- Base pay per box (reasonable starting point)
    basePayPerBox = 75,          -- $75 per box
    minimumDeliveryPay = 200,    -- Minimum $200 per delivery
    maximumDeliveryPay = 2500,   -- Maximum $2500 per delivery (prevents exploits)
    
    -- Distance multipliers (if you want to add distance-based pay)
    distanceBonus = {
        enabled = false,         -- Disabled for now
        perKm = 5               -- $5 per km
    }
}

-- ===================================
-- BALANCED DRIVER REWARDS SYSTEM
-- ===================================
Config.DriverRewards = {
    -- CONSERVATIVE Speed Bonuses (was way too high)
    speedBonuses = {
        lightning = { maxTime = 300, multiplier = 1.4, name = "⚡ Lightning Fast", icon = "⚡" },    -- Was 2.5x!
        express = { maxTime = 600, multiplier = 1.25, name = "🚀 Express Delivery", icon = "🚀" },  -- Was 2.0x!
        fast = { maxTime = 900, multiplier = 1.15, name = "⏰ Fast Delivery", icon = "⏰" },        -- Was 1.5x!
        standard = { maxTime = 1800, multiplier = 1.0, name = "Standard", icon = "📦" }
    },
    
    -- SMALLER Volume Bonuses (flat amounts)
    volumeBonuses = {
        mega = { minBoxes = 15, bonus = 200, name = "🏗️ Mega Haul", icon = "🏗️" },     -- Was 5000!
        large = { minBoxes = 10, bonus = 125, name = "📦 Large Haul", icon = "📦" },    -- Was 2500!
        medium = { minBoxes = 5, bonus = 50, name = "📋 Medium Haul", icon = "📋" },    -- Was 1000!
        small = { minBoxes = 1, bonus = 0, name = "📦 Standard", icon = "📦" }
    },
    
    -- REASONABLE Streak Bonuses (was way too high)
    streakBonuses = {
        legendary = { streak = 20, multiplier = 1.6, name = "👑 Legendary Streak", icon = "👑" },  -- Was 3.0x!
        master = { streak = 15, multiplier = 1.45, name = "🔥 Master Streak", icon = "🔥" },       -- Was 2.5x!
        expert = { streak = 10, multiplier = 1.3, name = "⭐ Expert Streak", icon = "⭐" },        -- Was 2.0x!
        skilled = { streak = 5, multiplier = 1.15, name = "💎 Skilled Streak", icon = "💎" },     -- Was 1.5x!
        basic = { streak = 0, multiplier = 1.0, name = "Standard", icon = "📦" }
    },
    
    -- CONSERVATIVE Daily Multipliers
    dailyMultipliers = {
        { deliveries = 1, multiplier = 1.0, name = "Getting Started" },
        { deliveries = 3, multiplier = 1.05, name = "Warming Up" },        -- Was 1.1x
        { deliveries = 5, multiplier = 1.1, name = "In the Zone" },        -- Was 1.2x
        { deliveries = 8, multiplier = 1.15, name = "On Fire" },           -- Was 1.3x
        { deliveries = 12, multiplier = 1.2, name = "Unstoppable" },       -- Was 1.5x
        { deliveries = 20, multiplier = 1.3, name = "LEGENDARY" }          -- Was 2.0x!
    },
    
    -- Perfect Delivery Criteria
    perfectDelivery = {
        maxTime = 1200,           -- Under 20 minutes
        noVehicleDamage = true,   -- Van must be in good condition
        onTimeBonus = 100         -- Was 500! Now reasonable
    }
}

-- ===================================
-- ACHIEVEMENT REWARDS (BALANCED)
-- ===================================
Config.AchievementRewards = {
    first_delivery = { reward = 150, name = "First Steps" },       -- Was 500
    speed_demon = { reward = 300, name = "Speed Demon" },          -- Was 1000  
    big_hauler = { reward = 450, name = "Big Hauler" },            -- Was 1500
    perfect_week = { reward = 1250, name = "Perfect Week" },       -- Was 5000
    century_club = { reward = 2500, name = "Century Club" }        -- Was 10000
}

-- ===================================
-- STOCK ALERTS CONFIGURATION
-- ===================================
Config.StockAlerts = {
    -- Alert thresholds (percentage of maximum stock)
    thresholds = {
        critical = 5,    -- Red alerts - Urgent action needed
        low = 20,        -- Yellow alerts - Restock soon
        moderate = 50,   -- Blue alerts - Plan ahead
        healthy = 80     -- Green - Good stock levels
    },
    
    -- Maximum recommended stock levels per item
    maxStock = {
        default = 500,           -- Default max stock
        high_demand = 1000,      -- Popular items
        seasonal = 200,          -- Seasonal items
        specialty = 100          -- Rare/expensive items
    },
    
    -- Prediction settings
    prediction = {
        analysisWindow = 7,      -- Days to analyze for patterns
        forecastDays = 3,        -- Days to predict ahead
        minDataPoints = 5,       -- Minimum orders needed for prediction
        confidenceThreshold = 0.7 -- Minimum confidence for predictions
    },
    
    -- Notification settings
    notifications = {
        checkInterval = 300,     -- Check every 5 minutes
        alertCooldown = 1800,    -- Don't spam same alert for 30 minutes
        maxAlertsPerCheck = 5    -- Max alerts per check cycle
    }
}

-- Market Configuration
Config.MarketPricing = {
    -- Enable/disable dynamic pricing
    enabled = true,
    
    -- Base pricing factors
    factors = {
        stockLevel = {
            enabled = true,
            weight = 0.4,           -- 40% of price calculation
            criticalMultiplier = 2.5, -- 5% stock = 2.5x price
            lowMultiplier = 1.8,      -- 20% stock = 1.8x price
            moderateMultiplier = 1.3, -- 50% stock = 1.3x price
            healthyMultiplier = 1.0   -- 80%+ stock = normal price
        },
        
        demand = {
            enabled = true,
            weight = 0.3,           -- 30% of price calculation
            analysisWindow = 6,     -- Hours to analyze demand
            highDemandMultiplier = 1.5,
            normalDemandMultiplier = 1.0,
            lowDemandMultiplier = 0.9
        },
        
        playerActivity = {
            enabled = true,
            weight = 0.2,           -- 20% of price calculation
            peakThreshold = 25,     -- 25+ players = peak pricing
            moderateThreshold = 15, -- 15+ players = moderate pricing
            lowThreshold = 5,       -- 5+ players = low pricing
            peakMultiplier = 1.3,
            moderateMultiplier = 1.1,
            lowMultiplier = 0.9
        },
        
        timeOfDay = {
            enabled = true,
            weight = 0.1,           -- 10% of price calculation
            peakHours = {19, 20, 21, 22}, -- 7PM-10PM peak hours
            moderateHours = {16, 17, 18, 23}, -- 4PM-6PM, 11PM moderate
            peakMultiplier = 1.2,
            moderateMultiplier = 1.05,
            offPeakMultiplier = 0.95
        }
    },
    
    -- Price limits
    limits = {
        minMultiplier = 0.7,    -- Never go below 70% of base price
        maxMultiplier = 3.0,    -- Never go above 300% of base price
        maxChangePerUpdate = 0.1 -- Max 10% change per update cycle
    },
    
    -- Update intervals
    intervals = {
        priceUpdate = 300,      -- Update prices every 5 minutes
        marketSnapshot = 1800,  -- Save market snapshot every 30 minutes
        demandAnalysis = 3600   -- Analyze demand every hour
    },
    
    -- Special events (temporary price modifications)
    events = {
        shortage = {
            enabled = true,
            threshold = 3,      -- Items with <3% stock
            multiplier = 2.0,   -- 2x base multiplier
            duration = 3600     -- 1 hour duration
        },
        surplus = {
            enabled = true,
            threshold = 95,     -- Items with >95% stock
            multiplier = 0.8,   -- 20% discount
            duration = 1800     -- 30 minute duration
        }
    }
}

-- Emergency Order Configuration
Config.EmergencyOrders = {
    enabled = true,
    
    -- Trigger conditions
    triggers = {
        restaurantStockout = 0,     -- Restaurant completely out
        warehouseStockout = 0,      -- Warehouse completely out
        criticalStock = 5,          -- Under 5 units total
        highDemandShortage = 10     -- High demand + low stock
    },
    
    -- Emergency bonuses
    bonuses = {
        emergencyMultiplier = 0.5,  -- 2.5x base delivery pay
        urgentMultiplier = 0.2,     -- 2x for urgent
        criticalMultiplier = 0.7,   -- 3x for critical
        speedBonus = 75,          -- +$1000 for under 10 min delivery
        heroBonus = 120            -- +$2000 for preventing complete stockout
    },
    
    -- Priority levels
    priorities = {
        critical = {
            level = 3,
            name = "🚨 CRITICAL",
            color = "error",
            timeout = 1800,  -- 30 minutes
            broadcastToAll = true
        },
        urgent = {
            level = 2, 
            name = "⚠️ URGENT",
            color = "warning",
            timeout = 3600,  -- 1 hour
            broadcastToAll = false
        },
        emergency = {
            level = 1,
            name = "🔥 EMERGENCY",
            color = "info", 
            timeout = 7200,  -- 2 hours
            broadcastToAll = false
        }
    }
}

-- ===================================
-- TEAM DELIVERY SYSTEM
-- ===================================
Config.TeamDeliveries = {
    enabled = true,
    
    -- Minimum requirements
    minBoxesForTeam = 5,        -- Minimum boxes to create team delivery
    maxTeamSize = 6,            -- Maximum team members
    minTeamSize = 2,            -- Minimum to start delivery
    
    -- Delivery types (for different order sizes)
    deliveryTypes = {
        duo = {
            name = "🚐 Duo Delivery",
            description = "Quick 2-person team job",
            minBoxes = 5,
            maxBoxes = 10,
            requiredMembers = 2,
            maxMembers = 2
        },
        squad = {
            name = "🚚 Squad Delivery", 
            description = "Medium team operation",
            minBoxes = 11,
            maxBoxes = 20,
            requiredMembers = 3,
            maxMembers = 4
        },
        convoy = {
            name = "🚛 Convoy Delivery",
            description = "Large coordinated operation",
            minBoxes = 21,
            maxBoxes = 50,
            requiredMembers = 4,
            maxMembers = 6
        }
    },
    
    -- BALANCED Team bonuses (competitive but not overpowered)
    teamBonuses = {
        { size = 2, multiplier = 1.15, name = "👥 Duo Team" },      -- 15% bonus
        { size = 3, multiplier = 1.20, name = "🚚 Squad Team" },    -- 20% bonus
        { size = 4, multiplier = 1.25, name = "🚛 Small Convoy" },  -- 25% bonus
        { size = 5, multiplier = 1.30, name = "🚛 Full Convoy" },   -- 30% bonus
        { size = 6, multiplier = 1.35, name = "🚛 Mega Convoy" }    -- 35% bonus
    },
    
    -- Coordination bonuses (skill-based, not just time)
    coordinationBonuses = {
        {
            name = "⚡ Perfect Sync",
            maxTimeDiff = 15,        -- All arrive within 15 seconds
            bonus = 100,             -- $100 flat bonus per member
            requirements = {
                noDamage = true,     -- No vehicle damage
                allMembers = true    -- All members must complete
            }
        },
        {
            name = "🎯 Great Coordination",
            maxTimeDiff = 30,
            bonus = 50              -- $50 per member
        },
        {
            name = "✅ Good Teamwork",
            maxTimeDiff = 60,
            bonus = 25              -- $25 per member
        },
        {
            name = "Basic Completion",
            maxTimeDiff = 120,
            bonus = 0               -- No bonus after 2 minutes
        }
    },
    
    -- Team roles (optional feature for future)
    roles = {
        leader = {
            name = "Team Leader",
            perks = {
                routePlanning = true,    -- Can set waypoints for team
                bonusMultiplier = 1.1    -- 10% extra for leadership
            }
        },
        driver = {
            name = "Driver",
            perks = {
                vehicleBonus = true,     -- Slightly better vehicle handling
                bonusMultiplier = 1.0
            }
        }
    },
    
    -- Competitive features
    competitive = {
        enableLeaderboard = true,
        weeklyReset = true,
        
        -- Team achievements
        achievements = {
            first_team_delivery = { reward = 250, name = "Teamwork Makes the Dream Work" },
            perfect_convoy = { reward = 500, name = "Perfect Convoy" },
            speed_team = { reward = 750, name = "Speed Team Champions" },
            weekly_team_best = { reward = 1000, name = "Team of the Week" }
        },
        
        -- Team challenges
        challenges = {
            daily = {
                { boxes = 25, reward = 200, name = "Daily Team Goal" },
                { boxes = 50, reward = 500, name = "Daily Team Champion" }
            },
            weekly = {
                { boxes = 200, reward = 2000, name = "Weekly Team Goal" },
                { boxes = 500, reward = 5000, name = "Weekly Team Legend" }
            }
        }
    },
    
    -- Anti-exploit measures
    antiExploit = {
        maxDeliveriesPerHour = 10,      -- Per team member
        cooldownBetweenTeamJobs = 300,  -- 5 minutes
        requireUniqueMembers = true,     -- Can't use alt accounts
        minDistanceForBonus = 500        -- Minimum distance for coordination bonus
    }
}

-- ===================================
-- HYBRID VEHICLE SPAWNING SYSTEM
-- ===================================
Config.HybridSpawnSystem = {
    enabled = true,  -- Use smart hybrid spawning instead of convoy
    
    -- Vehicle distribution rules
    distribution = {
        duo = {
            teamSize = 2,
            vehicles = 1,
            arrangement = "shared",
            description = "One vehicle, both players ride together"
        },
        squad = {
            minTeamSize = 3,
            maxTeamSize = 4,
            maxVehicles = 2,
            arrangement = "paired",
            description = "Two vehicles maximum, split team"
        },
        large = {
            minTeamSize = 5,
            maxTeamSize = 8,
            maxVehicles = 3,
            arrangement = "distributed",
            description = "Three vehicles maximum, distributed load"
        }
    },
    
    -- Spawn configuration
    spawning = {
        useConvoyPoints = true,  -- Reuse existing convoy points smartly
        maxActiveSpawns = 3,     -- Never more than 3 vehicles per team
        spawnDelay = 2000,       -- 2 second delay between spawns
        clearAfter = 30000,      -- Clear spawn marker after 30 seconds
        
        -- Simple offset pattern if convoy points not available
        fallbackOffsets = {
            {x = 0, y = 0},      -- First vehicle at base
            {x = 5, y = 0},      -- Second vehicle to the right
            {x = -5, y = 0},     -- Third vehicle to the left
        }
    },
    
    -- Vehicle selection by load
    vehicleSelection = {
        {maxBoxes = 10, model = "speedo"},
        {maxBoxes = 20, model = "mule"},
        {maxBoxes = 25, model = "mule3"},
        {maxBoxes = 999, model = "pounder"}
    },
    
    -- Visual distinction
    teamColors = {
        leader = {r = 0, g = 255, b = 0},      -- Green for leader
        member = {r = 0, g = 150, b = 255},     -- Blue for members
        shared = {r = 255, g = 165, b = 0}      -- Orange for shared vehicles
    },
    
    -- Key sharing for shared vehicles
    keySharing = {
        enabled = true,
        duoAutoShare = true,     -- Automatically share keys in duo mode
        squadAutoShare = true,  -- Manual key sharing for squads
        platePrefix = "TEAM"     -- Predictable plates for key sharing
    }
}

Config.ImportSystem = {
    enabled = true,
    
    -- Import warehouse configuration
    warehouseId = 2, -- Warehouse 2 becomes import center
    
    -- Import pricing
    importMarkup = 0.25, -- 25% markup on import items
    
    -- Delivery settings
    importDeliveryBonus = 0.15, -- 15% bonus for import deliveries
    
    -- Email notifications
    notifications = {
        arrivalAlerts = true,
        delayAlerts = true,
        shortageAlerts = true
    },
    
    -- Order splitting
    autoSplitOrders = true, -- Automatically split mixed orders
    
    -- Stock management
    separateStockTracking = true,
    importStockPrefix = "import_" -- Prefix for import stock items
}

Config.AchievementVehicles = {
    enabled = true,
    
    -- Achievement tiers and their vehicle benefits
    performanceTiers = {
        ["rookie"] = {
            name = "Rookie Driver",
            requirement = "Complete 10 deliveries",
            colorTint = {r = 200, g = 200, b = 200}, -- Silver
            performanceMods = {
                [11] = 0, -- Engine - Stock
                [12] = 0, -- Brakes - Stock  
                [13] = 0, -- Transmission - Stock
                [15] = 0, -- Suspension - Stock
                [18] = 0  -- Turbo - Off
            },
            speedMultiplier = 1.0,
            accelerationBonus = 0.0,
            fuelEfficiency = 1.0,
            description = "Standard delivery vehicle performance"
        },
        
        ["experienced"] = {
            name = "Experienced Driver", 
            requirement = "Complete 50 deliveries with 80%+ rating",
            colorTint = {r = 50, g = 150, b = 255}, -- Blue
            performanceMods = {
                [11] = 1, -- Engine - Level 1
                [12] = 1, -- Brakes - Level 1
                [13] = 1, -- Transmission - Level 1
                [15] = 0, -- Suspension - Stock
                [18] = 0  -- Turbo - Off
            },
            speedMultiplier = 1.05,
            accelerationBonus = 0.10,
            fuelEfficiency = 1.05,
            description = "Enhanced engine and braking performance"
        },
        
        ["professional"] = {
            name = "Professional Driver",
            requirement = "Complete 150 deliveries with 85%+ rating",
            colorTint = {r = 128, g = 0, b = 128}, -- Purple
            performanceMods = {
                [11] = 2, -- Engine - Level 2
                [12] = 2, -- Brakes - Level 2
                [13] = 2, -- Transmission - Level 2
                [15] = 1, -- Suspension - Level 1
                [18] = 0  -- Turbo - Off
            },
            speedMultiplier = 1.10,
            accelerationBonus = 0.15,
            fuelEfficiency = 1.10,
            description = "Professional-grade performance upgrades"
        },
        
        ["elite"] = {
            name = "Elite Driver",
            requirement = "Complete 300 deliveries with 90%+ rating",
            colorTint = {r = 255, g = 215, b = 0}, -- Gold
            performanceMods = {
                [11] = 3, -- Engine - Level 3
                [12] = 2, -- Brakes - Level 2
                [13] = 2, -- Transmission - Level 2
                [15] = 2, -- Suspension - Level 2
                [18] = 1  -- Turbo - Level 1
            },
            speedMultiplier = 1.15,
            accelerationBonus = 0.20,
            fuelEfficiency = 1.15,
            description = "Elite performance with turbo boost"
        },
        
        ["legendary"] = {
            name = "Legendary Driver",
            requirement = "Complete 500 deliveries with 95%+ rating + Team achievements",
            colorTint = {r = 255, g = 0, b = 0}, -- Red
            performanceMods = {
                [11] = 4, -- Engine - Max
                [12] = 3, -- Brakes - Level 3
                [13] = 3, -- Transmission - Level 3
                [15] = 3, -- Suspension - Level 3
                [18] = 1  -- Turbo - Level 1
            },
            speedMultiplier = 1.25,
            accelerationBonus = 0.30,
            fuelEfficiency = 1.25,
            specialEffects = {
                underglow = true,
                customLivery = true,
                hornUpgrade = true
            },
            description = "Maximum performance legendary vehicle"
        }
    },
    
    -- Visual effects for different tiers
    visualEffects = {
        underglow = {
            enabled = true,
            colors = {
                ["elite"] = {r = 255, g = 215, b = 0},      -- Gold
                ["legendary"] = {r = 255, g = 0, b = 0}     -- Red
            }
        },
        
        liveries = {
            ["professional"] = 1, -- Delivery company livery
            ["elite"] = 2,        -- Premium livery
            ["legendary"] = 3     -- Exclusive livery
        },
        
        hornSounds = {
            ["elite"] = "HORN_TRUCK_01",
            ["legendary"] = "HORN_TRUCK_02"
        }
    }
}

-- -- ============================================
-- -- MARKET-DYNAMIC NPC DELIVERY SYSTEM
-- -- NPCs only available during surplus conditions
-- -- ============================================

-- Config.NPCDeliverySystem = {
--     enabled = true,
    
--     -- Surplus thresholds that enable NPC jobs
--     surplusThresholds = {
--         moderate_surplus = {
--             stockPercentage = 80,           -- 80% of max warehouse stock
--             npcPayMultiplier = 0.7,         -- NPCs get 70% of player pay
--             maxConcurrentJobs = 1,          -- Only 1 NPC job at a time
--             cooldownMinutes = 30,           -- 30 min cooldown between NPC jobs
--             playerRequirement = "initiate", -- Player must start the job
--             description = "Moderate surplus - basic NPC assistance available"
--         },
        
--         high_surplus = {
--             stockPercentage = 90,           -- 90% of max warehouse stock  
--             npcPayMultiplier = 0.8,         -- NPCs get 80% of player pay
--             maxConcurrentJobs = 2,          -- Up to 2 concurrent NPC jobs
--             cooldownMinutes = 20,           -- 20 min cooldown
--             playerRequirement = "initiate", -- Still requires player initiation
--             description = "High surplus - enhanced NPC assistance available"
--         },
        
--         critical_surplus = {
--             stockPercentage = 95,           -- 95% of max warehouse stock
--             npcPayMultiplier = 0.9,         -- NPCs get 90% of player pay
--             maxConcurrentJobs = 3,          -- Up to 3 concurrent NPC jobs
--             cooldownMinutes = 15,           -- 15 min cooldown
--             playerRequirement = "initiate", -- Player must still initiate
--             emergencyMode = true,           -- Special emergency mode
--             description = "Critical surplus - maximum NPC assistance to clear backlog"
--         }
--     },
    
--     -- NPC behavior settings
--     npcBehavior = {
--         guaranteedCompletion = true,        -- NPCs always complete jobs (no skill factor)
--         randomFailureChance = 0.05,         -- 5% chance of "breakdown" or delay
--         baseCompletionTime = 300,           -- 5 minutes base completion time
--         timeVariation = 120,                -- ±2 minutes random variation
--         noTimeBonus = true,                 -- NPCs don't get speed bonuses
--         noQualityBonus = true,              -- NPCs don't get quality bonuses
--         basicPayOnly = true,                -- NPCs only get basic delivery pay
--     },
    
--     -- Integration with market dynamics
--     marketIntegration = {
--         reducesPrices = true,               -- NPC deliveries slightly reduce market prices
--         priceReductionFactor = 0.02,        -- 2% price reduction per NPC delivery
--         preventsMarketCrash = true,         -- Helps prevent market crashes from oversupply
--         balancingEffect = true,             -- Helps balance supply/demand automatically
--     },
    
--     -- Player interaction requirements
--     playerRequirements = {
--         mustBeOnDuty = true,                -- Player must be on warehouse duty
--         mustInitiateJob = true,             -- Player must manually start NPC jobs
--         cannotBePassive = true,             -- No passive income generation
--         limitPerPlayer = 2,                 -- Max 2 NPC jobs per player per cooldown period
--         requiresWarehouseAccess = true,     -- Must have warehouse job access
--     }
-- }

Config.SystemIntegration = {
    achievements = {
        enabled = true,
        vehicleModsEnabled = true,
        trackDeliveryRating = true,
        trackTeamDeliveries = true,
        updateInterval = 60 -- seconds
    },
    
    npcSystem = {
        enabled = false,
        requireSurplus = true,
        allowPassiveIncome = false,
        maxConcurrentPerPlayer = 2,
        integrationWithMarket = true
    }
}