local QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent('farming:sellFruit')
AddEventHandler('farming:sellFruit', function(fruit, amount)
    local src = source
    local itemCount = exports.ox_inventory:GetItemCount(src, fruit)
    if itemCount >= amount then
        local price = (Config.ItemsFarming.Meats[fruit] or Config.ItemsFarming.Vegetables[fruit] or Config.ItemsFarming.Fruits[fruit]).price
        local total = amount * price
        exports.ox_inventory:RemoveItem(src, fruit, amount)
        local xPlayer = QBCore.Functions.GetPlayer(src)
        xPlayer.Functions.AddMoney('cash', total)
        
        MySQL.Async.fetchAll('SELECT * FROM supply_warehouse_stock WHERE ingredient = ?', {
            fruit:lower()
        }, function(stockResults)
            if #stockResults > 0 then
                MySQL.Async.execute('UPDATE supply_warehouse_stock SET quantity = quantity + ? WHERE ingredient = ?', {
                    amount,
                    fruit:lower()
                })
            else
                MySQL.Async.execute('INSERT INTO supply_warehouse_stock (ingredient, quantity) VALUES (?, ?)', {
                    fruit:lower(),
                    amount
                })
            end
        end)
        
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Sold ' .. amount .. ' ' .. (Config.ItemsFarming.Meats[fruit] or Config.ItemsFarming.Vegetables[fruit] or Config.ItemsFarming.Fruits[fruit]).label,
            description = 'for $' .. total,
            type = 'success',
            duration = 9000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Not enough ' .. (Config.ItemsFarming.Meats[fruit] or Config.ItemsFarming.Vegetables[fruit] or Config.ItemsFarming.Fruits[fruit]).label,
            type = 'error',
            duration = 3000,
            position = Config.UI.notificationPosition,
            markdown = Config.UI.enableMarkdown
        })
    end
end)