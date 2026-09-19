class_name CarAutosteer
extends Node
## Applies a small, smoothly wandering vertical force to a car's body so
## every car drifts up/down a little within its lane and occasionally
## crosses into a neighbor's — no player input, no steering stat. Wheel
## shape already adds real bump/rock impulses on top of this for free
## (square/triangle wheels drift more than round ones just from physics).

@export var body: RigidBody2D
@export var drift_strength: float = 440.0
@export var noise_speed: float = 0.6

var _noise := FastNoiseLite.new()
var _t := 0.0

func _ready() -> void:
	_noise.seed = randi()
	_noise.frequency = 1.0

func _physics_process(delta: float) -> void:
	if body == null:
		return
	_t += delta * noise_speed
	var drift := _noise.get_noise_1d(_t * 100.0)
	body.apply_central_force(Vector2(0.0, drift * drift_strength))
