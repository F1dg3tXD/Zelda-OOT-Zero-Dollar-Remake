# Godot XMB Save System

Welcome to the Godot XMB Save System documentation! This system provides a beautiful, PSP/PS3-style visual save UI completely out-of-the-box, alongside a robust autosave, playtime tracker, and metadata API.

## Table of Contents
1. [Getting Started](getting_started.md)
   - Learn how to integrate the save system into your 2D or 3D games using the Save Adapter pattern.
2. [API Reference](api_reference.md)
   - Detailed documentation on the `XMBSave` singleton, covering all signals, methods, and properties.
3. [Autosave, Save Stations & Savable Objects](autosave_and_objects.md)
   - Drop-in autosave triggers, the autosave-mode prompt, interactive/automatic save stations, and the `Savable` component for persisting scene state.

## Features
* **Automated Screenshots**: Falls back to automatically capturing your 2D/3D viewport as the save icon if no custom icon is provided.
* **Auto Playtime Tracking**: Automatically accrues time via delta updates natively in the API and translates it to standard readable text format.
* **Autosave Modes**: Players pick between overwriting a dedicated autosave slot or saving to fresh slots each time, with old autosaves trimmed automatically.
* **Autosave Triggers**: Drop an `Area2D` into a level and the game autosaves when the player walks through it, with spawn-safe arming that never re-triggers on load.
* **Save Stations**: Interactive or fully automatic checkpoints that open the save menus, configurable per-station.
* **Savable Objects**: Persist any node's script variables and transform/visibility through a single drop-in component.
* **UI Protection**: Safely toggles background UI inputs to prevent game pausing glitches while the save menu is active.
* **Smart Contextual Menus**: Allows overwriting, deleting, copying, and creating saves fluently with fully functional mouse, keyboard, and controller support.
