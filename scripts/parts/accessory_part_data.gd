class_name AccessoryPartData
extends PartData
## A bolt-on extra (horns, a spoiler, a turtle shell...). It has no physics of
## its own: it rides on the body at its `spot` and changes the whole car's stats.
## Its look and any behaviour live in the scene's CarAccessory script.

## Where on the body it goes. A car wears at most one accessory per spot.
## SKIN repaints the whole car instead of sitting anywhere.
enum Spot { FRONT, TOP, REAR, SKIN }

@export var spot: Spot = Spot.TOP
## Every part on the car (body and wheels) gets this much durability.
@export var durability_multiplier: float = 1.0
## The car's engine power, and the map car's top speed, get this much.
@export var speed_multiplier: float = 1.0
## Replaces the car's horn loop while fitted (the siren).
@export var horn_sound: StringName = &""
## Replaces the body's own knock while fitted (a shell knocks hollow).
@export var body_impact_sound: StringName = &""
## Played in the garage when it's fitted.
@export var equip_sound: StringName = &"wrench_clunk"
@export var found_in_junk: bool = true
## What it does, for the effect badge tooltip. The stat changes are added
## to it automatically.
@export_multiline var effect_description: String = ""

const DURABILITY_MULTIPLIER_RANGE := Vector2(0.85, 1.45)
const SPEED_MULTIPLIER_RANGE := Vector2(0.85, 1.12)
const ACCESSORY_MASS_RANGE := Vector2(-2.0, 8.0)

func _init() -> void:
	category = Category.ACCESSORY
	durability = 0.0
	speed = 0.0
	mass = 1.0

func performance_score() -> float:
	return (
		_normalize(durability_multiplier, DURABILITY_MULTIPLIER_RANGE)
		+ _normalize(speed_multiplier, SPEED_MULTIPLIER_RANGE)
		+ (1.0 - _normalize(mass, ACCESSORY_MASS_RANGE))
	) / 3.0

func durability_rating_fraction() -> float:
	return _normalize(durability_multiplier, DURABILITY_MULTIPLIER_RANGE)

func speed_rating_fraction() -> float:
	return _normalize(speed_multiplier, SPEED_MULTIPLIER_RANGE)

func mass_rating_fraction() -> float:
	return _normalize(mass, ACCESSORY_MASS_RANGE)

func effect_summary() -> String:
	var stat_changes: Array[String] = []
	if not is_equal_approx(durability_multiplier, 1.0):
		stat_changes.append("Durability %s" % _percent_change(durability_multiplier))
	if not is_equal_approx(speed_multiplier, 1.0):
		stat_changes.append("Race speed %s" % _percent_change(speed_multiplier))
	if not is_zero_approx(mass):
		stat_changes.append("Weight %+d" % roundi(mass))
	var lines := PackedStringArray()
	if not effect_description.is_empty():
		lines.append(effect_description)
	if not stat_changes.is_empty():
		lines.append(", ".join(stat_changes))
	return "\n".join(lines)

static func _percent_change(multiplier: float) -> String:
	return "%+d%%" % roundi((multiplier - 1.0) * 100.0)
