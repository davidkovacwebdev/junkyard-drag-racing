extends Node
## Renders the boot screen's first frame to the engine's boot splash image, so
## the splash and the boot screen line up. Run it (not headless) after changing
## the boot screen or the Upside-Down Car / Standard Wheel art:
##   godot res://tools/render_boot_splash.tscn -- --no-save --no-cutscenes

const OUT_PATH := "res://assets/boot_splash.png"
const SPLASH_SIZE := Vector2i(1152, 648)

func _ready() -> void:
	SaveSystem.process_mode = Node.PROCESS_MODE_DISABLED
	ScrapCursor.visible = false
	get_window().size = SPLASH_SIZE
	var screen: BootScreen = load("res://scenes/menu/boot_screen.tscn").instantiate()
	screen.play_on_ready = false
	add_child(screen)
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image.get_size() != SPLASH_SIZE:
		image.resize(SPLASH_SIZE.x, SPLASH_SIZE.y, Image.INTERPOLATE_LANCZOS)
	image.save_png(ProjectSettings.globalize_path(OUT_PATH))
	print("Boot splash written to ", OUT_PATH)
	get_tree().quit()
