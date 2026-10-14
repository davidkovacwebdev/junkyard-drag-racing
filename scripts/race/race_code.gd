class_name RaceCode
## A random race (RandomRacePopup) as one string that can be pasted back in to
## run the same race again, on this machine or another:
##   venue-tier-seed-weather-car
##   drag-t2-1a2b3c4d-w000045-limo.propeller.hamster+giant.bubble_wrap
## The tier is t0 for random junk. The seed is hex. The weather is rain,
## wetness and cloud cover as two digits each (00-99). The car is what drove
## the first lane: body.engine.wheels[.extras] as part scene names without
## their folder prefix, or "random" for a car the seed builds. A garage car is
## written out as its parts, so a forged part comes back as the plain one.

const VENUE_CODES := {
	RandomRacePopup.Venue.DRAG: "drag",
	RandomRacePopup.Venue.HILL: "hill",
	RandomRacePopup.Venue.RALLY: "rally",
	RandomRacePopup.Venue.DERBY: "derby",
	RandomRacePopup.Venue.RAMP: "ramp",
}
const RANDOM_CAR := "random"
const PARTS_DIR := "res://scenes/parts/"
const BODY_PREFIX := "bodies/body_"
const ENGINE_PREFIX := "engines/engine_"
const WHEEL_PREFIX := "wheels/wheel_"
const ACCESSORY_PREFIX := "accessories/accessory_"
const WEATHER_KEYS := ["rain_intensity", "wetness", "cloud_cover"]
const WEATHER_STEPS := 99.0

## `race` as RandomRacePopup keeps it, with `player_car` the car that raced in
## the first lane (null when the seed built it).
static func encode(race: Dictionary, player_car: CarModelData) -> String:
	var weather := "w"
	for key in WEATHER_KEYS:
		weather += "%02d" % roundi(clampf(race["weather"].get(key, 0.0), 0.0, 1.0) * WEATHER_STEPS)
	return "-".join([
		VENUE_CODES[race["venue"]],
		"t%d" % race["tier"],
		"%08x" % race["seed"],
		weather,
		_encode_car(player_car),
	])

## The race a code describes, shaped like `encode()`'s input with the car as a
## picked roster spec, or {} when the code doesn't read or names a missing part.
static func decode(code: String) -> Dictionary:
	var fields := code.strip_edges().to_lower().split("-")
	if fields.size() != 5:
		return {}
	var venue: int = VENUE_CODES.find_key(fields[0]) if VENUE_CODES.values().has(fields[0]) else -1
	var tier_text := fields[1].trim_prefix("t")
	var seed_text := fields[2]
	var weather_text := fields[3].trim_prefix("w")
	if venue < 0 or not fields[1].begins_with("t") or not tier_text.is_valid_int() \
			or not seed_text.is_valid_hex_number() or seed_text.length() > 8 \
			or not fields[3].begins_with("w") or weather_text.length() != 2 * WEATHER_KEYS.size() \
			or not weather_text.is_valid_int():
		return {}
	var tier := tier_text.to_int()
	if tier < 0 or tier > RandomRacePopup.TIERS.back():
		return {}
	var weather := {}
	for i in WEATHER_KEYS.size():
		weather[WEATHER_KEYS[i]] = weather_text.substr(i * 2, 2).to_int() / WEATHER_STEPS
	var spec := {} if fields[4] == RANDOM_CAR else _decode_car(fields[4])
	if fields[4] != RANDOM_CAR and spec.is_empty():
		return {}
	return {
		"venue": venue,
		"tier": tier,
		"seed": seed_text.hex_to_int(),
		"driver": RandomRacePopup.Driver.RANDOM if spec.is_empty() else RandomRacePopup.Driver.PICKED,
		"picked_spec": spec,
		"weather": weather,
	}

static func _encode_car(car: CarModelData) -> String:
	if car == null or car.body == null or car.engine == null:
		return RANDOM_CAR
	var wheel_names: Array = car.wheels.filter(func(wheel: WheelPartData) -> bool: return wheel != null) \
			.map(func(wheel: WheelPartData) -> String: return _part_name(wheel.scene_path, WHEEL_PREFIX))
	var fields: Array[String] = [
		_part_name(car.body.scene_path, BODY_PREFIX),
		_part_name(car.engine.scene_path, ENGINE_PREFIX),
		"+".join(wheel_names),
	]
	if not car.accessories.is_empty():
		fields.append("+".join(car.accessories.map(func(accessory: AccessoryPartData) -> String:
			return _part_name(accessory.scene_path, ACCESSORY_PREFIX))))
	return ".".join(fields)

## A roster-style spec of scene paths, or {} if any part doesn't exist.
static func _decode_car(text: String) -> Dictionary:
	var fields := text.split(".")
	if fields.size() < 3 or fields.size() > 4:
		return {}
	var spec := {
		"body": _part_path(fields[0], BODY_PREFIX),
		"engine": _part_path(fields[1], ENGINE_PREFIX),
		"wheels": Array(fields[2].split("+")).map(func(part: String) -> String: return _part_path(part, WHEEL_PREFIX)),
		"accessories": [] if fields.size() < 4 else Array(fields[3].split("+")).map(func(part: String) -> String:
			return _part_path(part, ACCESSORY_PREFIX)),
	}
	var scene_paths: Array = [spec["body"], spec["engine"]] + spec["wheels"] + spec["accessories"]
	return spec if scene_paths.all(func(path: String) -> bool: return ResourceLoader.exists(path)) else {}

static func _part_name(scene_path: String, prefix: String) -> String:
	return scene_path.get_file().get_basename().trim_prefix(prefix.get_file())

static func _part_path(part_name: String, prefix: String) -> String:
	return "%s%s%s.tscn" % [PARTS_DIR, prefix, part_name]
