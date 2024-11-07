# GLD-NestEvent

A dynamic zombie nest event system for HRS_Zombies_V2/QBCore.

> [!IMPORTANT]
> This bundle works with version 2.0 (2024-10-24) of HRS zombie, check if it is up to date, otherwise some exports may not work


## Features

- Dynamic zombie nest events
- Survival zone system
- Player tracking and rewards
- Interactive reward chest
- Day/night spawn rates
- Admin commands
- Fully configurable

## Dependencies

- QBCore
- PolyZone
- ox_lib
- hrs_zombies_V2 -> https://hrs-scripts.tebex.io/

## Installation

1. Ensure you have all dependencies installed
2. Place the `gld-nestevent` folder in your `resources` directory
3. Add `ensure gld-nestevent` to your `server.cfg`
4. Configure the script in `config.lua`

## Configuration

All settings can be found in `config.lua`:
- Event timings
- Spawn chances
- Rewards
- Zone sizes
- UI settings

## Admin Commands

- `/forcenest [playerID]` - Force spawn a nest event
- `/clearnest` - Clear current event
- `/togglenest` - Enable/disable the system
- `/nestinfo` - Get current event info
>[!WARNING]
>## Add NestType in config HRS zombie
```
['horde_nest'] = {
        propModel = `prop_pile_dirt_06`,
        pedsType = 'military',
        zChange = -1.0,
        damageRadius = 0.0,
        damagePed = 15,
        drawDistance = 120.0, ---- recommended value
        blip = {
            label = "Horde",
            color = 1,
            alpha = 128,
            scale = 1.0,
            sprite = 378,
            shortRange = true  
        }, -- false will disable it
        maxHealth = 10.00,
        regenTime = 120, --- seconds
        maxZombies = 70,
        ptfx = true
    },
```

## Support

For support or questions: fabgros.

## License

This resource is protected under copyright law.

> [!NOTE]
> This is my first Lua script, so here I am, offering you this little bundle! It’s not perfect, there are still some inconsistencies ... but the main goal is to have fun. I’ll be updating the script regularly to improve it, setting myself a small challenge and immersing myself in the world of Lua development!
