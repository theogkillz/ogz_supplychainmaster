# 📚 OGz SupplyChain Master - Complete Installation Guide

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Download & Extract](#download--extract)
3. [Database Installation](#database-installation)
4. [Basic Configuration](#basic-configuration)
5. [Job Configuration](#job-configuration)
6. [Restaurant Setup](#restaurant-setup)
7. [Permissions Setup](#permissions-setup)
8. [Resource Start Order](#resource-start-order)
9. [Initial Testing](#initial-testing)
10. [Advanced Configuration](#advanced-configuration)
11. [Troubleshooting](#troubleshooting)
12. [Performance Optimization](#performance-optimization)

---

## 🔧 Prerequisites

### Required Dependencies

| Resource | Version | Download Link |
|----------|---------|---------------|
| **ox_lib** | Latest | [Download](https://github.com/overextended/ox_lib/releases/latest) |
| **ox_target** | Latest | [Download](https://github.com/overextended/ox_target/releases/latest) |
| **ox_inventory** | Latest | [Download](https://github.com/overextended/ox_inventory/releases/latest) |
| **oxmysql** | Latest | [Download](https://github.com/overextended/oxmysql/releases/latest) |
| **lation_ui** | Latest | Contact Vendor |

### Framework Requirements
- **QBCore** (Latest) OR **QBox** (Latest)
- **MySQL/MariaDB** Database
- **FiveM Server** Build 2802 or higher

### Optional Dependencies
- **lb-phone** - For email notifications (or any phone with email support)
- **qb-vehiclekeys** - For vehicle key management

---

## 📥 Download & Extract

### Step 1: Download Resource
```bash
# Clone from GitHub (recommended)
cd resources
git clone https://github.com/theogkillz/ogz_supplychainmaster

# OR download ZIP and extract
```

### Step 2: Verify File Structure
Ensure your folder structure matches:
```
resources/
└── ogz_supplychainmaster/
    ├── fxmanifest.lua
    ├── shared/
    ├── client/
    ├── server/
    └── sql/
```

---

## 💾 Database Installation

### Step 1: Import Core Tables
```sql
-- Run this in your database
-- File: sql/supplychain.sql
```

1. Open your database management tool (phpMyAdmin, HeidiSQL, etc.)
2. Select your FiveM database
3. Import `sql/supplychain.sql`
4. Verify all tables created successfully

### Step 2: Import Admin Tables
```sql
-- Additional admin tables
-- Run from artifacts: admin_sql_tables.sql
```

### Step 3: Verify Installation
Check that these tables exist:
- `supply_orders`
- `supply_warehouse_stock`
- `supply_restaurants`
- `supply_stock`
- `supply_player_stats`
- `supply_achievements`
- `supply_market_prices`
- `supply_admin_logs`
- And 20+ more...

```

---

## ⚙️ Basic Configuration

### Step 1: Open Configuration File
Navigate to `shared/config/config_main.lua`

### Step 2: Framework Selection
```lua
Config.Core = 'qbox' -- Options: 'qbcore' or 'qbox'
```

### Step 3: UI Settings
```lua
Config.UI = {
    notificationPosition = 'center-right',
    enableMarkdown = true,
    theme = 'default'
}
```

### Step 4: Job Configuration
```lua
Config.Jobs = {
    -- Add your warehouse job(s)
    warehouse = {"hurst", "admin", "god"},
    delivery = {"hurst", "admin", "god"},
    management = {"admin", "god"}
}
```

### Step 5: Notification Settings
```lua
Config.Notifications = {
    discord = {
        enabled = false, -- Set to true if using Discord webhooks
        webhookURL = "YOUR_WEBHOOK_HERE"
    },
    phone = {
        enabled = true,
        resource = "lb-phone" -- Change to your phone resource
    }
}
```

---

## 💼 Job Configuration

### Step 1: Add Warehouse Job to QBCore/Qbox
In your `qb-core/shared/jobs.lua`:

```lua
hurst = {
    label = 'Hurst Industries',
    type = "company",
    defaultDuty = true,
    offDutyPay = false,
    grades = {
        ['0'] = { name = 'Trainee', payment = 50 },
        ['1'] = { name = 'Driver', payment = 75 },
        ['2'] = { name = 'Senior Driver', payment = 100 },
        ['3'] = { name = 'Supervisor', payment = 125 },
        ['4'] = { name = 'Manager', isboss = true, payment = 150 },
    },
},
```
In your `qbx_core/shared/jobs.lua`:
```lua
['hurst'] = {
        label = 'Hurst Industries',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            [0] = { name = 'Employee', payment = 100 },
            [1] = { name = 'Sales Executive', payment = 150 },
            [2] = { name = 'Vice President', payment = 175 },
            [3] = { name = 'President', isboss = true, bankAuth = true, payment = 200 },
            [4] = { name = 'CEO', isboss = true, bankAuth = true, payment = 225 },
        },
    },
```

### Step 2: Add Restaurant Jobs
For each restaurant location:

For QBCore:
```lua
burgershot = {
    label = 'Burger Shot',
    type = "company",
    defaultDuty = true,
    offDutyPay = false,
    grades = {
        ['0'] = { name = 'Trainee', payment = 30 },
        ['1'] = { name = 'Employee', payment = 40 },
        ['2'] = { name = 'Burger Flipper', payment = 50 },
        ['3'] = { name = 'Shift Manager', payment = 60 },
        ['4'] = { name = 'Owner', isboss = true, payment = 80 },
    },
},
```
For QBox:
```lua
['burgershot'] = {
        label = 'Vespucci Burgershot',
        defaultDuty = false,
        offDutyPay = false,
        grades = {
            [0] = { name = 'Trainee', payment = 100 },
            [1] = { name = 'Employee', payment = 150 },
            [2] = { name = 'Assistant Manager', payment = 175 },
            [3] = { name = 'Manager', isboss = true, payment = 200 },
            [4] = { name = 'Boss', isboss = true, bankAuth = true, payment = 225 },
        },
    },
```
---

## 🏪 Restaurant Setup

### Step 1: Configure Locations
Edit `shared/config/config_locations.lua`:

```lua
Config.Restaurants = {
    [1] = {
        name = "Burgershot",
        job = "burgershot", -- Must match job name
        position = vector3(-1178.09, -896.11, 14.11),
        heading = 118.0,
        delivery = vector3(-1173.53, -892.72, 13.86),
        deliveryBox = vector3(-1177.39, -890.98, 12.79),
    },
    -- Add more restaurants here
}
```

### Step 2: Configure Items
Edit `shared/config/config_items.lua`:

```lua
Config.Items = {
    ["burgershot"] = {
        ["Meats"] = {
            ["meat"] = { label = "Beef Patty", price = 15 },
            ["chicken"] = { label = "Chicken Breast", price = 12 },
        },
        ["Vegetables"] = {
            ["lettuce"] = { label = "Lettuce", price = 5 },
            ["tomato"] = { label = "Tomato", price = 6 },
        },
        -- Add categories and items
    }
}
```

### Step 3: Register Restaurant Stashes
The script automatically creates stashes for each restaurant on resource start.

---

## 🔐 Permissions Setup

### Admin Permissions
In your server.cfg or permissions system:

```cfg
# God/Superadmin - Full access
add_ace group.god command.supply allow

# Admin - Most features
add_ace group.admin command.supply allow

# Moderator - View only
add_ace identifier.steam:xxxxx group.moderator
```

### Testing Permissions
```
/supply - Opens admin menu (requires moderator+)
```

---

## 🚀 Resource Start Order

### In your server.cfg:
```cfg
# Dependencies first
ensure oxmysql
ensure ox_lib
ensure ox_target
ensure ox_inventory
ensure lation_ui -- optional

# Core resources
ensure qb-core # or qbx_core
ensure qb-vehiclekeys/qbx_vehiclekeys

# Supply Chain Master
ensure ogz_supplychainmaster
```

⚠️ **IMPORTANT**: Start order matters! Dependencies must load first.

---

## 🧪 Initial Testing

### Step 1: Server Console Check
Look for:
```
[SCRIPT] OGz SupplyChain Master started successfully
[DEBUG] Registered stash: restaurant_stock_1
[DEBUG] Reset X accepted orders to pending
```

### Step 2: In-Game Testing Checklist

#### As Warehouse Employee:
- [ ] Go to warehouse location
- [ ] Can you see the warehouse ped?
- [ ] Can you access the warehouse menu?
- [ ] View pending orders
- [ ] Accept a test order
- [ ] Vehicle spawns correctly?
- [ ] Can load boxes from pallet?
- [ ] Can deliver to restaurant?

#### As Restaurant Boss:
- [ ] Go to restaurant computer
- [ ] Can access ordering menu?
- [ ] Can create orders?
- [ ] Can view stock?
- [ ] Orders appear at warehouse?

#### As Admin:
- [ ] Press F10 or use `/supply`
- [ ] Admin menu opens?
- [ ] Can view all stock levels?
- [ ] Can adjust prices?
- [ ] Can monitor deliveries?

### Step 3: Team Delivery Test
1. Create team with 2+ players
2. Accept large order (5+ boxes)
3. Test vehicle sharing (duo)
4. Test coordination bonuses

---

## 🎛️ Advanced Configuration

### Economy Balancing
```lua
Config.EconomyBalance = {
    basePayPerBox = 75,          -- Adjust base pay
    minimumDeliveryPay = 200,    -- Minimum per delivery
    maximumDeliveryPay = 2500,   -- Maximum cap
}
```

### Team System Tuning
```lua
Config.TeamDeliveries = {
    minBoxesForTeam = 5,         -- When teams unlock
    coordinationBonuses = {
        { maxTimeDiff = 15, bonus = 100 }, -- Perfect sync
        { maxTimeDiff = 30, bonus = 50 },  -- Good sync
    }
}
```

### Market Dynamics
```lua
Config.MarketPricing = {
    factors = {
        stockLevel = { weight = 0.4 },      -- 40% influence
        demand = { weight = 0.3 },          -- 30% influence
        playerActivity = { weight = 0.2 },  -- 20% influence
        timeOfDay = { weight = 0.1 },       -- 10% influence
    }
}
```

### Achievement Vehicles
```lua
Config.AchievementVehicles = {
    enabled = true,
    performanceTiers = {
        ["legendary"] = {
            speedMultiplier = 1.25,
            specialEffects = {
                underglow = true,
            }
        }
    }
}
```

---

## 🔧 Troubleshooting

### Common Issues & Solutions

#### "Resource not starting"
- Check all dependencies are installed
- Verify fxmanifest.lua is not corrupted
- Check server console for specific errors

#### "Database errors"
- Ensure all SQL files imported
- Check table names match exactly
- Verify database connection in oxmysql

#### "Can't see warehouse/restaurant"
- Verify coordinates in config_locations.lua
- Check job names match exactly
- Ensure player has correct job

#### "Vehicles not spawning"
- Check spawn areas are clear
- Verify vehicle models exist
- Check spawn coordinates

#### "Admin menu not opening"
- Verify permissions are set correctly
- Check keybind isn't conflicting (F10)
- Try command `/supply` instead

#### "Team deliveries not working"
- Minimum 5 boxes required
- Need 2+ players with warehouse job
- Check team delivery enabled in config

### Debug Mode
Enable debug prints:
```lua
-- Add to top of sv_main.lua
local DEBUG = true
```

---

## ⚡ Performance Optimization

### Database Indexes
```sql
-- Add these for better performance
CREATE INDEX idx_orders_status ON supply_orders(status);
CREATE INDEX idx_orders_created ON supply_orders(created_at);
CREATE INDEX idx_stats_citizenid ON supply_player_stats(citizenid);
```

### Config Optimizations
```lua
-- Reduce check intervals if needed
Config.StockAlerts.notifications.checkInterval = 600  -- 10 minutes
Config.MarketPricing.intervals.priceUpdate = 600     -- 10 minutes
```

### Resource Monitor
Monitor resource usage:
```
resmon 1
```
Target: < 2.0ms during normal operation

---

## 📞 Support

### Before Asking for Help:
1. Check all configurations
2. Verify dependencies installed
3. Read console errors carefully
4. Test with default config first
5. Check this guide again!

### Getting Help:
- Include your server console log
- Specify exact error messages
- List all modifications made
- Provide config files if modified

---

## 🎉 Final Steps

### Congratulations! 
Your supply chain system should now be operational!

### Next Steps:
1. Configure prices for your economy
2. Add more restaurants as needed
3. Adjust team bonuses to preference
4. Set up Discord webhooks
5. Train your staff on the system
6. Watch your economy THRIVE!

---

<div align="center">

### **"Excellence in installation leads to excellence in operation!"** 🚀

**Welcome to the Supply Chain Revolution!**

</div>