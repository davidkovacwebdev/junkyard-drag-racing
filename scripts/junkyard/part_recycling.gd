class_name PartRecycling
extends RefCounted
## The junkyard recycler's rules: what a part shreds down to, and which parts
## it won't take.
##
## A part is worth up to the sum of the three stat bars on its card
## (durability, speed, mass, 0-5 blocks each, see StatBar), and at least half
## of that; every shred rolls somewhere in between. Never less than 1 scrap.

## Scrap a part can shred down to, as Vector2i(least, most).
static func scrap_range(part: PartData) -> Vector2i:
	var most := StatBar.rating_for(part.durability_rating_fraction()) \
			+ StatBar.rating_for(part.speed_rating_fraction()) \
			+ StatBar.rating_for(part.mass_rating_fraction())
	most = maxi(most, 1)
	return Vector2i(maxi(ceili(most / 2.0), 1), most)

static func roll_scrap(part: PartData, rng: RandomNumberGenerator) -> int:
	var span := scrap_range(part)
	return rng.randi_range(span.x, span.y)

## The active quest still waiting on a part like this (one it wants owned or
## fitted), or null. Shredding it could leave that quest stuck.
static func quest_needing(part: PartData) -> QuestData:
	# Ready quests count too: handing one in may take the part.
	for quest in Quests.active:
		if part.scene_path == quest.own_part_goal or part.scene_path == quest.fit_part_goal:
			return quest
	return null
