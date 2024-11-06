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

-- Fonction de fin d'événement
local function EndNestEvent(success)
    if not activeEvent then return end
    Debug("Tentative de fin d'événement")

    -- Supprimer le nest
    TriggerEvent('hrs_zombies:removeNest', activeEvent.id)

    -- Notifier les clients
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
    
    Debug("Événement terminé")
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
    if not activeEvent then return end
    
    if not activeEvent.kills then
        activeEvent.kills = {}
    end
    
    activeEvent.kills[source] = (activeEvent.kills[source] or 0) + 1
    Debug(string.format("Kill enregistré pour %s, total: %d", source, activeEvent.kills[source]))
    
    TriggerClientEvent('nest-event:updateKills', -1, activeEvent.kills)
end)

-- Suivi des joueurs dans la zone
RegisterNetEvent('nest-event:updatePlayerZoneStatus')
AddEventHandler('nest-event:updatePlayerZoneStatus', function(isInZone)
    local source = source
    if not activeEvent then return end
    
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
    local player = QBCore.Functions.GetPlayer(source)
    
    if not player then 
        Debug("Joueur non trouvé")
        return 
    end
    
    -- Vérifier les kills
    local kills = activeEvent and activeEvent.kills and activeEvent.kills[source] or 0
    Debug(string.format("Joueur %s a %d kills", source, kills))
    
    -- Calculer la récompense
    local moneyReward = Config.NestEvent.rewards.money.base + (kills * Config.NestEvent.rewards.money.perKill)
    
    -- Donner l'argent
    player.Functions.AddMoney('cash', moneyReward, 'nest-event-reward')
    
    -- Ajouter les items selon les kills
    if kills >= Config.NestEvent.rewards.conditions.minKills then
        for _, item in ipairs(Config.NestEvent.rewards.items.standard) do
            if math.random(100) <= item.chance then
                local amount = math.random(item.amount.min, item.amount.max)
                player.Functions.AddItem(item.name, amount)
                TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[item.name], 'add', amount)
            end
        end
        
        -- Items rares
        for _, item in ipairs(Config.NestEvent.rewards.items.rare) do
            if kills >= (item.requireKills or 0) and math.random(100) <= item.chance then
                player.Functions.AddItem(item.name, item.amount)
                TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[item.name], 'add', item.amount)
            end
        end
    end
    
    -- Notifier le joueur
    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Récompense',
        description = string.format('Vous avez reçu $%d pour %d kills', moneyReward, kills),
        type = 'success'
    })
    
    Debug(string.format("Récompense donnée: $%d pour %d kills", moneyReward, kills))
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
