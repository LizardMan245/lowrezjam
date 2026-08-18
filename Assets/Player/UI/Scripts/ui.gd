extends Control

@export_group("Levels")
@export_range(0, 21, 1) var ram: int
@export var speeds := [0.0, 2.0, 5.0, 8.0]
@export var turn_speeds := [0.0, 3.0, 6.0, 8.0]
@export var view_angles := [45.0, 45.0, 90.0, 120.0]
@export var view_distances := [0.0, 10.0, 13.0, 20.0]
@export var heat_angles := [0.0, 70.0, 140.0]
@export var echo_radii := [0.0, 14.0, 30.0]
@export var camera_noise := [0.0, 0.28, 0.12, 0.0]

@export_group("Assets")
@export var options = Array([], TYPE_NODE_PATH, "", null)
@export var select_up_sfx: AudioStream
@export var select_down_sfx: AudioStream
@export var level_up_sfx: AudioStream
@export var level_down_sfx: AudioStream


var selected: int = 0

var in_menu: bool = false
var held_data_option := 4

var _success_left := 0.0

signal resize_ram_radius(ram)


func display_ram(obj: TextureRect, val: int) -> void:
	var ram_og_pos: int = -63
	obj.position.x = ram_og_pos + val * 3

func toggle_menu() -> void:
	if Input.is_action_just_pressed("menu"):
		$Sfx/ConsoleSfx.play()
		$Menu.visible = not $Menu.is_visible_in_tree()
		in_menu = $Menu.is_visible_in_tree()

func option_selection() -> void:
	var options_num: int = options.size()
	
	if Input.is_action_just_pressed("look_down"):	
		get_node(options[selected]).deselect()
		
		if selected < options_num - 1:
			selected += 1
		else:
			selected = 0
		$Sfx/SelectSfx.stream = select_down_sfx
		$Sfx/SelectSfx.play()
		get_node(options[selected]).select()
	
	if Input.is_action_just_pressed("look_up"):
		get_node(options[selected]).deselect()
		
		if selected > 0:
			selected -= 1
		else:
			selected = options_num -1
		$Sfx/SelectSfx.stream = select_up_sfx
		$Sfx/SelectSfx.play()
		get_node(options[selected]).select()

func option_effect(opt) -> void:
	var player = get_tree().get_first_node_in_group("player")
	match selected:
		0:
			player.vision_angle_degrees = view_angles[opt.curr_level]
			player.view_distance = view_distances[opt.curr_level]
			var vision_camera = get_tree().get_first_node_in_group("vision")
			vision_camera.camera_noise = camera_noise[opt.curr_level]
		1:
			player.SPEED = speeds[opt.curr_level]
			player.turn_speed = turn_speeds[opt.curr_level]
		2:
			var vision = get_tree().get_first_node_in_group("vision")
			vision.thermal_angle_degrees = heat_angles[opt.curr_level]
		3:
			$Echo.radius = echo_radii[opt.curr_level]


func _ready() -> void:
	$Menu.visible = false
	refresh_ram_bar()
	get_node(options[selected]).select()


func _process(delta: float) -> void:
	_tick_success(delta)
	toggle_menu()
	refresh_ram_bar()
	if in_menu:
		if Input.get_axis("look_down", "look_up"):
			option_selection()
		if selected == held_data_option:
			if Input.is_action_just_pressed("look_right"):
				$Inventory.select_next(1)
			if Input.is_action_just_pressed("look_left"):
				$Inventory.select_next(-1)
			if Input.is_action_just_pressed("interact"):
				$Inventory.drop_selected()
		elif Input.get_axis("look_left", "look_right"):
			var curr_option = get_node(options[selected])
			ram += curr_option.edit_ram_usage()
			option_effect(curr_option)
			resize_ram_radius.emit(ram)


func popup_doer(state: String, sprite, dur: float) -> void:
	var popup_rect = $TextureRect as TextureRect
	$Sfx/ConsoleSfx.play()
	match state:
		"up":
			popup_rect.texture = sprite
			var tween = get_tree().create_tween()
			tween.tween_property(popup_rect, "position", Vector2(0, 0), dur)
		"next":
			popup_rect.texture = sprite
		"down":
			var tween = get_tree().create_tween()
			tween.tween_property(popup_rect, "position", Vector2(0, 64), dur)


func add_ram(amount: int) -> void:
	ram = clampi(ram + amount, 0, 21)
	resize_ram_radius.emit(ram)


func refresh_ram_bar() -> void:
	var preview := 0
	if in_menu:
		preview = next_upgrade_cost() + fragment_cost_in_reach()
	display_ram($Ram/UsedRam, ram)
	display_ram($Ram/ActiveRam, mini(ram + preview, 21))
	$Ram/EmptyRam.visible = in_menu
	$Ram/ActiveRam.visible = in_menu and preview > 0


func next_upgrade_cost() -> int:
	if selected == held_data_option:
		return 0
	var opt = get_node(options[selected])
	if opt.curr_level >= opt.levels:
		return 0
	return opt.level_val


func fragment_cost_in_reach() -> int:
	for fragment in get_tree().get_nodes_in_group("blueprint"):
		if fragment.held:
			continue
		if fragment.has_overlapping_areas():
			return fragment.ram_cost
	return 0


func show_download(progress: float) -> void:
	var bar := get_node_or_null("Download/Fill") as ColorRect
	var frame := get_node_or_null("Download") as Control
	if bar == null or frame == null:
		return
	frame.visible = progress >= 0.0
	if progress >= 0.0:
		bar.size.x = frame.size.x * clampf(progress, 0.0, 1.0)


func show_success() -> void:
	var text := get_node_or_null("Success") as Label
	if text == null:
		return
	text.visible = true
	_success_left = 1.0


func show_held_data(count: int, chosen: int) -> void:
	var text := get_node_or_null("Success") as Label
	if text == null or count <= 0 or not in_menu:
		return
	text.text = "DROP %d/%d" % [chosen + 1, count]
	text.visible = true
	_success_left = 1.2


func _tick_success(delta: float) -> void:
	if _success_left <= 0.0:
		return
	_success_left -= delta
	if _success_left > 0.0:
		return
	var text := get_node_or_null("Success") as Label
	if text != null:
		text.visible = false
		text.text = "DOWNLOADED"


func show_interaction(is_on: bool, text: String = "") -> void:
	$Interaction.text = text
	$Interaction.visible = is_on
