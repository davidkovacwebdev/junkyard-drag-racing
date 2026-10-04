class_name GrandpaBaconCutscene
extends Cutscene
## Handing in "Chains": the player comes back with the chains to find
## Grandpa trying to smoke bacon on a couple of oil drums and road signs.
## He sees the chains, which turn out to be just what he needed to hang the
## meat, and once they're up he sends the player off to the hill climb. The
## quest's `turn_in_cutscene`; GrandpaNpc finishes the quest (which hands
## out "King of the Hill") once it's over.
##
## The words live in res://cutscenes/grandpa_bacon.tres; edit them in the
## inspector. The beats:
##   - opens on the smoker, smoke rolling, then over to Grandpa coughing
##   - the player walks up carrying the chains; his eyes pop and he says the
##     `chains_lines`
##   - a quick cut: the chains are up on the smoker's bar with bacon hanging
##     off them
##   - he says the `send_off_lines`

const ID := &"grandpa_bacon"
const GRANDPA := preload("res://characters/grandpa.tres")
const CHAINS := preload("res://scenes/items/icons/item_chains.tscn")

@export var speaker_name: String = "Grandpa"
## These defaults are the scene as written; edits in the inspector on the
## .tres override them.
@export_multiline var chains_lines: PackedStringArray = [
	"Excellent! Just what I needed to hang the meat for smoking.",
]
@export_multiline var send_off_lines: PackedStringArray = [
	"Now what are you waiting for? Go enter the hill climbing race and let me know how it was.",
]

@export_group("Staging")
## Where the player's own character stands, relative to Grandpa.
@export var player_offset := Vector2(110.0, -40.0)
@export var zoom: float = 1.7
@export var smoker_zoom: float = 2.2
## Aims above everyone's feet so heads stay in frame.
@export var camera_lift: float = 80.0
## Where the player carries the chains, in their character space.
@export var carry_spot := Vector2(30.0, -95.0)
@export var carry_scale: float = 1.6

## Set by GrandpaNpc before playing: the Grandpa parked in the world.
var grandpa: GrandpaNpc

func _init() -> void:
	id = ID

func play() -> void:
	if not is_instance_valid(grandpa):
		return
	var smoker := Cutscenes.get_tree().get_first_node_in_group(BaconSmoker.GROUP) as BaconSmoker
	var player_spot := grandpa.global_position + player_offset
	var middle := grandpa.global_position + Vector2(-60.0, -camera_lift)

	await Cutscenes.fade_out(0.0)
	var player: CutsceneActor = null
	var chains: Node2D = null
	if PlayerProfile.character != null:
		player = Cutscenes.spawn_actor(PlayerProfile.character, player_spot + Vector2(160.0, 0.0), false)
		chains = CHAINS.instantiate()
		chains.position = carry_spot
		chains.scale = Vector2.ONE * carry_scale
		chains.z_index = GrandpaNpc.WRENCH_Z
		player.attach(chains)
	if smoker != null:
		Cutscenes.cut_to(smoker.global_position + Vector2(0.0, -70.0), smoker_zoom)
		Cutscenes.sound(&"bacon_sizzle", -6.0, smoker)
	else:
		Cutscenes.cut_to(middle, zoom)
	await Cutscenes.fade_in(0.8)
	await Cutscenes.wait(1.0)
	await Cutscenes.camera_to(middle, zoom, 1.0)
	if not Cutscenes.is_skipping():
		# The smoke's getting to him.
		grandpa.hiccup(-6.0)
		await Cutscenes.wait(0.5)
		grandpa.hiccup(-8.0)
	if player != null:
		await Cutscenes.walk(player, player_spot, 120.0)
		Cutscenes.face(player, false)
	grandpa.actor.face(true)
	await Cutscenes.wait(0.3)

	if not Cutscenes.is_skipping():
		grandpa.widen_eyes(1.6)
	for line in chains_lines:
		await Cutscenes.subtitle(speaker_name, GRANDPA, line, grandpa.actor)

	# Up they go.
	await Cutscenes.fade_out(0.4)
	if is_instance_valid(chains):
		chains.queue_free()
	if smoker != null:
		smoker.chains_hung = true
		Cutscenes.cut_to(smoker.bar_center(), smoker_zoom)
	Cutscenes.sound(&"chain_rattle", -4.0, smoker if smoker != null else grandpa)
	await Cutscenes.fade_in(0.4)
	await Cutscenes.wait(1.2)
	await Cutscenes.camera_to(middle, zoom, 0.8)

	for line in send_off_lines:
		await Cutscenes.subtitle(speaker_name, GRANDPA, line, grandpa.actor)
	await Cutscenes.wait(0.4)
	grandpa.actor.face(grandpa.facing_right)
