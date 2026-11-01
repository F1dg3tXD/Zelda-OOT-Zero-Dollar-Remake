# Autosave, Save Stations & Savable Objects

This guide covers the drop-in gameplay components shipped with the addon: autosave
triggers, the autosave-mode prompt, interactive/automatic save stations, and the
`Savable` component for persisting arbitrary scene state.

## Autosave Trigger

`examples/autosave_trigger.tscn` (script: `examples/autosave_trigger.gd`) is an
`Area2D` zone. When the player (any body in the **"player"** group) enters it and the
zone is armed, an autosave runs through the `XMBSave` API.

**Exports**

| Export | Type | Default | Description |
|---|---|---|---|
| `save_slot_id` | `String` | `"autosave"` | Slot identity used by autosaves. |
| `trigger_once` | `bool` | `false` | When true, the zone fires only once; it never triggers again until the scene reloads. |

**Behavior**

* The very first autosave of a session opens the autosave prompt (see below) so the
  player can choose how autosaves are stored. The choice is persisted, so the prompt
  only ever appears once.
* The zone is **disarmed while the player spawns inside it** (for example right after
  loading a save), so loading never immediately re-triggers an autosave. It arms once
  the player leaves the area.
* A node in the **"player_ui"** group may implement
  `play_autosave(work: Callable)` to play an autosave animation while the save runs.
  If none exists, the save is performed directly.
* Emits `autosave_completed` after the save finishes — useful for feedback, sounds, or
  locking gameplay until the write lands.

```gdscript
# Optional: animate an autosave icon while the write happens.
func play_autosave(work: Callable) -> void:
    autosave_icon.show()
    await work.call()
    autosave_icon.hide()
```

## Autosave Mode Prompt

`scenes/autosave_prompt.tscn` (script: `scripts/autosave_prompt.gd`) is a small modal
`CanvasLayer` that asks how autosaves should be stored:

* **Overwrite my save slot** — every autosave replaces a single dedicated slot
  (`XMBSave.AUTOSAVE_SLOT_ID`), so manual saves are never displaced.
* **Save to new autosave slots** — each autosave gets a fresh slot; old autosaves are
  trimmed (oldest first) to stay within `XMBSave.MAX_SAVE_SLOTS`.

`prompt()` is a coroutine returning the chosen mode string (`"overwrite"` or
`"separate"`). The autosave trigger hands it straight to
`XMBSave.set_autosave_mode()`, which persists it in `user://autosave_pref.cfg`:

```gdscript
var prompt := preload("res://addons/godot_xmb/scenes/autosave_prompt.tscn").instantiate()
get_tree().root.add_child(prompt)
XMBSave.set_autosave_mode(await prompt.prompt())
```

## Save Station

`examples/save_station.tscn` (script: `examples/save_station.gd`) is a `Node2D` with an
interaction zone. The player (any body in the **"player"** group) entering the zone can
open the XMB save menu.

**Exports**

| Export | Type | Default | Description |
|---|---|---|---|
| `create_menu_scene_path` | `String` | `""` | Scene to warp to when creating the first save (defaults to the current scene). |
| `needs_interact` | `bool` | `true` | When true, the menu opens only after the player presses the interact input. When false, it opens automatically the moment the player walks in. |
| `interact_input` | `String` | `"interact"` | The `InputMap` action the player presses to use the station (only consulted while `needs_interact` is true). |
| `trigger_once` | `bool` | `false` | When true, the station fires once (first interaction or auto-open) and then stays dormant for the rest of the scene. |

**Usage**

* **Interactive station (default):** keep `needs_interact` true. The station polls the
  interact input itself, so a plain player body in the "player" group is enough — no
  player-side code required. Games that already drive interactions from the player
  script can keep calling `station.interact(player)` instead.
* **Automatic station:** set `needs_interact` false. Walking into the zone opens the
  menu (or creates the first save) immediately. Pair with `trigger_once` to make a
  scripted one-shot checkpoint.
* When entering/exiting, the station also calls `set_active_station(self)` /
  `clear_active_station(self)` on the player if it has those methods, so your player
  can show a prompt or highlight the station.

## Savable Component

`scenes/savable.tscn` (script: `scripts/savable.gd`) persists arbitrary scene state
without writing adapter code. Drop it anywhere and drag scene nodes into its
**`targets`** array:

* **Capture:** each target's script-declared variables plus
  `position` / `rotation` / `scale` / `visible` are collected. Node/resource
  references are skipped because they cannot be serialized to a save file.
* **Apply:** a saved snapshot is written back onto each target.
* The node adds itself to the **"savable"** group on `_ready`, so your game can gather
  every instance during a capture without keeping explicit references.

```gdscript
# In your XMBSave adapter (registered via register_save_adapter):
func capture_save_state() -> Dictionary:
    var state := {}
    for node in get_tree().get_nodes_in_group("savable"):
        if node.has_method("capture"):
            state[node.get_path()] = node.capture()
    return state

func apply_save_state(payload: Dictionary) -> void:
    var state: Dictionary = payload.get("state", {})
    for node in get_tree().get_nodes_in_group("savable"):
        if node.has_method("apply"):
            node.apply(state.get(node.get_path(), {}))
```

> **Note:** saved paths are relative to each `Savable` node, so place it high enough in
> the tree that its targets remain reachable by path after a scene load.
