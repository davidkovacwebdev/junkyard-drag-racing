class_name RaceCarAudio
extends RefCounted
## The one mix rule for every sound a race car makes — engine, knocks, crashes,
## stalls, backfires. All cars are equal: nobody's car is louder than anyone
## else's, and each is turned down by the number of cars racing (1/√n), so a
## full grid is about as loud overall as one car on its own instead of stacking
## into a wall of noise.

const GROUP := &"race_car"
const ENGINE_VOLUME_DB := -14.0

## Called by CarAssembler on every car it builds.
static func register(car_root: Node) -> void:
	car_root.add_to_group(GROUP)

## Volume offset for one car's sounds, given any node in the same scene tree.
## Counts every car that started the race, wrecked or not, so a crash doesn't
## suddenly make the survivors louder.
static func mix_db(node: Node) -> float:
	var car_count := maxi(node.get_tree().get_nodes_in_group(GROUP).size(), 1)
	return linear_to_db(1.0 / sqrt(car_count))

static func play(node: Node, sound_name: StringName, global_position: Vector2, volume_db: float = 0.0) -> void:
	Sfx.play_at(sound_name, global_position, volume_db + mix_db(node))
