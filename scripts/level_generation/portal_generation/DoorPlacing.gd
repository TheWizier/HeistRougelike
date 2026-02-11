class_name DoorPlacing extends RefCounted


static func place_doors(
	level_data: LevelData,
	portal_locations: Array[Vector2i],
	entity_library: EntityLibrary,
	entities_root: Node2D,
	level: Level
) -> void:
	var placed_portals: Array[Vector2i] = []

	for pos in portal_locations:
		if pos in placed_portals:
			continue

		var is_vertical: bool = pos.x % 2 == 0
		var neighbour_offset: Vector2i = Vector2i(0, 2) if is_vertical else Vector2i(2, 0)
		var corner_offset: Vector2i = Vector2i(0, 1) if is_vertical else Vector2i(1, 0)

		var adjacent: Array[Vector2i] = []
		for direction in [1, -1]:
			var corner_between: Vector2i = pos + corner_offset * direction
			var neighbour: Vector2i = pos + neighbour_offset * direction
			var corner_missing: bool = level_data.grid.get_cell(corner_between) == null
			if corner_missing and neighbour in portal_locations:
				adjacent.append(neighbour)

		var door_entity_def: EntityDef = entity_library.get_group("doors").pick_random(0)

		if adjacent.size() == 0:
			_create_door(pos, _random_facing(is_vertical), door_entity_def, level_data, entities_root, level)
		elif adjacent.size() == 1:
			var partner_pos: Vector2i = adjacent[0]
			if not _has_extra_neighbours(partner_pos, pos, portal_locations, level_data, corner_offset, neighbour_offset):
				var primary_facing: Facing.Direction = _random_facing(is_vertical)
				_create_door(pos, primary_facing, door_entity_def, level_data, entities_root, level)
				_create_door(partner_pos, _opposite_facing(primary_facing), door_entity_def, level_data, entities_root, level)
				placed_portals.append(partner_pos)

		placed_portals.append(pos)


static func _has_extra_neighbours(
	pos: Vector2i,
	exclude: Vector2i,
	portal_locations: Array[Vector2i],
	level_data: LevelData,
	corner_offset: Vector2i,
	axis_offset: Vector2i
) -> bool:
	for direction in [1, -1]:
		var corner_between: Vector2i = pos + corner_offset * direction
		var neighbour: Vector2i = pos + axis_offset * direction
		if neighbour == exclude:
			continue
		var corner_missing: bool = level_data.grid.get_cell(corner_between) == null
		if corner_missing and neighbour in portal_locations:
			return true
	return false


static func _create_door(
	pos: Vector2i,
	facing: Facing.Direction,
	door_entity_def: EntityDef,
	level_data: LevelData,
	entities_root: Node2D,
	level: Level
) -> void:
	var door := EntityPlacing.create_entity(pos, door_entity_def, level_data, entities_root, level)
	door.facing = facing
	entities_root.add_child(door)  # _ready() fires here, after facing is set


static func _random_facing(is_vertical: bool) -> Facing.Direction:
	var options: Array = [Facing.Direction.RIGHT, Facing.Direction.LEFT] \
		if is_vertical else [Facing.Direction.DOWN, Facing.Direction.UP]
	return options.pick_random()


static func _opposite_facing(facing: Facing.Direction) -> Facing.Direction:
	match facing:
		Facing.Direction.RIGHT: return Facing.Direction.LEFT
		Facing.Direction.LEFT:  return Facing.Direction.RIGHT
		Facing.Direction.DOWN:  return Facing.Direction.UP
		Facing.Direction.UP:    return Facing.Direction.DOWN
		_:                      return facing
