class_name FuneralCutscene
extends Cutscene
## Grandpa's funeral, in the cemetery: everyone who knew him (and a few who
## didn't) stands around his coffin, with Tiger, still painted, in the back.
## One by one they go up and say a few words: the shopkeeper, the two
## paramedics, the Drag Queen's family (waving little trans flags; the others
## trade awkward looks), Tiger (horse noises), the crane man, and last the
## player, who swears to find the Junkyard Treasure
## and leaves a six-pack by the coffin. Played by GrandpaGrave as soon as the
## cemetery loads while the funeral is due.
##
## The words live in res://cutscenes/funeral.tres; edit them in the
## inspector.

const ID := &"funeral"
const SHOPKEEPER := preload("res://characters/shopkeeper.tres")
const GORD := preload("res://characters/paramedic_gord.tres")
const LOU := preload("res://characters/paramedic_lou.tres")
const DARLENE := preload("res://characters/mourner_darlene.tres")
const GUS := preload("res://characters/mourner_gus.tres")
const SIX_PACK := preload("res://scenes/items/icons/item_six_pack.tscn")
const TRANS_FLAG := preload("res://scenes/characters/props/trans_hand_flag.tscn")

## These defaults are the scene as written; edits in the inspector on the
## .tres override them.
@export var shopkeeper_lines: Array[String] = [
	"Eugen single-handedly saved my store from bankruptcy.",
	"He bought two six-packs every day, for three years straight.",
	"I'll miss him.",
]
@export var paramedic_lines: Array[String] = [
	"I'm sorry I made the stupid flat-line joke earlier...",
	"But the joke was solid, and the timing was good.",
	"Bye, Eugen.",
]
@export var family_lines: Array[String] = [
	"We didn't know Eugen, but he sent us a Christmas card every year without fail.",
	"Even after our daughter passed away.",
	"It saddens me that we won't be getting them anymore.",
	"If the world treated trans people as well and as respectfully as Eugen did, it would be a much better place.",
]
@export var crane_lines: Array[String] = [
	"Eugen was my longtime friend.",
	"He was a simple man with big dreams. Always dreaming about finding the Junkyard Treasure.",
	"He never gave up. And in the end, that's what took his life.",
	"He also broke my crane, the drunk old log...",
]
## Tiger's turn: horse nonsense, in a voice like a wet engine.
@export var tiger_lines: Array[String] = [
	"Hrrrmm. Pbbbbbt.",
	"Nyeeehehehe hrm hrm... brrrrhuhuhu.",
	"Pfffrrrrt.",
]
## Said once the crane man has had his cry.
@export var crane_goodbye_line: String = "See ya soon, Eugen."
@export var player_lines: Array[String] = [
	"I never thought this day could come.",
	"He was so full of life, I figured he'd be a nagging piece of flesh forever...",
	"I miss him now.",
	"I'll take on your dream...",
]
## Shouted, last of all.
@export var vow_line: String = "AND I WILL FIND THE JUNKYARD TREASURE!"

@export_group("Staging")
@export var zoom: float = 1.15
@export var speech_zoom: float = 1.5
@export var walk_speed: float = 110.0
## The awkward looks after the family's speech, before anyone moves.
@export var awkward_seconds: float = 2.2
@export var cry_seconds: float = 2.6
## Where the player carries the six-pack, in their character space.
@export var carry_spot := Vector2(30.0, -70.0)

## Set by GrandpaGrave before playing.
var grave: GrandpaGrave

var _coffin_x: float = 0.0
var _tiger_voice: CharacterData

func _init() -> void:
	id = ID
	_tiger_voice = CharacterData.new()
	_tiger_voice.display_name = "Tiger"
	_tiger_voice.voice_pitch_hz = 64.0
	_tiger_voice.voice_throat = 0.65
	_tiger_voice.voice_rasp = 1.0
	_tiger_voice.voice_wobble = 1.0

func play() -> void:
	if not is_instance_valid(grave):
		return
	_coffin_x = grave.global_position.x
	var me := PlayerProfile.character
	var my_name := PlayerProfile.display_name()
	var operator := CraneWorkerGenerator.current_operator()

	await Cutscenes.fade_out(0.0)
	grave.park_car()
	var start := grave.spot(GrandpaGrave.CAR_SPOT + Vector2(-90.0, 0.0))
	var shopkeeper := _mourner(SHOPKEEPER, GrandpaGrave.SHOPKEEPER_SPOT)
	var gord := _mourner(GORD, GrandpaGrave.GORD_SPOT)
	var lou := _mourner(LOU, GrandpaGrave.LOU_SPOT)
	var crane_man := _mourner(operator, GrandpaGrave.OPERATOR_SPOT)
	var darlene := _mourner(DARLENE, GrandpaGrave.DARLENE_SPOT)
	var gus := _mourner(GUS, GrandpaGrave.GUS_SPOT)
	for family: CutsceneActor in [darlene, gus]:
		family.attach(TRANS_FLAG.instantiate())
	var tiger := GrandpaHorse.new()
	tiger.stand_in = true
	tiger.position = grave.spot(GrandpaGrave.TIGER_SPOT)
	grave.get_parent().add_child(tiger)
	tiger.face(false)
	var player: CutsceneActor = null
	if me != null:
		player = Cutscenes.spawn_actor(me, start, true)
	var overview := grave.global_position + Vector2(0.0, 90.0)
	Cutscenes.cut_to((start + overview) * 0.5, zoom)
	await Cutscenes.fade_in(1.2)

	# The player walks up to join them, and the bell tolls.
	if player != null:
		Cutscenes.camera_follow(player)
		await Cutscenes.walk(player, grave.spot(GrandpaGrave.PLAYER_SPOT), walk_speed)
		_face_coffin(player)
	await Cutscenes.camera_to(overview, zoom, 1.0)
	Cutscenes.sound(&"funeral_bell", -6.0, grave)
	await Cutscenes.wait(2.0)

	await _speech(shopkeeper, null, SHOPKEEPER.display_name, SHOPKEEPER, shopkeeper_lines)
	await _speech(gord, lou, GORD.display_name, GORD, paramedic_lines)

	# The family, and then nobody quite knows where to look.
	await _speech(darlene, gus, DARLENE.display_name, DARLENE, family_lines, false)
	var lookers: Array[CutsceneActor] = [shopkeeper, gord, lou, crane_man]
	if player != null:
		lookers.append(player)
	for i in lookers.size():
		var other := lookers[i + 1] if i % 2 == 0 and i + 1 < lookers.size() else lookers[i - 1]
		Cutscenes.face(lookers[i], other.global_position.x > lookers[i].global_position.x)
	await Cutscenes.camera_to(overview, zoom, 0.6)
	Cutscenes.sound(&"cricket_chirp", -8.0, grave)
	await Cutscenes.wait(awkward_seconds)
	for looker in lookers:
		_face_coffin(looker)
	await _walk_back(darlene, gus, GrandpaGrave.DARLENE_SPOT, GrandpaGrave.GUS_SPOT)

	# Tiger has something to say too.
	await _tiger_speech(tiger)

	# The crane man breaks down halfway through.
	await _walk_up(crane_man, null)
	for line in crane_lines:
		await Cutscenes.subtitle(operator.display_name, operator, line, crane_man)
	crane_man.cry(cry_seconds)
	if not Cutscenes.is_skipping():
		# Grandpa's sob, pitched down for a big gruff man.
		Sfx.play(&"grandpa_sob", -5.0, 0.0).pitch_scale = 0.8
	await Cutscenes.wait(cry_seconds)
	await Cutscenes.subtitle(operator.display_name, operator, crane_goodbye_line, crane_man)
	await _walk_back(crane_man, null, GrandpaGrave.OPERATOR_SPOT, Vector2.ZERO)

	# Last, the player.
	if player != null:
		await _walk_up(player, null)
	for line in player_lines:
		await Cutscenes.subtitle(my_name, me, line, player)
	if player != null:
		Cutscenes.shake(8.0, 0.4)
	await Cutscenes.subtitle(my_name, me, vow_line, player)
	await Cutscenes.wait(0.5)

	# A six-pack for the road.
	if player != null:
		var six_pack := SIX_PACK.instantiate() as Node2D
		six_pack.position = carry_spot
		player.attach(six_pack)
		await Cutscenes.walk(player, grave.spot(GrandpaGrave.SIX_PACK_SPOT + Vector2(-44.0, 30.0)), walk_speed * 0.6)
		Cutscenes.face(player, true)
		await Cutscenes.wait(0.3)
		six_pack.queue_free()
	grave.show_six_pack(true)
	Cutscenes.sound(&"can_clatter", -10.0, grave.spot(GrandpaGrave.SIX_PACK_SPOT))
	await Cutscenes.wait(0.6)
	if player != null:
		await Cutscenes.walk(player, grave.spot(GrandpaGrave.PLAYER_SPOT), walk_speed * 0.6)
		_face_coffin(player)
	Cutscenes.sound(&"funeral_bell", -6.0, grave)
	await Cutscenes.wait(2.5)
	await Cutscenes.fade_out(1.2)
	tiger.queue_free()
	# Under the black: the coffin's in the ground when the lights come back.
	grave.finish()

## Tiger clops up from the back, round the front of the coffin, neighs its
## piece, and goes back to its carrots.
func _tiger_speech(tiger: GrandpaHorse) -> void:
	var home := tiger.global_position
	var detour := grave.spot(Vector2(150.0, 115.0))
	var at := grave.spot(GrandpaGrave.SPEAK_SPOT + Vector2(-40.0, 10.0))
	Cutscenes.camera_to(at + Vector2(120.0, -100.0), speech_zoom, 1.6)
	await Cutscenes.play_tween(tiger.walk_to(detour, 1.0))
	await Cutscenes.play_tween(tiger.walk_to(at, 1.8))
	tiger.face(true)
	tiger.lift_head(true)
	Cutscenes.sound(&"horse_neigh", -4.0, tiger.global_position)
	await Cutscenes.wait(0.8)
	for line in tiger_lines:
		await Cutscenes.subtitle(_tiger_voice.display_name, _tiger_voice, line)
	Cutscenes.sound(&"horse_neigh", -6.0, tiger.global_position)
	await Cutscenes.wait(0.5)
	Cutscenes.camera_to(grave.global_position + Vector2(0.0, 90.0), zoom, 1.4)
	await Cutscenes.play_tween(tiger.walk_to(detour, 1.8))
	await Cutscenes.play_tween(tiger.walk_to(home, 1.0))
	tiger.face(false)
	tiger.lift_head(false)

## Someone standing in the crowd, turned to the coffin.
func _mourner(character: CharacterData, local: Vector2) -> CutsceneActor:
	var actor := Cutscenes.spawn_actor(character, grave.spot(local), true)
	_face_coffin(actor)
	return actor

func _face_coffin(actor: CutsceneActor) -> void:
	Cutscenes.face(actor, actor.global_position.x < _coffin_x)

## `speaker` (and `second`, standing by them) goes up, says `lines`, and
## (unless `go_back` is false) goes back to their place.
func _speech(speaker: CutsceneActor, second: CutsceneActor, speaker_name: String,
		character: CharacterData, lines: Array[String], go_back: bool = true) -> void:
	var home := speaker.global_position - grave.global_position
	var second_home := second.global_position - grave.global_position if second != null else Vector2.ZERO
	await _walk_up(speaker, second)
	for line in lines:
		await Cutscenes.subtitle(speaker_name, character, line, speaker)
	await Cutscenes.wait(0.4)
	if go_back:
		await _walk_back(speaker, second, home, second_home)

func _walk_up(speaker: CutsceneActor, second: CutsceneActor) -> void:
	var at := grave.spot(GrandpaGrave.SPEAK_SPOT)
	Cutscenes.camera_to(at + Vector2(120.0, -100.0), speech_zoom, 1.2)
	if second != null:
		Cutscenes.play_tween(second.walk_to(at + GrandpaGrave.SECOND_SPEAKER_OFFSET, walk_speed))
	await Cutscenes.walk(speaker, at, walk_speed)
	Cutscenes.face(speaker, true)
	if second != null:
		Cutscenes.face(second, true)
	await Cutscenes.wait(0.3)

func _walk_back(speaker: CutsceneActor, second: CutsceneActor, home: Vector2, second_home: Vector2) -> void:
	Cutscenes.camera_to(grave.global_position + Vector2(0.0, 90.0), zoom, 1.0)
	if second != null:
		Cutscenes.play_tween(second.walk_to(grave.spot(second_home), walk_speed))
	await Cutscenes.walk(speaker, grave.spot(home), walk_speed)
	_face_coffin(speaker)
	if second != null:
		_face_coffin(second)
