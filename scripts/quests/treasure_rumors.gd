class_name TreasureRumors
extends RefCounted
## "Ask Around" (after "Dig Deeper"): Chad has sent the player to snoop around
## town about the Junkyard Treasure. While it's on, everyone with a dialog
## gets an extra option to ask about it. Each asker passes its own `npc` key:
## the scrap dealer, the shopkeeper and the race clerks just answer, the
## farmer and the smith play a scene the first time (FarmerCoinsCutscene,
## SmithCoinsCutscene), the beggar wants paying first (BeggarNpc, "Wet His
## Whistle"), and once he's talked, the smith gets a second scene
## (SmithConfrontCutscene). Anyone else shrugs.

const QUEST := &"treasure_rumors"
const ASK_LINE := "So, about that Junkyard Treasure..."
const ANSWER_LINE := "I don't know."

const SCRAP_DEALER := &"scrap_dealer"
const SHOPKEEPER := &"shopkeeper"
const FARMER := &"farmer"
const SMITH := &"smith"
const CLERK_DRAG := &"clerk_drag"
const CLERK_RALLY := &"clerk_rally"
const CLERK_HILL := &"clerk_hill"
const CLERK_DERBY := &"clerk_derby"

const ANSWERS := {
	SCRAP_DEALER: "I know Eugen was crazy about it, especially in the recent times. Apart from the fake gold he saw before he died, I know nothing.",
	SHOPKEEPER: "Hell nah, leave me out of it. Ever since Eugen died everyone's been talking about it non stop. People even try to sell me junk now and then, sayin' it's a part of the treasure. Gus from the Scrap Forge is the most annoying with it. Go ask him, you won't be able to shut him up.",
	CLERK_DRAG: "Oh, I know nothing. I think it's a scam. Although one guy did propose a part of the treasure be the reward for first place. He presented some coins, but wanted to stay anonymous.",
	CLERK_RALLY: "Oh, someone did mention some coins as a possible reward, but I thought it was a scam. The guy wore a welding mask...",
	CLERK_HILL: "One dude did mention it 2 days ago. Said he wanted to give out a coin as a reward, for $2000. Puny scam, I think. Don't trouble yourself with that.",
	CLERK_DERBY: "Nope! I heard some guy was offering it as a reward, but he never came close to me.",
	## After their scenes have played.
	FARMER: "Still keepin' an eye out for whoever's plantin' them coins.",
	SMITH: "I said leave my store.",
}

const FARMER_SCENE := preload("res://cutscenes/farmer_coins.tres")
const SMITH_SCENE := preload("res://cutscenes/smith_coins.tres")
const CONFRONT_SCENE := preload("res://cutscenes/smith_confront.tres")
const BEGGAR_QUEST := &"beggar_info"

## Whether the player is asking around right now.
static func can_ask() -> bool:
	return Quests.has_quest(QUEST)

## What `npc` (one of the keys above) says when asked.
static func answer(npc: StringName = &"") -> String:
	return ANSWERS.get(npc, ANSWER_LINE)

## The dialog option, for a CharacterDialog: `dialog` says `npc`'s answer.
static func option(dialog: CharacterDialog, npc: StringName = &"") -> CharacterDialog.Option:
	return CharacterDialog.Option.new(ASK_LINE, func() -> void: dialog.say_about(QUEST, answer(npc), ASK_LINE))

## Whether `npc` still has a scene to play instead of a plain answer.
static func has_scene(npc: StringName) -> bool:
	match npc:
		FARMER: return not Cutscenes.has_seen(FarmerCoinsCutscene.ID)
		SMITH: return _smith_scene() != null
	return false

## The smith's next scene: his coins, then (after the beggar's tip) being
## accused. Null once both have played.
static func _smith_scene() -> CoinsCutscene:
	if not Cutscenes.has_seen(SmithCoinsCutscene.ID):
		return SMITH_SCENE
	if Quests.is_complete(BEGGAR_QUEST) and not Cutscenes.has_seen(SmithConfrontCutscene.ID):
		return CONFRONT_SCENE
	return null

## Plays `npc`'s scene once, with `rig` (the NPC's own CharacterRig in the
## world) standing in for them.
static func play_scene(npc: StringName, rig: CharacterRig) -> void:
	var source: CoinsCutscene = FARMER_SCENE if npc == FARMER else _smith_scene()
	if source == null:
		return
	var scene: CoinsCutscene = source.duplicate()
	scene.npc_rig = rig
	Cutscenes.play_once(scene)
