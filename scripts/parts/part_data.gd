class_name PartData
extends Resource
## Base data shared by every junk part (body/wheel/engine).
## Concrete parts extend this with category-specific fields.

enum Category { BODY, WHEEL, ENGINE }

## Cosmetic label only right now; not read by any gameplay system yet.
## Named MaterialType, not Material, because Material is a native Godot class.
enum MaterialType { METAL, WOOD, PLASTIC, CERAMIC, RUBBER, GLASS, FABRIC }

@export var id: StringName = &""
@export var display_name: String = ""
@export var category: Category = Category.BODY
@export var mass: float = 10.0
@export var durability: float = 100.0
## How much this part contributes to top speed — an engine's is just its
## power; a body/wheel's is a stand-in for drag/rolling efficiency until
## those actually factor into open-world driving.
@export var speed: float = 3.0
@export var material_type: MaterialType = MaterialType.METAL
## Scene this part's actual visual/physics rig lives in — set by whatever
## loads the part (PartDatabase), not authored on the resource itself.
@export var scene_path: String = ""

## Calibrated against the actual min/max seen across the current part
## catalog — not a physical unit, just enough spread that the worst and
## best parts in the catalog both land near the ends of the range. Shared
## here (rather than duplicated per-caller) so a part's star ratings in
## the garage and its performance_score() below always agree about what
## "good" means.
const DURABILITY_RANGE := Vector2(20.0, 140.0)
const SPEED_RANGE := Vector2(0.5, 8.0)
const MASS_RANGE := Vector2(3.0, 22.0)

const TIER_COUNT := 4

## Per-tier accent colors — bronze/silver/gold/"platinum" reads instantly
## without needing a label. Used both as PartSlot's border tint (at full
## strength) and, mixed faintly into the background, as its hover tint.
const TIER_COLORS := [
	Color(0.85, 0.46, 0.2, 0.9),  # 1: bronze — junk
	Color(0.8, 0.84, 0.88, 0.9),  # 2: silver
	Color(1.0, 0.8, 0.1, 0.9),    # 3: gold
	Color(0.3, 0.75, 1.0, 0.95),  # 4: platinum — top of the line
]

## Performance tier, 1 (junk) to TIER_COUNT (top-of-the-line). Stored
## rather than computed from a fixed formula: a tier is a QUARTILE rank
## among a part's own category (bodies vs bodies, wheels vs wheels, ...),
## not an absolute score, since "how good is this part" only means
## something relative to what else exists — averaging durability/speed/
## mass into one number and thresholding it clusters most of a small
## catalog into the middle tiers and never touches 1 or 4. See
## PartDatabase._assign_tiers(), which ranks every part in a category by
## performance_score() once the whole catalog loads and sets this field.
## Defaults to the top tier so a part instanced standalone (a test, a
## preview) before ever passing through PartDatabase doesn't read as
## "worst" purely by omission.
@export var tier: int = TIER_COUNT

## 0..1 performance score — durability and speed count up, mass counts
## down, each normalized against the catalog's real spread. Only
## meaningful as a basis for RANKING parts against each other (see
## PartDatabase._assign_tiers()); not meaningful as an absolute number on
## its own. An engine's `speed` already stands in for its power by
## convention (see the field above), so no category needs its own
## formula — this reads every part category the same way.
func performance_score() -> float:
	return (
		_normalize(durability, DURABILITY_RANGE)
		+ _normalize(speed, SPEED_RANGE)
		+ (1.0 - _normalize(mass, MASS_RANGE))
	) / 3.0

static func tier_color(tier_value: int) -> Color:
	return TIER_COLORS[clampi(tier_value, 1, TIER_COUNT) - 1]

static func _normalize(value: float, stat_range: Vector2) -> float:
	return clampf((value - stat_range.x) / (stat_range.y - stat_range.x), 0.0, 1.0)
