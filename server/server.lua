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
local validRewardPlayers = {}

-- Debug
local function Debug(message)
    if Config.NestEvent.Debug then
        print('^3[GLD-NestEvent] ^7' .. message)
    end
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

-- Vérifier si l'emplacement est valide pour le spawn
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
    if activeEvent or not systemEnabled then return end

    local selectedPlayer = targetPlayer or GetRandomPlayer()
    if not selectedPlayer then return end

    local playerCoords = GetEntityCoords(GetPlayerPed(selectedPlayer.PlayerData.source))
    local spawnCoords = nil
    local attempts = 0

    -- Trouver un point de spawn valide
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

-- Gérer les kills
RegisterNetEvent('nest-event:registerKill')
AddEventHandler('nest-event:registerKill', function()
    local source = source
    if not activeEvent then return end
    
    if activeEvent.participants[source] then
        activeEvent.kills[source] = (activeEvent.kills[source] or 0) + 1
        TriggerClientEvent('nest-event:updateKills', -1, activeEvent.kills)
        
        if activeEvent.kills[source] >= Config.NestEvent.rewards.conditions.minKills then
            validRewardPlayers[source] = true
        end
    end
end)

-- Calcul des récompenses
local function CalculateRewards(playerId)
    if not activeEvent or not activeEvent.participants[playerId] then return 0, {} end

    local participantData = activeEvent.participants[playerId]
    local kills = activeEvent.kills[playerId] or 0
    local reward = 0
    local items = {}

    -- Vérifier le temps minimum
    if participantData.timeInZone >= Config.NestEvent.rewards.conditions.minTimeInZone then
        -- Récompense de base
        reward = reward + Config.NestEvent.rewards.money.base
        -- Bonus par kill
        reward = reward + (kills * Config.NestEvent.rewards.money.perKill)
        
        -- Items standards
        for _, item in ipairs(Config.NestEvent.rewards.items.standard) do
            if math.random(100) <= item.chance then
                local amount = math.random(item.amount.min, item.amount.max)
                table.insert(items, {name = item.name, amount = amount})
            end
        end

        -- Items rares
        if kills >= Config.NestEvent.rewards.conditions.minKills then
            for _, item in ipairs(Config.NestEvent.rewards.items.rare) do
                if kills >= (item.requireKills or 0) and math.random(100) <= item.chance then
                    table.insert(items, {name = item.name, amount = item.amount})
                end
            end
        end
    end

    return reward, items
end

-- Distribution des récompenses
RegisterNetEvent('nest-event:claimReward')
AddEventHandler('nest-event:claimReward', function()
    local source = source
    if not validRewardPlayers[source] then 
        TriggerClientEvent('nest-event:rewardError', source, 'notEligible')
        return 
    end

    local reward, items = CalculateRewards(source)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then return end

    -- Donner l'argent
    if reward > 0 then
        player.Functions.AddMoney('cash', reward, 'nest-event-reward')
    end

    -- Donner les items
    for _, item in ipairs(items) do
        player.Functions.AddItem(item.name, item.amount)
        TriggerClientEvent('qb-inventory:client:ItemBox', source, QBCore.Shared.Items[item.name], 'add', item.amount)
    end

    -- Marquer comme réclamé
    validRewardPlayers[source] = nil
    TriggerClientEvent('nest-event:rewardClaimed', source, {money = reward, items = items})
end)

-- Fin de l'événement
local function EndNestEvent(success)
    if not activeEvent then return end

    -- Notifier tous les joueurs
    TriggerClientEvent('nest-event:end', -1, {
        success = success,
        stats = {
            totalKills = activeEvent.kills,
            participants = #activeEvent.participants
        }
    })

    -- Reset des variables
    if eventTimer then
        clearTimeout(eventTimer)
        eventTimer = nil
    end
    
    activeEvent = nil
    Debug("Événement terminé")
end

-- Thread principal pour le spawn
CreateThread(function()
    while true do
        if systemEnabled and not activeEvent then
            local chance = GetClockHours() >= 20 or GetClockHours() <= 6 
                and Config.NestEvent.timing.nightChance 
                or Config.NestEvent.timing.dayChance

            if math.random(100) <= chance then
                StartNestEvent()
            end
        end
        Wait(Config.NestEvent.timing.checkInterval * 60 * 1000)
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
            local info = {
                timeRemaining = Config.NestEvent.timing.duration * 60 - (os.time() - activeEvent.startTime),
                participants = #activeEvent.participants,
                totalKills = 0
            }
            for _, kills in pairs(activeEvent.kills) do
                info.totalKills = info.totalKills + kills
            end
            TriggerClientEvent('QBCore:Notify', source, string.format(
                'Event actif: %d participants, %d kills, %d secondes restantes',
                info.participants, info.totalKills, info.timeRemaining
            ))
        else
            TriggerClientEvent('QBCore:Notify', source, 'Aucun événement en cours', 'error')
        end
    end
end)

-- Commande pour activer/désactiver le système
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
