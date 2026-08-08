extends RefCounted

const EMPTY := 0
const ROOM := 1
const CORRIDOR := 2

const NORTH := 0
const EAST := 1
const SOUTH := 2
const WEST := 3

const STEPS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

const MAX_LINK_PASSES := 64
const MAX_SEED_PASSES := 64
const MAX_TRIM_PASSES := 8
const MAX_LINKS_PER_CELL := 3

var size := Vector2i(24, 24)
var cells := PackedInt32Array()
var door_links := {}

var _rng := RandomNumberGenerator.new()


func setup(grid_size: Vector2i, seed_value: int) -> void:
	size = grid_size
	cells.resize(size.x * size.y)
	cells.fill(EMPTY)
	door_links.clear()
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


func total_links(cell: Vector2i) -> int:
	var count := links_at(cell)
	var doors: int = door_links.get(cell, 0)
	for dir in 4:
		if doors & (1 << dir):
			count += 1
	return count


func openings_at(cell: Vector2i) -> int:
	var mask: int = door_links.get(cell, 0)
	for dir in 4:
		if get_cell(cell + STEPS[dir]) == CORRIDOR:
			mask |= 1 << dir
	return mask


func place_rooms(room_defs: Array, attempts: int, wanted: int, margin: int) -> Array:
	var placements := []
	if room_defs.is_empty():
		return placements
	for _attempt in attempts:
		if placements.size() >= wanted:
			break
		var index := _rng.randi_range(0, room_defs.size() - 1)
		var tiles: Vector2i = room_defs[index]["tiles"]
		if tiles.x + 2 > size.x or tiles.y + 2 > size.y:
			continue
		var origin := Vector2i(
			_rng.randi_range(1, size.x - tiles.x - 1),
			_rng.randi_range(1, size.y - tiles.y - 1))
		if not _area_is_free(origin, tiles, margin):
			continue
		for x in tiles.x:
			for y in tiles.y:
				set_cell(origin + Vector2i(x, y), ROOM)
		placements.append({"index": index, "origin": origin})
	return placements


func open_doors(placements: Array, room_defs: Array) -> void:
	for placement in placements:
		var origin: Vector2i = placement["origin"]
		for door in room_defs[placement["index"]]["doors"]:
			var inside: Vector2i = origin + door["cell"]
			var outside: Vector2i = inside + STEPS[door["dir"]]
			if not in_bounds(outside) or get_cell(outside) == ROOM:
				continue
			set_cell(outside, CORRIDOR)
			var inward: int = (int(door["dir"]) + 2) % 4
			door_links[outside] = int(door_links.get(outside, 0)) | (1 << inward)


func carve_maze() -> void:
	for _pass in MAX_SEED_PASSES:
		var start := _pick_seed()
		if start.x < 0:
			return
		_carve_from(start)


func connect_regions() -> void:
	for _pass in MAX_LINK_PASSES:
		var groups := _label_groups()
		if groups.size() <= 1:
			return
		if _link_first_group(groups, true):
			continue
		if not _link_first_group(groups, false):
			return


func trim_dead_ends(chance: float) -> void:
	if chance <= 0.0:
		return
	for _pass in MAX_TRIM_PASSES:
		var removed := 0
		for y in size.y:
			for x in size.x:
				var cell := Vector2i(x, y)
				if get_cell(cell) != CORRIDOR or door_links.has(cell):
					continue
				if links_at(cell) > 1 or _touches_room(cell):
					continue
				if _rng.randf() >= chance:
					continue
				set_cell(cell, EMPTY)
				removed += 1
		if removed == 0:
			return


func _area_is_free(origin: Vector2i, tiles: Vector2i, margin: int) -> bool:
	for x in range(origin.x - margin, origin.x + tiles.x + margin):
		for y in range(origin.y - margin, origin.y + tiles.y + margin):
			var cell := Vector2i(x, y)
			if not in_bounds(cell) or get_cell(cell) != EMPTY:
				return false
	return true


func _touches_room(cell: Vector2i) -> bool:
	for dir in 4:
		if get_cell(cell + STEPS[dir]) == ROOM:
			return true
	return false


func _pick_seed() -> Vector2i:
	var candidates := []
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			if get_cell(cell) != EMPTY:
				continue
			if _touches_room(cell) or links_at(cell) > 0:
				continue
			candidates.append(cell)
	if candidates.is_empty():
		return Vector2i(-1, -1)
	return candidates[_rng.randi_range(0, candidates.size() - 1)]


func _carve_from(start: Vector2i) -> void:
	set_cell(start, CORRIDOR)
	var stack := [start]
	while not stack.is_empty():
		var cell: Vector2i = stack[stack.size() - 1]
		var options := []
		if total_links(cell) < MAX_LINKS_PER_CELL:
			for dir in 4:
				var middle: Vector2i = cell + STEPS[dir]
				var far: Vector2i = cell + STEPS[dir] * 2
				if not in_bounds(far):
					continue
				if get_cell(middle) != EMPTY or get_cell(far) != EMPTY:
					continue
				if _would_crowd(middle) or _would_crowd(far):
					continue
				options.append(dir)
		if options.is_empty():
			stack.pop_back()
			continue
		var dir: int = options[_rng.randi_range(0, options.size() - 1)]
		set_cell(cell + STEPS[dir], CORRIDOR)
		set_cell(cell + STEPS[dir] * 2, CORRIDOR)
		stack.append(cell + STEPS[dir] * 2)


func _would_crowd(cell: Vector2i) -> bool:
	var links := 0
	var doors: int = door_links.get(cell, 0)
	for dir in 4:
		if doors & (1 << dir):
			links += 1
	for dir in 4:
		var side: Vector2i = cell + STEPS[dir]
		if get_cell(side) != CORRIDOR:
			continue
		links += 1
		if total_links(side) >= MAX_LINKS_PER_CELL:
			return true
	return links >= MAX_LINKS_PER_CELL


func _label_groups() -> Array:
	var seen := {}
	var groups := []
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			if get_cell(cell) == EMPTY or seen.has(cell):
				continue
			var group := []
			var queue := [cell]
			seen[cell] = true
			var head := 0
			while head < queue.size():
				var current: Vector2i = queue[head]
				head += 1
				group.append(current)
				for dir in 4:
					var side: Vector2i = current + STEPS[dir]
					if not in_bounds(side) or seen.has(side):
						continue
					if get_cell(side) == EMPTY:
						continue
					seen[side] = true
					queue.append(side)
			groups.append(group)
	return groups


func _link_first_group(groups: Array, avoid_crowding: bool) -> bool:
	var owner := {}
	for index in groups.size():
		for cell in groups[index]:
			owner[cell] = index

	var parents := {}
	var queue := []
	for cell in groups[0]:
		for dir in 4:
			var side: Vector2i = cell + STEPS[dir]
			if not in_bounds(side) or get_cell(side) != EMPTY or parents.has(side):
				continue
			if avoid_crowding and _would_crowd(side):
				continue
			parents[side] = cell
			queue.append(side)

	var head := 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		for dir in 4:
			var side: Vector2i = cell + STEPS[dir]
			if not in_bounds(side):
				continue
			if owner.has(side) and owner[side] != 0:
				_carve_back(cell, parents)
				return true
			if get_cell(side) != EMPTY or parents.has(side):
				continue
			if avoid_crowding and _would_crowd(side):
				continue
			parents[side] = cell
			queue.append(side)
	return false


func _carve_back(from: Vector2i, parents: Dictionary) -> void:
	var cell := from
	while parents.has(cell) and get_cell(cell) == EMPTY:
		set_cell(cell, CORRIDOR)
		cell = parents[cell]
