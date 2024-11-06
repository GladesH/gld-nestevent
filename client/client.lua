local QBCore = exports['qb-core']:GetCoreObject()

-- Variables d'état
local activeEvent = nil
local eventZone = nil
local rewardBox = nil
local isInZone = false
local eventStartTime = 0
local timeInZone = 0
local killCount = 0  -- Ajout d'un compteur local de kills

-- Debug
local function Debug(message)
    if Config.NestEvent.Debug then
        print('^3[NEST-EVENT] ^7' .. message)
    end
end

-- Mise à jour de l'UI
local function UpdateEventUI()
    if not activeEvent then 
        lib.hideTextUI()
        return 
    end
    
    local timeLeft = math.max(0, Config.NestEvent.timing.duration * 60 - (GetGameTimer() - eventStartTime) / 1000)
    local text = string.format(
        "ÉVÉNEMENT NEST : \n %02d:%02d\nKills: %d\nZone: %s",
        math.floor(timeLeft / 60),
        math.floor(timeLeft % 60),
        killCount,
        isInZone and "✓" or "✗"
    )
    
    lib.showTextUI(text, {
        position = "top-center",
        style = {
            backgroundColor = isInZone and Config.NestEvent.ui.notifications.style.backgroundColor or '#8B0000',
            color = Config.NestEvent.ui.notifications.style.color
        }
    })
end

-- Création de la zone
local function CreateEventZone(coords)
    if eventZone then 
        eventZone:destroy()
        eventZone = nil
    end
    
    Debug("Création de la zone à " .. json.encode(coords))
    
    eventZone = CircleZone:Create(
        coords, 
        Config.NestEvent.area.radius,
        {
            name = "nest_event_zone",
            debugPoly = Config.NestEvent.Debug,
            useZ = true
        }
    )

    eventZone:onPlayerInOut(function(isPointInside, point)
        Debug("Changement de statut de zone: " .. tostring(isPointInside))
        isInZone = isPointInside
        TriggerServerEvent('nest-event:updatePlayerZoneStatus', isPointInside)
        
        if isPointInside then
            lib.notify({
                title = Config.NestEvent.ui.notifications.title,
                description = 'Zone sécurisée',
                type = 'success'
            })
        else
            lib.notify({
                title = Config.NestEvent.ui.notifications.title,
                description = Config.NestEvent.messages.zoneWarning,
                type = 'error'
            })
        end
        UpdateEventUI()
    end)
end

-- Gestion du coffre de récompenses
local function SpawnRewardBox(coords)
    if rewardBox and DoesEntityExist(rewardBox) then 
        DeleteEntity(rewardBox) 
    end
    
    local groundZ = coords.z
    local found, safeZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 10.0, true)
    if found then groundZ = safeZ end
    
    rewardBox = CreateObject(GetHashKey('prop_mil_crate_01'), coords.x, coords.y, groundZ, true, false, false)
    PlaceObjectOnGroundProperly(rewardBox)
    FreezeEntityPosition(rewardBox, true)
    SetEntityHeading(rewardBox, math.random(360))
    
    exports.ox_target:addLocalEntity(rewardBox, {
        {
            name = 'nest_reward_box',
            label = 'Récupérer les récompenses',
            icon = 'fas fa-box',
            canInteract = function()
                return true
            end,
            onSelect = function()
                if activeEvent then
                    TriggerServerEvent('nest-event:claimReward')
                    DeleteEntity(rewardBox)
                    rewardBox = nil
                end
            end
        }
    })

    -- Effet visuel
    lib.requestNamedPtfxAsset('core')
    UseParticleFxAssetNextCall('core')
    StartParticleFxLoopedAtCoord('ent_ray_heli_aprtmnt_l_fire', 
        coords.x, coords.y, groundZ,
        0.0, 0.0, 0.0, 
        1.0, false, false, false, false
    )
end

-- Début de l'événement
RegisterNetEvent('nest-event:start')
AddEventHandler('nest-event:start', function(data)
    Debug("Début de l'événement")
    if activeEvent then return end
    
    activeEvent = data
    eventStartTime = GetGameTimer()
    timeInZone = 0
    killCount = 0
    isInZone = false
    
    CreateEventZone(data.coords)
    
    lib.notify({
        title = Config.NestEvent.ui.notifications.title,
        description = Config.NestEvent.messages.start,
        type = 'inform',
        duration = 7500
    })
    
    -- Progress circle
    lib.progressCircle({
        duration = Config.NestEvent.timing.duration * 60 * 1000,
        position = Config.NestEvent.ui.progressCircle.position,
        label = Config.NestEvent.ui.progressCircle.label,
        useWhileDead = false,
        canCancel = false,
        disable = {
            move = false,
            car = false,
            combat = false,
            mouse = false
        }
    })
end)

-- Mise à jour des kills
RegisterNetEvent('nest-event:updateKills')
AddEventHandler('nest-event:updateKills', function(kills)
    if not activeEvent then return end
    
    local playerId = GetPlayerServerId(PlayerId())
    killCount = kills[playerId] or 0
    Debug("Kills mis à jour: " .. killCount)
    UpdateEventUI()
end)

-- Gérer un kill
AddEventHandler('onZombieDied', function(zombie)
    if not activeEvent then return end
    
    if GetPedSourceOfDeath(zombie) == PlayerPedId() then
        TriggerServerEvent('nest-event:registerKill')
        Debug("Kill enregistré")
    end
end)

-- Fin de l'événement
RegisterNetEvent('nest-event:end')
AddEventHandler('nest-event:end', function(data)
    Debug("Fin de l'événement")
    if not activeEvent then return end
    
    if data.success then
        SpawnRewardBox(activeEvent.coords)
        lib.notify({
            title = Config.NestEvent.ui.notifications.title,
            description = Config.NestEvent.messages.success,
            type = 'success'
        })
    else
        lib.notify({
            title = Config.NestEvent.ui.notifications.title,
            description = Config.NestEvent.messages.failed,
            type = 'error'
        })
    end
    
    if eventZone then
        eventZone:destroy()
        eventZone = nil
    end
    
    lib.hideTextUI()
    activeEvent = nil
    isInZone = false
    killCount = 0
end)

-- Récompenses réclamées
RegisterNetEvent('nest-event:rewardClaimed')
AddEventHandler('nest-event:rewardClaimed', function(rewards)
    if not rewards then return end
    
    if rewards.money and rewards.money > 0 then
        lib.notify({
            title = 'Récompense',
            description = string.format('Vous avez reçu $%d', rewards.money),
            type = 'success'
        })
    end
    
    if rewards.items then
        for _, item in ipairs(rewards.items) do
            lib.notify({
                title = 'Objet reçu',
                description = string.format('%dx %s', item.amount, item.name),
                type = 'success'
            })
        end
    end
end)

-- Erreur de récompense
RegisterNetEvent('nest-event:rewardError')
AddEventHandler('nest-event:rewardError', function(errorType)
    lib.notify({
        title = 'Erreur',
        description = Config.NestEvent.messages.reward.noAccess[errorType],
        type = 'error'
    })
end)

-- Thread principal
CreateThread(function()
    while true do
        Wait(1000)
        if activeEvent and isInZone then
            timeInZone = timeInZone + 1
            if timeInZone == Config.NestEvent.rewards.conditions.minTimeInZone then
                lib.notify({
                    title = Config.NestEvent.ui.notifications.title,
                    description = "Temps minimum de participation atteint !",
                    type = 'success'
                })
            end
        end
    end
end)
