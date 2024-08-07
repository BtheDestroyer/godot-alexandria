# Alexandria - A Native Database Addon for Godot 4

```gdscript
# ./database/player_data/schema.gd
class_name PlayerData extends Resource

@export var name: String
@export var gold := 0
@export var 
```

```gdscript
# res://gameplay.gd
extends Node

func _ready():
  # Initialize default file
  ResourceLoader.save(PlayerData.new(), "./database/player_data/john.res") # Standard Godot
  Alexandria.get_schema("player_data").create_entry("john") # Local Alexandria Database
  await AlexandriaNetClient.create_remote_entry("player_data", "john") # Remote Alexandria Database
  
  # Load resource file
  var resource: PlayerData = ResourceLoader.load("./database/player_data/john.res") # Standard Godot
  var local_db_resource: PlayerData = Alexandria.get_entry("player_data", "john") # Local Alexandria Database
  var remote_db_resource: PlayerData = await AlexandriaNetClient.get_entry("player_data", "john") # Remote Alexandria Database
  
  # Modify data in memory
  resource.name = "john"
  local_db_resource.name = "john"
  remote_db_resource.name = "john"
  
  # Update resource file
  ResourceLoader.save(resource, "./database/player_data/john.res") # Standard Godot
  Alexandria.get_schema("player_data").update_entry("john", local_db_resource) # Local Alexandria Database
  await AlexandriaNetClient.update_remote_entry("player_data", "john", local_db_resource) # Remote Alexandria Database
```

## Why?

I wanted to easily manage Resources for online Godot projects in an database without needing to write project-specific code for serializing, transmitting, deserializing, and validating those Resources.

Alexandria is a project attempting to fulfill this niche. The primary goal is to allow for Godot facilitate the creation of online games without *necessarily* writing any networking code.

## Disclaimer

If you're completely unfamiliar with online networking in software, note that you *do need* some form of server hardware that's accessible via the internet for your players to connect to.

This can be [a server you rent online](https://duckduckgo.com/?q=rent+linux+server), a professional-grade server you own, a cheap single-board-computer like a [Raspberry Pi](https://www.raspberrypi.com/products/) or [Orange Pi](http://www.orangepi.org/html/hardWare/computerAndMicrocontrollers/details/Orange-Pi-Zero-3.html), or even an old desktop you have lying around.

If you've never worked with this before, I'd recommend [trying to host a basic website first](https://duckduckgo.com/?q=nginx+webhosting+tutorial+for+beginners) as it shouldn't take long to get up and running, will teach you the basics of port forwarding, IP addresses, what DNS is, and managing software services on a server, and by the end of it you'll also have your own website running on a server you own!

## Modules

"Alexandria" is the name of the overarching project, but it's made up of various individual plugins:

- [alexandria.db](https://github.com/BtheDestroyer/godot-alexandria/tree/master/addons/alexandria.db)
  - Manages a local database.
- [alexandria.net](https://github.com/BtheDestroyer/godot-alexandria/tree/master/addons/alexandria.net)
  - Base networking interface for other plugins.
- [alexandria.netserver](https://github.com/BtheDestroyer/godot-alexandria/tree/master/addons/alexandria.netserver)
  - Server-side interface for remote database interactions.
  - Depends on `alexandria.net` and `alexandria.db`.
- [alexandria.netclient](https://github.com/BtheDestroyer/godot-alexandria/tree/master/addons/alexandria.netclient)
  - Client-side interface for remote database interactions.
  - Depends on `alexandria.net` and `alexandria.db`.
- [alexandria.webapi](https://github.com/BtheDestroyer/godot-alexandria/tree/master/addons/alexandria.webapi)
  - **Not yet implemented.**
  - Handles HTTP API requests for remote database interactions.
  - Depends on `alexandria.db`.

## Getting Started

### Terminology

When dealing with online games, "synchronisity" is an important factor - that is, if multiple players can see and interact with each other in real-time. The two terms used below to describe games on each side of this line are:

- "Asynchronous" online games being games where players *do not* interact in real-time; for example: [Neopets](https://www.neopets.com/)
- "Synchronous" online games being games where players *do* interact in real-time; for example: [World of Warcraft](https://worldofwarcraft.blizzard.com/) or [Minecraft](https://www.minecraft.net/)

### Install

- Copy the desired plugin modules into `res://addons/` in your Godot project and enable them in Project Settings.
  - For most projects, this will be `alexandria.db`, `alexandria.net`, and `alexandria.netclient`.
  - `alexandria.netserver` isn't necessary for asynchronous online games, but if you're *also* writing server-side code for a synchronous multiplayer game, it should be included in the project which acts as your server.
- Run your project from the editor once to create `res://alexandria.cfg` and `res://database/`.
- Open `res://alexandria.cfg` and set the following values:
  - If your project is client-side only (eg: asynchronous online games or synchronous online games with a separate server-side project), set `enable_local_database` under `[Alexandria]` to `false`.
    - This isn't strictly necessary, but can prevent mistakes.
  - Set `address` under `[AlexandriaNetClient]` to a WAN-facing address of the computer you'll be using as your database server.
    - Setting this to a domain name (eg: `database.example-website.com`) should be fine as Godot does DNS resolution.
    - `127.0.0.1` may be used for testing with the database server running on the same computer as your project.
  - `port` can be left as the default value, but if you *do* change it, remember to make sure it matches on your database server's `alexandria.cfg` when you get to configuring it.

### Creating Database Schemas

A "schema" is basically the definition of a database entry. With Alexandria, "schemas" are GDScript files which inherit from [Resource](https://docs.godotengine.org/en/stable/classes/class_resource.html). An "entry" is just an instance of that schema as a Resource file.

Alexandria expects all schema scripts be located in one of two places:

- `database/<schema_name>/schema.gd`
- `database/<schema_name>.gd`

*Note*: Database entries for a schema will be located at `database/<schema_name>/<entry_name>.res` (the `.tres` extension will be used if `entries_default_as_binary` under `[Alexandria]` is `false` in `alexandria.cfg`).

It's important to ensure both the Alexandria server and all clients have the same database schema files. If using [the default Alexandria server](https://github.com/BtheDestroyer/godot-alexandria/releases), copy your project's `res://database/` directory next to the Alexandria server. For example:

```
res://
+- addons/
+- database/
|  +- player_data/
|  |  +- schema.gd
|  +- shop/
|     +- schema.gd
+- godot.project

~/AlexandriaServer/
+- database/
|  +- player_data/
|  |  +- schema.gd
|  +- shop/
|     +- schema.gd
+- Alexandria.x86_64
```

Now when running the Alexandria server with `--headless` from a terminal, you should see output like this:

```
user@linux:~/Alexandria$ ./Alexandria.x86_64 --headless
Godot Engine v4.3.rc2.official.3978628c6 - https://godotengine.org

AlexandriaNetServer hosting @ *:34902
Alexandria loaded data for schema: player_data
Alexandria loaded data for schema: shop
Alexandria loaded 2 schemas.
Alexandria loaded 0 transactions.
```

### Interacting with the Remote Database

With the Alexandria server still running in the background, go to your Godot project and open a script on a node in your launch scene (eg: the title screen) and add this:

```gdscript
func _ready() -> void:
  # Wait to connect to the remote database
  while not AlexandriaNetClient.is_connected_to_server():
    await get_tree().create_timer(0.5).timeout

  # Load player's data
  var player_data: PlayerData = await AlexandriaNetClient.get_remote_entry("player_data", "example")
  if not player_data:
    # player_data/example doesn't exist yet, we have to create it
    match await AlexandriaNetClient.create_remote_entry("player_data", "example"):
      OK:
        pass
      var error:
        OS.alert("Failed to create player data: " + error_string(error))
        return
    player_data = await AlexandriaNetClient.get_remote_entry("player_data", "example")
    if player_data == null:
      OS.alert("Failed to get player data!")
      return

  # Modify the player's data
  player_data.gold += 100

  # Save the player's data
  match await AlexandriaNetClient.update_remote_entry("player_data", "example", player_data):
    OK:
      pass
    var error:
      OS.alert("Failed to update player data: " + error_string(error))
      return
```

This should provide a decent example of the three main interactions with Alexandria's database:

1. Creating entries: `AlexandriaNetClient.create_remote_entry("player_data", "example")`
2. Reading entries: `AlexandriaNetClient.get_remote_entry("player_data", "example")`
3. Updating entries: `AlexandriaNetClient.update_remote_entry("player_data", "example", player_data)`

You may also want to delete entries, which could be done with `AlexandriaNetClient.delete_remote_entry("player_data", "example")`.

Also note that while `AlexandriaNetClient.get_remote_entry("player_data", "example")` returned a `Resource` (automatically cast to `PlayerData`), most other methods of `AlexandriaNetClient` will return an `Error`. The above `match` syntax can be used to handle different errors in-place.

### Inheriting from Alexandria_Entry

While schema scripts *must* inherit from Resource (or any of its derived types), they may choose to inherit from `Alexandria_Entry` for "ownership" and access permissions.

By default, `AlexandriaNetServer` will allow *anyone* read any entry, but only the owner (being the user who created the entry) can update or delete it. These permissions can be modified by setting `owner_permissions` and `everyone_permissions` in your schema's `func _init() -> void`.

For example, maybe the owner should be able to only read and delete a schema's entries, but not arbitrarily update them:

```gdscript
class_name PlayerData extends Alexandria_Entry

@export var name: String
@export var gold := 0
@export var items := {
  "Potion": 1
}

func _init() -> void:
  owner_permissions = Alexandria_Entry.Permissions.READ | Alexandria_Entry.Permissions.DELETE
```

If an entry has no owner (eg: its owner's account was deleted *or* it was created without being logged in), then `owner_permissions` will *always* be used.

## Transactions

Certain database interactions are best considered as "atomic" (aka: they can't be broken up) or might be unsafe to allow any connected user to perform. For example, if I wanted to allow a player to buy an item from a shop, I *could* implement that feature entirely on the client-side like this:

```gdscript
func buy_item(shop_name: String, item_name: String) -> bool:
  var player_data: PlayerData = await AlexandriaNetClient.get_remote_entry("player_data", "example")
  var shop_data: Shop = await AlexandriaNetClient.get_remote_entry("shop", shop_name)

  if not player_data or not shop_data:
    return false

  if shop_data.item_counts.get(item_name, 0) <= 0 or player_data.gold <= shop_data.prices[item_name]:
    return false

  player_data.gold -= shop_data.prices[item_name]
  player_data.items[item_name] = player_data.items.get(item_name, 0) + 1
  shop_data.item_counts[item_name] -= 1

  if await AlexandriaNetClient.update_remote_entry("player_data", "example", player_data) != OK:
    return false
  if await AlexandriaNetClient.update_remote_entry("shop", shop_name, shop_data) != OK:
    return false

  return true
```

On the surface, this seems totally harmless. However, what would happen if `await AlexandriaNetClient.update_remote_entry("shop", shop_name, shop_data)` failed and returned an error? The player's `items` and `gold` have already been updated, so do we set them back? What if someone else updated the shop before this purchase could finish?

Even worse, allowing any player to directly modify the contents of any `Shop` or even their own `PlayerData` could allow them to easily cheat!

To mitigate this, we can create a `Transaction` on the server:

```gdscript
# database/buy_shop_item.gd
class_name Transaction_BuyShopItem extends Alexandria_Transaction

@export var player: String
@export var shop: String
@export var item: String
var player_data: PlayerData
var shop_data: Shop

func check_requirements() -> bool:
  # Run on the server, so read local entries
  player_data = Alexandria.get_entry("player_data", player)
  if not player_data:
    error_reason = "Failed to load player data"
    return false

  shop_data = Alexandria.get_entry("shop", shop)
  if not shop_data:
    error_reason = "Failed to load shop data"
    return false

  if shop_data.item_counts.get(item_name, 0) <= 0:
    error_reason = "Shop does not have any of that item"
    return false

  if player_data.gold <= shop_data.prices[item_name]:
    error_reason = "Player cannot afford item"
    return false

  return false

func apply() -> void:
  player_data.gold -= shop_data.prices[item_name]
  player_data.items[item_name] = player_data.items.get(item_name, 0) + 1
  shop_data.item_counts[item_name] -= 1

  Alexandria.get_schema("player_data").update_entry(player, player_data)
  Alexandria.get_schema("shop").update_entry(shop, shop_data)
```

Note that now `await` *is not being used*, which means all of `check_requirements()` and `apply()` is guaranteed to run sequentially without interruptions. It also means players no longer need access to modify their own data or shops to buy items, they just need access to this transaction.

Usage would look like this:

```gdscript
# Client-side code
func buy_item(shop_name: String, item_name: String) -> bool:
  var transaction := Transaction_BuyShopItem.new()
  transaction.player = "example"
  transaction.shop = shop_name
  transaction.item = item_name
  return await AlexandriaNetClient.apply_remote_transaction("buy_shop_item", transaction) == OK
```
