class_name BoxingGloveAccessory
extends CarAccessory
## A boxing glove on a spring sticking out of the front bumper. Every so often
## it punches out and wobbles back. In a race, a punch that lands knocks the
## other car back and dents the part it hit.

@export var punch_period: float = 1.8
## How far the spring stretches, as a multiple of its rest length.
@export var reach: float = 2.6

## Phase marks within one punch, as shares of `punch_period`.
## Share of a struck part's durability each punch takes.
@export var punch_damage_share: float = 0.07
## Shove (px/s) a punch gives the struck part, straight out from the bumper.
@export var punch_push: float = 320.0
@export var glove_radius: float = 18.0

const PUNCH_START := 0.6
const PUNCH_END := 0.68
const WOBBLE_END := 0.8
const WOBBLE_AMOUNT := 0.25

@onready var _spring: Node2D = $Spring
@onready var _glove: Node2D = $Glove
@onready var _knuckles: Node2D = $Glove/Knuckles

var _phase: float = 0.0
var _spring_length: float = 0.0
var _glove_rest_x: float = 0.0

func _ready() -> void:
	super()
	_glove_rest_x = _glove.position.x
	_spring_length = _glove_rest_x - _spring.position.x

func _process(delta: float) -> void:
	super(delta)
	var previous := _phase
	_phase = fmod(_phase + delta / punch_period, 1.0)
	if previous < PUNCH_START and _phase >= PUNCH_START:
		play_sound(&"glove_boing", -12.0)
	var stretch := _stretch(_phase)
	_spring.scale.x = stretch
	_glove.position.x = _spring.position.x + _spring_length * stretch
	if previous < PUNCH_END and _phase >= PUNCH_END:
		_punch()

func _punch() -> void:
	var push := global_transform.x.normalized() * punch_push
	if strike(_knuckles.global_position, glove_radius * _knuckles.global_scale.x, punch_damage_share, push):
		play_sound(&"glove_punch", -6.0)

func _stretch(t: float) -> float:
	if t < PUNCH_START:
		return 1.0
	if t < PUNCH_END:
		return lerpf(1.0, reach, ease((t - PUNCH_START) / (PUNCH_END - PUNCH_START), 0.4))
	if t < WOBBLE_END:
		var wobble := (t - PUNCH_END) / (WOBBLE_END - PUNCH_END)
		return reach - WOBBLE_AMOUNT * sin(wobble * TAU * 1.5) * (1.0 - wobble)
	return lerpf(reach, 1.0, smoothstep(WOBBLE_END, 1.0, t))
