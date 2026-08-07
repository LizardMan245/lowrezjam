extends Window

@export var enabled := true
@export var debug_builds_only := true
@export var window_size := Vector2i(768, 768)
@export var screen_gap := 24
@export var map_centre := Vector3(0.0, 0.0, 0.0)
@export_range(4.0, 200.0) var map_extent := 21.0
@export_range(5.0, 500.0) var camera_height := 40.0
@export_flags_3d_render var render_layers := 7
@export var ambient_energy := 1.4
@export var backdrop := Color(0.03, 0.035, 0.05)

var _camera: Camera3D


func _ready() -> void:
	if not enabled or (debug_builds_only and not OS.is_debug_build()):
		queue_free()
		return

	get_tree().root.gui_embed_subwindows = false
	title = "Enemy AI monitor"
	size = window_size
	min_size = Vector2i(256, 256)
	transient = false
	_adopt_game_world()
	_camera = _build_camera()
	add_child(_camera)
	_aim_camera()
	close_requested.connect(hide)
	_place_beside_game_window()
	show()


func _adopt_game_world() -> void:
	var game_world := get_tree().root.find_world_3d()
	if find_world_3d() != game_world:
		own_world_3d = true
		world_3d = game_world


func _build_camera() -> Camera3D:
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = map_extent
	camera.cull_mask = render_layers
	camera.near = 0.05
	camera.far = camera_height * 4.0
	camera.environment = _build_environment()
	camera.current = true
	return camera


func _build_environment() -> Environment:
	var flat := Environment.new()
	flat.background_mode = Environment.BG_COLOR
	flat.background_color = backdrop
	flat.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	flat.ambient_light_color = Color(1.0, 1.0, 1.0)
	flat.ambient_light_energy = ambient_energy
	return flat


func _aim_camera() -> void:
	_camera.global_position = map_centre + Vector3(0.0, camera_height, 0.0)
	_camera.look_at(map_centre, Vector3.FORWARD)


func _place_beside_game_window() -> void:
	var here := DisplayServer.window_get_current_screen()
	var screens := DisplayServer.get_screen_count()

	if screens > 1:
		var spare := DisplayServer.screen_get_usable_rect((here + 1) % screens)
		position = spare.position + Vector2i(screen_gap, screen_gap)
		return

	var game := get_tree().root
	var usable := DisplayServer.screen_get_usable_rect(here)
	var wanted := game.position + Vector2i(game.size.x + screen_gap, 0)
	wanted.x = clampi(wanted.x, usable.position.x, maxi(usable.position.x, usable.end.x - size.x))
	wanted.y = clampi(wanted.y, usable.position.y, maxi(usable.position.y, usable.end.y - size.y))
	position = wanted
