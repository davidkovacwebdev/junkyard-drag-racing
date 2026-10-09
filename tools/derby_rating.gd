class_name DerbyRating
extends RefCounted
## Estimates how well a car spec ({"body", "engine", "wheels", "accessories"}
## scene paths) does at the demolition derby straight from its parts, no
## physics run: how much punishment it takes, how hard it hits back and how
## hard it is to tip onto its roof. Each car is assembled once to measure its
## centre of mass and wheel footprint, then freed before physics ever steps.
##
## rate_all() gives each spec a "weakness": the median car's strength over
## its own (0.5 is twice as strong as a median car). Lower is better, same as
## a time.

## Weapons that hit other cars on their own, and rams that make head-ons hurt.
const WEAPON_BONUS := {
	&"accessory_axe": 1.3,
	&"accessory_boxing_glove": 1.25,
	&"accessory_bull_horns": 1.12,
	&"accessory_cow_catcher": 1.1,
	&"accessory_deer_antlers": 1.05,
}
## Wheels breaking only costs a car once they're all gone; the body breaking
## is out straight away.
const WHEEL_DURABILITY_WEIGHT := 0.5
const MASS_EXPONENT := 0.5
const POWER_EXPONENT := 0.3
const STABILITY_EXPONENT := 0.5
## Half the wheel footprint over the centre of mass's height, clamped so one
## odd shape can't make or break a car on its own.
const STABILITY_RANGE := Vector2(0.25, 3.0)

static func rate_all(specs: Array[Dictionary], parent: Node, progress: ToolProgress) -> void:
	var strengths := PackedFloat64Array()
	for i in specs.size():
		strengths.append(strength(specs[i], parent))
		progress.draw(i + 1)
	var sorted := strengths.duplicate()
	sorted.sort()
	var median := sorted[sorted.size() / 2]
	for i in specs.size():
		specs[i]["weakness"] = snappedf(median / strengths[i], 0.001)

static func strength(spec: Dictionary, parent: Node) -> float:
	var car := CarAssembler.assemble_from_car_data(RaceProgression.rival_car_model(spec), parent, Vector2.ZERO)
	if car == null:
		return 0.001
	var body_data := car.body.part_data
	var durability_multiplier := 1.0
	var weapon_bonus := 1.0
	for accessory in car.body.find_children("*", "CarAccessory", true, false):
		var accessory_data := (accessory as CarAccessory).part_data
		if accessory_data != null:
			durability_multiplier *= accessory_data.durability_multiplier
			weapon_bonus *= WEAPON_BONUS.get(accessory_data.id, 1.0)
	var wheel_durability := 0.0
	var total_mass := car.body.mass
	for wheel in car.wheels:
		wheel_durability += wheel.part_data.durability if wheel.part_data != null else 0.0
		total_mass += wheel.mass
	wheel_durability /= maxf(car.wheels.size(), 1.0)
	var toughness := durability_multiplier * (body_data.durability + WHEEL_DURABILITY_WEIGHT * wheel_durability)
	var engine_data := car.engine.get("part_data") as EnginePartData if car.engine != null else null
	var power := engine_data.power if engine_data != null else 0.5
	var stability := clampf(_stability(car), STABILITY_RANGE.x, STABILITY_RANGE.y)
	car.root.free()
	return toughness * pow(total_mass, MASS_EXPONENT) * pow(power, POWER_EXPONENT) \
			* pow(stability, STABILITY_EXPONENT) * weapon_bonus

## Half the wheels' footprint (outermost wheel edges) over how high the centre
## of mass sits above the lowest point of the car. The body's mass, extras
## included, sits at its collision shapes' centre; each wheel's at its hub.
static func _stability(car: CarAssembler.AssembledCar) -> float:
	var body_bounds := _collision_bounds(car.body)
	var mass_sum := car.body.mass
	var weighted_center := body_bounds.get_center() * car.body.mass
	var lowest_y := body_bounds.end.y
	var left := INF
	var right := -INF
	for wheel in car.wheels:
		var wheel_bounds := _collision_bounds(wheel)
		weighted_center += wheel.global_position * wheel.mass
		mass_sum += wheel.mass
		lowest_y = maxf(lowest_y, wheel_bounds.end.y)
		left = minf(left, wheel_bounds.position.x)
		right = maxf(right, wheel_bounds.end.x)
	if car.wheels.is_empty():
		left = body_bounds.position.x
		right = body_bounds.end.x
	var center := weighted_center / maxf(mass_sum, 0.001)
	return (right - left) * 0.5 / maxf(lowest_y - center.y, 1.0)

## Global bounds of `body`'s own collision shapes (not those of the wheels or
## anything else parented under it).
static func _collision_bounds(body: CollisionObject2D) -> Rect2:
	var bounds := Rect2(body.global_position, Vector2.ZERO)
	for child in body.get_children():
		if child is CollisionPolygon2D:
			for point in (child as CollisionPolygon2D).polygon:
				bounds = bounds.expand((child as CollisionPolygon2D).global_transform * point)
		elif child is CollisionShape2D and (child as CollisionShape2D).shape != null:
			var shape_bounds := (child as CollisionShape2D).global_transform * (child as CollisionShape2D).shape.get_rect()
			bounds = bounds.merge(shape_bounds)
	return bounds
