# Getting Started with Godot XMB

The Godot XMB save system uses an **Adapter Pattern**. Instead of forcefully calling `save` from within individual nodes, your game will *register* an adapter object (like your Main Game Scene or a Game Manager Singleton). When a save or load occurs, `XMBSave` will dynamically call your registered methods to hand off or receive state data!

## 1. Registering the Save Adapter

First, designate a node (typically your main game script, player controller, or a state manager) as the Save Adapter. You must register it into the system, preferably in `_ready()` or right before opening the menus.

```gdscript
extends Node3D

func _ready():
    # Registers this script as the authority on save data.
    XMBSave.register_save_adapter(
        self, 
        "capture_save_state", 
        "apply_save_state", 
        "capture_save_icon" # Optional
    )
```

## 2. Implementing the Adapter Methods

Now, implement the exact methods you passed during registration:

```gdscript
# Called automatically when the XMB UI confirms an Overwrite or Create!
func capture_save_state() -> Dictionary:
    # 2D or 3D - the logic is the same! Gather your node transforms, health, etc.
    return {
        "player_position_x": $Player.global_position.x,
        "player_position_y": $Player.global_position.y,
        "player_position_z": $Player.global_position.z, # For 3D
        "health": $Player.current_health,
        "inventory": $Player.inventory_items
    }

# Called automatically when the XMB UI confirms a Load, AFTER it changes the scene
func apply_save_state(save_data: Dictionary) -> void:
    var pos_x = save_data.get("state", {}).get("player_position_x", 0.0)
    var pos_y = save_data.get("state", {}).get("player_position_y", 0.0)
    var pos_z = save_data.get("state", {}).get("player_position_z", 0.0)
    
    # Apply to 3D Player (For 2D, drop the Z axis)
    $Player.global_position = Vector3(pos_x, pos_y, pos_z)
    
    $Player.current_health = save_data.get("state", {}).get("health", 100)
    $Player.inventory_items = save_data.get("state", {}).get("inventory", [])

# (Optional) Called automatically to snag a custom icon.
# If omitted or if it returns null, the XMB system automatically captures the screen!
func capture_save_icon() -> Image:
    return load("res://custom_save_icon.png").get_image()
```

## 3. Opening the XMB Menus

Whenever you want the user to interact with the save system, just call the exact menu you need. The system entirely manages pausing, input focus, and blocking UI behind it safely via `XMBSave.ui_protection`.

### From a Title Screen (Creating / Loading)
```gdscript
# Pops up the context to forge a brand-new save, then warps you automatically to your level scene
XMBSave.default_game_scene_path = "res://levels/level_01.tscn"
XMBSave.open_create_menu()

# Opens a loader that reads the metadata and then automatically warps into the saved scene
XMBSave.open_load_menu()
```

### From a Pause Menu or Save Point (Overwriting / Dynamic Saving)
```gdscript
# Opens the standard mid-game Save Menu format, padded intelligently out to 10 slots
XMBSave.open_save_menu()
```

By keeping the menu open logic simple and the data extraction logic safely tucked into an Adapter, your 2D and 3D scenes will seamlessly support saving at minimal performance cost!

Next up: Check out the [API Reference](api_reference.md) for full commands.
