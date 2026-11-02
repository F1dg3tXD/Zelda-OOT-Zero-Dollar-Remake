# Surface Snap

An editor plugin for Godot 4.7+ that lets you drag a `Node3D` directly onto
the **surface** of another object — unlike the built-in vertex snap, which
only snaps to specific vertices.

## Usage

1. Enable the plugin in **Project → Project Settings → Plugins**.
2. Select the object you want to
   position.
3. Hold **Alt** and drag with the left mouse button over the target surface.
4. Release the button to confirm (the action is added to the editor's
   Undo/Redo, `Ctrl+Z` works normally).

The object's Y axis automatically aligns to the surface normal, and the
object's **edge** (computed from its AABB) touches the contact point — not
its origin/pivot.

## Requirements

- The **target (surface)** object needs real physics collision:
  `CollisionShape3D` (under a `StaticBody3D`, `Area3D`, etc.) or a
  `CSGShape3D` with `use_collision` enabled in the inspector.
- The **dragged** object does not need a collider.
- Only one selected `Node3D` at a time (multi-selection is not supported in
  this version).

## Configuration

In **Project Settings → Surface Snap → Collision Mask**, choose which
physics layers count as a valid snap surface (all layers by default).

## Known limitations

- The "object edge" offset is based on the AABB (bounding box), not the
  actual mesh — for very irregular or non-convex shapes, the contact point
  may not be the true closest point on the surface.
- Dragging multiple selected objects at once is not supported.

## AI usage disclosure

The GDScript code for this plugin was written with the assistance of an AI
language model (Claude, by Anthropic), based on requirements, testing, and
bug reports provided by the developer throughout an iterative development
process. The developer directed the design decisions, tested every
iteration in the Godot editor, and reported issues that were then fixed
collaboratively with the AI.

## License

MIT — see `LICENSE`.
