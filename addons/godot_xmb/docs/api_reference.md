# XMBSave API Reference

The `XMBSave` singleton is an AutoLoad injected into `project.godot` located at `res://addons/godot_xmb/scripts/api.gd`. You can call these variables and methods globally from any script.

## Properties

| Variable | Type | Description |
|---|---|---|
| `default_game_scene_path` | `String` | The default `.tscn` file path to swap to when starting a brand new game or if a save payload lacks a `scene_path`. |
| `current_save_id` | `String` | A UNIX-timestamp string uniquely identifying the active mounted save in `user://saves/`. Empty string if not saved yet. |
| `ui_protection` | `bool` | True by default. Forces the background UI to release keyboard / gamepad focus while the Save Menu is visible, drastically reducing navigation bleed bugs. |

## Constants

| Constant | Value | Description |
|---|---|---|
| `MAX_SAVE_SLOTS` | `10` | Total slot limit; excess autosaves are trimmed automatically. |
| `AUTOSAVE_SLOT_ID` | `"autosave"` | Fixed slot written by autosaves in "overwrite" mode, so manual saves are never replaced. |
| `MenuMode` | `enum` | `LOAD`, `SAVE`, `CREATE`. |

## Menu Opening Methods

### `open_create_menu(scene_path := "")`
Instantiates and mounts the Create Menu layout. It accepts an optional `scene_path` argument that forces it to warp to a specific map upon finalizing. Otherwise, it uses `default_game_scene_path`. **Recommended for use from Title Screens.**

### `open_load_menu()`
Instantiates and mounts the Load Menu layout, populated dynamically by saves inside your user filesystem.

### `open_save_menu()`
Instantiates and mounts the active mid-game Save Menu, mapping empty slots visually for clean structural layouts and enabling the 'Overwrite', 'Create', 'Copy', and 'Delete' functions natively.

## Adapter Management Core

### `register_save_adapter(target: Object, capture_method: StringName, apply_method: StringName, icon_method: StringName)`
Registers a node `target` (typically `self`) that the plugin utilizes as a callback proxy when structuring its payloads.

### `unregister_save_adapter(target: Object)`
Flushes out the internal variables linked to an adapter ensuring memory leaks bypass if a node leaves the tree awkwardly.

## Manual Invocation Triggers

*(Note: The XMB UI manages these calls natively in standard implementations. Access them manually if writing auto-save structures.)*

### `save_new(extra_data: Dictionary = {}, icon: Image = null) -> bool`
Constructs a brand new folder footprint and ID, resetting current playtime, and forcing a transition into `pending_create_scene_path`. Useful for brand new journeys!

### `save_current_as_new(extra_data: Dictionary = {}, icon: Image = null) -> bool`
Identical logic to an overwrite save (preserving playtime and current level bindings), but intelligently allocates a brand new UNIX ID to separate its lineage. Used directly by "Empty Slots" nested mid-game.

### `_save_overwrite(id: String, extra_data: Dictionary = {}, icon: Image = null) -> bool`
Directly writes or overwrites to a specific UUID `id`, pushing a newly captured play state to disk.

### `copy_save(id: String) -> bool`
Perfectly encapsulates cloning a targeted payload and icon context into an entirely disjoint UUID slot.

### `delete_save(id: String) -> void`
Erases a save metadata node fully.

### `copy_save(id: String) -> bool`
Perfectly encapsulates cloning a targeted payload and icon context into an entirely disjoint UUID slot.

## Autosave

Autosaves are manual invocations of the same file pipeline with `save_type: "autosave"`,
so they are listed alongside manual saves but are the only entries ever trimmed to make
room. The bundled [autosave trigger](autosave_and_objects.md) wires these together for
you.

### `get_autosave_mode() -> String`
Returns the persisted autosave mode: `"overwrite"`, `"separate"`, or `""` if unset.

### `set_autosave_mode(mode: String) -> void`
Persists the autosave mode to `user://autosave_pref.cfg`. Call once with the player's
choice (e.g. from the autosave prompt scene) — it survives restarts.

### `autosave() -> bool`
Performs an autosave according to the chosen mode: `"overwrite"` writes to the fixed
`AUTOSAVE_SLOT_ID` slot, otherwise a brand-new autosave slot is created each time (old
autosaves are trimmed to make room).

### `has_autosaves() -> bool`
Returns true if at least one save entry is flagged as an autosave. The autosave trigger
uses this to decide whether to show the mode prompt.

### `save_to_slot(slot_id: String, extra_data: Dictionary = {}, icon: Image = null) -> bool`
Saves to a fixed slot id (e.g. `"autosave"`), overwriting whatever was there, without
affecting `current_save_id`.

### `load_latest_save() -> bool`
Loads the most recently saved game. Returns false if no save exists. Useful for a
"Continue" button.

## Utility Functions

### `get_current_playtime() -> float`
Retrieves the realtime floating delta timer tracked globally.

### `has_saves() -> bool`
Checks whether `user://saves/` contains any valid payload data yet. Useful to toggle "Continue" vs "New Game" buttons.

### `is_menu_open() -> bool`
Identifies internally whether any Save CanvasLayer matches are aggressively mounted.

### `get_project_title() -> String`
Returns the project name from `application/config/name`.

### `format_playtime(playtime_seconds: float) -> String`
Formats a float of seconds as `HH:MM:SS`.

## Persisting Scene State

Beyond the adapter methods, the addon ships a `Savable` component
(`scenes/savable.tscn`) that captures and restores script variables plus
transform/visibility for any set of target nodes. Nodes join the **"savable"** group so
an adapter can collect them in bulk. See
[Autosave, Save Stations & Savable Objects](autosave_and_objects.md) for the full
adapter snippet.

## Signals

* `save_loaded(save_id: String, save_data: Dictionary)` - Fired after processing the scene switch out of the loader.
* `save_written(save_id: String, save_data: Dictionary)` - Fired cleanly after hitting the file system during Create/Overwrite/Copy passes.
* `save_deleted(save_id: String)` - Fired upon erasing an `id` directory tree.
