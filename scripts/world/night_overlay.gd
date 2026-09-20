class_name NightOverlay
extends ColorRect
## Screen-space day/night tint. Lives in PlayerCar's UI CanvasLayer so it
## covers the viewport regardless of the camera; just keeps the shader's
## night_factor uniform in sync with DayNightCycle every frame.

func _process(_delta: float) -> void:
	(material as ShaderMaterial).set_shader_parameter("night_factor", DayNightCycle.get_night_factor())
