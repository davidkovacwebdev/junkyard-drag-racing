@tool
class_name QuestData
extends Resource
## One quest, as shown in the journal (J). Each lives in its own .tres under
## res://quests, so its words can be edited in the inspector.
##
## A quest starts one of two ways: a story cutscene hands it out through its
## `gives_quest` (see Cutscene), or it becomes *available* when a quest that
## `unlocks` it is finished. An available quest shows its giver's head on the
## minimap; talking to the giver plays its `start_cutscene` (which gives it). Once
## its goal is met it either finishes on the spot or, with
## `return_to_giver`, waits for the player to go back and talk to the giver,
## who hands over the reward.

## What saves and code refer to it by. Never change it once a quest shipped.
@export var id: StringName = &""
@export var title: String = ""
## Who asked, shown under the title ("From Grandpa").
@export var giver: String = ""
## The journal entry. `{player}` becomes the player's name.
@export_multiline var description: String = ""
## The one thing to do right now, short enough for the on-screen tracker.
@export var objective: String = ""
## A place the player has to go for this quest: the display name of a
## building or person on the map ("Shop"). While this quest is tracked and
## not done yet, that place's minimap icon glows yellow.
@export var objective_place: String = ""

@export_group("Chain")
## Quests that become available (giver's head on the map) once this one is
## finished.
@export var unlocks: Array[QuestData] = []
## Quests handed to the player straight away when this one is finished.
@export var follow_ups: Array[QuestData] = []
## The scene played when the player takes this quest from its giver. It
## should give this quest (its Gives Quest). Empty: the quest is just given.
@export_file("*.tres") var start_cutscene: String = ""

@export_group("Goal")
## Finish automatically once the player is holding this much scrap. 0 means
## no scrap goal: code finishes the quest with `Quests.complete(id)` instead.
@export var scrap_goal: int = 0
## The giver takes the `scrap_goal` scrap off the player when the quest is
## handed in. The quest only counts as ready while the player still holds it.
@export var hand_over_scrap: bool = true
## Ready once the player owns this item (it's in the trunk).
@export var item_goal: ItemData
## Ready once this car part (its part scene) is fitted to one of the
## player's cars in the garage.
@export_file("*.tscn") var fit_part_goal: String = ""
## The giver takes the `item_goal` out of the trunk when it's handed in.
@export var hand_over_item: bool = true

@export_group("Hand-in")
## When the goal is met, the player has to go back and talk to the giver to
## finish the quest (and get the reward). Off: it finishes on the spot.
@export var return_to_giver: bool = true
## Cash the player gets when the quest is finished.
@export var reward_money: int = 0
## A car part (its part scene) the player gets when the quest is finished.
## It goes into the garage's spare parts.
@export_file("*.tscn") var reward_part: String = ""
## What the giver says if the player comes back before the goal is met.
@export var reminder_line: String = ""
## What the giver says when the player hands the quest in.
@export var turn_in_line: String = ""
