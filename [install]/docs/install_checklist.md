# ✅ Installation Checklist & File Verification

## 📋 Pre-Installation Checklist

### Dependencies Installed
- [ ] ox_lib
- [ ] ox_target  
- [ ] ox_inventory
- [ ] oxmysql
- [ ] lation_ui
- [ ] QBCore OR QBox

### Database Ready
- [ ] MySQL/MariaDB running
- [ ] Database created
- [ ] User has full permissions
- [ ] Can access phpMyAdmin/HeidiSQL

### Server Ready
- [ ] FiveM artifacts 2802+
- [ ] Clean server for testing
- [ ] Admin permissions configured

---

## 📁 Required Files Checklist

### From Main Resource
- [ ] `fxmanifest.lua`
- [ ] `sql/database_schema.sql`
- [ ] `shared/config/config_main.lua`
- [ ] `shared/config/config_locations.lua`
- [ ] `shared/config/config_items.lua`

### From Session Artifacts
- [ ] `admin_sql_tables.sql` (Admin system tables)
- [ ] `cl_team_deliveries.lua` (Enhanced team system)
- [ ] `sv_vehicle_spawn_manager.lua` (Collision prevention)
- [ ] `cl_team_ui_features.lua` (Team UI components)

### Created During Setup
- [ ] Jobs added to `qb-core/shared/jobs.lua`
- [ ] Permissions added to `server.cfg`
- [ ] Resource added to `server.cfg`

---

## 🔍 Quick Verification Commands

### In Game (F8 Console)
```lua
-- Check if resource is running
print(GetResourceState("ogz_supplychainmaster"))

-- Check if player has job
QBCore.Functions.GetPlayerData().job.name
```

### Server Console
```bash
# Check resource status
status ogz_supplychainmaster

# Check for errors
grep ERROR console.log
```

### Database
```sql
-- Check tables exist
SHOW TABLES LIKE 'supply_%';

-- Check initial data
SELECT COUNT(*) FROM supply_warehouse_stock;
SELECT COUNT(*) FROM supply_market_prices;
```

---

## 🚨 Critical Files to Double-Check

### 1. Job Names Must Match
- `config_locations.lua` → restaurant job
- `qbx_core/shared/jobs.lua` → job definition
- `config_items.lua` → job key

### 2. Coordinates Must Be Valid
- Warehouse location
- Restaurant position
- Delivery points
- Box spawn positions

### 3. Database Foreign Keys
- Restaurant IDs must exist
- Ingredient names must match
- Player citizenids valid

---

## 📝 Testing Order

1. **Solo Functionality First**
   - Basic warehouse access
   - Simple delivery
   - Payment received
   - Stock updated

2. **Restaurant Features**
   - Order creation
   - Stock viewing
   - Price history

3. **Team Features**
   - Team creation
   - Vehicle spawning
   - Coordination test

4. **Admin System**
   - Menu access
   - Stock adjustment
   - Price override

5. **Advanced Features**
   - Market events
   - Emergency orders
   - Achievements

---

## 🎯 Success Indicators

### ✅ You Know It's Working When:
- Warehouse ped spawns at location
- F10 opens admin menu (with perms)
- Vehicles spawn without colliding
- Teams can share vehicles (duos)
- Payments process correctly
- Stock updates on delivery
- Leaderboards show data
- Email notifications arrive

### ❌ Something's Wrong If:
- Red script errors in F8
- "Resource not found" errors
- Database connection failures
- Nil value errors
- Players stuck in animations
- Vehicles spawning inside each other

---

## 🔧 Quick Fixes

### Resource Won't Start
```bash
refresh
ensure ogz_supplychainmaster
```

### Database Errors
```sql
-- Reset and try again
DROP TABLE IF EXISTS supply_orders;
-- Re-import schema
```

### Permission Issues
```cfg
add_principal identifier.license:xxxxx group.admin
```

---

<div align="center">

### **"Check twice, launch once!"** 🚀

**Ready for greatness!**

</div>