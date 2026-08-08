extends Node3D

const DungeonLayout = preload("res://Assets/Scripts/Map/dungeon_layout.gd")
const RoomSlot = preload("res://Assets/Scripts/Map/room_slot.gd")

const OPEN_MASK := 0
const JUNCTION_MASK := 4
const STRAIGHT_MASK := 10
const CORNER_MASK := 12
const DEAD_END_MASK := 14

signal generated(rooms: int, corridors: int)

@export_group("Pieces")
@export_dir var rooms_folder := "res://Assets/Map/Rooms"
@export var open_piece: PackedScene
@export var junction_piece: PackedScene
@export var straight_piece: PackedScene
@export var corner_piece: PackedScene
@export var dead_end_piece: PackedScene

@export_group("Layout")
@export var grid_size := Vector2i(20, 20)
@export_range(1.0, 16.0, 0.5) var tile_size := 5.0
@export_range(1, 400) var room_attempts := 200
@export_range(1, 32) var max_rooms := 6
@export_range(0, 4) var room_margin := 1
@export_range(1, 24) var main_path_rooms := 5
@export_range(0, 16) var branch_rooms := 4
@export_range(1, 10) var run_min := 2
@export_range(1, 16) var run_max := 6
@export_range(0.0, 1.0, 0.05) var wide_corridor_chance := 0.7
@export var random_seed := 0
@export var randomise_on_start := true
@export var regenerate_action: StringName = &""

@export_group("Spawning")
@export var player_group: StringName = &"player"
@export var enemy_group: StringName = &"enemy"
@export_range(0.0, 8.0, 0.1) var spawn_height := 1.0

@export_group("Navigation")
@export var bake_navigation := true
@export_range(0.1, 4.0, 0.05) var agent_radius := 1.0
@export_range(0.5, 6.0, 0.1) var agent_height := 1.5

var layout

var _rng := RandomNumberGenerator.new()
var _room_defs := []
var _region: NavigationRegion3D
var _rooms_root: Node3D
var _corridors_root: Node3D


func _ready() -> void:
	_build_roots()
	_load_room_defs()
	if randomise_on_start:
		random_seed = randi()
	generate()


func _unhandled_input(event: InputEvent) -> void:
	if regenerate_action == &"" or not event.is_action_pressed(regenerate_action):
		return
	random_seed = randi()
	generate()


func generate() -> void:
	_clear()
	_rng.seed = random_seed

	layout = DungeonLayout.new()
	layout.setup(grid_size, random_seed)

	layout.build(_room_defs, main_path_rooms, branch_rooms, run_min, run_max, wide_corridor_chance)
	var placements: Array = layout.placements

	_build_rooms(placements)
	var corridors := _build_corridors()
	_bake_navigation()
	_place_spawn_nodes()

	generated.emit(placements.size(), corridors)


func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(
		(cell.x - grid_size.x * 0.5 + 0.5) * tile_size,
		0.0,
		(cell.y - grid_size.y * 0.5 + 0.5) * tile_size)


func _build_roots() -> void:
	_region = get_node_or_null("NavigationRegion3D") as NavigationRegion3D
	if _region == null:
		_region = NavigationRegion3D.new()
		_region.name = "NavigationRegion3D"
		add_child(_region)
	_rooms_root = Node3D.new()
	_rooms_root.name = "Rooms"
	_region.add_child(_rooms_root)
	_corridors_root = Node3D.new()
	_corridors_root.name = "Corridors"
	_region.add_child(_corridors_root)


func _clear() -> void:
	for root in [_rooms_root, _corridors_root]:
		for child in root.get_children():
			root.remove_child(child)
			child.queue_free()


func _load_room_defs() -> void:
	_room_defs.clear()
	var folder := DirAccess.open(rooms_folder)
	if folder == null:
		push_warning("no rooms folder at %s" % rooms_folder)
		return
	for file in folder.get_files():
		var scene_name := file.trim_suffix(".remap")
		if not scene_name.ends_with(".tscn"):
			continue
		var scene: PackedScene = load(rooms_folder.path_join(scene_name))
		if scene == null:
			continue
		var probe := scene.instantiate()
		var slot := probe as RoomSlot
		if slot == null:
			push_warning("room %s has no room_slot script on its root" % scene_name)
			probe.free()
			continue
		var doors := _read_doors(slot)
		if doors.is_empty():
			push_warning("room %s has no door markers" % scene_name)
		_room_defs.append({"scene": scene, "tiles": slot.tiles, "doors": doors, "role": slot.role})
		probe.free()
	if _room_defs.is_empty():
		push_warning("no usable rooms found in %s" % rooms_folder)


func _read_doors(slot) -> Array:
	var doors := []
	var half := Vector2(slot.tiles.x, slot.tiles.y) * tile_size * 0.5
	for marker in slot.get_door_markers():
		var spot := _position_in_room(slot, marker)
		var cell := Vector2i(
			clampi(int(floor((spot.x + half.x) / tile_size)), 0, slot.tiles.x - 1),
			clampi(int(floor((spot.z + half.y) / tile_size)), 0, slot.tiles.y - 1))
		doors.append({"cell": cell, "dir": _edge_direction(cell, slot.tiles)})
	return doors


func _position_in_room(slot, node: Node3D) -> Vector3:
	var offset := node.transform
	var parent := node.get_parent()
	while parent != null and parent != slot:
		var step := parent as Node3D
		if step == null:
			break
		offset = step.transform * offset
		parent = step.get_parent()
	return offset.origin


func _edge_direction(cell: Vector2i, tiles: Vector2i) -> int:
	var gaps := [cell.y, tiles.x - 1 - cell.x, tiles.y - 1 - cell.y, cell.x]
	var best := 0
	for dir in 4:
		if gaps[dir] < gaps[best]:
			best = dir
	return best


func _build_rooms(placements: Array) -> void:
	for placement in placements:
		var definition: Dictionary = _room_defs[placement["index"]]
		var tiles: Vector2i = definition["tiles"]
		var instance: Node3D = definition["scene"].instantiate()
		instance.position = cell_to_world(placement["origin"]) + Vector3(
			(tiles.x - 1) * tile_size * 0.5, 0.0, (tiles.y - 1) * tile_size * 0.5)
		_rooms_root.add_child(instance)


func _build_corridors() -> int:
	var built := 0
	for y in grid_size.y:
		for x in grid_size.x:
			var cell := Vector2i(x, y)
			if layout.get_cell(cell) != DungeonLayout.CORRIDOR:
				continue
			var mask: int = layout.wall_mask(cell)
			var scene := _piece_for(mask)
			if scene == null:
				continue
			var piece: Node3D = scene.instantiate()
			piece.position = cell_to_world(cell)
			piece.rotation.y = -_turns_for(mask) * PI * 0.5
			_corridors_root.add_child(piece)
			built += 1
	return built


func _piece_for(mask: int) -> PackedScene:
	match _wall_count(mask):
		0:
			return open_piece
		1:
			return junction_piece
		2:
			return straight_piece if _is_straight(mask) else corner_piece
		_:
			return dead_end_piece


func _canonical_for(mask: int) -> int:
	match _wall_count(mask):
		0:
			return OPEN_MASK
		1:
			return JUNCTION_MASK
		2:
			return STRAIGHT_MASK if _is_straight(mask) else CORNER_MASK
		_:
			return DEAD_END_MASK


func _turns_for(mask: int) -> int:
	var canonical := _canonical_for(mask)
	for turns in 4:
		if _rotate_mask(canonical, turns) == mask:
			return turns
	return 0


func _rotate_mask(mask: int, turns: int) -> int:
	var turned := 0
	for dir in 4:
		if mask & (1 << dir):
			turned |= 1 << ((dir + turns) % 4)
	return turned


func _is_straight(mask: int) -> bool:
	return mask == 5 or mask == 10


func _wall_count(mask: int) -> int:
	var count := 0
	for dir in 4:
		if mask & (1 << dir):
			count += 1
	return count


func _entrance_rect() -> Rect2i:
	if layout.entrance_index < 0:
		return Rect2i(-1, -1, 0, 0)
	return layout.room_rect(layout.entrance_index)


func _entrance_spot() -> Vector3:
	var rect := _entrance_rect()
	if rect.size == Vector2i.ZERO:
		return to_global(Vector3.ZERO)
	var middle := rect.position + rect.size / 2
	return to_global(cell_to_world(middle))


func _spawn_candidates() -> Array:
	var rect := _entrance_rect()
	var rooms := []
	var corridors := []
	for y in grid_size.y:
		for x in grid_size.x:
			var cell := Vector2i(x, y)
			if rect.has_point(cell):
				continue
			match layout.get_cell(cell):
				DungeonLayout.ROOM:
					rooms.append(cell)
				DungeonLayout.CORRIDOR:
					corridors.append(cell)
	return rooms if not rooms.is_empty() else corridors


func _spread_cell(spots: Array, used: Array) -> Vector2i:
	if used.is_empty():
		return spots[_rng.randi_range(0, spots.size() - 1)]
	var best: Vector2i = spots[0]
	var best_gap := -1.0
	for entry in spots:
		var cell: Vector2i = entry
		var gap := INF
		for taken in used:
			var other: Vector2i = taken
			gap = minf(gap, Vector2(cell - other).length())
		if gap > best_gap:
			best_gap = gap
			best = cell
	return best


func _place_spawn_nodes() -> void:
	var entrance := _entrance_spot()
	for node in get_tree().get_nodes_in_group(player_group):
		var body := node as Node3D
		if body != null:
			body.global_position = entrance + Vector3(0.0, spawn_height, 0.0)

	var spots := _spawn_candidates()
	if spots.is_empty():
		return
	var rect := _entrance_rect()
	var used := [rect.position + rect.size / 2]
	for node in get_tree().get_nodes_in_group(enemy_group):
		var body := node as Node3D
		if body == null:
			continue
		var cell := _spread_cell(spots, used)
		used.append(cell)
		var spot := to_global(cell_to_world(cell))
		body.global_position = Vector3(spot.x, spot.y + spawn_height, spot.z)


func _bake_navigation() -> void:
	if not bake_navigation:
		return
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.agent_radius = agent_radius
	mesh.agent_height = agent_height
	_region.navigation_mesh = mesh
	_region.bake_navigation_mesh(false)
