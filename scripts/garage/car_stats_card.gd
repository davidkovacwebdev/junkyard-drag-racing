@tool
class_name CarStatsCard
extends ScrapPanel
## The garage's read-out for the whole car being viewed: the same Durability /
## Speed / Mass bars as a part card, but for everything fitted together, and
## filled part way so a swap that shifts a stat a little still shows. The
## tooltip has the numbers behind the bars.

@onready var _durability_bar: StatBar = $Columns/DurabilityColumn/DurabilityBar
@onready var _speed_bar: StatBar = $Columns/SpeedColumn/SpeedBar
@onready var _mass_bar: StatBar = $Columns/MassColumn/MassBar

## Empties the bars when there's no car to rate.
func show_car(car: CarModelData) -> void:
	if car == null:
		_durability_bar.set_rating(0)
		_speed_bar.set_rating(0)
		_mass_bar.set_rating(0)
		tooltip_text = ""
		return
	_durability_bar.set_rating(StatBar.exact_rating_for(car.durability_rating_fraction()))
	_speed_bar.set_rating(StatBar.exact_rating_for(car.speed_rating_fraction()))
	_mass_bar.set_rating(StatBar.exact_rating_for(car.mass_rating_fraction()))
	tooltip_text = "Durability: %d average per part\nEngine power: %.1f\nWheel speed: %.1f average\nMass: %d" % [
		roundi(car.average_durability()), car.engine_power(), car.average_wheel_speed(), roundi(car.total_mass()),
	]
