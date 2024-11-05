# GLD-NestEvent

A dynamic zombie nest event system for HRS_Zombies_V2/QBCore.

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

## Support

For support or questions: fabgros.

## License

This resource is protected under copyright law.
