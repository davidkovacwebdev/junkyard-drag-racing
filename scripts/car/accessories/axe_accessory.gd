class_name AxeAccessory
extends CarAccessory
## An axe on a hinged arm that keeps chopping at whatever's in front of the car.
## It sits on the front of the roof line and swings forward over the nose. Just
## for show for now: the arena will give the chop teeth.

## Seconds per chop, wind-up to wind-up.
@export var chop_period: float = 2.2
## Arm angles (radians, 0 = straight up, + = toward the front).
@export var rest_angle: float = -0.35
@export var wind_angle: float = -0.95
@export var strike_angle: float = 1.95
## Where along the body the hinge sits, from its middle (0) to its nose (1).
@export_range(0.0, 1.0) var mount_toward_front: float = 0.6

## Phase marks within one chop, as shares of `chop_period`.
const WIND_END := 0.45
const STRIKE_END := 0.53
const RECOIL_END := 0.65
const RECOIL_BOUNCE := 0.12

@onready var _arm: Node2D = $Arm

var _phase: float = 0.0

func attach_to_body(body: CarBody) -> void:
	var center_x := body.outline_bounds().get_center().x
	var front_x := body.get_accessory_mount(AccessoryPartData.Spot.FRONT).x
	var x := lerpf(center_x, front_x, mount_toward_front)
	position = Vector2(x, body.top_surface_y(x))

func _process(delta: float) -> void:
	super(delta)
	var previous := _phase
	_phase = fmod(_phase + delta / chop_period, 1.0)
	if previous < WIND_END and _phase >= WIND_END:
		play_sound(&"axe_whoosh", -14.0)
	_arm.rotation = _arm_angle(_phase)

func _arm_angle(t: float) -> float:
	if t < WIND_END:
		return lerpf(rest_angle, wind_angle, ease(t / WIND_END, 0.5))
	if t < STRIKE_END:
		return lerpf(wind_angle, strike_angle, ease((t - WIND_END) / (STRIKE_END - WIND_END), 2.0))
	if t < RECOIL_END:
		return strike_angle - RECOIL_BOUNCE * sin(PI * (t - STRIKE_END) / (RECOIL_END - STRIKE_END))
	return lerpf(strike_angle, rest_angle, smoothstep(RECOIL_END, 1.0, t))
