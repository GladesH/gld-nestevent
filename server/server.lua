local QBCore = exports['qb-core']:GetCoreObject()

-- Message de démarrage
CreateThread(function()
    Wait(2000)
    print('^2[GLD-NestEvent] operational^7')
    print('^5[DISCORD SUPPORT] fabgros.^7')
end)

-- Variables d'état
local systemEnabled = true
local activeEvent = nil
local eventTimer = nil

-- Debug
local function Debug(message)
    if Config.NestEvent.Debug then
        print('^3[NEST-EVENT] ^7' .. message)
    end
end

-- Fonction de fin d'événement (doit être déclarée avant utilisation)
local function EndNestEvent(success)
    if not activeEvent then return end
    Debug("Tentative de fin d'événement")

    -- Notifier tous les clients
    TriggerClientEvent('nest-event:end', -1, {
        success = success,
        stats = {
            totalKills = activeEvent.kills or {},
            participants = activeEvent.participants or {}
        }
    })

    -- Reset des variables
    if eventTimer then
        clearTimeout(eventTimer)
        eventTimer = nil
    end
    
    -- Nettoyer le nest si possible
    if activeEvent.id then
        TriggerEvent('hrs_zombies:removeNest', activeEvent.id)
    end

    Debug("Événement terminé avec succès")
    activeEvent = nil
end

-- Sélection d'un joueur aléatoire
local function GetRandomPlayer()
    local players = QBCore.Functions.GetQBPlayers()
    local validPlayers = {}
    
    for _, player in pairs(players) do
        if not player.PlayerData.metadata.isdead and not player.PlayerData.metadata.inlaststand then
            table.insert(validPlayers, player)
        end
    end
    
    return #validPlayers > 0 and validPlayers[math.random(#validPlayers)] or nil
end

-- Vérifier si l'emplacement est valide
local function IsValidSpawnLocation(coords)
    local players = QBCore.Functions.GetQBPlayers()
    for _, player in pairs(players) do
        local ped = GetPlayerPed(player.PlayerData.source)
        if ped then
            local playerCoords = GetEntityCoords(ped)
            local distance = #(coords - playerCoords)
            if distance < Config.NestEvent.area.minSpawnDistance then
                return false
            end
        end
    end
    return true
end

-- Démarrer l'événement
local function StartNestEvent(targetPlayer)
    if activeEvent or not systemEnabled then 
        Debug("Impossible de démarrer: event actif ou système désactivé")
        return 
    end

    local selectedPlayer = targetPlayer or GetRandomPlayer()
    if not selectedPlayer then 
        Debug("Aucun joueur valide trouvé")
        return 
    end

    local playerCoords = GetEntityCoords(GetPlayerPed(selectedPlayer.PlayerData.source))
    local spawnCoords = nil
    local attempts = 0

    while attempts < 10 and not spawnCoords do
        local angle = math.random() * 2 * math.pi
        local distance = math.random(
            Config.NestEvent.area.minSpawnDistance,
            Config.NestEvent.area.maxSpawnDistance
        )

        local testCoords = vector3(
            playerCoords.x + math.cos(angle) * distance,
            playerCoords.y + math.sin(angle) * distance,
            playerCoords.z
        )

        if IsValidSpawnLocation(testCoords) then
            spawnCoords = testCoords
        end
        attempts = attempts + 1
    end

    if not spawnCoords then 
        Debug("Impossible de trouver un point de spawn valide")
        return 
    end

    -- Créer l'événement
    activeEvent = {
        id = "nest_" .. os.time(),
        startTime = os.time(),
        coords = spawnCoords,
        participants = {},
        kills = {},
        active = true
    }

    -- Spawn le nest
    exports.hrs_zombies_V2:SpawnNest(
        activeEvent.id,
        Config.NestEvent.nestType,
        spawnCoords
    )

    -- Notifier les clients
    TriggerClientEvent('nest-event:start', -1, {
        coords = spawnCoords,
        id = activeEvent.id
    })

    -- Timer de fin
    eventTimer = SetTimeout(Config.NestEvent.timing.duration * 60 * 1000, function()
        EndNestEvent(true)
    end)

    Debug("Événement démarré: " .. activeEvent.id)
end

-- Enregistrement des kills
RegisterNetEvent('nest-event:registerKill')
AddEventHandler('nest-event:registerKill', function()
    local source = source
    Debug("Tentative d'enregistrement de kill par: " .. source)

    if not activeEvent then 
        Debug("Pas d'événement actif")
        return 
    end
    
    if not activeEvent.kills then
        activeEvent.kills = {}
    end
    
    activeEvent.kills[source] = (activeEvent.kills[source] or 0) + 1
    Debug("Kill enregistré - Joueur: " .. source .. " - Total kills: " .. activeEvent.kills[source])

    -- Mettre à jour tous les clients
    TriggerClientEvent('nest-event:updateKills', -1, activeEvent.kills)
end)

-- Suivi des joueurs dans la zone
RegisterNetEvent('nest-event:updatePlayerZoneStatus')
AddEventHandler('nest-event:updatePlayerZoneStatus', function(isInZone)
    local source = source
    if not activeEvent then return end
    
    if not activeEvent.participants then
        activeEvent.participants = {}
    end
    
    if isInZone then
        if not activeEvent.participants[source] then
            activeEvent.participants[source] = {
                timeInZone = 0,
                joinTime = os.time()
            }
            Debug("Joueur " .. source .. " entré dans la zone")
        end
    else
        if activeEvent.participants[source] then
            Debug("Joueur " .. source .. " sorti de la zone")
        end
    end
end)

-- Distribution des récompenses
RegisterNetEvent('nest-event:claimReward')
AddEventHandler('nest-event:claimReward', function()
    local source = source
    Debug("Tentative de réclamation de récompense par: " .. source)
    
    local player = QBCore.Functions.GetPlayer(source)
    if not player then 
        Debug("Joueur non trouvé")
        return 
    end
    
    -- Vérifier les kills
    local kills = activeEvent and activeEvent.kills and activeEvent.kills[source] or 0
    Debug("Kills du joueur " .. source .. ": " .. kills)
    
    -- Récompense de base
    local moneyReward = Config.NestEvent.rewards.money.base
    
    -- Bonus par kill
    moneyReward = moneyReward + (kills * Config.NestEvent.rewards.money.perKill)
    
    -- Donner l'argent
    player.Functions.AddMoney('cash', moneyReward, 'nest-event-reward')
    Debug("Argent donné: $" .. moneyReward)
    
    -- Items de récompense
    local givenItems = {}
    
    -- Items standards
    for _, item in ipairs(Config.NestEvent.rewards.items.standard) do
        if math.random(100) <= item.chance then
            local amount = math.random(item.amount.min, item.amount.max)
            if player.Functions.AddItem(item.name, amount) then
                table.insert(givenItems, {name = item.name, amount = amount})
                Debug("Item donné: " .. item.name .. " x" .. amount)
            end
        end
    end
    
    -- Items rares (si assez de kills)
    if kills >= Config.NestEvent.rewards.conditions.minKills then
        for _, item in ipairs(Config.NestEvent.rewards.items.rare) do
            if math.random(100) <= item.chance then
                if player.Functions.AddItem(item.name, item.amount) then
                    table.insert(givenItems, {name = item.name, amount = item.amount})
                    Debug("Item rare donné: " .. item.name .. " x" .. item.amount)
                end
            end
        end
    end
    
    -- Notifier le client
    TriggerClientEvent('nest-event:rewardClaimed', source, {
        money = moneyReward,
        items = givenItems
    })

    Debug("Distribution des récompenses terminée pour le joueur " .. source)
end)

-- Thread principal
CreateThread(function()
    while true do
        Wait(Config.NestEvent.timing.checkInterval * 60 * 1000)
        
        if systemEnabled and not activeEvent then
            local hour = tonumber(os.date("%H"))
            local chance = (hour >= 20 or hour <= 6) 
                and Config.NestEvent.timing.nightChance 
                or Config.NestEvent.timing.dayChance

            if math.random(100) <= chance then
                StartNestEvent()
            end
        end
    end
end)

-- Commandes Admin
QBCore.Commands.Add('forcenest', 'Force un événement nest (Admin)', {{name = 'playerid', help = 'ID du joueur (optionnel)'}}, true, function(source, args)
    if QBCore.Functions.HasPermission(source, 'admin') then
        local targetSource = tonumber(args[1])
        if targetSource then
            local player = QBCore.Functions.GetPlayer(targetSource)
            if player then
                if activeEvent then EndNestEvent(false) end
                StartNestEvent(player)
            end
        else
            if activeEvent then EndNestEvent(false) end
            StartNestEvent()
        end
    end
end)

QBCore.Commands.Add('clearnest', 'Nettoie l\'événement en cours (Admin)', {}, true, function(source)
    if QBCore.Functions.HasPermission(source, 'admin') then
        if activeEvent then
            EndNestEvent(false)
            TriggerClientEvent('QBCore:Notify', source, 'Événement nettoyé', 'success')
        end
    end
end)

QBCore.Commands.Add('nestinfo', 'Info sur l\'événement en cours (Admin)', {}, true, function(source)
    if QBCore.Functions.HasPermission(source, 'admin') then
        if activeEvent then
            local participantCount = 0
            local totalKills = 0
            
            for _ in pairs(activeEvent.participants) do
                participantCount = participantCount + 1
            end
            
            for _, kills in pairs(activeEvent.kills) do
                totalKills = totalKills + kills
            end
            
            local timeRemaining = Config.NestEvent.timing.duration * 60 - (os.time() - activeEvent.startTime)
            
            TriggerClientEvent('QBCore:Notify', source, string.format(
                'Event actif: %d participants, %d kills, %d secondes restantes',
                participantCount, totalKills, timeRemaining
            ))
        else
            TriggerClientEvent('QBCore:Notify', source, 'Aucun événement en cours', 'error')
        end
    end
end)

QBCore.Commands.Add('togglenest', 'Active/Désactive le système de nest events (Admin)', {}, true, function(source)
    if QBCore.Functions.HasPermission(source, 'admin') then
        systemEnabled = not systemEnabled
        
        if not systemEnabled and activeEvent then
            EndNestEvent(false)
        end

        TriggerClientEvent('QBCore:Notify', source, 
            systemEnabled and 'Système de Nest Events activé' or 'Système de Nest Events désactivé', 
            'success'
        )
        
        Debug(string.format("Système %s par %s", 
            systemEnabled and "activé" or "désactivé",
            GetPlayerName(source)
        ))
    end
end)
