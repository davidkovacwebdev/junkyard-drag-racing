# Junkyard Drag Racing

Godot 4 game. All art is flat polygons (`Polygon2D` in scenes, or `_draw()` code), and all sound is synthesized.

## Always-on rules

- **Art:** any change that adds or modifies visuals must follow the Junk Toy style in `.claude/skills/art-style/SKILL.md`. That covers parts, props, buildings, characters, animals, terrain, effects and icons, whether scene polygons or `_draw()` code. Load the skill before drawing, including when the visuals are only a side effect of a gameplay feature.
- **UI:** Control-based UI follows `.claude/skills/ui-style/SKILL.md`.
- **Sound:** every new feature gets a fitting sound per `.claude/skills/sound-design/SKILL.md`.
- **Music:** follow `.claude/skills/music/SKILL.md`. Songs are versioned as new files and never deleted or overwritten.
- **Headless runs clobber saves:** run every probe, tool or test scene with `-- --no-save` (e.g. `godot --headless res://tools/x.tscn -- --no-save`). SaveSystem then never writes or deletes the save. Never edit `project.godot` to strip SaveSystem.
- **Checking art:** render with `godot res://tools/art_gallery.tscn -- <out_dir> [parts|world|race|screens|all]` and compare against the gold-standard parts listed in the art-style skill.
