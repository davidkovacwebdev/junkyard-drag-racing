class_name TowTruckRescueCutscene
extends Cutscene
## The player drove into the sea and sank to the axles (PlayerCar's Wading).
## A while later Hank's tow truck backs up to the beach, he climbs out, has a
## laugh, winches the car back onto the sand and charges `fee` for it (or
## whatever the player has, if that's less). Played by PlayerCar, which sets
## `car` first. Plays every time it happens, so it has no id.
##
## From the `rod_gift_tow`th tow on, if the player hasn't got it yet, Hank
## recognises them, and instead of his usual sign-off hands over his old
## fishing rod.
##
## The first tow uses `arrival_lines` and `sign_off_lines`; every later one
## (bar the rod tow) picks a random greeting from `repeat_arrivals` and a
## random goodbye from `repeat_sign_offs`, never the same one twice running.
##
## The words live in res://cutscenes/tow_truck_rescue.tres. `{fee}` in a line
## becomes the fee, `{tows}` how many times he's towed the player and
## `{player}` their name.

const HANK := preload("res://characters/tow_guy.tres")
const FISHING_ROD := preload("res://items/fishing_rod.tres")

@export var speaker_name: String = "Hank"
@export var fee: int = 20
@export var later_card: String = "HALF AN HOUR LATER..."
@export_multiline var arrival_lines: PackedStringArray = [
	"Heh. That ain't a boat, pal.",
	"Sit tight, I'll winch ya out.",
]
## Said once the car's out, then `broke_line` if the player couldn't cover it.
@export var fee_line: String = "That's ${fee}. Cash."
@export var broke_lines: PackedStringArray = [
	"...That's all ya got? Fine.",
	"You're short. I'll put the rest on your tab. You don't have a tab. Now you do.",
	"Is this... is this a button? You paid me partly in buttons?",
	"I've been paid better by seagulls.",
]
@export_multiline var sign_off_lines: PackedStringArray = [
	"Pleasure doin' business. Stay outta the drink.",
]

@export_group("Repeat customers")
## One of these is picked for every tow after the first, as the greeting.
@export var repeat_arrivals: Array[PackedStringArray] = [
	PackedStringArray(["Oh, look who it is.", "Lemme guess. Ya thought it was a puddle."]),
	PackedStringArray(["Tow number {tows}. I'm namin' my next truck after you.", "Hold still."]),
	PackedStringArray(["I was eatin' a sandwich, {player}.", "A good one. Had pickles."]),
	PackedStringArray(["The fish are startin' to recognise your car.", "One of 'em waved at me."]),
	PackedStringArray(["Ya know the sea's not a road, right?", "Blue means no. Remember that."]),
	PackedStringArray(["My wife asked where I keep goin'.", "I said 'the {player} situation'."]),
	PackedStringArray(["Didn't even let me finish my coffee.", "...It's in the cab. Gettin' cold. Like your engine."]),
	PackedStringArray(["Are ya tryin' to reach another island?", "'Cause there's a bridge for that. Sorta. It's closed."]),
	PackedStringArray(["Again. Again! AGAIN!", "...Sorry. Doc says I gotta let it out."]),
	PackedStringArray(["Heard the splash from across the island.", "Sounded expensive."]),
]
## And one of these as the goodbye.
@export var repeat_sign_offs: Array[PackedStringArray] = [
	PackedStringArray(["See ya next time. 'Cause there'll be a next time."]),
	PackedStringArray(["I'm puttin' your face on my fridge. Loyal customer."]),
	PackedStringArray(["Try drivin' on the brown and green bits. Not the blue bits."]),
	PackedStringArray(["Buy a boat. Or a snorkel. Or a map."]),
	PackedStringArray(["You're puttin' my kid through college, {player}."]),
	PackedStringArray(["Next one's on me. Kiddin'. It's twenty bucks."]),
	PackedStringArray(["Dry it out 'fore ya start it. Or don't. More business for me."]),
	PackedStringArray(["Say hi to the crabs for me."]),
]

@export_group("Fishing rod")
@export var rod_gift_tow: int = 3
## The rod tow swaps the usual greeting and sign-off for these.
@export_multiline var repeat_arrival_lines: PackedStringArray = [
	"You again?! That's {tows} times now, pal.",
	"Ya know the drill. Sit tight.",
]
@export_multiline var rod_gift_lines: PackedStringArray = [
	"Look. Ya can't catch fish like that.",
	"Here, take my old rod. Fish from the beach like a normal person.",
]
@export var rod_card: String = "GOT A FISHING ROD"
@export_multiline var rod_sign_off_lines: PackedStringArray = [
	"Now stay outta the drink.",
]
@export_multiline var trunk_full_lines: PackedStringArray = [
	"Was gonna give ya my old rod, but your trunk's fulla junk.",
	"Clear it out. We both know you'll be back.",
]

@export_group("Staging")
@export var zoom: float = 1.3
## How far up the beach (past the shoreline) the car is set down.
@export var set_down_inland: float = 90.0
## How far to the side of the set-down spot the truck parks, and how far off
## it starts backing in from.
@export var park_gap: float = 250.0
@export var drive_in_distance: float = 900.0
@export var back_in_seconds: float = 2.4
@export var pull_seconds: float = 2.0
@export var drive_off_seconds: float = 2.0
## Where Hank climbs out, past the truck's nose, and how far in front of the
## truck he walks round it so he never crosses over it.
@export var door_offset: Vector2 = Vector2(150.0, 40.0)
@export var walk_in_front: float = 50.0

## Set by PlayerCar before playing.
var car: PlayerCar

## The greeting and goodbye picked last time, so they don't repeat back to back.
static var _last_arrival: int = -1
static var _last_sign_off: int = -1

func play() -> void:
	if not is_instance_valid(car):
		return
	WorldState.tow_count += 1
	var terrain := car.get_terrain()
	var stuck_at := car.global_position
	var set_down := _set_down_spot(terrain, stuck_at)
	var side := _truck_side(terrain, set_down)
	var park := set_down + Vector2(side * park_gap, 0.0)
	var start := park + Vector2(side * drive_in_distance, 0.0)
	if terrain != null and not terrain.is_on_land(terrain.to_local(start)):
		start = park + Vector2(side * park_gap, 0.0)

	Cutscenes.cut_to(stuck_at + Vector2(0.0, -30.0), zoom * 1.3)
	await Cutscenes.wait(1.2)
	await Cutscenes.fade_out(0.5)
	await Cutscenes.title_card(later_card, 1.4)

	var truck := TowTruck.spawn(car.get_parent(), start, side > 0.0)
	Cutscenes.cut_to((stuck_at + park) * 0.5 + Vector2(0.0, -40.0), zoom)
	await Cutscenes.fade_in(0.5)
	Cutscenes.sound(&"tow_reverse_beep", -8.0, truck)
	await Cutscenes.play_tween(truck.drive_to(park, back_in_seconds))
	Cutscenes.sound(&"door_close", -6.0, truck)

	var gifting := WorldState.tow_count >= rod_gift_tow and not Inventory.has_item(FISHING_ROD.id)
	var cab_door := park + Vector2(side * door_offset.x, door_offset.y)
	var round_the_nose := cab_door + Vector2(0.0, walk_in_front)
	var by_the_car := set_down + Vector2(side * 40.0, door_offset.y + walk_in_front)
	var hank := Cutscenes.spawn_actor(HANK, cab_door, side < 0.0)
	await Cutscenes.walk(hank, round_the_nose)
	await Cutscenes.walk(hank, by_the_car)
	Cutscenes.face(hank, stuck_at.x > hank.global_position.x)
	var first_tow := WorldState.tow_count <= 1
	if gifting:
		await _say(repeat_arrival_lines, hank)
	elif first_tow:
		await _say(arrival_lines, hank)
	else:
		_last_arrival = _pick(repeat_arrivals, _last_arrival)
		await _say(repeat_arrivals[_last_arrival], hank)

	await _winch(truck, stuck_at, set_down)

	var paid := mini(fee, Inventory.money)
	Inventory.spend_money(paid)
	Cutscenes.face(hank, car.global_position.x > hank.global_position.x)
	if paid > 0:
		Cutscenes.sound(&"cash_register", -4.0)
	await _say([fee_line] if paid >= fee else [fee_line, broke_lines[randi() % broke_lines.size()]], hank)
	if gifting:
		await _give_rod(hank)
	elif first_tow:
		await _say(sign_off_lines, hank)
	else:
		_last_sign_off = _pick(repeat_sign_offs, _last_sign_off)
		await _say(repeat_sign_offs[_last_sign_off], hank)

	await Cutscenes.walk(hank, round_the_nose)
	await Cutscenes.walk(hank, cab_door)
	hank.visible = false
	Cutscenes.sound(&"door_close", -6.0, truck)
	Cutscenes.sound(&"truck_honk", -10.0, truck)
	await Cutscenes.play_tween(truck.drive_to(park + Vector2(side * drive_in_distance, 0.0), drive_off_seconds))
	truck.queue_free()

## Instead of his usual sign-off: the rod, or a promise of it if the trunk's
## too full to take it.
func _give_rod(hank: CutsceneActor) -> void:
	if not Inventory.give_item(FISHING_ROD):
		await _say(trunk_full_lines, hank)
		return
	await _say(rod_gift_lines, hank)
	Cutscenes.sound(&"part_pickup", -6.0)
	await Cutscenes.title_card(rod_card, 1.6)
	await _say(rod_sign_off_lines, hank)

## A random index into `pool` that isn't `last` (when there's a choice).
static func _pick(pool: Array, last: int) -> int:
	if pool.size() <= 1:
		return 0
	var index := randi() % (pool.size() - 1)
	return index + 1 if index >= last and last >= 0 else index

func _say(lines: Variant, hank: CutsceneActor) -> void:
	for line: String in lines:
		line = line.replace("{fee}", str(fee)).replace("{tows}", str(WorldState.tow_count))
		await Cutscenes.subtitle(speaker_name, HANK, line, hank)

## The cable goes taut and the car is dragged up out of the water onto the
## sand, with a splash as it breaks free and the winch whining throughout.
func _winch(truck: TowTruck, from: Vector2, to: Vector2) -> void:
	truck.cable_target = car
	car.set_towed(true)
	Cutscenes.sound(&"tow_winch", -6.0, truck)
	await Cutscenes.wait(0.3)
	Cutscenes.sound(&"car_splash", -6.0, car)
	Cutscenes.shake(4.0, 0.3)
	var pull := car.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pull.tween_property(car, "global_position", to, pull_seconds).from(from)
	await Cutscenes.play_tween(pull)
	car.set_towed(false)
	truck.cable_target = null
	await Cutscenes.wait(0.3)

## The nearest bit of shoreline, pushed `set_down_inland` up the beach.
func _set_down_spot(terrain: TerrainNetwork, stuck_at: Vector2) -> Vector2:
	if terrain == null:
		return stuck_at
	var local := terrain.to_local(stuck_at)
	var nearest := local
	var best := INF
	for coastline in terrain.get_island_polygons():
		for i in coastline.size():
			var point := Geometry2D.get_closest_point_to_segment(local, coastline[i], coastline[(i + 1) % coastline.size()])
			var distance := local.distance_squared_to(point)
			if distance < best:
				best = distance
				nearest = point
	var inland := (nearest - local).normalized()
	return terrain.to_global(nearest + inland * set_down_inland)

## Which side of the set-down spot the truck parks on (+1 east, -1 west): the
## one with land under both where it parks and where it backs in from.
func _truck_side(terrain: TerrainNetwork, set_down: Vector2) -> float:
	if terrain == null:
		return 1.0
	var best_side := 1.0
	var best_score := -1
	for side: float in [1.0, -1.0]:
		var park := set_down + Vector2(side * park_gap, 0.0)
		var score := 0
		if terrain.is_on_land(terrain.to_local(park)):
			score += 2
		if terrain.is_on_land(terrain.to_local(park + Vector2(side * drive_in_distance, 0.0))):
			score += 1
		if score > best_score:
			best_score = score
			best_side = side
	return best_side
