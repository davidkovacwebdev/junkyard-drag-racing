class_name ForgeAnvilCutscene
extends CoinsCutscene
## Handing in "Hammer Time": the player rolls up to the scrap forge with an
## anvil bolted on as a wheel. Gus can't believe it, walks over, unbolts it
## right off the car and carries it back to his stump. One test strike, then
## he looks at the car, now a wheel short, and asks if the player can even
## make it home like that. The one time a car drives around missing a wheel:
## the garage won't let it back out until the mount is filled. Played by
## ForgeSmith, which finishes the quest once it's over.
##
## The words live in res://cutscenes/forge_anvil.tres.

const ID := &"forge_anvil"
const QUEST_ID := &"forge_anvil"
const ANVIL_WHEEL := "res://scenes/parts/wheels/wheel_anvil.tscn"
## Held over his head, in his character space.
const CARRY_SPOT := Vector2(0.0, -300.0)
const CARRY_SCALE := 1.3

@export var spot_line: String = "Hold on. Is that... MY ANVIL? Bolted on your car? As a WHEEL?"
@export var found_line: String = "Found it in the junk. It rolls terrible."
@export var take_line: String = "'Course it rolls terrible, it's an anvil. Gimme that."
@export var music_line: String = "Ahh. Hear that? That's music."
@export var home_line: String = "...You think you'll make it home like that?"
@export var answer_line: String = "Probably."
@export var open_line: String = "Hah! Forge is open. Bring me junk to melt. And maybe get yourself a wheel."

@export_group("Staging")
## How long Gus stands at the car unbolting it.
@export var unbolt_seconds: float = 0.9

## Set before playing: the stump the anvil goes back on.
var stump: ForgeProp

func _init() -> void:
	id = ID

## Whether the car being driven has an anvil on one of its mounts.
static func driving_on_anvil() -> bool:
	return _anvil_mount(Inventory.get_selected_car()) != -1

func play() -> void:
	if not await stage():
		return
	var car_node := Cutscenes.get_tree().get_first_node_in_group(PlayerCar.GROUP) as PlayerCar
	var car := Inventory.get_selected_car()
	var mount := _anvil_mount(car)
	var wheel_at := _wheel_position(car_node, mount)

	await npc_says(spot_line)
	await i_say(found_line)
	await npc_says(take_line)

	Cutscenes.camera_to((wheel_at + npc.global_position) * 0.5 + Vector2(0.0, -90.0), zoom - 0.2, 0.8)
	await Cutscenes.walk(npc, wheel_at + Vector2(0.0, 18.0), 170.0)
	Cutscenes.sound(&"part_unbolt", -4.0)
	await Cutscenes.wait(unbolt_seconds * 0.5)
	Cutscenes.sound(&"part_unbolt", -4.0, wheel_at)
	await Cutscenes.wait(unbolt_seconds * 0.5)
	# Taken even on a skip, so the car's a wheel short either way.
	var anvil := _take_anvil(car, mount, car_node)
	var carried := _carry(anvil)
	Cutscenes.sound(&"anvil_clang", -6.0)
	Cutscenes.shake(5.0, 0.2)

	var stump_at := stump.global_position if is_instance_valid(stump) else npc_rig.global_position
	Cutscenes.camera_to(two_shot, zoom, 0.8)
	await Cutscenes.walk(npc, stump_at + Vector2(-72.0, -2.0), 110.0)
	Cutscenes.face(npc, true)
	if is_instance_valid(carried):
		carried.queue_free()
	if is_instance_valid(stump):
		stump.anvil_on_stump = true
	Cutscenes.sound(&"anvil_clang", -2.0)
	Cutscenes.shake(10.0, 0.3)
	await Cutscenes.wait(0.6)
	Cutscenes.sound(&"forge_hammer", -4.0)
	Cutscenes.hop(npc, 14.0)
	await Cutscenes.wait(0.5)
	await npc_says(music_line)

	if car_node != null:
		await Cutscenes.camera_to(car_node.global_position + Vector2(0.0, -40.0), zoom, 0.7)
		await Cutscenes.wait(0.9)
	await npc_says(home_line)
	await i_say(answer_line)
	await Cutscenes.camera_to(two_shot, zoom, 0.5)
	await npc_says(open_line)

	if player != null and car_node != null:
		await Cutscenes.walk(player, car_node.global_position + Vector2(0.0, 14.0), 200.0)
		Cutscenes.sound(&"door_close", -6.0)
	unstage()

## Which of `car`'s mounts wears an anvil, or -1.
static func _anvil_mount(car: CarModelData) -> int:
	if car == null:
		return -1
	for i in car.wheels.size():
		var wheel := car.wheels[i]
		if wheel != null and wheel.catalog_id() == &"wheel_anvil":
			return i
	return -1

## Where mount `mount` sits on the map car, or just beside the car when it
## can't be found.
static func _wheel_position(car_node: PlayerCar, mount: int) -> Vector2:
	if car_node == null:
		return Vector2.ZERO
	var view := car_node.get_node_or_null("Visual") as CarView
	if view != null and mount >= 0:
		var mounts := view.get_wheel_mounts()
		if mount < mounts.size():
			return view.to_global(mounts[mount])
	return car_node.global_position

## The anvil comes off for good, leaving its mount empty.
static func _take_anvil(car: CarModelData, mount: int, car_node: PlayerCar) -> WheelPartData:
	if car == null or mount < 0:
		return null
	var anvil := car.wheels[mount]
	car.wheels[mount] = null
	if car_node != null:
		car_node.refresh_parts()
	return anvil

## The anvil, held up over Gus's head on the walk back.
func _carry(anvil: WheelPartData) -> Node2D:
	if anvil == null or Cutscenes.is_skipping():
		return null
	var art := PartFactory.instantiate(anvil)
	if art == null:
		return null
	if art is RigidBody2D:
		art.freeze = true
		art.collision_layer = 0
		art.collision_mask = 0
	art.position = CARRY_SPOT
	art.scale = Vector2.ONE * CARRY_SCALE
	art.z_index = GrandpaNpc.WRENCH_Z
	npc.attach(art)
	return art
