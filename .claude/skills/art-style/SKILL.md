---
name: art-style
description: The game's "Junk Toy" art style and its complexity budget. Use whenever drawing, adding, changing or reviewing ANY visual: a car part (body, wheel, engine), a world prop, landmark, building, tree, character, animal, ground/terrain wear, pickup, effect, part icon or HUD icon. That covers .tscn Polygon2D art and code drawn in `_draw()`. Also use when a new feature needs new art, even if the request never mentions art.
---

# Junk Toy art style

Everything in the game looks like a **cheap toy version of the object**. It is cut from a handful of flat, solid-color shapes. It reads from its silhouette and **one** signature feature, and it never tries to be a realistic illustration.

Aim for the fridge, not the horse painting. When unsure, draw less.

UI (menus, HUD, minimap, icons, cursor) follows the `ui-style` skill, which extends this one with UI components and tighter budgets.

## The gold standard

Open these before drawing anything new and match their level of detail:

| Kind | Reference | Why it works |
|---|---|---|
| Body | `scenes/parts/bodies/body_fridge.tscn` | 3 polys: box, door seam, handle. Unmistakably a fridge. |
| Body | `scenes/parts/bodies/body_bathtub.tscn` | Tub, rim, feet, faucet, plus one gag (the rubber duck). |
| Wheel | `wheel_traffic_cone.tscn`, `wheel_trash_lid.tscn`, `wheel_alarm_clock.tscn`, `wheel_dartboard.tscn`, `wheel_paddle.tscn`, `wheel_ceiling_fan.tscn` | 2–5 polys each, bold shapes, one feature. |
| Engine | `engine_blender.tscn`, `engine_leaf_blower.tscn`, `engine_soda_bottle.tscn` | 3 polys: body, one feature, one accent. |
| Rigged part | `engine_horse.tscn`, `wheel_tv.tscn`, `body_sofa.tscn` | Reworked to this style: one polygon per rig segment, no anatomy. |
| World | Houses and trees built with the Building/Tree Creator plugins (`scenes/buildings/parts/`, `scenes/trees/parts/`) | 3–13 polys per plugin part. |
| Landmark | `scripts/world/farm_barn.gd`, `scripts/world/forge_building.gd` | Wall, shade, roof band, door, one opening. |

`tools/art_gallery.tscn` renders all of these side by side (see **Checking your work**).

## The four rules

1. **Silhouette + one signature feature.** Pick the one thing that names the object and draw only that: the TV's screen, the fridge's handle, the cone's stripe, the sign's "!", the barn's white X. Everything else is body and shade.
2. **At most one gag.** A single funny touch is allowed but never required: the bathtub duck, tape on the sofa arm, a spring out of the mattress, the hamster in the wheel. One. Not a gag plus a sticker plus a rust spot.
3. **Chunky or nothing.** No shape thinner than **4 px** at the part's native scale (**6–8 px** for world art usually seen zoomed out, like race tracks and cranes). If a detail would be thinner than that, it doesn't exist.
4. **Flat and few.** Solid fills, a few vertices each, no outlines, no gradients, no curves.

## Budgets

Count every drawn polygon (`Polygon2D` node, `draw_colored_polygon`, `draw_rect`). Repeats count individually.

| What | Polygons | Notes |
|---|---|---|
| Car part (body, wheel, engine) | **3–8** | A big body with a gag can reach ~13 (the bathtub is the ceiling). Anything over 8 needs a reason. |
| Rigged part (horse, prosthetic leg, hamster) | 1 per rig segment, plus ≤ 4 | The extras are things like a shade, mane, eye or one gag. Ground shadow and mount hardware (the horse's hitch) don't count. Keep every node the script needs. Each segment gets one polygon, never upper/lower/hoof/highlight. |
| Plugin building / tree part | ≤ 13 | Already the gold standard. Match what's there. |
| World landmark structure (barn, forge, booth) | **6–12** for the building itself | Props around it are counted separately. |
| Small world prop (hay bale, drum, trough, sign) | **2–5** | |
| Tyre stack | 1 per tyre + top + hole | Use `FlatProps.draw_tire_stack`. |
| HUD / UI icon | **3–6** | See the `ui-style` skill for UI. |
| Repeated elements (fins, fence posts, checker cells, lugs, crowd) | ≤ 6–10 per object | Fewer and bigger. A crowd is a few chunky people spaced far apart. |
| Scattered ground wear (patches, cracks, puddles, stains) | a handful per screen | 3–8 big shapes, never dozens. |

## Always cut

These are the things that pushed the art from toy to illustration. They are banned unless the item's single signature feature *is* one of them:

- rivets, bolts, lug nuts, screws, nails on props (UI boards may keep their nails per `ui-style`)
- scanlines, speaker slots, knobs beyond one, power lights, stickers, labels
- panel lines, seams, wood grain, plank lines, brick mortar, corrugation ribs, cooling fins
- rust speckles, dents, scuffs, grime, mud splats, oil drips, soot streaks
- anatomy: hooves, knees, nostrils, muzzles, blazes, forelocks, bridles, eye glints, cheeks
- fringe, tufts, stitching, piping, buttons, laces, tape wraps, grips
- hairline cracks (a crack is 1–3 chunky bars or nothing)
- cables and struts thinner than the budget; lattices with many braces
- more than one highlight per object; any highlight on a small object
- smoke, steam and sparkle bits on static art (animated effects are fine, keep them few and big)

## Shading and color

- Build back to front: **body → one shade strip** (darker, right or bottom) **→ feature → optional gag**. Add at most one highlight, and only on big objects.
- The shade is a tone step of the body: same hue, about 0.15–0.25 darker. Don't introduce a new color for shading.
- Keep saturation low. One loud color per object at most, usually on the feature (red valve wheel, yellow rim, orange cone).
- Reuse `UiPalette` (`scripts/ui/ui_palette.gd`) constants and the colors already in neighboring art before inventing new ones.
- A ground shadow (`UiPalette.SHADOW`, a flat squashed octagon) is allowed under world props and buildings.
- **No outlines, ever.** That includes `draw_rect(..., false, w)`, `draw_polyline` rings, `Line2D` borders, and a darker copy of the shape poking out behind it. An edge comes from a shade strip or from the background.
- No gradients or fading chains of alpha slices. Transparency is only for shadows, glass/blur effects that already exist (prop blur), and lighting systems.

## Shapes

- Rectangles, trapezoids, triangles, simple chevrons. 4–8 vertices per polygon is normal.
- Round things are **6–14-gons** (wheels up to 16). Never `draw_circle` or high-vertex ellipses for art: use `FlatProps.octagon()` or an n-gon.
- Rings (tyres, rims) are one polygon with an outer and inner loop stitched by `polygons` quads, like `wheel_bicycle.tscn`'s `Tire`.
- Thin sticks (spokes, poles, frames) are bars of at least 4 px (`FlatProps.sliver(from, to, thickness)`).
- Slightly off is good: a 2–3° tilt, one uneven edge. Perfectly regular CAD shapes look wrong.

## Code-drawn art (`_draw()`)

The same budgets apply. Specifically:

- Seeded scatter loops (`for i in N`) are where complexity sneaks in. Keep `N` small and the shapes large.
- Use `FlatProps` helpers (`draw_tire_stack`, `draw_drum`, `octagon`, `sliver`) rather than new one-off detail.
- Don't draw per-brick, per-plank or per-rib lines across a surface. A wall is one fill plus one shade strip.
- Animated bits (flames, smoke, windmill blades, flicker) get 1–3 big shapes, not layered tongues and many puffs.

## Rigged and scripted parts

Parts with scripts (`horse_engine.gd`, `car_pogo.gd`, `car_hamster_wheel.gd`, `car_prosthetic_leg.gd`, `spinning_propeller.gd`) look nodes up by path. When simplifying:

1. Grep the script for `$`, `get_node` and `@onready` paths first. Keep those nodes and their transforms.
2. Put exactly one polygon in each rig node. Delete the extra detail polygons around it.
3. If the script lists a polygon you are deleting, remove it from the script in the same change.
4. Forged parts (`ForgedLook`) reference base polygons by path with `get_node_or_null`. Deleting a node only drops that override, and nothing breaks.

## New art checklist

Before calling any new or changed visual done:

- [ ] Could a kid name it from the silhouette plus one feature?
- [ ] Within the polygon budget for its kind (count them).
- [ ] Nothing thinner than 4 px (6–8 px for zoomed-out world art).
- [ ] At most one gag, at most one highlight, one shade strip.
- [ ] No outlines, gradients, circles or hairlines. None of the **Always cut** items.
- [ ] Colors are tone steps of existing palette colors, and saturation is low.
- [ ] Rendered next to the gold standard with `tools/art_gallery.tscn`. It doesn't look more detailed than the fridge, cone or houses around it.
- [ ] If it's a new feature, it also got its sound (see the `sound-design` skill).

## Checking your work

`tools/art_gallery.tscn` renders review sheets to PNG:

```
godot res://tools/art_gallery.tscn -- <out_dir> [parts|world|race|screens|all]
```

- `parts` gives a labeled grid of every body, wheel and engine, the fastest way to compare a new part against the gold standard.
- `world` covers the farm, forge, world drag strip, houses/trees and a row of props.
- `race` and `screens` capture live screens (race, main menu, garage, junkyard, world, crane pen).

The tool disables `SaveSystem`, but always back up `save.tres` first and restore it in the same shell command, per the project memory about headless runs clobbering saves. Look at the PNGs yourself. For purely visual judgement calls, show the user instead of building tests.
