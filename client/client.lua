local QBCore = exports['qb-core']:GetCoreObject()

-- Variables d'état
local activeEvent = nil
local eventZone = nil
local rewardBox = nil
local isInZone = false
local eventStartTime = 0
local timeInZone = 0

-- Debug
local function Debug(message)
    if Config.NestEvent.Debug then
        print('^3[NEST-EVENT] ^7' .. message)
    end
end

-- Création de la zone PolyZone
local function CreateEventZone(coords)
    if eventZone then eventZone:destroy() end
    
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
        isInZone = isPointInside
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

-- Interface UI avec ox_lib
local function UpdateEventUI()
    if not activeEvent then return end
    
    local timeLeft = Config.NestEvent.timing.duration * 60 - (GetGameTimer() - eventStartTime) / 1000
    local kills = (activeEvent.kills and activeEvent.kills[GetPlayerServerId(PlayerId())]) or 0
    
    if isInZone then
        lib.showTextUI(string.format(
            "ÉVÉNEMENT NEST\nTemps: %02d:%02d\nKills: %d\nZone: ✓",
            math.floor(timeLeft / 60),
            math.floor(timeLeft % 60),
            kills
        ), {
            position = "top-center",
            style = Config.NestEvent.ui.notifications.style
        })
    else
        lib.showTextUI(string.format(
            "ÉVÉNEMENT NEST\nTemps: %02d:%02d\nKills: %d\nZone: ✗",
            math.floor(timeLeft / 60),
            math.floor(timeLeft % 60),
            kills
        ), {
            position = "top-center",
            style = {
                backgroundColor = '#8B0000',
                color = '#ffffff'
            }
        })
    end
end

-- Gestion du coffre de récompenses
local function SpawnRewardBox(coords)
    if rewardBox and DoesEntityExist(rewardBox) then 
        DeleteEntity(rewardBox) 
    end
    
    rewardBox = CreateObject(GetHashKey('prop_mil_crate_01'), coords.x, coords.y, coords.z - 1.0, true, false, false)
    PlaceObjectOnGroundProperly(rewardBox)
    FreezeEntityPosition(rewardBox, true)
    
    exports.ox_target:addLocalEntity(rewardBox, {
        {
            name = 'nest_reward_box',
            label = 'Récupérer les récompenses',
            icon = 'fas fa-box',
            canInteract = function()
                return true
            end,
            onSelect = function()
                TriggerServerEvent('nest-event:claimReward')
                DeleteEntity(rewardBox)
                rewardBox = nil
            end
        }
    })

    -- Effet visuel pour le spawn
    lib.requestNamedPtfxAsset('core')
    UseParticleFxAssetNextCall('core')
    StartParticleFxLoopedAtCoord('ent_ray_heli_aprtmnt_l_fire', 
        coords.x, coords.y, coords.z,
        0.0, 0.0, 0.0, 
        1.0, false, false, false, false
    )
end

-- Début de l'événement
RegisterNetEvent('nest-event:start')
AddEventHandler('nest-event:start', function(data)
    activeEvent = data
    eventStartTime = GetGameTimer()
    timeInZone = 0
    
    CreateEventZone(data.coords)
    
    lib.notify({
        title = Config.NestEvent.ui.notifications.title,
        description = Config.NestEvent.messages.start,
        type = 'inform',
        duration = 7500
    })
    
    -- Progress circle pour le timer
    lib.progressCircle({
        duration = Config.NestEvent.timing.duration * 60 * 1000,
        position = Config.NestEvent.ui.progressCircle.position,
        label = Config.NestEvent.ui.progressCircle.label,
        useWhileDead = false,
        canCancel = false,
    })
end)

-- Mise à jour des kills
RegisterNetEvent('nest-event:updateKills')
AddEventHandler('nest-event:updateKills', function(kills)
    if activeEvent then
        activeEvent.kills = kills
        UpdateEventUI()
    end
end)

-- Fin de l'événement
RegisterNetEvent('nest-event:end')
AddEventHandler('nest-event:end', function(data)
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
end)

-- Récompenses réclamées
RegisterNetEvent('nest-event:rewardClaimed')
AddEventHandler('nest-event:rewardClaimed', function(rewards)
    if rewards.money > 0 then
        lib.notify({
            title = 'Récompense',
            description = string.format('Vous avez reçu $%d', rewards.money),
            type = 'success'
        })
    end
    
    for _, item in ipairs(rewards.items) do
        lib.notify({
            title = 'Objet reçu',
            description = string.format('%dx %s', item.amount, item.name),
            type = 'success'
        })
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

-- Thread pour tracker le temps dans la zone
CreateThread(function()
    while true do
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
        Wait(1000)
    end
end)

-- Thread pour les mises à jour UI
CreateThread(function()
    while true do
        if activeEvent then
            UpdateEventUI()
        end
        Wait(1000)
    end
end)