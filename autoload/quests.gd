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
## Finishing a quest makes the quests in its `unlocks` *available*: not in
## the log yet, but waiting with their giver (whose head the minimap shows)
## until the player talks to them.
##
## The first quest given while nothing is tracked gets tracked straight away,
## so a new player sees what to do without opening the journal.

signal quest_added(quest: QuestData)
## The goal is met and the player should go back to the giver.
signal quest_ready(quest: QuestData)
signal quest_completed(quest: QuestData)
## A quest can now be taken from its giver, or no longer can (it was taken).
signal available_changed
signal tracked_changed(quest: QuestData)

## In the order they were given, oldest first. Ready quests are still here.
var active: Array[QuestData] = []
var completed: Array[QuestData] = []
## Ids of active quests whose goal is met, waiting to be handed in.
var ready_ids: Array[StringName] = []
## Unlocked quests the player hasn't taken yet.
var available: Array[QuestData] = []
## Shown by the on-screen tracker. Null when nothing is tracked.
var tracked: QuestData = null

func _process(_delta: float) -> void:
	# Iterate a copy: finishing a quest takes it out of `active`.
	for quest: QuestData in active.duplicate():
		if quest.scrap_goal <= 0 and quest.item_goal == null and quest.fit_part_goal.is_empty():
			continue
		var met := _goal_reached(quest)
		if met and not is_ready(quest.id):
			goal_met(quest.id)
		elif not met and is_ready(quest.id) and (hands_over_scrap(quest) or hands_over_item(quest)):
			# Sold, spent or lost it before handing it in: back to the goal.
			ready_ids.erase(quest.id)

func _goal_reached(quest: QuestData) -> bool:
	if quest.scrap_goal > 0 and Inventory.scrap < quest.scrap_goal:
		return false
	if quest.item_goal != null and not Inventory.has_item(quest.item_goal.id):
		return false
	if not quest.fit_part_goal.is_empty() and not _part_fitted(quest.fit_part_goal):
		return false
	return true

## Whether any car the player owns wears the part from `scene_path`.
static func _part_fitted(scene_path: String) -> bool:
	for car in Inventory.owned_cars:
		if car == null:
			continue
		if car.body != null and car.body.scene_path == scene_path:
			return true
		if car.engine != null and car.engine.scene_path == scene_path:
			return true
		for wheel in car.wheels:
			if wheel != null and wheel.scene_path == scene_path:
				return true
		for accessory in car.accessories:
			if accessory != null and accessory.scene_path == scene_path:
				return true
	return false

func reset() -> void:
	active.clear()
	completed.clear()
	ready_ids.clear()
	available.clear()
	available_changed.emit()
	tracked = null
	tracked_changed.emit(null)

## Adds `quest` to the log. Does nothing if the player already has it, or
## already finished it.
func give(quest: QuestData) -> void:
	if quest == null or has_quest(quest.id) or is_complete(quest.id):
		return
	if _find(available, quest.id) != null:
		available.erase(_find(available, quest.id))
		available_changed.emit()
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
	if not _goal_reached(quest):
		ready_ids.erase(id)
		return -1
	if hands_over_scrap(quest):
		Inventory.scrap -= quest.scrap_goal
	if hands_over_item(quest):
		Inventory.remove_item(quest.item_goal.id)
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
	var part := reward_part_data(quest)
	if part != null:
		Inventory.add_part(part)
	quest_completed.emit(quest)
	for next in quest.follow_ups:
		give(next)
	var unlocked := false
	for next in quest.unlocks:
		if next != null and not has_quest(next.id) and not is_complete(next.id) \
				and _find(available, next.id) == null:
			available.append(next)
			unlocked = true
	if unlocked:
		available_changed.emit()
	if tracked == quest:
		set_tracked(active.back() if not active.is_empty() else null)
	return quest.reward_money

## Whether handing `quest` in costs the player its scrap goal.
static func hands_over_scrap(quest: QuestData) -> bool:
	return quest.scrap_goal > 0 and quest.hand_over_scrap and quest.return_to_giver

## Whether handing `quest` in takes its item goal out of the trunk.
static func hands_over_item(quest: QuestData) -> bool:
	return quest.item_goal != null and quest.hand_over_item and quest.return_to_giver

## Unlocked quests `giver_name` has waiting for the player, oldest first.
func available_from(giver_name: String) -> Array[QuestData]:
	var found: Array[QuestData] = []
	for quest in available:
		if quest.giver == giver_name:
			found.append(quest)
	return found

## The catalogue entry for `quest`'s reward part, or null.
static func reward_part_data(quest: QuestData) -> PartData:
	if quest == null or quest.reward_part.is_empty():
		return null
	for list: Array in [PartDatabase.bodies, PartDatabase.engines, PartDatabase.wheels, PartDatabase.accessories]:
		for part: PartData in list:
			if part.scene_path == quest.reward_part:
				return part
	return null

## What finishing `quest` pays, for the journal and cards ("$50 + Old
## Generator"), or "" when it pays nothing.
static func reward_text(quest: QuestData) -> String:
	var bits: PackedStringArray = []
	if quest.reward_money > 0:
		bits.append("$%d" % quest.reward_money)
	var part := reward_part_data(quest)
	if part != null:
		bits.append(part.display_name)
	return " + ".join(bits)

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
		if hands_over_item(quest):
			return "Bring the %s back to %s" % [quest.item_goal.display_name, quest.giver]
		return "Go back to %s" % quest.giver
	var text := PlayerProfile.fill(quest.objective)
	if quest.scrap_goal > 0:
		text += " (%d / %d)" % [mini(Inventory.scrap, quest.scrap_goal), quest.scrap_goal]
	return text

## The name of whatever the tracked quest sends the player to right now,
## for the minimap to light up: the giver once it's ready to hand in,
## otherwise its `objective_place`. Empty when there's nothing to point at.
func tracked_target() -> String:
	if tracked == null:
		return ""
	if is_ready(tracked.id):
		return tracked.giver if tracked.return_to_giver else ""
	return tracked.objective_place

## Where `tracked_target()` stands in the world, or Vector2.INF when there's
## nothing to point at (or it isn't in this scene).
func tracked_target_position() -> Vector2:
	var target := tracked_target()
	if target.is_empty():
		return Vector2.INF
	for marker: MinimapMarker in get_tree().get_nodes_in_group(MinimapMarker.GROUP):
		if MapIcons.marker_name(marker) == target:
			return marker.global_position
	for giver in get_tree().get_nodes_in_group(Minimap.GIVER_GROUP):
		if String(giver.get("display_name")) == target:
			return (giver as Node2D).global_position
	return Vector2.INF

## For SaveSystem: putting a saved log back.
func restore(saved_active: Array[QuestData], saved_completed: Array[QuestData],
		saved_ready: Array[StringName], saved_available: Array[QuestData],
		saved_tracked: QuestData) -> void:
	active = saved_active.duplicate()
	completed = saved_completed.duplicate()
	ready_ids = saved_ready.duplicate()
	available = saved_available.duplicate()
	available_changed.emit()
	tracked = _find(active, saved_tracked.id) if saved_tracked != null else null
	tracked_changed.emit(tracked)

static func _find(quests: Array[QuestData], id: StringName) -> QuestData:
	for quest in quests:
		if quest.id == id:
			return quest
	return null
