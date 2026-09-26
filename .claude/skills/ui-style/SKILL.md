---
name: ui-style
description: Visual style guide for all game UI (menus, HUD, panels, buttons, bars, popups). Use whenever creating or restyling any Control-based UI so it matches the flat, cut-out polygon art used by the world.
---

# Junkyard UI Style

UI is cut from the same flat polygons as the world. Every shape is a solid fill with hard edges, stacked on top of other shapes. No outlines, no gradients, no textures, no blur, no rounded corners. A button is a slab. A panel is a board. A bar is a row of blocks.

## Core rules

1. **Flat fills only.** One solid color per shape. Depth comes from stacking a darker or lighter polygon on top.
2. **No outlines, ever.** The game's art has none, so the UI has none. That includes the "darker polygon behind that pokes out a few pixels" trick, which is just an outline in disguise. Edges come only from flat shapes meeting other flat shapes of a different tone: a body against its shade strip, its skirt, the drop shadow, or the background. If something doesn't read, change its tone or add a shade/shadow shape. Don't ring it.
3. **Few vertices.** Rectangles, trapezoids, triangles, octagons. Never smooth curves. If it looks vector-perfect, it's wrong.
4. **Slightly off.** Panels and buttons get 1–4° tilt or a few px of vertex jitter so nothing is a perfect box. Text stays straight and readable.
5. **Layering = shading.** Build back to front:
   - `Shadow` (optional) — black at 0.15–0.2 alpha, offset down/right
   - `Body` — the main tone
   - `Shade` — darker strip on one side (right or bottom)
   - Details — seams, nails, cracks, tape (thin 2–4 px polygons)
   - `Highlight` — one small lighter shape, top-left
6. **Tone steps, not new colors.** 3–5 steps of the same hue, roughly ±0.04–0.08 per channel apart.
7. **Salvaged surfaces.** UI reads as scrap: sheet metal, cardboard, tape, rusty steel, warning signs.

## Palette

| Role | Color |
|---|---|
| Surface base | `Color(0.55, 0.40, 0.28)` |
| Surface shade | `Color(0.46, 0.33, 0.22)` |
| Surface dark | `Color(0.40, 0.29, 0.19)` |
| Light surface | `Color(0.58, 0.44, 0.28)` |
| Void / hole | `Color(0.08, 0.07, 0.06)` |
| Ink (near-black) | `Color(0.15, 0.14, 0.13)` |
| Accent yellow | `Color(0.95, 0.75, 0.10)` |
| Rust | `Color(0.55, 0.28, 0.14, 0.75)` |
| Metal grey | `Color(0.30, 0.30, 0.32)` |
| Steel light / base / shade / dark | `Color(0.80, 0.83, 0.88)` / `(0.64, 0.68, 0.74)` / `(0.52, 0.56, 0.63)` / `(0.38, 0.41, 0.47)` |
| Post grey | `Color(0.40, 0.38, 0.34)` |
| Cardboard light / base / shade / dark | `Color(0.74, 0.63, 0.47)` / `(0.68, 0.57, 0.41)` / `(0.60, 0.49, 0.34)` / `(0.53, 0.43, 0.30)` |
| Stat block empty | `Color(0.35, 0.33, 0.25)` |
| Trim off-white | `Color(0.70, 0.68, 0.63)` |
| Glass | `Color(0.40, 0.50, 0.52)` |
| Text brown | `Color(0.25, 0.16, 0.08)` |
| Danger red | `Color(0.60, 0.15, 0.15)` |
| Shadow | `Color(0, 0, 0, 0.18)` |

Saturation stays low everywhere. Yellow and red are the only loud colors — use them for focus, hover, selected, and alerts, never for large surfaces.

## Typography

- Font: `res://assets/fonts/Poco.ttf`. Don't add another.
- Flat color text, no drop shadows. A thin paper-colored halo is allowed for legibility over busy backgrounds.
- Dark text on light surfaces, off-white (`0.9, 0.9, 0.9`) on dark surfaces.
- Titles in ALL CAPS, buttons in Title Case.

## Components

**Panel** — `Shadow` → `Skirt` → `Body` → `Shade` strip on bottom/right → 2–4 seams or nails in the corners → optional tape strip or rust streak. Slight tilt. Headers use a smaller yellow plate on top.

**Button** — a single slab. Normal: body + darker bottom skirt. Hover: body steps one tone lighter and/or a yellow `Highlight` sliver appears. Pressed: shift the body down 2–3 px so the skirt shrinks. Disabled: desaturate toward post grey, alpha ~0.6.

**Progress / stat bar** — separate blocks with small gaps. Empty cells dark (`0.35, 0.33, 0.25`), filled cells use an accent. Blocks can be slightly uneven heights.

**Slot / card** — a cardboard board with a darker inset `Gap` where the icon sits. Rarity/tier is a strip of coloured tape across a corner, never a coloured border.

**Tabs / filters** — ScrapButtons with `selected = true` on the current one: the slab stays pushed in with the yellow sliver.

**Drop-target highlights** — flat, pulsing translucent yellow shapes over the target (an octagon, or a wash over the polygons). Never a ring or outline.

**Icons** — 3–8 polygons max, one shade, one highlight. Prefer scaling down an existing world part scene over drawing a new icon.

**Dividers** — a thin seam or a strip of hazard stripes (alternating yellow / ink parallelograms, no frame around them). Never a 1 px line.

**Cursor** — a bent offcut of blue-grey steel (the steel tones), with shadow, body, shade flank, one rivet and one highlight. Not yellow: yellow stays reserved for UI state.

**Overlays** — plain black at 0.4–0.6 alpha behind a panel; the panel carries the style.

## Godot implementation

- Use the existing components before writing new drawing code:
  - `UiPalette` (`scripts/ui/ui_palette.gd`): the palette above as constants.
  - `ScrapBoard` (`scripts/ui/scrap_board.gd`): draws one board (shadow, skirt, body, shade, nails, highlight; no frame) with seeded corner jitter and tilt. Everything below builds on it.
  - `ScrapPanel` (`scripts/ui/scrap_panel.gd`): a Control board to put labels on (title plates, dialog backs, sign posts).
  - `ScrapButton` (`scripts/ui/scrap_button.gd`): extends `BaseButton` and draws its own slab and straight text. Hover/focus gives a lighter slab, a yellow sliver, an elastic wobble and a `ui_hover` tick. Pressed pushes the slab down; disabled goes grey. Give each one its own `tilt_degrees` and `jitter_seed`.
  - `HazardStripe` (`scripts/ui/hazard_stripe.gd`): divider.
  - `BackButton` (`scenes/ui/back_button.tscn`): a ScrapButton that leaves the screen (Esc too).
  - `StatBar` (`scenes/garage/stat_bar.tscn`): 5 drawn blocks with uneven heights.
  - `PartSlot` (`scenes/garage/part_slot.tscn`): the cardboard part card, shared by the garage and the F1 dev menu.
  - `WorkshopBackdrop` (`scripts/garage/workshop_backdrop.gd`): plank wall + concrete floor for indoor screens.
  - `themes/scrap_theme.tres`: project-wide theme (`gui/theme/custom`) holding the font, flat scrollbars and cardboard tooltips. Put Godot-native widget styling there, not per scene.
  - `ScrapCursor` (autoload `autoload/scrap_cursor.gd`): the global cursor. It squashes on click and tilts over enabled buttons. Don't set OS cursors anywhere.
  - `JunkPileBackdrop` / `FallingParts` (`scripts/menu/`): flat junkyard backdrop layers and the tumbling real-part shower. Stack them as far pile → falling parts → near pile.
- New drawn controls draw polygons in `_draw()` with `draw_colored_polygon()`, sized from `size` so they resize with containers.
- Plain `Polygon2D` children under a Control are fine for fixed-size decorations that never resize.
- Do NOT use `StyleBoxFlat` rounded corners, borders, shadows, or anti-aliasing. Flat, square `StyleBoxFlat`s are only for native widgets we can't draw ourselves (scrollbars, tooltips) and live in `scrap_theme.tres`. Layout-only containers use `StyleBoxEmpty` for margins and draw a ScrapBoard in `_draw()`.
- Dark or dev-tool screens can use the steel tones for the main board with off-white text (see the F1 dev menu); normal screens use wood and cardboard.
- Name every polygon by what it is (`Body`, `Shade`, `Skirt`, `Seam1`, `NailTopLeft`, `Highlight`).
- Keep colors in one shared palette script/const once more than one UI script needs them.
- Animations stay chunky: snaps, wobbles, and position bumps with tweens. No fades on individual shapes except whole-screen overlays.

## Checklist before finishing

- [ ] Only flat fills — no outlines or frame rings, no gradients, textures, or rounded StyleBoxes
- [ ] Each element has a darker shade/skirt and at most one highlight
- [ ] Shapes slightly irregular, text straight
- [ ] Colors come from the palette (or are tone steps of them)
- [ ] Yellow/red used only for accent/state
- [ ] Reads clearly at the game's resolution — ask the user to eyeball it instead of building visual tests