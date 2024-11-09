Config = {}

Config.SafeZones = {
    {coords = vector3(4.4551482200623, -1829.2199707031, 25.019714355469), radius = 25.0},
    {coords = vector3(117.71314239502, -1953.0933837891, 24.628721237183), radius = 60.0},
    {coords = vector3(2404.7822265625, 3108.1706542969, 48.120086669922), radius = 100.0},
    {coords = vector3(189.46621704102, -1654.0627441406, -7.7600207328796), radius = 50.0},
    -- add
}

Config.NestEvent = {
    -- Paramètres de base

    framework = {
        target = 'ox_target', -- 'ox_target' ou 'qb-target'
        
        -- For qb --
        chest = {
            coords = {
                offsetX = 0.0,
                offsetY = 0.0,
                offsetZ = -1.0
            },
            options = {
                distance = 2.0,
                icon = 'fas fa-gift'
            }
        }
    },
    
    nestType = 'horde_nest',  
    Debug = true,            -- Mis à true pour le debugging
    language = 'en',         -- 'fr' pour Français, 'en' pour Anglais

    -- Paramètres de timing
    timing = {
        dayChance = 100,          
        nightChance = 100,        
        checkInterval = 15,      
        duration = 6,            
        warningTimes = {3, 1}    
    },

    -- Paramètres de zone
    area = {
        radius = 50.0,          
        minSpawnDistance = 40.0, 
        maxSpawnDistance = 100.0 
    },

    -- Système de récompenses
    rewards = {
        money = {
            base = 1000,        
            perKill = 100,      
            survival = 500,
            timeBonus = {
                requiredTime = 180,   -- 3 minutes
                multiplier = 1.5
            }
        },
        
        items = {
            standard = {
                {name = 'bandage', chance = 70, amount = {min = 1, max = 3}},
            },
            
            rare = {
                {
                    name = 'inhibiteur',
                    chance = 25,
                    amount = 1,
                    requireKills = 5
                }
            }
        },
        
        conditions = {
            minTimeInZone = 60,    -- 1 minute
            minKills = 1,          
            perfectSurvival = true  
        }
    },

    -- Interface utilisateur
    ui = {
        notifications = {
            title = {
                fr = 'ÉVÉNEMENT NEST',
                en = 'NEST EVENT'
            },
            style = {
                backgroundColor = '#1c1c1c',
                color = '#ffffff'
            }
        },
    },   

    -- Messages et notifications
    messages = {
        -- Messages de base
        timeLeftTitle = {
            fr = "TEMPS DE SURVIE",
            en = "SURVIVAL TIME"
        },
        kills = {
            fr = "Kills",
            en = "Kills"
        },
        zone = {
            fr = "Zone",
            en = "Zone"
        },
        timeInZone = {
            fr = "Temps en zone",
            en = "Time in zone"
        },
        seconds = {
            fr = "secondes",
            en = "seconds"
        },
        timeBonusReached = {
            fr = "Bonus de temps débloqué !",
            en = "Time bonus unlocked!"
        },

        -- Messages d'événement
        start = {
            fr = "Un nid de ravageurs est apparu ! Survivez pendant 5 minutes !",
            en = "A ravager nest has appeared! Survive for 5 minutes!"
        },
        timeWarning = {
            fr = "Plus que %d minutes !",
            en = "%d minutes remaining!"
        },
        success = {
            fr = "Vous avez survécu à l'attaque !",
            en = "You survived the attack!"
        },
        failed = {
            fr = "L'événement a échoué...",
            en = "Event failed..."
        },
        zoneWarning = {
            fr = "Vous vous éloignez trop du nid !",
            en = "You're getting too far from the nest!"
        },
        zoneSecure = {
            fr = "Zone sécurisée",
            en = "Secure zone"
        },
        minTimeReached = {
            fr = "Temps minimum de participation atteint !",
            en = "Minimum participation time reached!"
        },
        killConditionMet = {
            fr = "Condition de kills atteinte !",
            en = "Kill condition met!"
        },
        newRecord = {
            fr = "Nouveau record ! %d kills !",
            en = "New record! %d kills!"
        },
        timeBonus = {
            fr = "Bonus de temps ! (+50% de récompenses)",
            en = "Time bonus! (+50% rewards)"
        },

        -- Messages de kill
        kill = {
            title = {
                fr = "Elimination",
                en = "Kill"
            },
            confirmed = {
                fr = "Elimination confirmée",
                en = "Kill confirmed"
            }
        },

        -- Messages de récompense
        reward = {
            title = {
                fr = "Récompense",
                en = "Reward"
            },
            claimReward = {
                fr = "Récupérer les récompenses",
                en = "Claim rewards"
            },
            moneyReceived = {
                fr = "Vous avez reçu %d$",
                en = "You received $%d"
            },
            timeBonus = {
                fr = "Bonus de temps appliqué !",
                en = "Time bonus applied!"
            },
            itemReceived = {
                fr = "Objet reçu",
                en = "Item received"
            },
            inventoryFull = {
                fr = "Inventaire plein !",
                en = "Inventory full!"
            },
            timeBonus = {
                fr = "Bonus de temps appliqué !",
                en = "Time bonus applied!"
            },
            noAccess = {
                lowKills = {
                    fr = "Pas assez de kills pour la récompense",
                    en = "Not enough kills for the reward"
                },
                lowTime = {
                    fr = "Temps de participation insuffisant",
                    en = "Insufficient participation time"
                },
                notParticipated = {
                    fr = "Vous n'avez pas participé",
                    en = "You did not participate"
                }
            }
        },

        -- Messages d'erreur
        error = {
            fr = "Erreur",
            en = "Error"
        },

        -- Messages admin
        admin = {
            eventStarted = {
                fr = "Événement démarré",
                en = "Event started"
            },
            eventStartedFor = {
                fr = "Événement démarré pour %s",
                en = "Event started for %s"
            },
            playerNotFound = {
                fr = "Joueur non trouvé",
                en = "Player not found"
            },
            eventCleaned = {
                fr = "Événement nettoyé",
                en = "Event cleaned"
            },
            noActiveEvent = {
                fr = "Aucun événement en cours",
                en = "No active event"
            },
            systemEnabled = {
                fr = "Système de Nest Events activé",
                en = "Nest Events system enabled"
            },
            systemDisabled = {
                fr = "Système de Nest Events désactivé",
                en = "Nest Events system disabled"
            }
        },

        -- Messages de stats
        stats = {
            title = {
                fr = "Statistiques",
                en = "Statistics"
            },
            total = {
                fr = "Total événements: %d\nKills totaux: %d\nArgent donné: %d$",
                en = "Total events: %d\nTotal kills: %d\nMoney given: $%d"
            },
            records = {
                fr = "Record de kills: %d\nMeilleur bonus temps: %d$",
                en = "Kill record: %d\nBest time bonus: $%d"
            }
        }
    }
}

function Config.NestEvent.GetText(path, text_params)
    local lang = Config.NestEvent.language
    local keys = {}
    
    for key in string.gmatch(path, "([^.]+)") do
        table.insert(keys, key)
    end
    
    local current = Config.NestEvent
    for _, key in ipairs(keys) do
        if current[key] then
            current = current[key]
        else
            print("^1[NEST-EVENT] Missing text key: " .. path .. "^7")
            return "MISSING_TEXT: " .. path
        end
    end
    
    if type(current) == "table" then
        if current[lang] then
            if text_params then
                return string.format(current[lang], text_params)
            else
                return current[lang]
            end
        else
            print("^1[NEST-EVENT] Missing translation for " .. lang .. ": " .. path .. "^7")
            return "MISSING_TRANSLATION: " .. path
        end
    end
    
    return "INVALID_PATH: " .. path
end
