class_name PathingManager
extends RefCounted

const DIRS_8: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0),
	Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1),
	Vector2i(-1, 1), Vector2i(-1, -1),
]

var _old_level_data: LevelData
var astar: AStar2D

func _init() -> void:
	astar = AStar2D.new()
	_old_level_data = null

func get_path(from: Vector2i, to: Vector2i, level_data: LevelData, allow_partial=false) -> PackedVector2Array:
	update_pathing(level_data)
	return astar.get_point_path(logical_pos_to_node_id(from, level_data.logical_size.x), logical_pos_to_node_id(to, level_data.logical_size.x), allow_partial)


static func node_id_to_logical_pos(node_id: int, logical_grid_width: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(node_id % logical_grid_width, node_id / logical_grid_width)

static func logical_pos_to_node_id(logical_pos: Vector2i, logical_grid_width: int) -> int:
	return logical_grid_width * logical_pos.y + logical_pos.x

func update_pathing(new_level_data: LevelData) -> void:
	var dirty_centers: Dictionary[Vector2i, bool] = {} # Using dictionary as set as gdscript does not have sets yet

	# Step 1: Diff the expanded grid
	for y in range(new_level_data.expanded_size.y):
		for x in range(new_level_data.expanded_size.x):
			var expanded_pos := Vector2i(x, y)

			if _old_level_data == null or _old_level_data.grid.get_cell(expanded_pos) != new_level_data.grid.get_cell(expanded_pos):
				_mark_dirty_centers_from_expanded_cell(expanded_pos, dirty_centers, new_level_data)
	# Early exit if no diff
	if dirty_centers.is_empty():
		return
	# Step 2: Update AStar nodes for all dirty centers
	for logical_pos in dirty_centers.keys():
		var node_id = logical_pos_to_node_id(logical_pos, new_level_data.logical_size.x)

		if new_level_data.is_walkable(LevelData.logical_to_expanded(logical_pos)):
			if not astar.has_point(node_id):
				astar.add_point(node_id, Vector2(logical_pos))
		else:
			if astar.has_point(node_id):
				astar.remove_point(node_id)

	# Step 3: Update connections for dirty centers
	for logical_pos in dirty_centers.keys():
		var node_id = logical_pos_to_node_id(logical_pos, new_level_data.logical_size.x)
		
		if not astar.has_point(node_id):
			continue

		for direction in DIRS_8:
			var neighbor_pos = logical_pos + direction
			if not new_level_data.is_in_bounds(neighbor_pos):
				continue

			var neighbor_id = logical_pos_to_node_id(neighbor_pos, new_level_data.logical_size.x)
			if not astar.has_point(neighbor_id):
				continue

			if new_level_data.can_move(logical_pos, neighbor_pos):
				if not astar.are_points_connected(node_id, neighbor_id):
					astar.connect_points(node_id, neighbor_id)
			else:
				if astar.are_points_connected(node_id, neighbor_id):
					astar.disconnect_points(node_id, neighbor_id)

	# Step 4: Save snapshot for next diff
	_old_level_data = new_level_data.duplicate()

func _mark_dirty_centers_from_expanded_cell(expanded_cell: Vector2i, out_dirty_centers: Dictionary, level_data: LevelData) -> void:
	# Any expanded cell can affect up to 4 logical center nodes
	for offset_y in [-1, 1]:
		for offset_x in [-1, 1]:
			var affected_center_expanded := expanded_cell + Vector2i(offset_x, offset_y)
			# Only consider actual centers (odd, odd in expanded grid)
			if affected_center_expanded.x % 2 == 1 and affected_center_expanded.y % 2 == 1:
				var logical_center := LevelData.expanded_to_logical(affected_center_expanded)
				if level_data.is_in_bounds(logical_center):
					out_dirty_centers[logical_center] = true
