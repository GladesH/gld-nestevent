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
local eventStats = {
    totalEvents = 0,
    totalKills = 0,
    bestKills = 0,
    bestKiller = nil
}

-- Debug
local function Debug(message, level)
    if Config.NestEvent.Debug then
        level = level or 'info'
        local colors = {
            info = '^3',
            success = '^2',
            warning = '^8',
            error = '^1'
        }
        print(string.format('%s[NEST-EVENT] %s^7', colors[level] or '^3', message))
    end
end

-- Fonctions de gestion des stats en JSON
local function LoadStats()
    local file = LoadResourceFile(GetCurrentResourceName(), "stats.json")
    if file then
        local decoded = json.decode(file)
        if decoded then
            eventStats = decoded
            Debug("Stats chargées depuis stats.json", "success")
        else
            Debug("Erreur de décodage des stats, initialisation par défaut", "warning")
            eventStats = {
                totalEvents = 0,
                totalKills = 0,
                bestKills = 0,
                bestKiller = nil
            }
        end
    else
        Debug("Aucun fichier de stats trouvé, initialisation par défaut", "info")
        eventStats = {
            totalEvents = 0,
            totalKills = 0,
            bestKills = 0,
            bestKiller = nil
        }
    end
end

local function SaveStats()
    local encoded = json.encode(eventStats)
    if encoded then
        SaveResourceFile(GetCurrentResourceName(), "stats.json", encoded, -1)
        Debug("Stats sauvegardées dans stats.json", "success")
    else
        Debug("Erreur lors de la sauvegarde des stats", "error")
    end
end

-- Fonction de fin d'événement
local function EndNestEvent(success)
    if not activeEvent then return end
    Debug("Tentative de fin d'événement")

    -- Calcul des statistiques finales
    local totalEventKills = 0
    local bestPlayerKills = 0
    local bestPlayer = nil

    for source, kills in pairs(activeEvent.kills or {}) do
        totalEventKills = totalEventKills + kills
        if kills > bestPlayerKills then
            bestPlayerKills = kills
            bestPlayer = source
        end
    end

    -- Mise à jour des stats globales
    eventStats.totalEvents = eventStats.totalEvents + 1
    eventStats.totalKills = eventStats.totalKills + totalEventKills
    if bestPlayerKills > eventStats.bestKills then
        eventStats.bestKills = bestPlayerKills
        eventStats.bestKiller = bestPlayer
        
        if bestPlayer then
            TriggerClientEvent('QBCore:Notify', bestPlayer, 
                Config.NestEvent.GetText('messages.newRecord', bestPlayerKills),
                'success'
            )
        end
    end

    -- Sauvegarder les stats
    SaveStats()

    -- Notifier tous les clients
    TriggerClientEvent('nest-event:end', -1, {
        success = success,
        stats = {
            totalKills = activeEvent.kills or {},
            participants = activeEvent.participants or {},
            eventStats = {
                totalKills = totalEventKills,
                bestKills = bestPlayerKills,
                bestPlayer = bestPlayer
            }
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

-- Vérifier si l'emplacement est valide
local function IsValidSpawnLocation(coords)
    local players = QBCore.Functions.GetQBPlayers()
    for _, player in pairs(players) do
        local ped = GetPlayerPed(player.PlayerData.source)
        if ped then
            local playerCoords = GetEntityCoords(ped)
            local distance = #(vector3(coords.x, coords.y, 0) - vector3(playerCoords.x, playerCoords.y, 0))
            if distance < Config.NestEvent.area.minSpawnDistance then
                Debug("Position rejetée: trop proche d'un joueur", "warning")
                return false, 0
            end
        end
    end
    return true, coords.z + 0.5
end

-- Démarrer l'événement
local function StartNestEvent(targetPlayer)
    if activeEvent or not systemEnabled then 
        Debug("Impossible de démarrer: event actif ou système désactivé", "warning")
        return false
    end

    local selectedPlayer = targetPlayer or GetRandomPlayer()
    if not selectedPlayer then 
        Debug("Aucun joueur valide trouvé", "warning")
        return false
    end

    local playerCoords = GetEntityCoords(GetPlayerPed(selectedPlayer.PlayerData.source))
    Debug("Coordonnées du joueur: " .. json.encode(playerCoords), "info")

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
            Debug("Point de spawn valide trouvé: " .. json.encode(spawnCoords), "success")
        end
        
        attempts = attempts + 1
    end

    if not spawnCoords then 
        Debug("Impossible de trouver un point de spawn valide", "error")
        return false
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
        active = true,
        initiator = selectedPlayer.PlayerData.source
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

    -- Timer de fin avec avertissements
    local function SendTimeWarning(minutesLeft)
        if activeEvent then
            TriggerClientEvent('QBCore:Notify', -1, 
                Config.NestEvent.GetText('messages.timeWarning', minutesLeft),
                'inform'
            )
        end
    end

    -- Configurer les avertissements de temps
    for _, minutes in ipairs(Config.NestEvent.timing.warningTimes) do
        local warningTime = (Config.NestEvent.timing.duration - minutes) * 60 * 1000
        if warningTime > 0 then
            SetTimeout(warningTime, function()
                SendTimeWarning(minutes)
            end)
        end
    end

    -- Timer principal
    eventTimer = SetTimeout(Config.NestEvent.timing.duration * 60 * 1000, function()
        EndNestEvent(true)
    end)

    Debug("Événement démarré: " .. activeEvent.id, "success")
    return true
end
-- Enregistrement des kills
RegisterNetEvent('nest-event:registerKill')
AddEventHandler('nest-event:registerKill', function()
    local source = source
    Debug("Tentative d'enregistrement de kill par: " .. source, "info")

    if not activeEvent then 
        Debug("Pas d'événement actif", "warning")
        return 
    end
    
    if not activeEvent.kills then
        activeEvent.kills = {}
    end
    
    activeEvent.kills[source] = (activeEvent.kills[source] or 0) + 1
    Debug("Kill enregistré - Joueur: " .. source .. " - Total kills: " .. activeEvent.kills[source], "success")

    -- Mettre à jour tous les clients
    TriggerClientEvent('nest-event:updateKills', -1, activeEvent.kills)
end)

-- Suivi des joueurs dans la zone
RegisterNetEvent('nest-event:updatePlayerZoneStatus')
AddEventHandler('nest-event:updatePlayerZoneStatus', function(isInZone)
    local source = source
    Debug("Mise à jour du statut de zone pour le joueur " .. source .. ": " .. tostring(isInZone), "info")
    
    if not activeEvent then 
        Debug("Pas d'événement actif", "warning")
        return 
    end
    
    if not activeEvent.participants then
        activeEvent.participants = {}
    end
    
    if isInZone then
        eventParticipants[source] = true
        Debug("Joueur " .. source .. " ajouté aux participants éligibles", "success")
        
        if not activeEvent.participants[source] then
            activeEvent.participants[source] = {
                timeInZone = 0,
                joinTime = os.time(),
                hasParticipated = true
            }
            Debug("Joueur " .. source .. " enregistré comme participant", "success")
        end
    end
end)

-- Distribution des récompenses
RegisterNetEvent('nest-event:claimReward')
AddEventHandler('nest-event:claimReward', function()
    local source = source
    Debug("Tentative de réclamation de récompense par: " .. source, "info")
    
    local player = QBCore.Functions.GetPlayer(source)
    if not player then 
        Debug("Joueur non trouvé", "error")
        return 
    end
    
    -- Vérification de participation
    if not eventParticipants[source] then
        Debug("Joueur " .. source .. " n'a pas participé à l'événement", "warning")
        TriggerClientEvent('nest-event:rewardError', source, 'notParticipated')
        return
    end

    local kills = activeEvent and activeEvent.kills and activeEvent.kills[source] or 0
    Debug("Kills du joueur " .. source .. ": " .. kills, "info")

    -- Calcul des récompenses
    local moneyReward = Config.NestEvent.rewards.money.base
    moneyReward = moneyReward + (kills * Config.NestEvent.rewards.money.perKill)
    
    -- Bonus de performance
    if kills >= Config.NestEvent.rewards.conditions.minKills * 2 then
        moneyReward = moneyReward * 1.5
        Debug("Bonus de performance appliqué", "success")
    end

    -- Donner l'argent
    player.Functions.AddMoney('cash', moneyReward, 'nest-event-reward')
    Debug("Argent donné: $" .. moneyReward, "success")
    
    -- Items de récompense
    local givenItems = {}
    
    -- Items standards
    for _, item in ipairs(Config.NestEvent.rewards.items.standard) do
        if math.random(100) <= item.chance then
            local amount = math.random(item.amount.min, item.amount.max)
            if player.Functions.AddItem(item.name, amount) then
                table.insert(givenItems, {name = item.name, amount = amount})
                Debug("Item donné: " .. item.name .. " x" .. amount, "success")
            else
                TriggerClientEvent('QBCore:Notify', source, 
                    Config.NestEvent.GetText('messages.reward.inventoryFull'),
                    'error'
                )
                break
            end
        end
    end
    
    -- Items rares
    if kills >= Config.NestEvent.rewards.conditions.minKills then
        for _, item in ipairs(Config.NestEvent.rewards.items.rare) do
            if math.random(100) <= item.chance then
                if player.Functions.AddItem(item.name, item.amount) then
                    table.insert(givenItems, {name = item.name, amount = item.amount})
                    Debug("Item rare donné: " .. item.name .. " x" .. item.amount, "success")
                end
            end
        end
    end
    
    -- Notifier le client
    TriggerClientEvent('nest-event:rewardClaimed', source, {
        money = moneyReward,
        items = givenItems
    })

    -- Retirer le joueur des participants éligibles
    eventParticipants[source] = nil
    Debug("Distribution des récompenses terminée pour le joueur " .. source, "success")
end)

-- Thread principal avec vérification automatique
CreateThread(function()
    -- Charger les stats au démarrage
    Wait(1000)
    LoadStats()
    
    while true do
        Wait(Config.NestEvent.timing.checkInterval * 60 * 1000)
        
        if systemEnabled and not activeEvent then
            local hour = tonumber(os.date("%H"))
            local chance = (hour >= 20 or hour <= 6) 
                and Config.NestEvent.timing.nightChance 
                or Config.NestEvent.timing.dayChance

            local players = QBCore.Functions.GetQBPlayers()
            local playerCount = 0
            for _ in pairs(players) do playerCount = playerCount + 1 end
            
            local adjustedChance = chance + (playerCount * 2)
            Debug(string.format("Chance d'événement: %d%% (Base: %d%%, Bonus joueurs: %d%%)", 
                adjustedChance, chance, playerCount * 2), "info")

            if math.random(100) <= adjustedChance then
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
            TriggerClientEvent('QBCore:Notify', source, 
                Config.NestEvent.GetText('messages.admin.eventCleaned'),
                'success'
            )
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
                Config.NestEvent.GetText('messages.admin.eventInfo'),
                participantCount, totalKills, timeRemaining
            ))
        else
            TriggerClientEvent('QBCore:Notify', source, 
                Config.NestEvent.GetText('messages.admin.noActiveEvent'),
                'error'
            )
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
            Config.NestEvent.GetText(systemEnabled and 'messages.admin.systemEnabled' or 'messages.admin.systemDisabled'),
            'success'
        )
        
        Debug(string.format("Système %s par %s", 
            systemEnabled and "activé" or "désactivé",
            GetPlayerName(source)
        ))
        
        SaveStats()
    end
end)

-- Nettoyage à l'arrêt de la ressource
AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
    
    Debug("Arrêt du système d'événements", "warning")
    
    if activeEvent then
        EndNestEvent(false)
    end
    
    SaveStats()
end)
