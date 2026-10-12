class_name ChadNpc
extends StaticBody2D
## Chad, Grandpa's brother: the island's police officer, standing out front
## of his house past the west bridge: police shirt hanging open over a hairy
## chest, leather trousers, leather cap and a moustache, squeaky as a toy. The first
## time the player talks to him during "Over the Bridge" they meet properly
## (ChadMeetCutscene), which finishes the quest; after that E is a chat, one
## of his Idle Lines (characters/chad.tres).
##
## In the quest_giver group, so the minimap and GPS can point at him while
## he's what the quest is after (the quest's `objective_place` is his name).
##
## Back from his weekend ("Weekend's Over", two days into "Ask Around"),
## talking to him plays ChadReportCutscene. If it sends the two of them to the
## forge ("Strike While It's Hot"), and then out to the dig site ("The Dig
## Site"), he's riding along in the player's car and isn't at his house till
## that's done.
##
## `at_junkyard`: the Chad who meets the player in the junkyard yard for "Dig
## Deeper" (JunkyardStory puts him there once the crane is fixed). That one
## only chats, from `junkyard_lines`, telling the player to get in the crane.

const CHARACTER := preload("res://characters/chad.tres")
const DIALOG_SCENE := preload("res://scenes/ui/character_dialog.tscn")
const MEET_SCENE_PATH := "res://cutscenes/chad_meet.tres"
const QUEST_ID := &"west_bridge"
const REPORT_SCENE_PATH := "res://cutscenes/chad_report.tres"
const ACTOR_SCALE := 0.55
const BODY_SIZE := Vector2(44.0, 14.0)

@export var display_name: String = "Chad"
@export var dialog_range: float = 300.0
@export var at_junkyard: bool = false
@export var junkyard_lines: PackedStringArray = [
	"Go on, get in that crane. The digs are on me while we look.",
	"Stir that heap up good, {player}. Whatever Eugen saw is under there somewhere.",
	"Swing the claw through it, then dig through what it turned over. Press E, like a bin.",
]

var actor: CutsceneActor
## What the minimap draws his head from.
var character_data: CharacterData = CHARACTER

var _dialog: CharacterDialog
var _talker: Node2D = null
## His name while he's home; `display_name` empties while he's out with the
## player so the car doesn't offer to talk to nobody.
var _name: String
var _away := false

func _ready() -> void:
	_name = display_name
	add_to_group(Minimap.GIVER_GROUP)
	actor = CutsceneActor.new()
	actor.setup(CHARACTER, ACTOR_SCALE)
	add_child(actor)
	actor.face(false)
	var shape := RectangleShape2D.new()
	shape.size = BODY_SIZE
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0.0, -BODY_SIZE.y * 0.5)
	add_child(collision)
	_dialog = DIALOG_SCENE.instantiate()
	add_child(_dialog)

func _process(_delta: float) -> void:
	var away := not at_junkyard and not Cutscenes.is_active() \
			and (Quests.has_quest(TreasureStory.VISIT.id) or Quests.has_quest(TreasureStory.DIG_SITE.id))
	if away != _away:
		_set_away(away)
	if _dialog.is_open() and (not is_instance_valid(_talker)
			or global_position.distance_to(_talker.global_position) > dialog_range):
		_dialog.close()

func _set_away(away: bool) -> void:
	_away = away
	display_name = "" if away else _name
	visible = not away
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape == null:
		for child in get_children():
			if child is CollisionShape2D:
				shape = child
	if shape != null:
		shape.set_deferred("disabled", away)
	if away:
		_dialog.close()

func _report_due() -> bool:
	return not at_junkyard and Quests.has_quest(TreasureStory.MEETUP.id)

func _meeting_due() -> bool:
	return not at_junkyard and Quests.has_quest(QUEST_ID) and not Quests.is_ready(QUEST_ID)

func get_interact_prompt() -> String:
	if _meeting_due():
		return "%s: Press E to talk (Grandpa's brother)" % display_name
	if _report_due():
		return "%s: Press E to talk (back from his weekend)" % display_name
	return "%s: Press E to talk" % display_name

## Called by PlayerCar on E or a click.
func interact(talker: Node = null) -> void:
	if _dialog.is_open() or Cutscenes.is_active() or _away:
		return
	if _report_due():
		_report()
		return
	if _meeting_due():
		var scene := ResourceLoader.load(MEET_SCENE_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as ChadMeetCutscene
		if scene != null:
			scene.chad = self
			await Cutscenes.play(scene)
		Quests.goal_met(QUEST_ID)
		SaveSystem.save_game()
		return
	_talker = talker as Node2D
	_dialog.open(display_name, CHARACTER)
	if at_junkyard:
		_dialog.say(junkyard_lines[randi() % junkyard_lines.size()])
	else:
		_dialog.say(CHARACTER.idle_line("Move along, citizen."))

## "Weekend's Over": the player and Chad swap what they've found out. Finishes
## that and "Ask Around"; if Gus is still loose it hands out "Strike While
## It's Hot", otherwise the player shows Chad the dig spot on their map.
func _report() -> void:
	var scene := ResourceLoader.load(REPORT_SCENE_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as ChadReportCutscene
	if scene == null:
		return
	scene.chad = self
	var caught := TreasureStory.gus_caught()
	scene.gus_caught = caught
	if not caught:
		scene.gives_quest = TreasureStory.VISIT
	await Cutscenes.play(scene)
	Quests.complete(TreasureStory.MEETUP.id)
	Quests.complete(TreasureStory.RUMORS)
	if not caught:
		Quests.set_tracked(Quests.active.filter(
				func(quest: QuestData) -> bool: return quest.id == TreasureStory.VISIT.id).front())
	SaveSystem.save_game()
	if caught and Inventory.has_item(WorldMap.MAP_ITEM):
		WorldMap.open()
