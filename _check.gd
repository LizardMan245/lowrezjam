extends SceneTree
var main
var frames := 0
func _initialize() -> void:
	main = load("res://Scenes/Main.tscn").instantiate()
	root.add_child(main)
func _process(_d: float) -> bool:
	frames += 1
	if frames < 240:
		return false
	var gen = main.find_child("Dungeon", true, false)
	var region = gen.get_node("NavigationRegion3D")
	var map = region.get_navigation_map()
	var doors = gen.layout.door_links.keys()
	var bad := 0
	for i in doors.size():
		var a = gen.to_global(gen.cell_to_world(doors[i]))
		var b = gen.to_global(gen.cell_to_world(doors[(i + 1) % doors.size()]))
		var path = NavigationServer3D.map_get_path(map, a, b, true)
		if path.size() < 2 or path[path.size() - 1].distance_to(b) > 4.0:
			bad += 1
	print("doors: %d, unreachable door-to-door routes: %d" % [doors.size(), bad])
	var space = gen.get_viewport().world_3d.direct_space_state
	var q = PhysicsRayQueryParameters3D.new()
	q.collision_mask = 16
	var blocked := 0
	var total := 0
	for room in gen.get_node("NavigationRegion3D/Rooms").get_children():
		for prop in room.get_node("Props").get_children():
			total += 1
			if prop.collision_layer & 16:
				blocked += 1
	print("props: %d total, %d block sight, %d see-through" % [total, blocked, total - blocked])
	print("navmesh polys: %d  rooms: %d  corridors: %d" % [
		region.navigation_mesh.get_polygon_count(),
		gen.get_node("NavigationRegion3D/Rooms").get_child_count(),
		gen.get_node("NavigationRegion3D/Corridors").get_child_count()])
	main.find_child("DebugMapWindow", true, false).get_texture().get_image().save_png("user://m.png")
	return true
