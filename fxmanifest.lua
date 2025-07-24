fx_version 'cerulean'
game 'gta5'

author 'The OG KiLLz - All praise and credit to VirgilDev for the inspiration and original idea.!'
description 'OGz_SupplyChainMaster - The Ultimate Supply Chain/Business Script'
version '2.0.0'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    '@lation_ui/init.lua',
    'shared/config_main.lua',
    'shared/config_locations.lua',
    'shared/config_items.lua',
}

client_scripts {
    -- Core Foundation
    'client/cl_main.lua',
    
    -- Business Management
    'client/cl_restaurant.lua',
    'client/cl_restaurant_alerts.lua',
    'client/cl_warehouse.lua',
    
    -- Stock & Market Systems
    'client/cl_stock.lua',
    'client/cl_stock_alerts.lua',
    'client/cl_stock_alerts_menu.lua',
    'client/cl_market.lua',
    'client/cl_seller.lua',
    
    -- Team & Delivery Systems
    'client/cl_team_deliveries.lua',
    
    -- Analytics & Rewards
    'client/cl_leaderboard.lua',
    'client/cl_rewards.lua',
    'client/cl_vehicle_achievements.lua',
    'client/cl_vehicle_achievement_handler.lua',
    'client/cl_achievement_progress.lua',
    -- 'client/cl_npc_surplus.lua',
    
    -- Administration
    'client/cl_admin.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    
    -- Core Foundation
    'server/sv_main.lua',
    
    -- Market & Pricing Systems
    'server/sv_market_pricing.lua',
    
    -- Core Business Logic
    'server/sv_restaurant.lua',
    'server/sv_warehouse.lua',
    'server/sv_farming.lua',
    
    -- Analytics & Tracking
    'server/sv_stock_alerts.lua',
    'server/sv_performance_tracking.lua',
    'server/sv_leaderboard.lua',
    'server/sv_achievements.lua',
    -- 'server/sv_npc_surplus.lua',

    
    -- Reward Systems
    'server/sv_rewards.lua',
    
    -- Team & Emergency Systems
    'server/sv_team.lua',
    'server/sv_team_deliveries.lua',
    'server/sv_emergency_orders.lua',
    
    -- Communication Systems
    'server/sv_notifications.lua',
    'server/integrations/sv_lbphone_integration.lua',
    'server/sv_duty_emails.lua',
    
    -- Administration
    'server/sv_admin.lua'
}

dependencies {
    'ox_lib',
    'ox_target',
    'ox_inventory',
    'oxmysql',
    'lation_ui'
}