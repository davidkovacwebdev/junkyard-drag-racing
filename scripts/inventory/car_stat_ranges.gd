class_name CarStatRanges
extends RefCounted
## The worst and best whole-car stats the part catalog can build, so the
## garage's car stat bars run from the worst possible car (one block) to the
## best (five). Worked out from PartDatabase (see PartDatabase.car_stat_ranges),
## so new parts move the ends without anyone retuning numbers. A forged part
## can land outside these; the bars just clamp it.

var durability := Vector2.ZERO
var engine_power := Vector2.ZERO
var wheel_speed := Vector2.ZERO
var mass := Vector2.ZERO

static func from_catalog(bodies: Array[BodyPartData], engines: Array[EnginePartData],
		wheels: Array[WheelPartData], accessories: Array[AccessoryPartData]) -> CarStatRanges:
	var ranges := CarStatRanges.new()
	var engine_durability := _spread(engines, func(engine: EnginePartData) -> float: return engine.durability)
	var engine_mass := _spread(engines, func(engine: EnginePartData) -> float: return engine.mass)
	var engine_power := _spread(engines, func(engine: EnginePartData) -> float: return engine.power)
	var wheel_durability := _spread(wheels, func(wheel: WheelPartData) -> float: return wheel.durability)
	var wheel_mass := _spread(wheels, func(wheel: WheelPartData) -> float: return wheel.mass)
	ranges.wheel_speed = _spread(wheels, func(wheel: WheelPartData) -> float: return wheel.speed)

	var durability_multiplier := _accessory_product(accessories, func(accessory: AccessoryPartData) -> float: return accessory.durability_multiplier)
	var speed_multiplier := _accessory_product(accessories, func(accessory: AccessoryPartData) -> float: return accessory.speed_multiplier)
	var accessory_mass := _accessory_sum(accessories, func(accessory: AccessoryPartData) -> float: return accessory.mass)
	ranges.engine_power = engine_power * speed_multiplier * BodyPartData.SPEED_MULTIPLIER_RANGE

	ranges.durability = Vector2(INF, -INF)
	ranges.mass = Vector2(INF, -INF)
	for body in bodies:
		var mounts := PartDatabase.wheel_mount_count(body)
		var part_count := 2 + mounts
		var worst_durability := (body.durability + engine_durability.x + mounts * wheel_durability.x) / part_count
		var best_durability := (body.durability + engine_durability.y + mounts * wheel_durability.y) / part_count
		ranges.durability.x = minf(ranges.durability.x, worst_durability * durability_multiplier.x)
		ranges.durability.y = maxf(ranges.durability.y, best_durability * durability_multiplier.y)
		var lightest := body.mass + engine_mass.x + mounts * wheel_mass.x + accessory_mass.x
		var heaviest := body.mass + engine_mass.y + mounts * wheel_mass.y + accessory_mass.y
		ranges.mass.x = minf(ranges.mass.x, maxf(lightest, 0.0))
		ranges.mass.y = maxf(ranges.mass.y, heaviest)
	return ranges

## (lowest, highest) of `stat` across `parts`.
static func _spread(parts: Array, stat: Callable) -> Vector2:
	var spread := Vector2(INF, -INF)
	for part in parts:
		var value: float = stat.call(part)
		spread = Vector2(minf(spread.x, value), maxf(spread.y, value))
	return spread

## The lowest and highest a multiplier can stack to, one accessory per spot.
## A spot can stay empty, so it never stacks past 1.0 the wrong way.
static func _accessory_product(accessories: Array[AccessoryPartData], stat: Callable) -> Vector2:
	var product := Vector2.ONE
	for spot in _spread_by_spot(accessories, stat):
		product *= Vector2(minf(spot.x, 1.0), maxf(spot.y, 1.0))
	return product

## The lowest and highest an added stat can sum to, one accessory per spot.
static func _accessory_sum(accessories: Array[AccessoryPartData], stat: Callable) -> Vector2:
	var total := Vector2.ZERO
	for spot in _spread_by_spot(accessories, stat):
		total += Vector2(minf(spot.x, 0.0), maxf(spot.y, 0.0))
	return total

static func _spread_by_spot(accessories: Array[AccessoryPartData], stat: Callable) -> Array[Vector2]:
	var spreads: Array[Vector2] = []
	for spot in AccessoryPartData.Spot.values():
		var in_spot := accessories.filter(func(accessory: AccessoryPartData) -> bool: return accessory.spot == spot)
		if not in_spot.is_empty():
			spreads.append(_spread(in_spot, stat))
	return spreads
