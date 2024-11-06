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
local eventParticipants = {}

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

    TriggerClientEvent('nest-event:end', -1, {
        success = success,
        stats = {
            totalKills = activeEvent.kills or {},
            participants = activeEvent.participants or {}
        }
    })

    if eventTimer then
        clearTimeout(eventTimer)
        eventTimer = nil
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

-- Fonction pour vérifier si une position est sur une route
local function IsLocationOnRoad(coords)
    -- On va demander au client de faire la vérification
    TriggerClientEvent('nest-event:checkRoadLocation', -1, coords)
    -- Note: idéalement il faudrait attendre la réponse du client ici
    return true -- Par défaut on autorise et on laissera le client faire la vérification finale
end

-- Vérifier si l'emplacement est valide
local function IsValidSpawnLocation(coords)
    -- Vérifier la distance avec les joueurs d'abord
    local players = QBCore.Functions.GetQBPlayers()
    for _, player in pairs(players) do
        local ped = GetPlayerPed(player.PlayerData.source)
        if ped then
            local playerCoords = GetEntityCoords(ped)
            local distance = #(vector3(coords.x, coords.y, 0) - vector3(playerCoords.x, playerCoords.y, 0))
            if distance < Config.NestEvent.area.minSpawnDistance then
                Debug("Point rejeté: trop proche d'un joueur")
                return false, 0
            end
        end
    end

    -- Vérifier si on est sur une route
    if IsLocationOnRoad(coords) then
        Debug("Point validé: sur une route")
        return true, coords.z + 0.5
    end

    Debug("Point rejeté: pas sur une route")
    return false, 0
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
    Debug("Coordonnées du joueur: " .. json.encode(playerCoords))

    local spawnCoords = nil
    local attempts = 0
    local maxAttempts = Config.NestEvent.spawnPreferences and Config.NestEvent.spawnPreferences.maxSpawnAttempts or 20

    while attempts < maxAttempts and not spawnCoords do
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

        local valid, groundZ = IsValidSpawnLocation(testCoords)
        if valid then
            spawnCoords = vector3(testCoords.x, testCoords.y, groundZ)
            Debug("Point de spawn valide trouvé: " .. json.encode(spawnCoords))
        end
        
        attempts = attempts + 1
        Debug("Tentative " .. attempts .. " sur " .. maxAttempts)
    end

    if not spawnCoords then 
        Debug("Impossible de trouver un point de spawn valide après " .. maxAttempts .. " tentatives")
        return 
    end

    -- Réinitialiser les participants
    eventParticipants = {}

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
    Debug("Mise à jour du statut de zone pour le joueur " .. source .. ": " .. tostring(isInZone))
    
    if not activeEvent then 
        Debug("Pas d'événement actif")
        return 
    end
    
    if not activeEvent.participants then
        activeEvent.participants = {}
    end
    
    if isInZone then
        eventParticipants[source] = true
        Debug("Joueur " .. source .. " ajouté aux participants éligibles")
        
        if not activeEvent.participants[source] then
            activeEvent.participants[source] = {
                timeInZone = 0,
                joinTime = os.time(),
                hasParticipated = true
            }
            Debug("Joueur " .. source .. " enregistré comme participant")
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
    
    -- Débug détaillé de la vérification de participation
    Debug("Vérification de participation pour le joueur " .. source)
    Debug("Statut de participation: " .. tostring(eventParticipants[source]))
    
    -- Vérifier si le joueur a participé
    if not eventParticipants[source] then
        Debug("Joueur " .. source .. " n'a pas participé à l'événement")
        TriggerClientEvent('nest-event:rewardError', source, 'notParticipated')
        return
    end
    
    local kills = activeEvent and activeEvent.kills and activeEvent.kills[source] or 0
    Debug("Kills du joueur " .. source .. ": " .. kills)
    
    -- Récompense de base
    local moneyReward = Config.NestEvent.rewards.money.base
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

    -- Retirer le joueur des participants éligibles après une réclamation réussie
    eventParticipants[source] = nil
    Debug("Distribution des récompenses terminée pour le joueur " .. source)
end)

-- Écouter la réponse du client pour la vérification de route
RegisterNetEvent('nest-event:roadCheckResult')
AddEventHandler('nest-event:roadCheckResult', function(coords, isValid)
    Debug("Résultat de vérification de route reçu: " .. tostring(isValid) .. " pour coords " .. json.encode(coords))
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
