Config = {}

Config.NestEvent = {
    -- Paramètres de base
    nestType = 'horde_nest',  -- Type de nest de hrs_zombies_V2
    Debug = false,            -- Mode debug

    -- Timing des événements
    timing = {
        dayChance = 20,          -- Chance d'apparition le jour (%)
        nightChance = 30,        -- Chance d'apparition la nuit (%)
        checkInterval = 15,      -- Minutes entre chaque check
        duration = 5,            -- Durée de l'événement en minutes
        warningTimes = {3, 1}    -- Minutes restantes pour les notifications
    },

    -- Paramètres de zone
    area = {
        radius = 50.0,          -- Rayon de la zone de survie
        minSpawnDistance = 20.0, -- Distance minimum du joueur
        maxSpawnDistance = 100.0 -- Distance maximum du joueur
    },

    -- Système de récompenses
    rewards = {
        -- Récompenses monétaires
        money = {
            base = 1000,        -- Récompense de base
            perKill = 100,      -- Par kill
            survival = 500      -- Bonus de survie
        },
        
        -- Récompenses items
        items = {
            -- Items standards (plus grande chance)
            standard = {
                {name = 'bandage', chance = 70, amount = {min = 1, max = 3}},
                -- Ajoutez d'autres items standards ici
            },
            
            -- Items rares (plus faible chance)
            rare = {
                {
                    name = 'inhibiteur',
                    chance = 25,
                    amount = 1,
                    requireKills = 5  -- Minimum kills requis
                }
                -- Ajoutez d'autres items rares ici
            }
        },
        
        -- Conditions pour les récompenses
        conditions = {
            minTimeInZone = 60,    -- Temps minimum dans la zone (secondes)
            minKills = 1,          -- Kills minimum
            perfectSurvival = true  -- Bonus si jamais sorti de la zone
        }
    },

    -- Interface utilisateur
    ui = {
        notifications = {
            title = 'ÉVÉNEMENT NEST',
            style = {
                backgroundColor = '#1c1c1c',
                color = '#ffffff'
            }
        },
        
        progressCircle = {
            position = 'top-middle',
            label = 'SURVIE PENDANT 5 MIN'
        }
    },

    -- Messages et notifications
    messages = {
        start = "Un nid de ravageurs est apparu ! Survivez pendant 5 minutes !",
        timeWarning = "Plus que %d minutes !",
        success = "Vous avez survécu à l'attaque !",
        failed = "L'événement a échoué...",
        reward = {
            success = "Récompenses récupérées !",
            noAccess = {
                lowKills = "Pas assez de kills pour la récompense",
                lowTime = "Temps de participation insuffisant",
                notParticipated = "Vous n'avez pas participé"
            }
        },
        zoneWarning = "Vous vous éloignez trop du nid !"
    }
}
