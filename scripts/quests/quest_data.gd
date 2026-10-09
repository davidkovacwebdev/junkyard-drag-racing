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

const QUEST_ARRAY_HINT := "24/17:QuestData"

@export_group("Chain")
## Quests that become available (giver's head on the map) once this one is
## finished. Untyped with a QuestData-only hint rather than Array[QuestData]:
## a script holding typed arrays of its own class leaks at exit.
@export_custom(PROPERTY_HINT_TYPE_STRING, QUEST_ARRAY_HINT) var unlocks: Array = []
## Quests handed to the player straight away when this one is finished.
@export_custom(PROPERTY_HINT_TYPE_STRING, QUEST_ARRAY_HINT) var follow_ups: Array = []
## Holds the `follow_ups` back this many in-game days after the quest is
## finished (see DayNightCycle.day): they land in the log out of nowhere
## once the time has passed. 0: straight away.
@export var follow_up_delay_days: int = 0
## The scene played when the player takes this quest from its giver. It
## should give this quest (its Gives Quest). Empty: the quest is just given.
@export_file("*.tres") var start_cutscene: String = ""

## Cash the giver hands over along with the quest (to spend on it), paid
## when it's given.
@export var start_money: int = 0

@export_group("Goal")
## Finish automatically once the player is holding this much scrap. 0 means
## no scrap goal: code finishes the quest with `Quests.complete(id)` instead.
@export var scrap_goal: int = 0
## Ready while the player has at least this much cash. 0: no money goal.
## The giver never takes it; it only has to be there when handing in.
@export var money_goal: int = 0
## The giver takes the `scrap_goal` scrap off the player when the quest is
## handed in. The quest only counts as ready while the player still holds it.
@export var hand_over_scrap: bool = true
## Ready once the player owns this item (it's in the trunk).
@export var item_goal: ItemData
## Ready once the player also owns every one of these items (alongside
## `item_goal`, for an errand with more than one thing on the list).
@export var item_goals: Array[ItemData] = []
## Ready once the player owns this car part (its part scene), loose in the
## spare parts or fitted to a car.
@export_file("*.tscn") var own_part_goal: String = ""
## The giver takes the `own_part_goal` part when it's handed in (off the car
## too, which gets the starter part back in that slot).
@export var hand_over_part: bool = true
## Ready once this car part (its part scene) is fitted to one of the
## player's cars in the garage.
@export_file("*.tscn") var fit_part_goal: String = ""
## Ready once the player reads this item from the trunk (its
## `read_text`; see `Quests.item_read()`): a letter they've been handed.
@export var read_goal: ItemData
## Ready once the player has driven a race (won or lost) at the venue with
## this display name ("Drag Strip"). The quest's note becomes "won" or "lost".
@export var race_goal_venue: String = ""
## Something code counts up with `Quests.add_count()` (rams on the garbage
## truck, say), shown on the tracker as "(3 / 10)". It isn't a goal by
## itself: the code doing the counting decides what reaching it does. 0: no
## count.
@export var count_goal: int = 0
## What the count is of, after it on the tracker ("3 / 10 rams"). Empty:
## just the numbers.
@export var count_label: String = ""
## Seconds of honking the horn this quest wants, added up by code with
## `Quests.add_horn_time()` (at the garbage truck, say) and shown on the
## tracker. Like `count_goal`, the code doing the adding decides what
## reaching it does. 0: none.
@export var horn_goal_seconds: float = 0.0
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
## A scene played when the player hands the quest in to the giver (who it's
## given to as `grandpa`, if it has one); the quest is finished and paid
## once it's over, and `turn_in_line` isn't said. Empty: no scene.
@export_file("*.tres") var turn_in_cutscene: String = ""
## What the giver says when the player hands the quest in.
@export var turn_in_line: String = ""
## Said instead of `turn_in_line` when the goal was met with nothing to show
## for it (the quest's note is empty: the crane came up empty, say). The
## giver weeps through it. Empty: `turn_in_line` either way.
@export var empty_handed_line: String = ""
## A one-shot played as the giver takes the quest back, on top of the usual
## reward sounds (Grandpa cracking open the beer he sent you for, say).
## Empty: nothing extra.
@export var turn_in_sound: StringName = &""
