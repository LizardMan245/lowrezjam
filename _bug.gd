extends SceneTree
var main
var frames := 0
func _initialize() -> void:
	main = load("res://Scenes/Main.tscn").instantiate()
	var world = main.find_child("Basicenemy", true, false).get_parent()
	var scene = load("res://Assets/Enemies/BasicEnemy.tscn")
	for i in 2:
		var e = scene.instantiate()
		e.name = "Basicenemy%d" % (i + 2)
		world.add_child(e)
		e.owner = main
	root.add_child(main)
func _process(_d: float) -> bool:
	frames += 1
	if frames % 200 != 0:
		return false
	var world = main.find_child("Render", true, false).find_child("World", true, false)
	var found := []
	for child in world.get_children():
		if child.name.begins_with("Basicenemy"):
			found.append("%s y=%.1f state=%s" % [child.name, child.global_position.y, child.get_state_name()])
	print("frame %d: %d enemies -> %s" % [frames, found.size(), ", ".join(found)])
	return frames >= 600
