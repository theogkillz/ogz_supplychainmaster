-- Creating the supply_orders table
CREATE TABLE IF NOT EXISTS `supply_orders` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `owner_id` INT(11) DEFAULT NULL,
  `ingredient` VARCHAR(255) DEFAULT NULL,
  `quantity` INT(11) DEFAULT NULL,
  `status` ENUM('pending','accepted','completed','denied') DEFAULT 'pending',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP(),
  `restaurant_id` INT(11) NOT NULL,
  `total_cost` DECIMAL(10,2) DEFAULT NULL,
  `order_group_id` VARCHAR(36) DEFAULT NULL,
  PRIMARY KEY (`id`),
  INDEX `idx_order_group_id` (`order_group_id`),
  INDEX `idx_status` (`status`),
  INDEX `idx_restaurant_id` (`restaurant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Creating the supply_stock table
CREATE TABLE IF NOT EXISTS `supply_stock` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `restaurant_id` INT(11) DEFAULT NULL,
  `ingredient` VARCHAR(255) DEFAULT NULL,
  `quantity` INT(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_restaurant_ingredient` (`restaurant_id`, `ingredient`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Creating the supply_warehouse_stock table
CREATE TABLE IF NOT EXISTS `supply_warehouse_stock` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `ingredient` VARCHAR(255) DEFAULT NULL,
  `quantity` INT(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_ingredient` (`ingredient`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Creating the supply_leaderboard table (MISSING IN GROK VERSION)
CREATE TABLE IF NOT EXISTS `supply_leaderboard` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `deliveries` INT(11) DEFAULT 0,
  `earnings` DECIMAL(10,2) DEFAULT 0.00,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Enhanced driver statistics table
CREATE TABLE IF NOT EXISTS `supply_driver_stats` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL,
  `name` varchar(100) NOT NULL,
  `delivery_date` date NOT NULL,
  `completed_deliveries` int(11) DEFAULT 0,
  `total_deliveries` int(11) DEFAULT 0,
  `total_boxes_delivered` int(11) DEFAULT 0,
  `total_delivery_time` int(11) DEFAULT 0,
  `total_earnings` decimal(10,2) DEFAULT 0.00,
  `perfect_deliveries` int(11) DEFAULT 0,
  `performance_rating` int(11) DEFAULT 0,
  `consecutive_days` int(11) DEFAULT 0,
  `last_delivery` int(11) DEFAULT 0,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_driver_date` (`citizenid`, `delivery_date`),
  KEY `idx_citizenid` (`citizenid`),
  KEY `idx_delivery_date` (`delivery_date`),
  KEY `idx_performance_rating` (`performance_rating`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

- Achievements table
CREATE TABLE IF NOT EXISTS `supply_achievements` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `citizenid` varchar(50) NOT NULL,
    `achievement_id` varchar(50) NOT NULL,
    `earned_date` int(11) NOT NULL,
    `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `unique_achievement` (`citizenid`, `achievement_id`),
    KEY `idx_citizenid` (`citizenid`),
    KEY `idx_achievement_id` (`achievement_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Delivery Logs Table (for detailed analytics)
CREATE TABLE IF NOT EXISTS `supply_delivery_logs` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `citizenid` varchar(50) NOT NULL,
    `order_group_id` varchar(100) NOT NULL,
    `restaurant_id` int(11) NOT NULL,
    `boxes_delivered` int(11) NOT NULL,
    `delivery_time` int(11) NOT NULL,
    `base_pay` decimal(10,2) NOT NULL,
    `bonus_pay` decimal(10,2) DEFAULT 0.00,
    `total_pay` decimal(10,2) NOT NULL,
    `is_perfect_delivery` tinyint(1) DEFAULT 0,
    `is_team_delivery` tinyint(1) DEFAULT 0,
    `team_id` varchar(100) DEFAULT NULL,
    `speed_multiplier` decimal(4,2) DEFAULT 1.00,
    `streak_multiplier` decimal(4,2) DEFAULT 1.00,
    `daily_multiplier` decimal(4,2) DEFAULT 1.00,
    `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_citizenid` (`citizenid`),
    KEY `idx_restaurant_id` (`restaurant_id`),
    KEY `idx_created_at` (`created_at`),
    KEY `idx_is_perfect` (`is_perfect_delivery`),
    KEY `idx_team_delivery` (`is_team_delivery`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Driver streak tracking
CREATE TABLE IF NOT EXISTS `supply_driver_streaks` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL,
  `perfect_streak` int(11) DEFAULT 0,
  `best_streak` int(11) DEFAULT 0,
  `last_delivery` int(11) DEFAULT 0,
  `streak_broken_count` int(11) DEFAULT 0,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_citizenid` (`citizenid`),
  KEY `idx_perfect_streak` (`perfect_streak`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Reward logs table
CREATE TABLE IF NOT EXISTS `supply_reward_logs` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `citizenid` varchar(50) NOT NULL,
    `order_group_id` varchar(50) NOT NULL,
    `base_pay` decimal(10,2) NOT NULL,
    `bonus_amount` decimal(10,2) DEFAULT 0.00,
    `final_payout` decimal(10,2) NOT NULL,
    `speed_multiplier` decimal(4,2) DEFAULT 1.00,
    `streak_multiplier` decimal(4,2) DEFAULT 1.00,
    `daily_multiplier` decimal(4,2) DEFAULT 1.00,
    `perfect_delivery` tinyint(1) DEFAULT 0,
    `delivery_time` int(11) NOT NULL,
    `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_citizenid` (`citizenid`),
    KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Daily bonus tracking
CREATE TABLE IF NOT EXISTS `supply_daily_bonuses` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL,
  `bonus_date` date NOT NULL,
  `deliveries_completed` int(11) DEFAULT 0,
  `current_multiplier` decimal(4,2) DEFAULT 1.00,
  `total_bonus_earned` decimal(10,2) DEFAULT 0.00,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_driver_date` (`citizenid`, `bonus_date`),
  KEY `idx_bonus_date` (`bonus_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Team deliveries tracking table
CREATE TABLE IF NOT EXISTS `supply_team_deliveries` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `team_id` varchar(50) NOT NULL,
    `order_group_id` varchar(50) NOT NULL,
    `restaurant_id` int(11) NOT NULL,
    `leader_citizenid` varchar(50) NOT NULL,
    `member_count` int(11) NOT NULL DEFAULT 2,
    `total_boxes` int(11) NOT NULL,
    `delivery_type` varchar(50) NOT NULL DEFAULT 'duo',
    `coordination_bonus` decimal(10,2) DEFAULT 0.00,
    `team_multiplier` decimal(3,2) DEFAULT 1.00,
    `completion_time` int(11) NOT NULL COMMENT 'Time difference in seconds between first and last arrival',
    `total_payout` decimal(10,2) NOT NULL,
    `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_team_id` (`team_id`),
    KEY `idx_leader` (`leader_citizenid`),
    KEY `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Team members tracking (for detailed stats)
CREATE TABLE IF NOT EXISTS `supply_team_members` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `team_delivery_id` int(11) NOT NULL,
    `citizenid` varchar(50) NOT NULL,
    `role` varchar(20) NOT NULL DEFAULT 'member',
    `boxes_assigned` int(11) NOT NULL,
    `individual_payout` decimal(10,2) NOT NULL,
    `completion_order` int(11) NOT NULL COMMENT 'Order of arrival (1 = first, 2 = second, etc)',
    `vehicle_damaged` tinyint(1) DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_citizenid` (`citizenid`),
    KEY `idx_team_delivery` (`team_delivery_id`),
    CONSTRAINT `fk_team_delivery` FOREIGN KEY (`team_delivery_id`) REFERENCES `supply_team_deliveries` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- All player stats
CREATE TABLE supply_player_stats (
    id INT AUTO_INCREMENT PRIMARY KEY,
    citizenid VARCHAR(50) UNIQUE NOT NULL,
    experience INT DEFAULT 0,
    level INT DEFAULT 1,
    total_deliveries INT DEFAULT 0,
    solo_deliveries INT DEFAULT 0,
    team_deliveries INT DEFAULT 0,
    perfect_deliveries INT DEFAULT 0,
    perfect_syncs INT DEFAULT 0,
    team_earnings DECIMAL(10,2) DEFAULT 0.00,
    average_rating DECIMAL(3,2) DEFAULT 0.00,
    total_earnings DECIMAL(10,2) DEFAULT 0.00,
    last_activity TIMESTAMP NULL DEFAULT NULL,
    -- Optional columns you might keep:
    -- containers_used INT DEFAULT 0,
    -- distance_traveled DECIMAL(10,2) DEFAULT 0.00,
    
    INDEX idx_citizenid (citizenid),
    INDEX idx_level (level),
    INDEX idx_experience (experience),
    INDEX idx_total_deliveries (total_deliveries),
    INDEX idx_last_activity (last_activity)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Stock Analytics and Alerts Database Tables

-- Stock Alerts Table
CREATE TABLE IF NOT EXISTS `supply_stock_alerts` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `ingredient` varchar(100) NOT NULL,
    `alert_level` enum('critical','low','moderate','healthy') NOT NULL,
    `current_stock` int(11) NOT NULL,
    `threshold_percentage` decimal(5,2) NOT NULL,
    `predicted_stockout_date` datetime DEFAULT NULL,
    `resolved` tinyint(1) DEFAULT 0,
    `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
    `resolved_at` timestamp NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_ingredient` (`ingredient`),
    KEY `idx_alert_level` (`alert_level`),
    KEY `idx_resolved` (`resolved`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Usage pattern analytics
CREATE TABLE IF NOT EXISTS `supply_usage_analytics` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ingredient` varchar(100) NOT NULL,
  `analysis_date` date NOT NULL,
  `avg_daily_usage` decimal(8,2) DEFAULT 0.00,
  `peak_usage` decimal(8,2) DEFAULT 0.00,
  `min_usage` decimal(8,2) DEFAULT 0.00,
  `usage_variance` decimal(8,2) DEFAULT 0.00,
  `trend` enum('increasing','decreasing','stable','unknown') DEFAULT 'unknown',
  `confidence_score` decimal(4,3) DEFAULT 0.000,
  `prediction_accuracy` decimal(4,3) DEFAULT NULL,
  `data_points` int(11) DEFAULT 0,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_ingredient_date` (`ingredient`, `analysis_date`),
  KEY `idx_analysis_date` (`analysis_date`),
  KEY `idx_trend` (`trend`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Restock recommendations tracking
CREATE TABLE IF NOT EXISTS `supply_restock_suggestions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ingredient` varchar(100) NOT NULL,
  `current_stock` int(11) NOT NULL,
  `suggested_quantity` int(11) NOT NULL,
  `priority` enum('high','normal','low') DEFAULT 'normal',
  `reasoning` text DEFAULT NULL,
  `days_of_stock_remaining` decimal(4,1) DEFAULT NULL,
  `confidence_score` decimal(4,3) DEFAULT 0.000,
  `suggestion_status` enum('pending','acknowledged','ordered','dismissed') DEFAULT 'pending',
  `cost_estimate` decimal(10,2) DEFAULT NULL,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_ingredient` (`ingredient`),
  KEY `idx_priority` (`priority`),
  KEY `idx_suggestion_status` (`suggestion_status`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Stock Snapshots Table (for trend analysis)
CREATE TABLE IF NOT EXISTS `supply_stock_snapshots` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `ingredient` varchar(100) NOT NULL,
    `warehouse_stock` int(11) NOT NULL,
    `total_restaurant_stock` int(11) DEFAULT 0,
    `daily_usage` int(11) DEFAULT 0,
    `predicted_days_remaining` decimal(5,2) DEFAULT NULL,
    `snapshot_date` date NOT NULL,
    `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `unique_ingredient_date` (`ingredient`, `snapshot_date`),
    KEY `idx_ingredient` (`ingredient`),
    KEY `idx_snapshot_date` (`snapshot_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Demand forecasting data
CREATE TABLE IF NOT EXISTS `supply_demand_forecasts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ingredient` varchar(100) NOT NULL,
  `forecast_date` date NOT NULL,
  `predicted_usage` decimal(8,2) NOT NULL,
  `confidence_interval_low` decimal(8,2) DEFAULT NULL,
  `confidence_interval_high` decimal(8,2) DEFAULT NULL,
  `actual_usage` decimal(8,2) DEFAULT NULL,
  `forecast_accuracy` decimal(5,2) DEFAULT NULL,
  `model_version` varchar(20) DEFAULT 'v1.0',
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_ingredient_forecast_date` (`ingredient`, `forecast_date`),
  KEY `idx_forecast_date` (`forecast_date`),
  KEY `idx_ingredient` (`ingredient`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Dynamic Market Pricing Database Tables

-- Market Snapshots Table
CREATE TABLE IF NOT EXISTS `supply_market_snapshots` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `ingredient` varchar(100) NOT NULL,
    `base_price` decimal(10,2) NOT NULL,
    `multiplier` decimal(4,2) NOT NULL DEFAULT 1.00,
    `final_price` decimal(10,2) NOT NULL,
    `stock_level` int(11) NOT NULL,
    `demand_level` enum('low','normal','high') DEFAULT 'normal',
    `player_count` int(11) DEFAULT 0,
    `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_ingredient` (`ingredient`),
    KEY `idx_created_at` (`created_at`),
    KEY `idx_multiplier` (`multiplier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Market events tracking (shortages, surpluses, etc.)
CREATE TABLE IF NOT EXISTS `supply_market_events` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ingredient` varchar(100) NOT NULL,
  `event_type` enum('shortage','surplus','spike','crash','volatility') NOT NULL,
  `trigger_condition` varchar(255) DEFAULT NULL,
  `price_before` decimal(10,2) NOT NULL,
  `price_after` decimal(10,2) NOT NULL,
  `multiplier_applied` decimal(6,3) NOT NULL,
  `duration` int(11) DEFAULT NULL,
  `stock_level_at_trigger` int(11) DEFAULT NULL,
  `player_count_at_trigger` int(11) DEFAULT NULL,
  `started_at` int(11) NOT NULL,
  `ended_at` int(11) DEFAULT NULL,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_ingredient` (`ingredient`),
  KEY `idx_event_type` (`event_type`),
  KEY `idx_started_at` (`started_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Demand analysis data
CREATE TABLE IF NOT EXISTS `supply_demand_analysis` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ingredient` varchar(100) NOT NULL,
  `analysis_date` date NOT NULL,
  `hour_of_day` tinyint(2) NOT NULL,
  `order_count` int(11) DEFAULT 0,
  `total_quantity` int(11) DEFAULT 0,
  `unique_buyers` int(11) DEFAULT 0,
  `average_order_size` decimal(8,2) DEFAULT 0.00,
  `peak_order_time` time DEFAULT NULL,
  `demand_score` decimal(6,3) DEFAULT 0.000,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_ingredient_date_hour` (`ingredient`, `analysis_date`, `hour_of_day`),
  KEY `idx_analysis_date` (`analysis_date`),
  KEY `idx_demand_score` (`demand_score`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Market Settings Table (for admin stock adjustments)
CREATE TABLE IF NOT EXISTS `supply_market_settings` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `ingredient` varchar(100) NOT NULL,
    `max_stock` int(11) DEFAULT 500,
    `min_stock_threshold` int(11) DEFAULT 25,
    `base_price` decimal(10,2) DEFAULT 10.00,
    `category` enum('default','high_demand','seasonal','specialty') DEFAULT 'default',
    `enabled` tinyint(1) DEFAULT 1,
    `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `unique_ingredient` (`ingredient`),
    KEY `idx_category` (`category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Player market notifications preferences
CREATE TABLE IF NOT EXISTS `supply_market_notifications` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL,
  `notification_type` enum('price_alerts','shortage_alerts','surplus_alerts','market_trends') NOT NULL,
  `ingredient_filter` text DEFAULT NULL,
  `threshold_percentage` decimal(5,2) DEFAULT 20.00,
  `is_enabled` tinyint(1) DEFAULT 1,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_citizenid` (`citizenid`),
  KEY `idx_notification_type` (`notification_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Add market transaction logging table
CREATE TABLE IF NOT EXISTS `supply_market_transactions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `order_group_id` varchar(100) NOT NULL,
  `player_id` int(11) NOT NULL,
  `restaurant_id` int(11) NOT NULL,
  `total_cost` decimal(10,2) NOT NULL,
  `market_impact` decimal(10,2) DEFAULT 0.00,
  `transaction_type` enum('purchase','sale') NOT NULL,
  `transaction_time` int(11) NOT NULL,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_player_id` (`player_id`),
  KEY `idx_transaction_time` (`transaction_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

CREATE TABLE IF NOT EXISTS `supply_notification_preferences` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL,
  `new_orders` tinyint(1) DEFAULT 1,
  `emergency_alerts` tinyint(1) DEFAULT 1,
  `market_changes` tinyint(1) DEFAULT 1,
  `team_invites` tinyint(1) DEFAULT 1,
  `achievements` tinyint(1) DEFAULT 1,
  `stock_alerts` tinyint(1) DEFAULT 1,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Emergency Orders Table
CREATE TABLE IF NOT EXISTS `supply_emergency_orders` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `restaurant_id` int(11) NOT NULL,
    `ingredient` varchar(100) NOT NULL,
    `priority_level` enum('emergency','urgent','critical') NOT NULL,
    `quantity_needed` int(11) NOT NULL,
    `bonus_multiplier` decimal(4,2) DEFAULT 1.50,
    `timeout_minutes` int(11) DEFAULT 60,
    `completed` tinyint(1) DEFAULT 0,
    `completed_by` varchar(50) DEFAULT NULL,
    `completed_at` timestamp NULL DEFAULT NULL,
    `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_restaurant_id` (`restaurant_id`),
    KEY `idx_priority_level` (`priority_level`),
    KEY `idx_completed` (`completed`),
    KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

-- Achievement tracking table
CREATE TABLE IF NOT EXISTS `supply_achievement_progress` (
  `id` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `citizenid` varchar(50) NOT NULL,
  `achievement_type` varchar(50) NOT NULL,
  `current_value` int(11) NOT NULL DEFAULT 0,
  `milestone_reached` varchar(50) DEFAULT NULL,
  `last_updated` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  UNIQUE KEY `unique_achievement` (`citizenid`, `achievement_type`),
  INDEX `idx_citizenid` (`citizenid`),
  INDEX `idx_achievement_type` (`achievement_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- NPC delivery tracking
CREATE TABLE IF NOT EXISTS `supply_npc_deliveries` (
  `id` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `job_id` varchar(100) NOT NULL UNIQUE,
  `initiated_by` varchar(50) NOT NULL,
  `ingredient` varchar(100) NOT NULL,
  `quantity` int(11) NOT NULL,
  `target_restaurant` int(11) NOT NULL,
  `surplus_level` varchar(50) NOT NULL,
  `start_time` int(11) NOT NULL,
  `completion_time` int(11) DEFAULT NULL,
  `status` varchar(20) DEFAULT 'in_progress',
  `payment_amount` int(11) DEFAULT 0,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  
  INDEX `idx_initiated_by` (`initiated_by`),
  INDEX `idx_status` (`status`),
  INDEX `idx_start_time` (`start_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Update delivery logs table for achievement tracking
ALTER TABLE `supply_delivery_logs` 
ADD COLUMN `delivery_rating` decimal(3,2) DEFAULT 5.00,
ADD COLUMN `team_delivery` tinyint(1) DEFAULT 0,
ADD COLUMN `achievement_tier` varchar(50) DEFAULT 'rookie',
ADD COLUMN `performance_bonus` decimal(10,2) DEFAULT 0.00;


-- ===================================
-- ADMIN SYSTEM TABLES
-- ===================================

-- Admin action logs
CREATE TABLE IF NOT EXISTS `supply_admin_logs` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `admin_id` VARCHAR(50) NOT NULL,
    `admin_name` VARCHAR(100) DEFAULT NULL,
    `action` VARCHAR(50) NOT NULL,
    `details` TEXT DEFAULT NULL,
    `timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_admin_id` (`admin_id`),
    INDEX `idx_timestamp` (`timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Price overrides
CREATE TABLE IF NOT EXISTS `supply_price_overrides` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `ingredient` VARCHAR(50) NOT NULL,
    `override_price` DECIMAL(10,2) NOT NULL,
    `override_until` DATETIME NOT NULL,
    `created_by` INT(11) DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `active` BOOLEAN DEFAULT TRUE,
    PRIMARY KEY (`id`),
    INDEX `idx_ingredient` (`ingredient`),
    INDEX `idx_active` (`active`),
    INDEX `idx_override_until` (`override_until`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Market events log
CREATE TABLE IF NOT EXISTS `supply_market_events` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `event_type` VARCHAR(50) NOT NULL,
    `ingredients` TEXT DEFAULT NULL,
    `multiplier` DECIMAL(4,2) DEFAULT 1.00,
    `duration` INT(11) DEFAULT 3600,
    `created_by` VARCHAR(50) DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `expires_at` DATETIME NOT NULL,
    `active` BOOLEAN DEFAULT TRUE,
    PRIMARY KEY (`id`),
    INDEX `idx_active` (`active`),
    INDEX `idx_expires_at` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- System pause states
CREATE TABLE IF NOT EXISTS `supply_system_states` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `state_name` VARCHAR(50) NOT NULL UNIQUE,
    `state_value` VARCHAR(255) DEFAULT NULL,
    `updated_by` VARCHAR(50) DEFAULT NULL,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `idx_state_name` (`state_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Insert default system states
INSERT INTO `supply_system_states` (`state_name`, `state_value`) VALUES
('deliveries_paused', 'false'),
('market_events_enabled', 'true'),
('team_deliveries_enabled', 'true'),
('emergency_orders_enabled', 'true')
ON DUPLICATE KEY UPDATE state_name = state_name;

-- Add missing columns to existing tables if they don't exist
-- For supply_orders table
ALTER TABLE `supply_orders` 
ADD COLUMN IF NOT EXISTS `paused_at` DATETIME DEFAULT NULL,
ADD COLUMN IF NOT EXISTS `admin_notes` TEXT DEFAULT NULL;

-- For supply_player_stats table
ALTER TABLE `supply_player_stats` 
ADD COLUMN IF NOT EXISTS `admin_modified` BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS `last_admin_action` VARCHAR(255) DEFAULT NULL;

