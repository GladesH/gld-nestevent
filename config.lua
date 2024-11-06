Config = {}

Config.NestEvent = {
    -- Paramètres de base
    nestType = 'horde_nest',  -- Type de nest de hrs_zombies_V2
    Debug = true,            -- Mode debug

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
        minSpawnDistance = 15.0, -- Distance minimum du joueur
        maxSpawnDistance = 35.0 -- Distance maximum du joueur
    },

    -- Système de récompenses
    rewards = {
        -- Récompenses monétaires
        money = {
            base = 0,        -- Récompense de base
            perKill = 0,      -- Par kill
            survival = 0      -- Bonus de survie
        },
        
        -- Récompenses items
        items = {
            -- Items standards (plus grande chance)
            standard = {
                {name = 'bandage', chance = 70, amount = {min = 4, max = 6}},
                {name = 'old_money', chance = 100, amount = {min = 500, max = 5899}},
                {name = 'plastic', chance = 70, amount = {min = 2, max = 8}},
                {name = 'battery', chance = 50, amount = {min = 1, max = 3}},
                {name = 'copper', chance = 70, amount = {min = 1, max = 6}},
                -- Ajoutez d'autres items standards ici
            },
            
            -- Items rares (plus faible chance)
            rare = {
                {
                    name = 'inhibiteur1',
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
            title = 'Nid de Ravageur',
            style = {
                backgroundColor = '#1c1c1c',
                color = '#ffffff'
            }
        },
    },   
    -- Messages et notifications
    messages = {
        start = "Un nid de ravageurs est apparu ! Survivez pendant 5 minutes !",
        timeWarning = "Plus que %d minutes !",
        success = "Vous avez survécu à l'attaque !",
        failed = "C'est trop tard , les Ravageur on pris le dessus",
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

    -- Modif de spawn des Nest
    
}

Config.NestEvent.spawnPreferences = {
    preferRoads = true,

}
Config.NestEvent.spawnCheck = {
    maxHeight = 0.5,            -- Différence maximale de hauteur acceptable
    checkRadius = 2.0,          -- Rayon de vérification autour du point de spawn
    minGroundDistance = 0.5,    -- Distance minimale du sol
    maxGroundDistance = 1.0     -- Distance maximale du sol
} 
-- cette configue d'après pita sur cfx.re peut améliorer le spawn mais j'ai pas trop vue la diff 
