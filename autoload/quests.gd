extends Node
## The quest log (autoload `Quests`): which quests the player has, which are
## done, and which one is tracked on screen. The journal (J) and the tracker
## read it; SaveSystem saves it.
##
## Quests come in through `give()`, usually from a cutscene's `gives_quest`
## once the scene ends. A quest with a `scrap_goal` notices by itself when the
## player holds that much scrap; code can say the same for any other goal with
## `goal_met()`. Then, for a quest with `return_to_giver`, the quest is
## "ready": the tracker says to go back, and talking to the giver calls
## `turn_in()`, which finishes it and pays the reward. Without it, the quest
## finishes (and pays) on the spot.
##
## The first quest given while nothing is tracked gets tracked straight away,
## so a new player sees what to do without opening the journal.

signal quest_added(quest: QuestData)
## The goal is met and the player should go back to the giver.
signal quest_ready(quest: QuestData)
signal quest_completed(quest: QuestData)
signal tracked_changed(quest: QuestData)

## In the order they were given, oldest first. Ready quests are still here.
var active: Array[QuestData] = []
var completed: Array[QuestData] = []
## Ids of active quests whose goal is met, waiting to be handed in.
var ready_ids: Array[StringName] = []
## Shown by the on-screen tracker. Null when nothing is tracked.
var tracked: QuestData = null

func _process(_delta: float) -> void:
	# Iterate a copy: finishing a quest takes it out of `active`.
	for quest: QuestData in active.duplicate():
		if quest.scrap_goal <= 0:
			continue
		var enough := Inventory.scrap >= quest.scrap_goal
		if enough and not is_ready(quest.id):
			goal_met(quest.id)
		elif not enough and is_ready(quest.id) and hands_over_scrap(quest):
			# Sold or spent some before handing it in: back to gathering.
			ready_ids.erase(quest.id)

func reset() -> void:
	active.clear()
	completed.clear()
	ready_ids.clear()
	tracked = null
	tracked_changed.emit(null)

## Adds `quest` to the log. Does nothing if the player already has it, or
## already finished it.
func give(quest: QuestData) -> void:
	if quest == null or has_quest(quest.id) or is_complete(quest.id):
		return
	active.append(quest)
	quest_added.emit(quest)
	if tracked == null:
		set_tracked(quest)

## The quest's goal is done. It waits for the giver if it has to be handed
## in, otherwise it finishes now.
func goal_met(id: StringName) -> void:
	var quest := _find(active, id)
	if quest == null or is_ready(id):
		return
	if quest.return_to_giver:
		ready_ids.append(id)
		quest_ready.emit(quest)
	else:
		complete(id)

## The giver takes the quest back: it's finished and the reward is paid.
## Returns the money paid, or -1 if the quest wasn't ready to hand in.
func turn_in(id: StringName) -> int:
	if not is_ready(id):
		return -1
	var quest := _find(active, id)
	if hands_over_scrap(quest):
		if Inventory.scrap < quest.scrap_goal:
			ready_ids.erase(id)
			return -1
		Inventory.scrap -= quest.scrap_goal
	return complete(id)

## Finishes the quest and pays its reward, whatever state it was in. Returns
## the money paid (0 if the quest wasn't active).
func complete(id: StringName) -> int:
	var quest := _find(active, id)
	if quest == null:
		return 0
	active.erase(quest)
	ready_ids.erase(id)
	completed.append(quest)
	Inventory.money += quest.reward_money
	quest_completed.emit(quest)
	if tracked == quest:
		set_tracked(active.back() if not active.is_empty() else null)
	return quest.reward_money

## Whether handing `quest` in costs the player its scrap goal.
static func hands_over_scrap(quest: QuestData) -> bool:
	return quest.scrap_goal > 0 and quest.hand_over_scrap and quest.return_to_giver

## Tracks `quest`, or stops tracking with null.
func set_tracked(quest: QuestData) -> void:
	if tracked == quest:
		return
	tracked = quest
	tracked_changed.emit(quest)

func has_quest(id: StringName) -> bool:
	return _find(active, id) != null

func is_ready(id: StringName) -> bool:
	return ready_ids.has(id)

func is_complete(id: StringName) -> bool:
	return _find(completed, id) != null

## Active quests `giver_name` handed out, oldest first.
func quests_from(giver_name: String) -> Array[QuestData]:
	var found: Array[QuestData] = []
	for quest in active:
		if quest.giver == giver_name:
			found.append(quest)
	return found

## What to do next on `quest`, for the tracker and journal: "Go back to
## Grandpa" once it's ready, otherwise its objective with a live count
## ("... (12 / 20)") when it has one.
func objective_text(quest: QuestData) -> String:
	if quest == null:
		return ""
	if is_ready(quest.id):
		if quest.giver.is_empty():
			return "Done!"
		if hands_over_scrap(quest):
			return "Bring the %d scrap back to %s" % [quest.scrap_goal, quest.giver]
		return "Go back to %s" % quest.giver
	var text := PlayerProfile.fill(quest.objective)
	if quest.scrap_goal > 0:
		text += " (%d / %d)" % [mini(Inventory.scrap, quest.scrap_goal), quest.scrap_goal]
	return text

## For SaveSystem: putting a saved log back.
func restore(saved_active: Array[QuestData], saved_completed: Array[QuestData],
		saved_ready: Array[StringName], saved_tracked: QuestData) -> void:
	active = saved_active.duplicate()
	completed = saved_completed.duplicate()
	ready_ids = saved_ready.duplicate()
	tracked = _find(active, saved_tracked.id) if saved_tracked != null else null
	tracked_changed.emit(tracked)

static func _find(quests: Array[QuestData], id: StringName) -> QuestData:
	for quest in quests:
		if quest.id == id:
			return quest
	return null
