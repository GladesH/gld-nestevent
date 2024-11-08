local QBCore = exports['qb-core']:GetCoreObject()

-- Variables d'état
local activeEvent = nil
local eventZone = nil
local rewardBox = nil
local isInZone = false
local eventStartTime = 0
local timeInZone = 0
local killCount = 0
local particleEffects = {}
local hasParticipated = false

-- Debug sécurisé
local function Debug(message)
    if Config and Config.NestEvent and Config.NestEvent.Debug then
        print('^3[NEST-EVENT] ^7' .. message)
    end
end

-- Cleanup des effets
local function CleanupParticleEffects()
    for _, effect in ipairs(particleEffects) do
        if effect and DoesParticleFxLoopedExist(effect) then
            StopParticleFxLooped(effect, 0)
        end
    end
    particleEffects = {}
end

-- Format du temps
local function FormatTime(seconds)
    return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

-- Mise à jour de l'UI
local function UpdateEventUI()
    if not activeEvent then 
        lib.hideTextUI()
        return 
    end
    
    local timeLeft = math.max(0, Config.NestEvent.timing.duration * 60 - (GetGameTimer() - eventStartTime) / 1000)
    local bonusUnlocked = timeInZone >= Config.NestEvent.rewards.money.timeBonus.requiredTime
    
    local text = string.format(
        "%s \n %s\n | %s: %d | \n%s: %s\n%s: %s/%s%s",
        Config.NestEvent.GetText('messages.timeLeftTitle'),
        FormatTime(math.floor(timeLeft)),
        Config.NestEvent.GetText('messages.kills'),
        killCount,
        Config.NestEvent.GetText('messages.zone'),
        isInZone and "✓" or "✗",
        Config.NestEvent.GetText('messages.timeInZone'),
        FormatTime(timeInZone),
        FormatTime(Config.NestEvent.rewards.money.timeBonus.requiredTime),
        bonusUnlocked and " ✨" or ""
    )
    
    lib.showTextUI(text, {
        position = "top-center",
        style = {
            backgroundColor = isInZone and Config.NestEvent.ui.notifications.style.backgroundColor or '#8B0000',
            color = Config.NestEvent.ui.notifications.style.color
        }
    })
end

function onEnterZone()
    isInZone = true
    hasParticipated = true
    Debug("Entrée dans la zone, envoi du statut au serveur")
    TriggerServerEvent('nest-event:updatePlayerZoneStatus', true)
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
        
        if isPointInside then
            onEnterZone()
            lib.notify({
                title = Config.NestEvent.GetText('ui.notifications.title'),
                description = Config.NestEvent.GetText('messages.zoneSecure'),
                type = 'success'
            })
        else
            isInZone = false
            lib.notify({
                title = Config.NestEvent.GetText('ui.notifications.title'),
                description = Config.NestEvent.GetText('messages.zoneWarning'),
                type = 'error'
            })
        end
        
        TriggerServerEvent('nest-event:updatePlayerZoneStatus', isPointInside)
        UpdateEventUI()
    end)
end

-- Gestion du coffre de récompenses
local function SpawnRewardBox(coords)
    if rewardBox and DoesEntityExist(rewardBox) then 
        DeleteEntity(rewardBox) 
    end
    
    -- Trouver le sol de manière plus précise
    local ground, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 10.0, true)
    if not ground then
        Debug("Impossible de trouver le sol pour le coffre")
        return
    end

    local finalCoords = vector3(coords.x, coords.y, groundZ)
    
    -- Vérifier si le point est valide (pas dans un objet)
    local rayHandle = StartShapeTestRay(
        finalCoords.x, finalCoords.y, finalCoords.z + 2.0,
        finalCoords.x, finalCoords.y, finalCoords.z - 2.0,
        1, 0, 7
    )
    local _, hit, hitCoords = GetShapeTestResult(rayHandle)
    
    if hit then
        finalCoords = hitCoords
    end
    
    -- Spawn du coffre
    rewardBox = CreateObject(GetHashKey('prop_mil_crate_01'), finalCoords.x, finalCoords.y, finalCoords.z, true, false, false)
    
    if not DoesEntityExist(rewardBox) then
        Debug("Erreur lors de la création du coffre")
        return
    end

    PlaceObjectOnGroundProperly_2(rewardBox)
    FreezeEntityPosition(rewardBox, true)
    SetEntityAsMissionEntity(rewardBox, true, true)

    -- Effet visuel
    lib.requestNamedPtfxAsset('core')
    UseParticleFxAssetNextCall('core')
    local effect = StartParticleFxLoopedAtCoord(
        'ent_ray_heli_aprtmnt_l_fire', 
        finalCoords.x, finalCoords.y, finalCoords.z,
        0.0, 0.0, 0.0, 
        1.0, false, false, false, false
    )
    table.insert(particleEffects, effect)

    -- Configuration de l'interaction
    if Config.NestEvent.framework.target == 'qb-target' then
        exports['qb-target']:AddTargetEntity(rewardBox, {
            options = {
                {
                    type = "client",
                    event = "nest-event:claimReward",
                    icon = "fas fa-box",
                    label = Config.NestEvent.GetText('messages.reward.claimReward'),
                    action = function(entity)
                        if not hasParticipated then
                            lib.notify({
                                title = Config.NestEvent.GetText('messages.error'),
                                description = Config.NestEvent.GetText('messages.reward.noAccess.notParticipated'),
                                type = 'error'
                            })
                            return
                        end
        
                        TriggerServerEvent('nest-event:claimReward', timeInZone)
                        DeleteEntity(rewardBox)
                        rewardBox = nil
                        CleanupParticleEffects()
                    end
                }
            },
            distance = Config.NestEvent.framework.chest.options.distance
        })
    elseif Config.NestEvent.framework.target == 'ox_target' then
        exports.ox_target:addLocalEntity(rewardBox, {{
            name = 'nest_reward_box',
            label = Config.NestEvent.GetText('messages.reward.claimReward'),
            icon = 'fas fa-box',
            distance = 3.0,
            onSelect = function()
                if not hasParticipated then
                    lib.notify({
                        title = Config.NestEvent.GetText('messages.error'),
                        description = Config.NestEvent.GetText('messages.reward.noAccess.notParticipated'),
                        type = 'error'
                    })
                    return
                end
                
                TriggerServerEvent('nest-event:claimReward', timeInZone)
                DeleteEntity(rewardBox)
                rewardBox = nil
                CleanupParticleEffects()
            end
        }})
    end

    Debug("Coffre de récompense créé avec succès à " .. json.encode(finalCoords))
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
    hasParticipated = false
    bonusTimeReached = false
    CleanupParticleEffects()
    
    CreateEventZone(data.coords)
    
    -- Vérifier si le joueur est déjà dans la zone au début
    if eventZone and eventZone:isPointInside(GetEntityCoords(PlayerPedId())) then
        onEnterZone()
    end
    
    lib.notify({
        title = Config.NestEvent.GetText('ui.notifications.title'),
        description = Config.NestEvent.GetText('messages.start'),
        type = 'inform',
        duration = 7500
    })
    
    PlaySoundFrontend(-1, "Mission_Pass_Notify", "DLC_HEISTS_GENERAL_FRONTEND_SOUNDS", 0)
end)

-- Fin de l'événement
RegisterNetEvent('nest-event:end')
AddEventHandler('nest-event:end', function(data)
    Debug("Fin de l'événement")
    if not activeEvent then return end
    
    -- Supprimer le nest via l'export
    if activeEvent.id then
        exports.hrs_zombies_V2:DeleteNest(activeEvent.id)
        Debug("Nest supprimé: " .. activeEvent.id)
    end
    
    if data.success then
        SpawnRewardBox(activeEvent.coords)
        local message = Config.NestEvent.GetText('messages.success')
        if bonusTimeReached then
            message = message .. "\n" .. Config.NestEvent.GetText('messages.timeBonus')
        end
        
        lib.notify({
            title = Config.NestEvent.GetText('ui.notifications.title'),
            description = message,
            type = 'success'
        })
        PlaySoundFrontend(-1, "Mission_Pass_Notify", "DLC_HEISTS_GENERAL_FRONTEND_SOUNDS", 0)
    else
        lib.notify({
            title = Config.NestEvent.GetText('ui.notifications.title'),
            description = Config.NestEvent.GetText('messages.failed'),
            type = 'error'
        })
        PlaySoundFrontend(-1, "Mission_Failed", "DLC_HEISTS_GENERAL_FRONTEND_SOUNDS", 0)
    end
    
    if eventZone then
        eventZone:destroy()
        eventZone = nil
    end
    
    CleanupParticleEffects()
    lib.hideTextUI()
    activeEvent = nil
    isInZone = false
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
        
        lib.notify({
            title = Config.NestEvent.GetText('messages.kill.title'),
            description = Config.NestEvent.GetText('messages.kill.confirmed'),
            type = 'success'
        })
        
        PlaySoundFrontend(-1, "MEDAL_BRONZE", "HUD_AWARDS", 0)
    end
end)

-- Récompenses réclamées
RegisterNetEvent('nest-event:rewardClaimed')
AddEventHandler('nest-event:rewardClaimed', function(rewards)
    if not rewards then return end
    
    if rewards.money and rewards.money > 0 then
        local description = string.format(
            Config.NestEvent.GetText('messages.reward.moneyReceived'),
            rewards.money
        )
        
        if rewards.timeBonus then
            description = description .. "\n" .. Config.NestEvent.GetText('messages.reward.timeBonus')
        end
        
        lib.notify({
            title = Config.NestEvent.GetText('messages.reward.title'),
            description = description,
            type = 'success'
        })
        PlaySoundFrontend(-1, "WEAPON_PURCHASE", "HUD_AMMO_SHOP_SOUNDSET", 0)
    end
    
    if rewards.items then
        local delay = 0
        for _, item in ipairs(rewards.items) do
            SetTimeout(delay, function()
                lib.notify({
                    title = Config.NestEvent.GetText('messages.reward.itemReceived'),
                    description = string.format('%dx %s', item.amount, item.name),
                    type = 'success'
                })
                PlaySoundFrontend(-1, "PICK_UP", "HUD_FRONTEND_DEFAULT_SOUNDSET", 0)
            end)
            delay = delay + 800
        end
    end
end)

-- Thread principal pour le compteur de temps dans la zone
CreateThread(function()
    while true do
        Wait(1000)
        if activeEvent and isInZone then
            timeInZone = timeInZone + 1
            
            -- Vérifier si le bonus de temps est atteint
            if timeInZone == Config.NestEvent.rewards.money.timeBonus.requiredTime then
                bonusTimeReached = true
                lib.notify({
                    title = Config.NestEvent.GetText('ui.notifications.title'),
                    description = Config.NestEvent.GetText('messages.timeBonusReached'),
                    type = 'success'
                })
                PlaySoundFrontend(-1, "CHALLENGE_UNLOCKED", "HUD_AWARDS", 0)
            end
            
            UpdateEventUI()
        end
    end
end)

-- Thread séparé pour l'UI
CreateThread(function()
    while true do
        Wait(1000)
        if activeEvent then
            UpdateEventUI()
        end
    end
end)

-- Vérification des routes
RegisterNetEvent('nest-event:checkRoadLocation')
AddEventHandler('nest-event:checkRoadLocation', function(coords)
    local isOnRoad = IsPointOnRoad(coords.x, coords.y, coords.z, 0)
    TriggerServerEvent('nest-event:roadCheckResult', coords, isOnRoad)
end)

-- Nettoyage à l'arrêt de la ressource
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    if rewardBox and DoesEntityExist(rewardBox) then
        DeleteEntity(rewardBox)
    end
    
    if eventZone then
        eventZone:destroy()
    end
    
    CleanupParticleEffects()
    lib.hideTextUI()
    
    if activeEvent and activeEvent.id then
        exports.hrs_zombies_V2:DeleteNest(activeEvent.id)
        Debug("Nest supprimé lors de l'arrêt de la ressource")
    end
    
    Debug("Ressource arrêtée, nettoyage effectué")
end)

-- Initialisation
CreateThread(function()
    Wait(1000)
    Debug("Client initialisé")
end)
