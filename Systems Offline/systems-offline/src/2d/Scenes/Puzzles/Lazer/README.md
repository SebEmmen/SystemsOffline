# Crossed Signals — Godot 4.7 editor tools

These files are a NEW node-based level authoring system. They do not modify the earlier fixed-board Crossed Signals scripts.

## Installation
1. Extract the folder `crossed_signals_editor_tools` into the root of your Godot project, so the scripts exist at `res://crossed_signals_editor_tools/`.
2. In Godot, create a new scene with a **Node2D** root. Name it `CrossedSignalsLevel`.
3. Save the empty scene, then open `generate_cs_editor_level.gd` in the Script editor.
4. Use File > Run (Ctrl+Shift+X). Save the scene again.
5. Use the 2D editor's **Move tool (W)** to drag nodes; select nodes and change Inspector properties.
6. Duplicate nodes (Ctrl+D) to add more emitters, receivers, relays, walls and barriers. Save each level as a separate .tscn.

## Node scripts
- `cs_level.gd`: runtime network, drawing, drag movement, receiver_changed and puzzle_solved signals
- `cs_device.gd`: emitter/receiver/relay, with color and movement options
- `cs_wall.gd`: resizable wall, line-of-sight blocking
- `cs_barrier.gd`: wall that opens when a linked receiver powers on
- `generate_cs_editor_level.gd`: one-shot editor scene generator

## Editing
- Move devices/walls using Godot's 2D Move tool.
- Resize walls using `dimensions` in the Inspector.
- Change a device's `kind` (EMITTER, RECEIVER, RELAY) and `laser_color` (RED, BLUE).
- A barrier's `receiver_path` is relative to the barrier node, e.g. `../RedReceiver`.
- The level root has `max_relay_link_distance`, `background_size`, and `preview_in_editor`.
- Play the scene with F6; drag yellow relay nodes with left mouse.
- `puzzle_solved` emits once when all receivers are powered.

## Current prototype limitations
- Links are automatically formed to all visible compatible nodes; no manual target selection.
- Red gets first claim on universal relays when both colors can reach them. This is deterministic but is NOT full Talos-style simultaneous color-conflict simulation.
- Receivers can be powered directly by emitters, without relays.
- Barriers update after the current network calculation, so a newly opened barrier's effect is reflected in the next frame.
- The level uses a simple node drawing style; no sprites, sound, or SaveManager integration.
- Relay movement is only tested against wall rectangles and is not constrained to the background.
- Godot runtime testing was not available in this environment; fix any engine-specific parser warnings before integrating with the main project.

## Recommended workflow
Design each level as a separate scene, then instance it into the game. Keep your existing Bird Matrix and older Crossed Signals scene unchanged.
