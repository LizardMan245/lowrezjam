extends RefCounted

const EMPTY := 0
const ROOM := 1
const CORRIDOR := 2

const NORTH := 0
const EAST := 1
const SOUTH := 2
const WEST := 3

const STEPS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

var size := Vector2i(28, 28)
var cells := PackedInt32Array()
var door_links := {}
var placements := []
var entrance_index := -1
var goal_index := -1

var _rng := RandomNumberGenerator.new()
var _connectors := []


func setup(grid_size: Vector2i, seed_value: int) -> void:
	size = grid_size
	cells.resize(size.x * size.y)
	cells.fill(EMPTY)
	door_links.clear()
	placements.clear()
	_connectors.clear()
	entrance_index = -1
	goal_index = -1
	_rng.seed = seed_value


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func get_cell(cell: Vector2i) -> int:
	if not in_bounds(cell):
		return EMPTY
	return cells[cell.y * size.x + cell.x]


func set_cell(cell: Vector2i, value: int) -> void:
	if in_bounds(cell):
		cells[cell.y * size.x + cell.x] = value


func links_at(cell: Vector2i) -> int:
	var count := 0
	for dir in 4:
		if get_cell(cell + STEPS[dir]) == CORRIDOR:
			count += 1
	return count


func wall_mask(cell: Vector2i) -> int:
	var doors: int = door_links.get(cell, 0)
	var mask := 0
	for dir in 4:
		if doors & (1 << dir):
			continue
		if get_cell(cell + STEPS[dir]) != CORRIDOR:
			mask |= 1 << dir
	return mask


func build(room_defs: Array, main_length: int, branches: int, run_min: int, run_max: int, wide_chance: float) -> void:
	if room_defs.is_empty():
		return
	var entrance_def := _def_with_role(room_defs, &"entrance")
	var goal_def := _def_with_role(room_defs, &"goal")

	if entrance_def < 0 or not _place_entrance(room_defs, entrance_def):
		if not _place_anywhere(room_defs, _plain_defs(room_defs), 0):
			return
	entrance_index = 0

	for _step in main_length:
		if not _extend(room_defs, _plain_defs(room_defs), run_min, run_max, wide_chance, true):
			break

	if goal_def >= 0:
		for _try in 40:
			if _extend_with(room_defs, [goal_def], run_min, run_max, wide_chance, true):
				goal_index = placements.size() - 1
				break

	for _branch in branches:
		_extend(room_defs, _plain_defs(room_defs), run_min, run_max, wide_chance, false)


func room_rect(index: int) -> Rect2i:
	var placement: Dictionary = placements[index]
	return Rect2i(placement["origin"], placement["tiles"])


func _def_with_role(room_defs: Array, role: StringName) -> int:
	for index in room_defs.size():
		if room_defs[index]["role"] == role:
			return index
	return -1


func _plain_defs(room_defs: Array) -> Array:
	var plain := []
	for index in room_defs.size():
		if room_defs[index]["role"] == &"":
			plain.append(index)
	return plain


func _place_entrance(room_defs: Array, index: int) -> bool:
	var definition: Dictionary = room_defs[index]
	var tiles: Vector2i = definition["tiles"]
	for _try in 60:
		var origin := Vector2i(_rng.randi_range(1, maxi(1, size.x - tiles.x - 1)), 1)
		if _commit(room_defs, index, origin):
			return true
	return false


func _place_anywhere(room_defs: Array, choices: Array, _depth: int) -> bool:
	if choices.is_empty():
		return false
	for _try in 80:
		var index: int = choices[_rng.randi_range(0, choices.size() - 1)]
		var tiles: Vector2i = room_defs[index]["tiles"]
		var origin := Vector2i(
			_rng.randi_range(1, maxi(1, size.x - tiles.x - 1)),
			_rng.randi_range(1, maxi(1, size.y - tiles.y - 1)))
		if _commit(room_defs, index, origin):
			return true
	return false


func _extend(room_defs: Array, choices: Array, run_min: int, run_max: int, wide_chance: float, deepest: bool) -> bool:
	return _extend_with(room_defs, choices, run_min, run_max, wide_chance, deepest)


func _extend_with(room_defs: Array, choices: Array, run_min: int, run_max: int, wide_chance: float, deepest: bool) -> bool:
	if _connectors.is_empty() or choices.is_empty():
		return false
	var order := _connector_order(deepest)
	for slot in order:
		var connector: Dictionary = _connectors[slot]
		var length := _rng.randi_range(run_min, run_max)
		var run := _trace_run(connector["cell"], connector["dir"], length)
		if run.is_empty():
			continue
		var tail: Vector2i = run[run.size() - 1]
		var heading: int = connector["heading"]
		var index: int = choices[_rng.randi_range(0, choices.size() - 1)]
		var origin := _origin_for(room_defs, index, tail, heading)
		if origin.x < -900:
			continue
		var carved := []
		for entry in run:
			var cell: Vector2i = entry
			if get_cell(cell) == EMPTY:
				carved.append(cell)
			set_cell(cell, CORRIDOR)
		if not _commit(room_defs, index, origin):
			for entry in carved:
				set_cell(entry, EMPTY)
			continue
		if _rng.randf() < wide_chance:
			_widen(run)
		_connectors.remove_at(slot)
		return true
	return false


func _connector_order(deepest: bool) -> Array:
	var order := []
	for slot in _connectors.size():
		order.append(slot)
	if deepest:
		order.sort_custom(func(a, b): return _connectors[a]["depth"] > _connectors[b]["depth"])
	else:
		for index in range(order.size() - 1, 0, -1):
			var swap := _rng.randi_range(0, index)
			var keep: int = order[index]
			order[index] = order[swap]
			order[swap] = keep
	return order


func _trace_run(from: Vector2i, dir: int, length: int) -> Array:
	var run := []
	var cell := from
	var heading := dir
	var turn_at := _rng.randi_range(2, maxi(2, length - 1))
	for step in length:
		if step == turn_at and _rng.randf() < 0.5:
			heading = (heading + (1 if _rng.randf() < 0.5 else 3)) % 4
		cell += STEPS[heading]
		if not in_bounds(cell) or get_cell(cell) == ROOM:
			return []
		if cell.x < 1 or cell.y < 1 or cell.x >= size.x - 1 or cell.y >= size.y - 1:
			return []
		run.append(cell)
	if run.is_empty():
		return []
	_last_heading = heading
	return run


var _last_heading := 0


func _origin_for(room_defs: Array, index: int, tail: Vector2i, _heading: int) -> Vector2i:
	var definition: Dictionary = room_defs[index]
	var inward := (_last_heading + 2) % 4
	var options := []
	for door in definition["doors"]:
		if int(door["dir"]) == inward:
			options.append(door)
	if options.is_empty():
		return Vector2i(-999, -999)
	var door: Dictionary = options[_rng.randi_range(0, options.size() - 1)]
	var door_cell: Vector2i = door["cell"]
	return tail + STEPS[_last_heading] - door_cell


func _commit(room_defs: Array, index: int, origin: Vector2i) -> bool:
	var definition: Dictionary = room_defs[index]
	var tiles: Vector2i = definition["tiles"]
	if not _area_is_free(origin, tiles):
		return false
	for x in tiles.x:
		for y in tiles.y:
			set_cell(origin + Vector2i(x, y), ROOM)

	var depth := placements.size()
	placements.append({"index": index, "origin": origin, "tiles": tiles, "role": definition["role"]})

	for door in definition["doors"]:
		var inside: Vector2i = origin + door["cell"]
		var dir: int = door["dir"]
		var outside: Vector2i = inside + STEPS[dir]
		if not in_bounds(outside) or get_cell(outside) == ROOM:
			continue
		set_cell(outside, CORRIDOR)
		door_links[outside] = int(door_links.get(outside, 0)) | (1 << ((dir + 2) % 4))
		_connectors.append({"cell": outside, "dir": dir, "heading": dir, "depth": depth})
	return true


func _area_is_free(origin: Vector2i, tiles: Vector2i) -> bool:
	for x in range(origin.x - 1, origin.x + tiles.x + 1):
		for y in range(origin.y - 1, origin.y + tiles.y + 1):
			var cell := Vector2i(x, y)
			if not in_bounds(cell):
				return false
			if get_cell(cell) == ROOM:
				return false
	for x in tiles.x:
		for y in tiles.y:
			if get_cell(origin + Vector2i(x, y)) != EMPTY:
				return false
	return true


func _widen(run: Array) -> void:
	for index in run.size():
		var cell: Vector2i = run[index]
		if door_links.has(cell):
			continue
		var along := Vector2i(1, 0)
		if index + 1 < run.size():
			along = run[index + 1] - cell
		elif index > 0:
			along = cell - run[index - 1]
		var mate := cell + Vector2i(-along.y, along.x)
		if not in_bounds(mate) or get_cell(mate) != EMPTY:
			continue
		if _touches_room(mate):
			continue
		set_cell(mate, CORRIDOR)


func _touches_room(cell: Vector2i) -> bool:
	for dir in 4:
		if get_cell(cell + STEPS[dir]) == ROOM:
			return true
	return false
