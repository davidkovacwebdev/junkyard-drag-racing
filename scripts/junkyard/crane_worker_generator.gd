class_name CraneWorkerGenerator
extends RefCounted
## Makes up the crane worker who takes over the pen once Vern has been fished
## out. He's picked from parts that read as yard crew (work clothes, boots, a
## cap or a moustache) and seeded by the save's player, so it's the same guy
## every visit. Unlike Vern he can't be caught: the claw only shoves him.

## His spot in the pen. Never claimed, since he can't be caught.
const CLAIM := "crane_pen_worker"
## Vern runs the crane until the claw takes him; his claim in the pen.
const VERN := preload("res://characters/crane_vern.tres")
const VERN_CLAIM := "crane_pen_vern"
const PARTS_DIRECTORY := "res://scenes/characters/parts/"

const LEGS: Array[String] = ["legs_cargo", "legs_standard", "legs_baggy", "legs_slacks", "legs_plaid"]
const BOOTS: Array[String] = ["boots_work", "boots_steel", "boots_rain", "boots_combat"]
## The hi-vis jacket is in twice: most of the crew wear one.
const TORSOS: Array[String] = ["torso_hazmat", "torso_hazmat", "torso_barrel", "torso_box",
		"torso_muscle", "torso_hoodie", "torso_round"]
const HEADS: Array[String] = ["head_square", "head_jaw", "head_round", "head_wide", "head_big",
		"head_oval", "head_block", "head_pear"]
## An empty entry is a bald head (hair) or nothing extra (accessory).
const HAIRS: Array[String] = ["hair_buzz", "hair_balding", "hair_mullet", "hair_curly", ""]
const EYES: Array[String] = ["eyes_squint", "eyes_grumpy", "eyes_dots", "eyes_sleepy", "eyes_angry", "eyes_wide"]
const ACCESSORIES: Array[String] = ["acc_cap", "acc_moustache", "acc_beard", "acc_goggles", "acc_bandana", ""]

const NAMES: Array[String] = ["Stan", "Boris", "Dragan", "Mirko", "Big Lou", "Rusty", "Zoran", "Dusko",
		"Slavko", "Earl", "Bogdan", "Vlado", "Dale", "Gary", "Milan", "Teddy", "Branko", "Lyle"]
## Their small talk at the junkyard counter.
const IDLE_LINES: Array[String] = [
	"Buyin' scrap. Or take the crane out back and dig for somethin' better yourself.",
	"Got Vern's shift now. Heard that's your fault, {player}.",
	"Crane's out back, cash goes in my pocket.",
	"Don't park on the oil stains. They're load-bearing.",
	"Found a whole toilet in the heap yesterday. Still had the seat warm.",
]
## Said over their head when a shell shoves them.
const BUMP_LINES: Array[String] = [
	"Oi! I'm on my break!",
	"Watch the claw, rookie!",
	"The union's hearin' about this!",
	"Vern never swung it like that!",
	"I'm not scrap, pal!",
	"Easy! I just got these boots!",
	"I saw what you did to Vern. Not happenin' twice!",
]

## Whoever runs the crane right now: Vern, or once he's been fished out, the
## worker on shift. The junkyard counter and the pen agree on it.
static func current_operator() -> CharacterData:
	if not WorldState.is_claimed(VERN_CLAIM):
		return VERN
	return worker()

## The worker's look, name and voice: the same guy every visit.
static func worker() -> CharacterData:
	var rng := _rng("look")
	var data := CharacterData.new()
	data.display_name = _pick(rng, NAMES)
	data.legs_scene = _part(rng, "legs", LEGS)
	data.boots_scene = _part(rng, "boots", BOOTS)
	data.torso_scene = _part(rng, "torsos", TORSOS)
	data.head_scene = _part(rng, "heads", HEADS)
	data.hair_scene = _part(rng, "hairs", HAIRS)
	data.eyes_scene = _part(rng, "eyes", EYES)
	data.accessory_scene = _part(rng, "accessories", ACCESSORIES)
	data.voice_pitch_hz = rng.randf_range(90.0, 150.0)
	data.voice_throat = rng.randf_range(0.82, 1.1)
	data.voice_rasp = rng.randf_range(0.3, 0.8)
	data.voice_wobble = rng.randf_range(0.0, 0.35)
	data.idle_lines = PackedStringArray(IDLE_LINES)
	return data

## Seeded by the save's player too, so two saves don't get the same crew.
## (The 0 is left over from when there was a line of workers, so a save
## keeps the same guy it already had.)
static func _rng(what: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s/%d/%s" % [PlayerProfile.player_name, 0, what])
	return rng

static func _pick(rng: RandomNumberGenerator, options: Array[String]) -> String:
	return options[rng.randi_range(0, options.size() - 1)]

static func _part(rng: RandomNumberGenerator, folder: String, options: Array[String]) -> PackedScene:
	var part_name := _pick(rng, options)
	if part_name.is_empty():
		return null
	return load("%s%s/%s.tscn" % [PARTS_DIRECTORY, folder, part_name]) as PackedScene
