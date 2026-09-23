extends Node
## Headless smoke test for the weather system (rain -> wetness -> puddles ->
## slippery car). Run with:
##   timeout 120 godot --headless --path <proj> res://_weather_smoke.tscn
##
## The simulation is stepped by hand (`Weather._process(0.05)` in a loop)
## rather than by waiting on real frames: headless runs uncapped, so a few
## hundred wall-clock frames are only milliseconds of in-game time and a
## rain-soak assertion would never be reached.

const SIM_STEP := 0.05
const SIM_FRAMES := 200

var _checks := 0
var _failures := 0

func _ready() -> void:
	# `await` is mandatory: a bare `_run()` returns at its first await and
	# this function would print its own success line with nothing tested.
	await _run()

func _run() -> void:
	var main: Node = (load("res://scenes/world/main.tscn") as PackedScene).instantiate()
	add_child(main)
	for i in 3:
		await get_tree().process_frame

	var puddles := main.get_node("Puddles") as PuddleField
	var rain := main.get_node("Rain") as RainLayer
	var car := main.get_node("Sortables/PlayerCar") as PlayerCar
	var roads := main.get_node("Roads") as RoadNetwork

	_check(Weather.get_showers().size() <= 2, "a day has at most two showers")

	if puddles._puddles.is_empty():
		_check(false, "the puddle field placed something")
		_finish()
		return
	_check(true, "the puddle field placed %d puddles" % puddles._puddles.size())

	# Every puddle must sit on the tarmac — the whole point of the feature.
	var on_road := 0
	for puddle in puddles._puddles:
		if roads.is_on_road(puddle["pos"] as Vector2):
			on_road += 1
	_check(on_road == puddles._puddles.size(), "all %d puddles are on a road" % on_road)

	# Rain soaks the ground.
	Weather.force_rain(1)
	for i in SIM_FRAMES:
		Weather._process(SIM_STEP)
	puddles._process(SIM_STEP)
	_check(Weather.get_rain_intensity() > 0.9, "forcing rain brings it to full")
	_check(Weather.get_wetness() > 0.5, "rain soaks the ground (wetness %.2f)" % Weather.get_wetness())

	await get_tree().process_frame
	_check(rain.visible, "the rain layer shows while it's raining")
	_check(rain._visible_rect().size.x > 1.0, "the rain layer covers a real area")

	# Puddles puddle.
	var centre: Vector2 = puddles._puddles[0]["pos"]
	_check(puddles.is_on_puddle(centre), "standing in a puddle registers")
	_check(not puddles.is_on_puddle(centre + Vector2(6000.0, 6000.0)), "dry ground does not")

	# An invisible puddle must not grab the car.
	var saved_fade := puddles._fade
	puddles._fade = 0.0
	_check(not puddles.is_on_puddle(centre), "an invisible puddle isn't slippery")
	puddles._fade = saved_fade

	# Same scatter after a rebuild (a map reload must not reshuffle puddles).
	var count_a: int = puddles._puddles.size()
	var first_a: Vector2 = puddles._puddles[0]["pos"]
	puddles.build()
	_check(puddles._puddles.size() == count_a and (puddles._puddles[0]["pos"] as Vector2) == first_a,
			"rebuilding places the same puddles")

	# The car's grip.
	_check(car._puddles == puddles, "the car found the puddle field")
	car.velocity = Vector2(300.0, 0.0)
	var turn := Vector2.from_angle(deg_to_rad(28.0))
	_check(car._is_skidding(turn, true), "a 28deg turn peels out on a puddle")
	_check(not car._is_skidding(turn, false), "the same turn grips when dry")

	# And it dries up when the shower passes (rain fading, not the ground).
	Weather.force_rain(0)
	for i in 60:
		Weather._process(SIM_STEP)
	_check(not Weather.is_raining(), "rain stops when the shower passes")

	_finish()

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  ok   %s" % label)
	else:
		_failures += 1
		print("  FAIL %s" % label)

func _finish() -> void:
	print("weather smoke: %d checks, %d failures" % [_checks, _failures])
	if _failures == 0:
		print("SMOKE OK")
	else:
		print("SMOKE FAILED")
	get_tree().quit(1 if _failures > 0 else 0)
