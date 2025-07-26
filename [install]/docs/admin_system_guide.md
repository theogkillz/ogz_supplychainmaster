# 🛠️ Supply Chain Admin System - Quick Reference Guide

## 🎯 Overview
The admin system provides comprehensive control over the entire supply chain ecosystem with permission-based access levels.

## 🔑 Permission Levels

| Level | Permission | Access |
|-------|------------|--------|
| **Superadmin** | `god` | Full system access, emergency controls, resets |
| **Admin** | `admin` | Stock/price management, player modifiers |
| **Moderator** | `mod` | View-only monitoring, basic reports |

## 📋 Features

### 1. 📦 Stock Management
- **View Stock**: Real-time warehouse and restaurant inventory
- **Adjust Stock**: Set, add, or remove stock quantities
- **Emergency Restock**: Instant restock all locations to defaults
  - Warehouses: 500 units
  - Restaurants: 100 units

### 2. 💰 Price Controls
- **View Prices**: Current market prices with override status
- **Manual Override**: Set specific prices for X hours
- **Market Events**:
  - **Shortage**: 2.5x prices (1 hour)
  - **Surplus**: 0.8x prices (30 min)
  - **Reset**: Return to base prices

### 3. 👥 Player Management
- **View Stats**: Comprehensive player statistics
- **Reset Achievements**: Clear all progress
- **Grant Bonuses**:
  - Money rewards
  - Experience points

### 4. 📊 System Monitoring
- **Active Deliveries**: Track all ongoing jobs
- **System Metrics**:
  - Today's orders
  - Revenue
  - Active players
  - Low stock alerts

### 5. 🚨 Emergency Controls
- **Pause/Resume**: Halt all deliveries system-wide
- **System Resets**:
  - Daily stats
  - Weekly stats
  - Full system (DANGER!)

## 🎮 Commands

| Command | Description | Permission |
|---------|-------------|------------|
| `/supply` | Open admin menu | moderator+ |
| `/supplypause` | Pause all deliveries | superadmin |
| `/supplyresume` | Resume deliveries | superadmin |

## 🔥 Quick Actions

### Emergency Situations
1. **Server Lag**: `/supplypause` to halt deliveries
2. **Economic Crash**: Force market reset in price controls
3. **Exploit Found**: Use emergency controls to pause system

### Regular Maintenance
1. Check system metrics daily
2. Monitor low stock warnings
3. Review active deliveries for stuck jobs
4. Check player reports in admin logs

## ⚠️ Warning Notes

- **Full System Reset** deletes ALL data - use with extreme caution!
- **Price Overrides** affect the entire economy - test carefully
- **Emergency Restock** can flood the market - use sparingly
- All actions are logged in `supply_admin_logs` table

## 📊 Database Tables

- `supply_admin_logs` - All admin actions
- `supply_price_overrides` - Active price modifications
- `supply_market_events` - Market event history
- `supply_system_states` - System-wide states

## 🎯 Best Practices

1. **Always check metrics** before making changes
2. **Use moderate adjustments** - avoid extreme values
3. **Communicate with players** before system pauses
4. **Document reasons** for major actions
5. **Test in off-peak hours** when possible

---

*"With great power comes great responsibility - use admin tools wisely!"* 🚀