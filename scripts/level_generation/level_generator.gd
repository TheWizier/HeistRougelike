class_name LevelGenerator extends Node


# Level generation goes like this:
# Start with a size map x*y
# The Cut phase:
# To generate the outside first do 1-4 Edge cuts with size 1-n (must be min 1 to place start point)
# Then to bc-1 building cuts where bc is number of buildings (create roads 0-n wide)
# Then for each building randomly do either corridor or room cuts until no more cuts left due to min sizes
# The Merge phase:
# Merge all roads
# Randomly merge some extrerior rooms or corridors to outside (and tag as outside)
# Randomly merge some rooms
# Randomly with high chance merge corridors
# The placement phase
# Place doors, starting pos, treasure, traps, guards etc...
@export var use_fixed: bool = true
@export var level: Level


func generate_level(
	config: LevelGenerationConfig,
	tile_library: TileLibrary,
	entity_library: EntityLibrary,
	entities_root: Node2D,
	level: Level
) -> LevelData:
	# --- BSP Generation ---
	var bsp_leaves: Array[BSPAreaNode] = BSPSplitting.generate_level_BSP(config).get_leaf_nodes()
	# --- Area node merging ---
	var level_nodes: Array[AreaNode] = AreaMerging.create_areas_from_bsp_leaves(bsp_leaves, config)
	
	# --- Tiles ---
	set_up_security_levels(level_nodes)
	var level_data := populate_level_data(level_nodes, config, tile_library)
	var portal_locations: Array[Vector2i] = choose_portal_locations(
		level_nodes,
		level_data,
		config.portal_placement_percentage,
		config.portal_repair_chance,
	)
	var player_spawn_pos := choose_start_pos(level_nodes, config.start_inside)
	# choose_vault_rooms(level_nodes, config.vault_rooms_min, config.vault_rooms_max) # TODO needs change now that it is after populate
	place_portals(level_data, portal_locations, tile_library)
	
	# --- Entities ---
	DoorPlacing.place_doors(level_data, portal_locations, entity_library, entities_root, level)
	
	
	return level_data


func paint_area_floors(level_data: LevelData, area: AreaNode, floor_tile_def: TileDef):
	for rect in area.geometry:
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			for x in range(rect.position.x, rect.position.x + rect.size.x):
				level_data.set_logical_tile(Vector2i(x, y), Tile.new(floor_tile_def), area)

func add_missing_walls(level_data: LevelData, area: AreaNode, wall_tile: TileDef):
	for rect in area.geometry:
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			for x in range(rect.position.x, rect.position.x + rect.size.x):
				var pos = Vector2i(x,y)
				for direction in Facing.Direction.values():
					# Walls
					var facing_vector = Facing.to_vector(direction)
					var neighbour = pos + facing_vector
					var same_area_neighbour_exists = (
						level_data.is_in_bounds(neighbour)
						and level_data.get_logical_tile(neighbour) != null
						and level_data.get_logical_tile_owner(neighbour) == area
					)
					if not same_area_neighbour_exists:
						var rotation = Tile.TileTransforms.ROTATE_0 if facing_vector.x != 0 else Tile.TileTransforms.ROTATE_90
						var wall_pos = LevelData.logical_to_expanded(pos) + Facing.to_vector(direction)
						level_data.grid.set_cell(wall_pos, Tile.new(wall_tile, rotation))


static func _get_tile_for_corner(level_data: LevelData, pos: Vector2i, tile_library: TileLibrary, allow_pillar: bool = false) -> Tile:
	# Neighbor flags [up, right, down, left]
	var neighbors = [
		level_data.has_tile_at(pos + Vector2i(0, -1)),
		level_data.has_tile_at(pos + Vector2i(1, 0)),
		level_data.has_tile_at(pos + Vector2i(0, 1)),
		level_data.has_tile_at(pos + Vector2i(-1, 0))
	]

	# Encode neighbors as bitmask: U=1, R=2, D=4, L=8
	var mask = 0
	for i in range(4):
		if neighbors[i]:
			mask |= 1 << i

	# Lookup table: mask -> (tile_name, rotation)
	var lookup = {
		0b0001: ["corner_1", Tile.TileTransforms.ROTATE_0],
		0b0010: ["corner_1", Tile.TileTransforms.ROTATE_90],
		0b0100: ["corner_1", Tile.TileTransforms.ROTATE_180],
		0b1000: ["corner_1", Tile.TileTransforms.ROTATE_270],

		0b0011: ["corner_2", Tile.TileTransforms.ROTATE_0],
		0b0110: ["corner_2", Tile.TileTransforms.ROTATE_90],
		0b1100: ["corner_2", Tile.TileTransforms.ROTATE_180],
		0b1001: ["corner_2", Tile.TileTransforms.ROTATE_270],

		0b0111: ["corner_3", Tile.TileTransforms.ROTATE_0],
		0b1110: ["corner_3", Tile.TileTransforms.ROTATE_90],
		0b1101: ["corner_3", Tile.TileTransforms.ROTATE_180],
		0b1011: ["corner_3", Tile.TileTransforms.ROTATE_270],

		0b1111: ["corner_4", Tile.TileTransforms.ROTATE_0],
		0b0000: ["wall_block", Tile.TileTransforms.ROTATE_0],

		0b0101: ["wall", Tile.TileTransforms.ROTATE_0],
		0b1010: ["wall", Tile.TileTransforms.ROTATE_90],
	}

	if mask == 0 and not allow_pillar:
		return null

	var info = lookup.get(mask, null)
	if info == null:
		return null

	var tile_name = info[0]
	var rotation = info[1]

	return Tile.new(tile_library.lib[tile_name], rotation)


func place_corners(level_data: LevelData, tile_library: TileLibrary) -> void:
	var expanded_size = level_data.grid.size
	for y in range(0, expanded_size.y, 2):
		for x in range(0, expanded_size.x, 2):
			var pos = Vector2i(x, y)
			var tile = _get_tile_for_corner(level_data, pos, tile_library)
			level_data.grid.set_cell(pos, tile)


func populate_level_data(level_nodes: Array[AreaNode], config: LevelGenerationConfig, tile_library: TileLibrary) -> LevelData:
	var level_data := LevelData.new(config.level_size)
	# place walls and floors
	for area in level_nodes:
		var area_tag = AreaTypes.AREA_TYPE_TO_TAG[area.area_type]
		if area_tag not in tile_library.by_area:
			area_tag = &"room" # Default to room if missing area in tile_library
		paint_area_floors(level_data, area, tile_library.by_area[area_tag].pick_random())
		add_missing_walls(level_data, area, tile_library.lib[&"wall"]) # use wall block as marker
	place_corners(level_data, tile_library)


	return level_data

func choose_start_pos(level_nodes: Array[AreaNode], start_inside: bool) -> Vector2i:
	# Choose player spawn location
	var wanted_type := AreaTypes.Type.ROOM if start_inside else AreaTypes.Type.ROAD
	var areas := level_nodes.filter(
		func(a: AreaNode):
			return a.area_type == wanted_type and not a.geometry.is_empty()
	)

	if areas.is_empty():
		push_error("No valid start areas found")
		return Vector2i.ZERO
	
	var start_rect: Rect2i = areas.pick_random().geometry.pick_random()
	return Utils.random_rect_pos_safe(start_rect)
	
	
func choose_vault_rooms(level_nodes: Array[AreaNode], vault_rooms_min, vault_rooms_max):
	# Chose "vault" rooms (we might want those to have higher security levels for instance)
	# TODO And we might want to have adjustable neighbour distance from start
	# This would also mean that we should place it after placing doors?
	# So -1 would be as far away as possible while 1 would be one room away
	var rooms := level_nodes.duplicate().filter(func(x): return x.area_type == AreaTypes.Type.ROOM)
	rooms.shuffle()

	var count := randi_range(vault_rooms_min, vault_rooms_max)
	for i in range(min(count, rooms.size())):
		rooms[i].area_type = AreaTypes.Type.VAULT
		

func set_up_security_levels(level_nodes: Array[AreaNode]):
	for area in level_nodes:
		area.security_level = randi_range(0,3)
		# TODO: Update this to use config
		# TODO: How can I configure the distibution?

static func get_affected_corner_positions(wall_pos: Vector2i) -> Array[Vector2i]:
	# vertical wall: x even, y odd
	if wall_pos.x % 2 == 0:
		return [
			wall_pos + Vector2i(0, -1),
			wall_pos + Vector2i(0,  1),
		]
	# horizontal wall: x odd, y even
	else:
		return [
			wall_pos + Vector2i(-1, 0),
			wall_pos + Vector2i( 1, 0),
		]

func place_portals(level_data: LevelData, portal_locations: Array[Vector2i], tile_library: TileLibrary):
	for pos in portal_locations:
		level_data.grid.set_cell(pos, null)
		# Recalculate corners
		for corner in get_affected_corner_positions(pos):
			var tile = _get_tile_for_corner(level_data, corner, tile_library)
			level_data.grid.set_cell(corner, tile)


func choose_portal_locations(
	level_nodes: Array[AreaNode],
	level_data: LevelData,
	portal_placement_percentage: float,
	portal_repair_chance: float,
) -> Array[Vector2i]:
	var candidates := collect_portal_candidates(level_data)
	candidates.shuffle()
	
	var union_find = UnionFind.new()
	for area in level_nodes:
		union_find.add(area)
	
	var chosen: Array[Vector2i] = []
	var placement_count := int(candidates.size() * portal_placement_percentage)
	
	# Place random portals
	for i in range(placement_count):
		var candidate: PortalCandidate = candidates[i]
		chosen.append(candidate.wall_pos)
		union_find.union(candidate.area_a, candidate.area_b)
	
	# repair with probability (to achieve portal_repair_chance)
	for i in range(placement_count, candidates.size()):
		var candidate: PortalCandidate = candidates[i]
		if not union_find.connected(candidate.area_a, candidate.area_b):
			if randf() < portal_repair_chance:
				chosen.append(candidate.wall_pos)
				union_find.union(candidate.area_a, candidate.area_b)
	return chosen
	
func collect_portal_candidates(level_data: LevelData) -> Array[PortalCandidate]:
	var candidates: Array[PortalCandidate] = []

	for y in range(level_data.logical_size.y):
		for x in range(level_data.logical_size.x):
			var pos := Vector2i(x, y)
			var area_a := level_data.get_logical_tile_owner(pos)
			if area_a == null:
				continue

			for dir in [Facing.Direction.RIGHT, Facing.Direction.DOWN]:
				var npos := pos + Facing.to_vector(dir)
				if not level_data.is_in_bounds(npos):
					continue

				var area_b := level_data.get_logical_tile_owner(npos)
				if area_b == null or area_a == area_b:
					continue

				var wall_pos := LevelData._get_between(pos, npos)
				if level_data.grid.get_cell(wall_pos) != null:
					candidates.append(PortalCandidate.new(wall_pos, area_a, area_b))

	return candidates


# RESIDUAL GPT STUFF
#func nodes_share_edge(a: AreaNode, b: AreaNode) -> bool:
	#for ra in a.geometry:
		#for rb in b.geometry:
			#if rects_share_edge(ra, rb):
				#return true
	#return false
