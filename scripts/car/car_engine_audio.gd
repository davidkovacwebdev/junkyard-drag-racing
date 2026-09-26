class_name CarEngineAudio
extends EngineSound
## A race car's engine. Revs follow how fast the driven wheels are really
## spinning against the speed the engine is trying to hold them at, so a car
## bogged down on a ramp sounds strained and the finish-line boost pushes it
## toward the limiter. Level comes from RaceCarAudio, same as every car.

## Normal racing stays below the top of the rev range so it isn't a constant
## scream; only the boost gets near the limiter.
const RACING_RPM_RANGE := Vector2(0.2, 0.8)
const BOOST_RPM := 0.95

## Shared with CarAssembler, which drops a wheel from it when the wheel breaks.
var wheels: Array[CarWheel] = []
var engine_power: float = 0.0

func _process(delta: float) -> void:
	var total_spin := 0.0
	var spinning_wheels := 0
	for wheel in wheels:
		if is_instance_valid(wheel):
			total_spin += absf(wheel.angular_velocity)
			spinning_wheels += 1
	var spin_ratio := 1.0
	if spinning_wheels > 0:
		spin_ratio = clampf(total_spin / spinning_wheels / maxf(engine_power, 0.01), 0.0, 1.0)
	rpm = lerpf(RACING_RPM_RANGE.x, RACING_RPM_RANGE.y, spin_ratio)
	throttle = 0.6
	var body := get_parent() as CarBody
	if body != null and body.boost_force != 0.0:
		rpm = BOOST_RPM
	volume_db = RaceCarAudio.ENGINE_VOLUME_DB + RaceCarAudio.mix_db(self)
	super(delta)
