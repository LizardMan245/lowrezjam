extends Node3D

const DungeonLayout = preload("res://Assets/Scripts/Map/dungeon_layout.gd")
const RoomSlot = preload("res://Assets/Scripts/Map/room_slot.gd")

const WALL_NAMES := ["WallNorth", "WallEast", "WallSouth", "WallWest"]

const DEAD_END_MASK := 1
const STRAIGHT_MASK := 5
const CORNER_MASK := 3
const JUNCTION_MASK := 11

signal generated(rooms: int, corridors: int)

@export_group("Pieces")
@export_dir var rooms_folder := "res://Assets/Map/Rooms"
@export var dead_end_piece: PackedScene
@export var straight_piece: PackedScene
@export var corner_piece: PackedScene
@export var junction_piece: PackedScene

@export_group("Layout")
@export var grid_size := Vector2i(24, 24)
@export_range(1.0, 16.0, 0.5) var tile_size := 4.0
@export_range(1, 400) var room_attempts := 120
@export_range(1, 32) var max_rooms := 6
@export_range(0, 4) var room_margin := 1
@export_range(0.0, 1.0, 0.05) var dead_end_trim := 0.55
@export var random_seed := 0
@export var randomise_on_start := true
@export var regenerate_action: StringName = &""

@export_group("Navigation")
@export var bake_navigation := true
@export_range(0.1, 4.0, 0.05) var agent_radius := 0.5
@export_range(0.5, 6.0, 0.1) var agent_height := 1.5

var layout

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

	layout = DungeonLayout.new()
	layout.setup(grid_size, random_seed)

	var placements: Array = layout.place_rooms(_room_defs, room_attempts, max_rooms, room_margin)
	layout.open_doors(placements, _room_defs)
	layout.carve_maze()
	layout.connect_regions()
	layout.trim_dead_ends(dead_end_trim)

	_build_rooms(placements)
	var corridors := _build_corridors()
	_bake_navigation()

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
		_room_defs.append({"scene": scene, "tiles": slot.tiles, "doors": doors})
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
			var mask: int = layout.openings_at(cell)
			var scene := _piece_for(mask)
			if scene == null:
				continue
			var turns := _turns_for(mask)
			var piece: Node3D = scene.instantiate()
			piece.position = cell_to_world(cell)
			piece.rotation.y = -turns * PI * 0.5
			_corridors_root.add_child(piece)
			_merge_walls(piece, cell, mask, turns)
			built += 1
	return built


func _piece_for(mask: int) -> PackedScene:
	match _opening_count(mask):
		0, 1:
			return dead_end_piece
		2:
			return straight_piece if _is_straight(mask) else corner_piece
		_:
			return junction_piece


func _turns_for(mask: int) -> int:
	var canonical := _canonical_for(mask)
	for turns in 4:
		if _rotate_mask(canonical, turns) == mask:
			return turns
	return 0


func _canonical_for(mask: int) -> int:
	match _opening_count(mask):
		0, 1:
			return DEAD_END_MASK
		2:
			return STRAIGHT_MASK if _is_straight(mask) else CORNER_MASK
		_:
			return JUNCTION_MASK


func _rotate_mask(mask: int, turns: int) -> int:
	var turned := 0
	for dir in 4:
		if mask & (1 << dir):
			turned |= 1 << ((dir + turns) % 4)
	return turned


func _is_straight(mask: int) -> bool:
	return mask == 5 or mask == 10


func _opening_count(mask: int) -> int:
	var count := 0
	for dir in 4:
		if mask & (1 << dir):
			count += 1
	return count


func _merge_walls(piece: Node3D, cell: Vector2i, mask: int, turns: int) -> void:
	for dir in 4:
		var open := (mask & (1 << dir)) != 0
		var shared: bool = layout.get_cell(cell + DungeonLayout.STEPS[dir]) == DungeonLayout.ROOM
		if not open and not shared:
			continue
		var local_dir := (dir - turns + 4) % 4
		var wall := piece.get_node_or_null(WALL_NAMES[local_dir])
		if wall != null:
			wall.free()


func _bake_navigation() -> void:
	if not bake_navigation:
		return
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.agent_radius = agent_radius
	mesh.agent_height = agent_height
	_region.navigation_mesh = mesh
	_region.bake_navigation_mesh(false)
