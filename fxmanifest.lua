fx_version 'cerulean'
game 'gta5'

author 'The OG KiLLz - All praise and credit to VirgilDev for the inspiration and original idea.!'
description 'OGz_SupplyChainMaster - The Ultimate Supply Chain/Business Script'
version '2.0.0'

lua54 'yes'

-- ===================================
-- SHARED SCRIPTS (Load First)
-- ===================================
shared_scripts {
    '@ox_lib/init.lua',
    -- '@lation_ui/init.lua',,
    
    -- Configuration Files (Order matters!)
    'shared/config/config_main.lua',           -- Main config FIRST
    'shared/config/config_locations.lua',      -- Locations config
    'shared/config/config_items.lua',          -- Items config
}

-- ===================================
-- CLIENT SCRIPTS
-- ===================================
client_scripts {
    -- Core Foundation (Load First)
    'client/core/cl_main.lua',
    
    -- Business Management Systems
    'client/business/cl_restaurant.lua',
    'client/business/cl_restaurant_alerts.lua',
    'client/business/cl_warehouse.lua',
    
    -- Market & Stock Systems
    'client/market/cl_stock.lua',
    'client/market/cl_stock_alerts.lua',
    'client/market/cl_stock_alerts_menu.lua',
    'client/market/cl_market.lua',
    'client/market/cl_seller.lua',
    
    -- Delivery Systems
    'client/delivery/cl_team_deliveries.lua',
    
    -- UI Systems
    'client/ui/cl_team_ui_features.lua',
    'client/ui/cl_leaderboard.lua',
    'client/ui/cl_team_leaderboard.lua',
    
    -- Rewards & Achievements
    'client/rewards/cl_rewards.lua',
    'client/rewards/cl_achievement_progress.lua',
    'client/rewards/cl_vehicle_achievements.lua',
    'client/rewards/cl_vehicle_achievement_handler.lua',
    
    -- Administration
    'client/admin/cl_admin.lua'
}

-- ===================================
-- SERVER SCRIPTS
-- ===================================
server_scripts {
    '@oxmysql/lib/MySQL.lua',           -- Database FIRST
    
    -- Core Foundation
    'server/core/sv_main.lua',
    'server/core/sv_vehicle_spawn_manager.lua',
    
    -- Business Logic
    'server/business/sv_restaurant.lua',
    'server/business/sv_warehouse.lua',
    'server/business/sv_farming.lua',
    
    -- Market Systems
    'server/market/sv_market_pricing.lua',
    'server/market/sv_stock_alerts.lua',
    'server/market/sv_emergency_orders.lua',
    
    -- Delivery Systems
    'server/delivery/sv_team.lua',
    'server/delivery/sv_team_deliveries.lua',
    'server/delivery/sv_team_vehicle_handler.lua',
    
    -- Analytics & Tracking
    'server/analytics/sv_performance_tracking.lua',
    'server/analytics/sv_leaderboard.lua',
    'server/analytics/sv_team_leaderboard.lua',
    
    -- Rewards & Achievements
    'server/rewards/sv_rewards.lua',
    'server/rewards/sv_achievements.lua',
    
    -- Communications
    'server/communications/sv_notifications.lua',
    'server/communications/sv_duty_emails.lua',
    
    -- Integrations
    'server/integrations/sv_lbphone_integration.lua',
    
    -- Administration (Load Last)
    'server/admin/sv_admin.lua'
}

-- ===================================
-- DEPENDENCIES
-- ===================================
dependencies {
    'ox_lib',
    'ox_target', 
    'ox_inventory',
    'oxmysql',
    'lation_ui'
}

-- ===================================
-- FOLDER STRUCTURE
-- ===================================
--[[
ogz_supplychainmaster/
├── fxmanifest.lua
├── README.md
├── LICENSE
│
├── shared/
│   └── config/
│       ├── config_main.lua
│       ├── config_locations.lua
│       └── config_items.lua
│
├── client/
│   ├── core/
│   │   └── cl_main.lua
│   ├── business/
│   │   ├── cl_restaurant.lua
│   │   ├── cl_restaurant_alerts.lua
│   │   └── cl_warehouse.lua
│   ├── market/
│   │   ├── cl_stock.lua
│   │   ├── cl_stock_alerts.lua
│   │   ├── cl_stock_alerts_menu.lua
│   │   ├── cl_market.lua
│   │   └── cl_seller.lua
│   ├── delivery/
│   │   ├── cl_team_deliveries.lua
│   │   └── cl_team_vehicle_handler.lua
│   ├── ui/
│   │   ├── cl_team_ui_features.lua
│   │   ├── cl_leaderboard.lua
│   │   └── cl_team_leaderboard.lua
│   ├── rewards/
│   │   ├── cl_rewards.lua
│   │   ├── cl_achievement_progress.lua
│   │   ├── cl_vehicle_achievements.lua
│   │   └── cl_vehicle_achievement_handler.lua
│   └── admin/
│       └── cl_admin.lua
│
├── server/
│   ├── core/
│   │   ├── sv_main.lua
│   │   └── sv_vehicle_spawn_manager.lua
│   ├── business/
│   │   ├── sv_restaurant.lua
│   │   ├── sv_warehouse.lua
│   │   └── sv_farming.lua
│   ├── market/
│   │   ├── sv_market_pricing.lua
│   │   ├── sv_stock_alerts.lua
│   │   └── sv_emergency_orders.lua
│   ├── delivery/
│   │   ├── sv_team.lua
│   │   ├── sv_team_deliveries.lua
│   │   └── sv_team_vehicle_handler.lua
│   ├── analytics/
│   │   ├── sv_performance_tracking.lua
│   │   ├── sv_leaderboard.lua
│   │   └── sv_team_leaderboard.lua
│   ├── rewards/
│   │   ├── sv_rewards.lua
│   │   └── sv_achievements.lua
│   ├── communications/
│   │   ├── sv_notifications.lua
│   │   └── sv_duty_emails.lua
│   ├── integrations/
│   │   └── sv_lbphone_integration.lua
│   └── admin/
│       └── sv_admin.lua
│
└── sql/
    └── database_schema.sql
--]]