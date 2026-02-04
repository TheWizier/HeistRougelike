class_name LevelData
extends RefCounted

# Core data
var logical_size: Vector2i
var expanded_size: Vector2i

# Tile array is set up like this:
# cwcwc
# wxwxw
# cwcwc
# x = centre, w = wall, c = corner

# we will use centre for floor tiles and full wall tiles.
# interactable stuff should probably be entity instead
# Doors would be exception to this then as they dont fit the logical grid

var grid: Grid2D # 2D array of tile types [y][x] (expanded size)
var area_owner: Grid2D # Grid2D[AreaNode] (logical size)

var entity_list: Array[Entity]

func _init(p_logical_size: Vector2i) -> void:
	logical_size = p_logical_size
	expanded_size = logical_size * 2 + Vector2i(1,1)
	grid = Grid2D.new(expanded_size, null)
	area_owner = Grid2D.new(logical_size)

# --- Coordinate helpers ---

static func logical_to_expanded(pos: Vector2i) -> Vector2i:
	return pos*2 + Vector2i(1,1)
	
static func expanded_to_logical(pos: Vector2i) -> Vector2i:
	assert((pos.x - 1) % 2 == 0)
	assert((pos.y - 1) % 2 == 0)
	return (pos - Vector2i(1, 1)) / 2

static func _get_between(logical_pos_a: Vector2i, logical_pos_b: Vector2i) -> Vector2i:
	assert(logical_pos_a.distance_to(logical_pos_b) == 1)
	var a = logical_to_expanded(logical_pos_a)
	var b = logical_to_expanded(logical_pos_b)
	return (a + b) / 2

func is_in_bounds(logical_pos: Vector2i) -> bool:
	return logical_pos.x >= 0 and logical_pos.y >= 0 \
	and logical_pos.x < logical_size.x and logical_pos.y < logical_size.y

func is_expanded_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 \
		and pos.x < expanded_size.x and pos.y < expanded_size.y

# --- Logical API ---

func set_logical_tile(logical_pos: Vector2i, tile: Tile, owner: AreaNode = null):
	grid.set_cell(logical_to_expanded(logical_pos), tile)
	area_owner.set_cell(logical_pos, owner)
	
func get_logical_tile(logical_pos: Vector2i) -> Tile:
	return grid.get_cell(logical_to_expanded(logical_pos))

func get_logical_tile_owner(logical_pos: Vector2i) -> AreaNode:
	return area_owner.get_cell(logical_pos)

# --- Walls / portals ---

func set_wall_between(logical_pos_a: Vector2i, logical_pos_b: Vector2i, tile: Tile):
	grid.set_cell(_get_between(logical_pos_a, logical_pos_b), tile)

func get_wall_between(logical_pos_a: Vector2i, logical_pos_b: Vector2i) -> Tile:
	return grid.get_cell(_get_between(logical_pos_a, logical_pos_b))
	
# --- Expanded API ---

func has_tile_at(expanded_pos: Vector2i) -> bool:
	return is_expanded_in_bounds(expanded_pos) \
		and grid.get_cell(expanded_pos) != null

# NOTE To access expanded coords do .grid.get_cell()

# --- Pathfinding ---

func can_move(from: Vector2i, to: Vector2i) -> bool:
	var d = to - from

	# Only adjacent logical tiles
	if abs(d.x) > 1 or abs(d.y) > 1 or d == Vector2i.ZERO:
		return false

	var a = logical_to_expanded(from)
	var b = logical_to_expanded(to)
	var mid = (a + b) / 2

	# Wall directly between the tiles
	if not is_walkable(Vector2i(mid.x, mid.y)):
		return false

	# Diagonal move. Prevent corner cutting
	if d.x != 0 and d.y != 0:
		if not is_walkable(Vector2i(mid.x, a.y)):
			return false
		if not is_walkable(Vector2i(a.x, mid.y)):
			return false
		if not is_walkable(Vector2i(mid.x, b.y)):
			return false
		if not is_walkable(Vector2i(b.x, mid.y)):
			return false

	return true

func is_walkable(expanded_pos: Vector2i) -> bool:
	# Blocked by tile
	var cell = grid.get_cell(expanded_pos)
	if cell != null and not cell.definition.is_walkable:
		return false
	# Blocked by entity
	for entity in entity_list:
		if entity.is_blocking and entity.pos == expanded_to_logical(expanded_pos):
			return false
	return true

# --- util ---

func duplicate() -> LevelData:
	var copy = LevelData.new(logical_size)
	copy.grid = grid.duplicate()
	return copy
