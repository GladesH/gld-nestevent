local QBCore = exports['qb-core']:GetCoreObject()

-- Vérification que Config existe
if not Config then
    Config = {}
    Config.NestEvent = {
        Debug = true  -- Debug par défaut si config non chargée
    }
end

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
local eventStats = {}

-- Debug avec vérification de Config
local function Debug(message, level)
    if Config and Config.NestEvent and Config.NestEvent.Debug then
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
    local defaultStats = {
        totalEvents = 0,
        totalKills = 0,
        bestKills = 0,
        bestKiller = nil,
        totalMoneyGiven = 0,
        bestTimeBonus = 0,
        rewardHistory = {}
    }

    if file then
        local decoded = json.decode(file)
        if decoded then
            -- Fusionner avec les valeurs par défaut pour s'assurer que tous les champs existent
            for k, v in pairs(defaultStats) do
                if decoded[k] == nil then
                    decoded[k] = v
                end
            end
            eventStats = decoded
            Debug("Stats chargées depuis stats.json", "success")
        else
            Debug("Erreur de décodage des stats, initialisation par défaut", "warning")
            eventStats = defaultStats
        end
    else
        Debug("Aucun fichier de stats trouvé, initialisation par défaut", "info")
        eventStats = defaultStats
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

-- Calcul des récompenses
-- Calcul des récompenses
local function CalculateRewards(source, kills, timeInZone)
    local baseReward = Config.NestEvent.rewards.money.base
    local killReward = kills * Config.NestEvent.rewards.money.perKill
    local timeBonus = 0
    local totalReward = baseReward + killReward

    Debug(string.format("Calcul des récompenses pour le joueur %s:", source))
    Debug(string.format("- Récompense de base: $%d", baseReward))
    Debug(string.format("- Bonus de kills: $%d (%d kills × $%d)", 
        killReward, kills, Config.NestEvent.rewards.money.perKill))

    -- Appliquer le bonus de temps
    if timeInZone >= Config.NestEvent.rewards.money.timeBonus.requiredTime then
        timeBonus = totalReward * (Config.NestEvent.rewards.money.timeBonus.multiplier - 1)
        totalReward = totalReward * Config.NestEvent.rewards.money.timeBonus.multiplier
        Debug(string.format("- Bonus de temps appliqué: +$%d (×%.1f)", 
            timeBonus, Config.NestEvent.rewards.money.timeBonus.multiplier))
    end

    -- S'assurer que les champs existent
    if not eventStats.rewardHistory then eventStats.rewardHistory = {} end
    if not eventStats.totalMoneyGiven then eventStats.totalMoneyGiven = 0 end
    if not eventStats.bestTimeBonus then eventStats.bestTimeBonus = 0 end

    -- Enregistrer dans l'historique
    table.insert(eventStats.rewardHistory, {
        timestamp = os.time(),
        player = source,
        baseReward = baseReward,
        killReward = killReward,
        timeBonus = timeBonus,
        totalReward = totalReward,
        kills = kills,
        timeInZone = timeInZone,
        hadTimeBonus = timeBonus > 0
    })

    eventStats.totalMoneyGiven = eventStats.totalMoneyGiven + totalReward
    if timeBonus > eventStats.bestTimeBonus then
        eventStats.bestTimeBonus = timeBonus
    end

    SaveStats()
    return totalReward, timeBonus > 0
end

local function EndNestEvent(success)
    if not activeEvent then return end
    Debug("Tentative de fin d'événement")

    -- Calcul des statistiques finales
    local totalEventKills = 0
    local bestPlayerKills = 0
    local bestPlayer = nil
    
    -- Sauvegarder les kills dans notre variable globale
    lastEventKills = activeEvent.kills or {}
    Debug("Sauvegarde des kills: " .. json.encode(lastEventKills))

    for source, kills in pairs(lastEventKills) do
        totalEventKills = totalEventKills + kills
        if kills > bestPlayerKills then
            bestPlayerKills = kills
            bestPlayer = source
        end
        Debug("Joueur " .. source .. ": " .. kills .. " kills")
    end

    -- Mise à jour des stats globales
    eventStats.totalEvents = (eventStats.totalEvents or 0) + 1
    eventStats.totalKills = (eventStats.totalKills or 0) + totalEventKills
    
    if bestPlayerKills > (eventStats.bestKills or 0) then
        eventStats.bestKills = bestPlayerKills
        eventStats.bestKiller = bestPlayer
        
        if bestPlayer then
            TriggerClientEvent('QBCore:Notify', bestPlayer, 
                Config.NestEvent.GetText('messages.newRecord', bestPlayerKills),
                'success'
            )
            Debug("Nouveau record établi par " .. bestPlayer .. ": " .. bestPlayerKills .. " kills")
        end
    end

    SaveStats()

    -- Notifier tous les clients
    TriggerClientEvent('nest-event:end', -1, {
        success = success,
        stats = {
            totalKills = lastEventKills,
            participants = activeEvent.participants or {},
            eventStats = {
                totalKills = totalEventKills,
                bestKills = bestPlayerKills,
                bestPlayer = bestPlayer
            }
        }
    })

    -- Nettoyer les timers
    if eventTimer then
        clearTimeout(eventTimer)
        eventTimer = nil
    end
    
    Debug(string.format("Événement terminé - Total Kills: %d, Meilleur joueur: %s avec %d kills", 
        totalEventKills, 
        bestPlayer and tostring(bestPlayer) or "aucun", 
        bestPlayerKills
    ))
    
    -- Ne pas effacer lastEventKills pour permettre la réclamation des récompenses
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

-- Vérification de l'emplacement
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
        Debug("Tentative " .. attempts .. " sur " .. maxAttempts)
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
    SaveStats() -- Sauvegarder les stats après le début de l'événement
    return true
end

-- Enregistrement des kills
RegisterNetEvent('nest-event:registerKill')
AddEventHandler('nest-event:registerKill', function()
    local source = source
    Debug("Tentative d'enregistrement de kill par: " .. source)

    if not activeEvent then 
        Debug("Pas d'événement actif", "warning")
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
        Debug("Pas d'événement actif", "warning")
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
-- Distribution des récompenses
RegisterNetEvent('nest-event:claimReward')
AddEventHandler('nest-event:claimReward', function(clientTimeInZone)
    local source = source
    Debug("Tentative de réclamation de récompense par: " .. source)
    
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

    -- Utiliser les kills sauvegardés
    local kills = lastEventKills[source] or 0
    Debug("Kills pour le joueur " .. source .. ": " .. kills)

    -- Calcul des récompenses avec bonus
    local totalReward, hadTimeBonus = CalculateRewards(source, kills, clientTimeInZone)
    Debug("Récompense calculée: $" .. totalReward .. " (avec " .. kills .. " kills)")
    
    -- Donner l'argent
    player.Functions.AddMoney('cash', totalReward, 'nest-event-reward')
    Debug("Argent donné: $" .. totalReward)
    
    -- Items de récompense
    local givenItems = {}
    
    -- Items standards
    for _, item in ipairs(Config.NestEvent.rewards.items.standard) do
        if math.random(100) <= item.chance then
            local amount = math.random(item.amount.min, item.amount.max)
            if player.Functions.AddItem(item.name, amount) then
                table.insert(givenItems, {name = item.name, amount = amount})
                Debug("Item donné: " .. item.name .. " x" .. amount)
            else
                TriggerClientEvent('QBCore:Notify', source, 
                    Config.NestEvent.GetText('messages.reward.inventoryFull'),
                    'error'
                )
                break
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
        money = totalReward,
        items = givenItems,
        timeBonus = hadTimeBonus,
        stats = {
            kills = kills,
            wasTopKiller = kills == eventStats.bestKills
        }
    })

    -- Retirer le joueur des participants éligibles
    eventParticipants[source] = nil
    Debug("Distribution des récompenses terminée pour le joueur " .. source)
    
    -- Sauvegarder les stats
    eventStats.totalMoneyGiven = (eventStats.totalMoneyGiven or 0) + totalReward
    SaveStats()
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
                adjustedChance, chance, playerCount * 2))

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
    end
end)

-- Nettoyage à l'arrêt de la ressource
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    if activeEvent then
        EndNestEvent(false)
    end
    
    SaveStats()
end)

-- Vérification des routes
RegisterNetEvent('nest-event:roadCheckResult')
AddEventHandler('nest-event:roadCheckResult', function(coords, isValid)
    Debug(string.format("Résultat vérification route: %s pour coords %s", 
        tostring(isValid), 
        json.encode(coords)))
end)
