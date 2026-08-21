# Puppygistics

A logistics mainframe for CC: Tweaked inspired by Factorio's [Logistic Networks](https://wiki.factorio.com/Logistic_network).

## Installation
Download and run the installer on a CC: Tweaked terminal
```
wget run https://raw.githubusercontent.com/lexifuzzpup/puppygistics/refs/heads/main/installer.lua
```

## System Settings
There are CC-level settings available for the computer. Use the `set <name> <value>` shell command to change them.
* **logging.level** - *number*
    * Logging level for the system.
    * verbose=0, debug=1, info=2, warning=3, error=4, fatal=5
    * Default: 2
* **logging.file.enabled** - *boolean*
    * Whether or not to log to a file
    * With long-running systems, the disk storage can quickly fill up, so disabling logging helps prevent that from happening
    * Default: false
* **puppygistics.updates.active_provider** - *number*
    * Frequency (in updates) at which active_provider inventories should be re-polled
    * Default: 1
* **puppygistics.updates.passive_provider** - *number*
    * Frequency (in updates) at which passive_provider inventories should be re-polled
    * Default: 1
* **puppygistics.updates.storage** - *number*
    * Frequency (in updates) at which storage inventories should be re-polled
    * Default: 20
* **puppygistics.updates.requester** - *number*
    * Frequency (in updates) at which requester inventories should be re-polled
    * Default: 1
* **puppygistics.compacting.enabled** - *boolean*
    * Enables storage compaction on startup and at set intervals
    * Default: false
* **puppygistics.compacting.interval** - *number*
    * How many seconds should pass between storage compactions
    * Default: 50
* **puppygistics.parallelism** - *number*
    * How many parallel inventory operations to allow
    * More is faster, but has a higher chance to hang the system.
    * Default: 128

## Configuration
`puppygistics.config.lua` is a file that outlines the entire logistics network. Inside, there are three types of storage peripherals:

* Active provider (`active_provider`)
    * Will attempt to pFush all of its contents into the network. Pushes into requesters first, then storage.
    * Requires no configuration
* Passive provider (`passive_provider`)
    * Will act as a source for items. It does not try to push contents outwards. Items will not automatically be inserted.
    * Requires no configuration
* Requester (`requester`)
    * Will attempt to pull contents from the network. Pulls from active providers first, then passive providers, then finally storage.
    * Requires desired items to be set. Use an `"item": count` format for configuration in `options.filter`.
* Storage (`storage`)
    * Neutral inventory. Does not push or pull anything on its own.
    * Requires no configuration

Below is an example of a `puppygistics.config.lua` file:
```lua
{
    members = {
        ["minecraft:chest_1"] = {
            type = "active_provider"
        },
        "minecraft:chest_2" = {
            type = "passive_provider"
        },
        "minecraft:chest_3" = {
            type = "requester",
            options = {
                filter = {
                    ["minecraft:stone"] = 64
                }
            }
        },
        "minecraft:chest_4" = {
            type = "storage"
        }
    }
}
```

When items are inserted into `minecraft:chest_1`, they will be pushed into the network. If stone is inserted, and `minecraft:chest_3` needs stone, it will be pulled there. Otherwise, it will be inserted into storage.

When items are inserted into `minecraft:chest_2`, and `minecraft:chest_3` needs stone (and `minecraft:chest_4` has none), then stone will be moved from `minecraft:chest_2` to `minecraft:chest_3`.

If `minecraft:chest_3` has less than 64 stone, and it's only available in `minecraft:chest_4`, it will be pulled from `minecraft:chest_4`. If it has 64 or more stone, it will not pull any more stone from the network.