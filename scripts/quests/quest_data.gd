@tool
class_name QuestData
extends Resource
## One quest, as shown in the journal (J). Each lives in its own .tres under
## res://quests, so its words can be edited in the inspector.
##
## A cutscene hands one out through its `gives_quest` (see Cutscene). Once
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

@export_group("Goal")
## Finish automatically once the player is holding this much scrap. 0 means
## no scrap goal: code finishes the quest with `Quests.complete(id)` instead.
@export var scrap_goal: int = 0
## The giver takes the `scrap_goal` scrap off the player when the quest is
## handed in. The quest only counts as ready while the player still holds it.
@export var hand_over_scrap: bool = true

@export_group("Hand-in")
## When the goal is met, the player has to go back and talk to the giver to
## finish the quest (and get the reward). Off: it finishes on the spot.
@export var return_to_giver: bool = true
## Cash the player gets when the quest is finished.
@export var reward_money: int = 0
## What the giver says if the player comes back before the goal is met.
@export var reminder_line: String = ""
## What the giver says when the player hands the quest in.
@export var turn_in_line: String = ""
