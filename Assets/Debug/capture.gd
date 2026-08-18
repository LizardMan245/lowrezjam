extends SceneTree

var frame := 0
var main: Node
var _walk_from := Vector3.ZERO
var _first: Image

func _process(_d: float) -> bool:
	frame += 1
	if frame == 1:
		main = (load("res://Scenes/Main.tscn") as PackedScene).instantiate()
		root.add_child(main)
		return false
	if frame == 30:
		var world := main.get_node("Render/WorldLayer/World")
		var player: Node3D = world.get_node("Player")
		var ui: Control = main.get_node("Render/UI")
		var field := main.get_node("Render/WorldLayer")

		player.view_distance = 20.0
		player.vision_angle_degrees = 90.0
		player.godmode = true
		field.thermal_angle_degrees = 140.0
		field.camera_noise = 0.28

		var here: Vector3 = player.nearest_walkable_point if false else Vector3.ZERO
		var mob: Node3D = world.get_node("Basicenemy")
		here = mob.nearest_walkable_point(Vector3(9.0, 0.0, -60.0))
		player.global_position = here
		player.facing = Vector2(1.0, 0.0)
		player._apply_facing()
		mob.global_position = here + Vector3(6.5, 0.0, -1.8)
		(world.get_node("ThermalMonster") as Node3D).global_position = here + Vector3(7.5, 0.0, 2.2)

		_walk_from = here + Vector3(1.0, 0.0, -1.0)
		return false
	if frame > 30 and frame < 95:
		var mob2: Node3D = main.get_node("Render/WorldLayer/World/Basicenemy")
		mob2.global_position = _walk_from + Vector3(float(frame - 30) * 0.11, 0.0, 0.0)
		return false
	if frame == 100:
		_save("world", main.get_node("Render/WorldLayer/World"))
		_save("thermal_world", main.get_node("ThermalWorld"))
		_save("heat", main.get_node("Render/ThermalLayer/Heat"))
		var heat_img := (main.get_node("Render/ThermalLayer/Heat") as SubViewport).get_texture().get_image()
		var alphas := {}
		for y in range(0, 64, 4):
			for x in range(0, 64, 4):
				var px := heat_img.get_pixel(x, y)
				var a: float = snappedf(px.r * 0.299 + px.g * 0.587 + px.b * 0.114, 0.25)
				alphas[a] = alphas.get(a, 0) + 1
		print("heat pass luminance histogram: %s" % str(alphas))
		var env_img := (main.get_node("ThermalWorld") as SubViewport).get_texture().get_image()
		var reds := {}
		for y in 64:
			for x in 64:
				var r: float = snappedf(env_img.get_pixel(x, y).r, 0.1)
				reds[r] = reds.get(r, 0) + 1
		var keys := reds.keys()
		keys.sort()
		var line := PackedStringArray()
		for k in keys:
			line.append("%.1f:%d" % [k, reds[k]])
		print("thermal world RED channel: %s" % " ".join(line))
		_first = root.get_texture().get_image()
		var shot := _first
		shot.save_png("res://shots/final.png")
		shot.resize(256, 256, Image.INTERPOLATE_NEAREST)
		shot.save_png("res://shots/final_big.png")
		print("saved final.png %dx%d" % [shot.get_width(), shot.get_height()])
		return false
	if frame == 104:
		_compare()
		return true
	return false

func _save(name: String, vp: SubViewport) -> void:
	var img := vp.get_texture().get_image()
	img.save_png("res://shots/%s.png" % name)
	var big := img.duplicate() as Image
	big.resize(256, 256, Image.INTERPOLATE_NEAREST)
	big.save_png("res://shots/%s_big.png" % name)
	print("saved %s.png %dx%d" % [name, img.get_width(), img.get_height()])

func _sample(name: String) -> void:
	pass


func _compare() -> void:
	var later := root.get_texture().get_image()
	var moved := 0
	var total := 0
	for y in 64:
		for x in 64:
			total += 1
			if _first.get_pixel(x, y) != later.get_pixel(x, y):
				moved += 1
	print("grain check: %d of %d pixels changed between frames (animated noise)" % [moved, total])
