# Puppygistics

A logistics mainframe for CC: Tweaked inspired by Factorio's [Logistic Networks](https://wiki.factorio.com/Logistic_network).

## Installation
Download and run the installer on a CC: Tweaked terminal
```
wget run https://raw.githubusercontent.com/lexifuzzpup/puppygistics/refs/heads/main/installer.lua
```

## Configuration
`storage.json` is a file that outlines the entire storage network. Inside, there are four types of storage peripherals:

* Active provider (`active_provider`)
    * Will attempt to push all of its contents into the network. Pushes into requesters first, then storage.
    * Requires no configuration
* Passive provider (`passive_provider`)
    * Will act as a source for items. It does not try to push contents outwards. Items will not automatically be inserted.
    * Requires no configuration
* Storage (`storage`)
    * Neutral inventory. Does not push or pull anything on its own.
    * Requires no configuration
* Requester (`requester`)
    * Will attempt to pull contents from the network. Pulls from active providers first, then passive providers, then finally storage.
    * Requires desired items to be set. Use an `"item": count` format for configuration.

Below is an example of a `storage.json` file:
```json
{
    "systems": [
        {
            "active_providers": {
                "minecraft:chest_7": {}
            },
            "passive_providers": {
                "minecraft:chest_1": {}
            },
            "storages": {
                "minecraft:chest_3": {},
                "minecraft:chest_4": {},
                "minecraft:chest_5": {},
                "minecraft:chest_6": {}
            },
            "requesters": {
                "minecraft:chest_2": {
                    "minecraft:stone": 64
                }
            }
        }
    ]
}
```

When items are inserted into `minecraft:chest_7`, they will be pushed into the network. If stone is inserted, and `minecraft:chest_2` needs stone, it will be pulled there. Otherwise, it will be inserted into storage.

When items are inserted into `minecraft:chest_1`, and `minecraft:chest_2` needs stone (and `minecraft:chest_7` has none), then stone will be moved from `minecraft:chest_1` to `minecraft:chest_2`.

If `minecraft:chest_2` has less than 64 stone, and it's only available in storage, it will be pulled from the storages sequentially. If it has 64 or more stone, it will not pull any more stone from the network.