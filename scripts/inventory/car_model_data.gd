class_name CarModelData
extends Resource
## One garage-inventory entry, built from real parts — the same
## BodyPartData/EnginePartData/WheelPartData classes the drag-race rig
## uses — instead of a one-off car struct. A body (which may bring its
## own default engine along), plus one WheelPartData per wheel mount.
## A Resource on purpose: this slots straight into ResourceSaver/JSON
## later for save games without restructuring.

@export var body: BodyPartData
@export var engine: EnginePartData
@export var wheels: Array[WheelPartData] = []
## Bolt-ons, at most one per AccessoryPartData.Spot.
@export var accessories: Array[AccessoryPartData] = []

## The body IS the car's identity/paint job for now — no separate
## "car name" or "car color" to keep in sync with whatever body is
## equipped.
var display_name: String:
	get: return body.display_name if body != null else "Unnamed Car"

var body_color: Color:
	get: return body.color if body != null else Color.WHITE

## Whether the car can leave the garage: a body, an engine and a wheel on
## every mount. Parts can be taken off in the garage, so a car can sit there
## half built.
func is_drivable() -> bool:
	return missing_parts().is_empty()

## What's keeping the car off the road, as "no engine, 2 wheels". Empty when
## nothing is.
func missing_parts() -> String:
	if body == null:
		return "no body"
	var missing: PackedStringArray = []
	if engine == null:
		missing.append("no engine")
	var empty_mounts := 0
	for i in PartDatabase.wheel_mount_count(body):
		if i >= wheels.size() or wheels[i] == null:
			empty_mounts += 1
	if empty_mounts == 1:
		missing.append("a wheel missing")
	elif empty_mounts > 1:
		missing.append("%d wheels missing" % empty_mounts)
	return ", ".join(missing)

func accessory_in(spot: AccessoryPartData.Spot) -> AccessoryPartData:
	for accessory in accessories:
		if accessory != null and accessory.spot == spot:
			return accessory
	return null

## Puts `accessory` in its spot, replacing whatever was there.
func set_accessory(accessory: AccessoryPartData) -> void:
	remove_accessory(accessory.spot)
	accessories.append(accessory)

func remove_accessory(spot: AccessoryPartData.Spot) -> void:
	for i in range(accessories.size() - 1, -1, -1):
		if accessories[i] == null or accessories[i].spot == spot:
			accessories.remove_at(i)

func durability_multiplier() -> float:
	var multiplier := 1.0
	for accessory in accessories:
		if accessory != null:
			multiplier *= accessory.durability_multiplier
	return multiplier

func speed_multiplier() -> float:
	var multiplier := 1.0
	for accessory in accessories:
		if accessory != null:
			multiplier *= accessory.speed_multiplier
	return multiplier

func accessory_mass() -> float:
	var total := 0.0
	for accessory in accessories:
		if accessory != null:
			total += accessory.mass
	return total

# --- Car-wide stats (the garage's stats card) ---------------------------------

## The fitted body, engine and wheels: the parts that carry durability and speed.
func _structural_parts() -> Array[PartData]:
	var parts: Array[PartData] = []
	for part: PartData in [body, engine]:
		if part != null:
			parts.append(part)
	for wheel in wheels:
		if wheel != null:
			parts.append(wheel)
	return parts

## Average durability of the fitted parts, with the accessories' bonus on top.
func average_durability() -> float:
	var parts := _structural_parts()
	if parts.is_empty():
		return 0.0
	var total := 0.0
	for part in parts:
		total += part.durability
	return total / parts.size() * durability_multiplier()

## What the engine spins the wheels to, with the body's and accessories'
## bonuses on top.
func engine_power() -> float:
	if engine == null:
		return 0.0
	var body_multiplier := body.speed_multiplier() if body != null else 1.0
	return engine.power * speed_multiplier() * body_multiplier

## How well the wheels turn that spin into ground speed.
func average_wheel_speed() -> float:
	var total := 0.0
	var count := 0
	for wheel in wheels:
		if wheel != null:
			total += wheel.speed
			count += 1
	return total / count if count > 0 else 0.0

func total_mass() -> float:
	var total := accessory_mass()
	for part in _structural_parts():
		total += part.mass
	return maxf(total, 0.0)

## The rating fractions run from the worst car the catalog can build (0) to
## the best (1), see CarStatRanges.
func durability_rating_fraction() -> float:
	return PartData._normalize(average_durability(), PartDatabase.car_stat_ranges().durability)

## Engine and wheels count half each: a jet on toilet bowls goes nowhere.
func speed_rating_fraction() -> float:
	var ranges := PartDatabase.car_stat_ranges()
	return (PartData._normalize(engine_power(), ranges.engine_power)
			+ PartData._normalize(average_wheel_speed(), ranges.wheel_speed)) / 2.0

func mass_rating_fraction() -> float:
	return PartData._normalize(total_mass(), PartDatabase.car_stat_ranges().mass)

## The first non-empty override any fitted accessory sets for `property`
## (horn_sound, body_impact_sound), or `fallback`.
func accessory_sound(property: StringName, fallback: StringName) -> StringName:
	for accessory in accessories:
		if accessory != null and accessory.get(property) != &"":
			return accessory.get(property)
	return fallback
