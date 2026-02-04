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

signal new_split_made(areas: Array[BSPAreaNode])

enum Direction { NORTH, EAST, SOUTH, WEST }
enum CutType { ROOM, CORRIDOR }

func validate_config(config: LevelGenerationConfig):
	# TODO: Make this more lenient if the algorithm can support it after it is done
	var possible_edge_size: int
	if config.edge_count_max > 1:
		possible_edge_size = config.edge_width_max*2
	else:
		possible_edge_size = config.edge_width_max

	var min_required_size = possible_edge_size + config.min_room_size*config.building_count_max + config.road_width_max*config.building_count_max-1
	
	assert(config.level_size.x > min_required_size and config.level_size.y > min_required_size)
	
func generate_level(config: LevelGenerationConfig, tile_library: TileLibrary) -> LevelData:
	var bsp_leaves: Array[BSPAreaNode] = generate_level_BSP(config).get_leaf_nodes()
	var level_nodes: Array[AreaNode] = bsp_leaves_to_area_nodes(bsp_leaves)
	build_area_node_neighbors(level_nodes)
	merge_rooms_into_roads(level_nodes, config.outside_merge_prob)
	merge_random_nodes_of_same_type(level_nodes, AreaTypes.Type.ROOM, config.room_merge_prob)
	merge_random_nodes_of_same_type(level_nodes, AreaTypes.Type.CORRIDOR, config.corridor_merge_prob)
	merge_random_nodes_of_same_type(level_nodes, AreaTypes.Type.ROAD, 1)
	var player_spawn_pos := choose_start_pos(level_nodes, config.start_inside)
	var portal_locations: Array[Vector2i] = choose_portal_locations()
	choose_vault_rooms(level_nodes, config.vault_rooms_min, config.vault_rooms_max)
	set_up_security_levels()
	place_portals(portal_locations)
	
	var level_data := populate_level_data(level_nodes, config, tile_library)
	
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


func place_corners(level_data: LevelData, tile_library: TileLibrary) -> void:
	var expanded_size = level_data.grid.size
	# Lookup table: mask -> (tile_name, rotation)
	var lookup = {
		0b0001: ["corner_1", Tile.TileTransforms.ROTATE_0],   # up only
		0b0010: ["corner_1", Tile.TileTransforms.ROTATE_90],  # right only
		0b0100: ["corner_1", Tile.TileTransforms.ROTATE_180], # down only
		0b1000: ["corner_1", Tile.TileTransforms.ROTATE_270], # left only

		0b0011: ["corner_2", Tile.TileTransforms.ROTATE_0],   # up+right
		0b0110: ["corner_2", Tile.TileTransforms.ROTATE_90],  # right+down
		0b1100: ["corner_2", Tile.TileTransforms.ROTATE_180], # down+left
		0b1001: ["corner_2", Tile.TileTransforms.ROTATE_270], # left+up

		0b0111: ["corner_3", Tile.TileTransforms.ROTATE_0],   # up+right+down, missing left
		0b1110: ["corner_3", Tile.TileTransforms.ROTATE_90],  # right+down+left, missing up
		0b1101: ["corner_3", Tile.TileTransforms.ROTATE_180], # down+left+up, missing right
		0b1011: ["corner_3", Tile.TileTransforms.ROTATE_270], # left+up+right, missing down

		0b1111: ["corner_4", Tile.TileTransforms.ROTATE_0],    # all four walls
		
		0b0101: ["wall", Tile.TileTransforms.ROTATE_0],
		0b1010: ["wall", Tile.TileTransforms.ROTATE_90],
	}

	for y in range(0, expanded_size.y, 2):
		for x in range(0, expanded_size.x, 2):
			var pos = Vector2i(x, y)

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

			# Count number of walls
			var wall_count = neighbors.count(true)
			if wall_count == 0:
				continue # Nothing to place

			var info = lookup[mask]
			var tile_name = info[0]
			var rotation = info[1]

			level_data.grid.set_cell(pos, Tile.new(tile_library.lib[tile_name], rotation))

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
		

func set_up_security_levels():
	pass # TODO

func generate_portals(level_nodes: Array[AreaNode]):
	pass # TODO
	# pick random connections
	# repair with probability (to achieve reachability_prob)
	# Choose portal type (Might need to set security levels on rooms first

func rects_share_edge(a: Rect2i, b: Rect2i) -> bool:
	# Vertical edge touch
	if a.position.x + a.size.x == b.position.x \
	or b.position.x + b.size.x == a.position.x:
		var overlap: int = min(a.position.y + a.size.y, b.position.y + b.size.y) \
			- max(a.position.y, b.position.y)
		return overlap > 0

	# Horizontal edge touch
	if a.position.y + a.size.y == b.position.y \
	or b.position.y + b.size.y == a.position.y:
		var overlap: int = min(a.position.x + a.size.x, b.position.x + b.size.x) \
			- max(a.position.x, b.position.x)
		return overlap > 0

	return false

func nodes_share_edge(a: AreaNode, b: AreaNode) -> bool:
	for ra in a.geometry:
		for rb in b.geometry:
			if rects_share_edge(ra, rb):
				return true
	return false

# Convert BSP leaves into AreaNodes
func bsp_leaves_to_area_nodes(leaves: Array[BSPAreaNode]) -> Array[AreaNode]:
	var nodes: Array[AreaNode] = []
	for leaf in leaves:
		var node := AreaNode.new(leaf.area_type)
		node.geometry.append(leaf.rect)
		nodes.append(node)
	return nodes

# Build neighbor lists for AreaNodes based on shared edges
func build_area_node_neighbors(nodes: Array[AreaNode]) -> void:
	for i in range(nodes.size()):
		for j in range(i + 1, nodes.size()):
			var a := nodes[i]
			var b := nodes[j]

			if rects_share_edge(a.geometry[0], b.geometry[0]):
				a.neighbours.append(b)
				b.neighbours.append(a)
	
func add_neighbour(a: AreaNode, b: AreaNode) -> void:
	if b == a:
		return
	if b not in a.neighbours:
		a.neighbours.append(b)

func merge_nodes(a: AreaNode, b: AreaNode, all_nodes: Array[AreaNode]) -> void:
	# 1. Geometry
	a.geometry.append_array(b.geometry)

	# 2. Neighbours
	for n in b.neighbours:
		if n == a:
			continue

		add_neighbour(a, n)
		n.neighbours.erase(b)
		add_neighbour(n, a)

	# 3. Cleanup
	a.neighbours.erase(b)
	all_nodes.erase(b)
	
#func can_road_absorb_room(road: AreaNode, room: AreaNode) -> bool:
	#if road.area_type != AreaTypes.Type.ROAD:
		#return false
	#if room.area_type != AreaTypes.Type.ROOM:
		#return false
#
	#for r in road.geometry:
		#for s in room.geometry:
			#if rects_share_edge(r, s):
				#return true
#
	#return false

func absorb_room_into_road(road: AreaNode, room: AreaNode, nodes: Array[AreaNode]) -> void:
	merge_nodes(road, room, nodes)
	road.area_type = AreaTypes.Type.ROAD

func merge_rooms_into_roads(nodes: Array[AreaNode], chance := 0.05) -> void:
	var shuffled := nodes.duplicate()
	shuffled.shuffle()

	for node in shuffled:
		if node not in nodes:
			continue

		if node.area_type != AreaTypes.Type.ROAD:
			continue

		if randf() > chance:
			continue

		var room_candidates := []
		for n in node.neighbours:
			if n.area_type == AreaTypes.Type.ROOM:
				room_candidates.append(n)

		if room_candidates.is_empty():
			continue

		var room: AreaNode = room_candidates.pick_random()
		absorb_room_into_road(node, room, nodes)

func merge_random_nodes_of_same_type(nodes: Array[AreaNode], area_type: AreaTypes.Type, merge_chance: float, max_node_count = 999999) -> void:
	var node_queue: Array[AreaNode] = nodes.duplicate().filter(
		func(n):
			return n.area_type == area_type
	)
	node_queue.shuffle()
	# Use node queue to ensure each node is only considered once
	# For every node of area_type
	while not node_queue.is_empty():
		var node: AreaNode = node_queue.pop_front()
		var neighbour_queue: Array[AreaNode] = node.neighbours.duplicate()
		# For every neighbour of current growing node
		while not neighbour_queue.is_empty() and node.geometry.size() <= max_node_count:
			var other: AreaNode = neighbour_queue.pop_front()
			if other.area_type == area_type:
				# Roll chance
				if randf() > merge_chance:
					continue
				# Test if we already considered this node
				if other not in node_queue:
					continue
				# Put our new neighbours in the queue
				for n in other.neighbours:
					if n != node and n not in neighbour_queue:
						neighbour_queue.push_back(n)
				# Merge nodes
				merge_nodes(node, other, nodes)
				node_queue.erase(other)
				

func generate_level_BSP(config: LevelGenerationConfig) -> BSPGraph:
	var signal_areas: Array[BSPAreaNode] 
	if OS.is_debug_build():
		validate_config(config)
	
	var starting_area: Rect2i = Rect2i(Vector2i(0,0), config.level_size)
	var result: BSPGraph = BSPGraph.new()
	result.root = BSPAreaNode.new(starting_area, AreaTypes.Type.ROOM)
	
	var area_queue: Array[BSPAreaNode] = []
	
	# Edge cuts
	var directions: Array[Direction] = [Direction.NORTH, Direction.EAST, Direction.SOUTH, Direction.WEST]
	directions.shuffle()
	var cuts: Array[Rect2i]
	var cur_area: BSPAreaNode = result.root
	var new_main_area: BSPAreaNode
	var new_edge_area: BSPAreaNode
	for n in range(randi_range(config.edge_count_min, config.edge_count_max)):
		cuts = edge_cut(cur_area.rect, directions[n], randi_range(config.edge_width_min, config.edge_width_max))
		new_main_area = BSPAreaNode.new(cuts[0], AreaTypes.Type.ROOM)
		new_edge_area = BSPAreaNode.new(cuts[1], AreaTypes.Type.ROAD)
		cur_area.children.append(new_main_area)
		cur_area.children.append(new_edge_area)
		cur_area = new_main_area
		
		# NOTE: Visualize signal for debug
		if OS.is_debug_build():
			signal_areas = [new_main_area, new_edge_area]
			new_split_made.emit(signal_areas)
	
	# Building cuts
	var cut_a: BSPAreaNode
	var road: BSPAreaNode
	var cut_b: BSPAreaNode
	var road_width: int
	area_queue.append(cur_area)
	for n in range(randi_range(config.building_count_min, config.building_count_max)-1):
		cur_area = area_queue.pop_front()
		road_width = randi_range(config.road_width_min, config.road_width_max)
		cuts = road_cut(cur_area.rect, road_width, config.min_room_size, true)
		cut_a = BSPAreaNode.new(cuts[0], AreaTypes.Type.ROOM)
		if road_width != 0:
			road = BSPAreaNode.new(cuts[1], AreaTypes.Type.ROAD)
		cut_b = BSPAreaNode.new(cuts[2], AreaTypes.Type.ROOM)
		cur_area.children.append(cut_a)
		if road_width != 0:
			cur_area.children.append(road)
		cur_area.children.append(cut_b)
		area_queue.push_back(cut_a)
		area_queue.push_back(cut_b)
		
		if OS.is_debug_build():
			if road_width != 0:
				signal_areas = [cut_a, road, cut_b]
			else:
				signal_areas = [cut_a, cut_b]
				print("NO ROAD")
			new_split_made.emit(signal_areas)
	
	# Corridor and Room cuts
	var cut_type: CutType
	var corridor: BSPAreaNode
	var cut_done: bool
	while not area_queue.is_empty():
		cur_area = area_queue.pop_front()
		if cur_area.area_type == AreaTypes.Type.CORRIDOR:
			continue # TODO: corridor special cut thing? #Skip for now
		cut_type = CutType.CORRIDOR if randf() < config.corridor_prob else CutType.ROOM
		cut_done = false
		while not cut_done:
			match cut_type:
				CutType.ROOM:
					cuts = room_cut(cur_area.rect, config.min_room_size)
					for cut in cuts:
						cut_a = BSPAreaNode.new(cut, AreaTypes.Type.ROOM)
						cur_area.children.append(cut_a)
						area_queue.push_back(cut_a)
						
						if OS.is_debug_build():
							signal_areas = [cut_a]
							new_split_made.emit(signal_areas)
					cut_done = true
				
				CutType.CORRIDOR:
					cuts = road_cut(cur_area.rect, randi_range(config.corridor_width_min, config.corridor_width_max), config.min_room_size)
					if cuts.is_empty():
						# Try room cut instead
						cut_type = CutType.ROOM
						continue
					cut_a = BSPAreaNode.new(cuts[0], AreaTypes.Type.ROOM)
					corridor = BSPAreaNode.new(cuts[1], AreaTypes.Type.CORRIDOR)
					cut_b = BSPAreaNode.new(cuts[2], AreaTypes.Type.ROOM)
					cur_area.children.append(cut_a)
					cur_area.children.append(corridor)
					cur_area.children.append(cut_b)
					area_queue.push_back(cut_a)
					# area_queue.push_back(corridor) # TODO maybe
					area_queue.push_back(cut_b)
					cut_done = true
					
					if OS.is_debug_build():
						signal_areas = [cut_a, corridor, cut_b]
						new_split_made.emit(signal_areas)
	
	return result

func edge_cut(area: Rect2i, direction: Direction, cut_width: int) -> Array[Rect2i]:
	# Returns [main_area, edge]
	var result: Array[Rect2i]
	match direction:
		Direction.NORTH:
			result.append(Rect2i(Vector2i(area.position.x, area.position.y+cut_width), Vector2i(area.size.x, area.size.y-cut_width)))
			result.append(Rect2i(area.position, Vector2i(area.size.x, cut_width)))
		Direction.SOUTH:
			result.append(Rect2i(area.position, Vector2i(area.size.x, area.size.y-cut_width)))
			result.append(Rect2i(Vector2i(area.position.x, area.position.y+area.size.y-cut_width), Vector2i(area.size.x, cut_width)))
		Direction.EAST:
			result.append(Rect2i(area.position, Vector2i(area.size.x-cut_width, area.size.y)))
			result.append(Rect2i(Vector2i(area.position.x+area.size.x-cut_width, area.position.y), Vector2i(cut_width, area.size.y)))
		Direction.WEST:
			result.append(Rect2i(Vector2i(area.position.x+cut_width, area.position.y), Vector2i(area.size.x-cut_width, area.size.y)))
			result.append(Rect2i(area.position, Vector2i(cut_width, area.size.y)))
	return result
	
func _choose_axis(area: Rect2i, prefer_wide_side: bool):
	# Returns true for vertical false for horizontal
	# Cut along the widest side or random if both sides are equal or not prefer wide side
	if area.size.x == area.size.y or not prefer_wide_side:
		return randi_range(0, 1)
	else:
		return area.size.x > area.size.y


func road_cut(area: Rect2i, road_width: int, min_room_size: int, prefer_wide_side: bool = false) -> Array[Rect2i]:
	# Returns [area1, road, area2]
	var result: Array[Rect2i]
	
	# Cut along the widest side or random if both sides are equal or not prefer wide side
	var do_vertical_cut: bool = _choose_axis(area, prefer_wide_side)
	
	# Check if cut is possible
	
	# Check if cut is possible
	if not _can_cut(area, do_vertical_cut, road_width+min_room_size*2):
		#Try other axis
		do_vertical_cut = not do_vertical_cut
		if not _can_cut(area, do_vertical_cut, road_width+min_room_size*2):
			return [] # Give up
	
	# Create areas
	var area1_width: int
	if do_vertical_cut:
		area1_width = randi_range(min_room_size, area.size.x-min_room_size-road_width)
		result.append(Rect2i(area.position, Vector2i(area1_width, area.size.y)))
		result.append(Rect2i(Vector2i(area.position.x+area1_width, area.position.y), Vector2(road_width, area.size.y)))
		result.append(Rect2i(Vector2i(area.position.x+area1_width+road_width, area.position.y), Vector2i(area.size.x-road_width-area1_width, area.size.y)))
	else: # do horizontal cut
		area1_width = randi_range(min_room_size, area.size.y-min_room_size-road_width)
		result.append(Rect2i(area.position, Vector2i(area.size.x, area1_width)))
		result.append(Rect2i(Vector2i(area.position.x, area.position.y+area1_width), Vector2(area.size.x, road_width)))
		result.append(Rect2i(Vector2i(area.position.x, area.position.y+area1_width+road_width), Vector2i(area.size.x, area.size.y-road_width-area1_width)))
	
	return result

func _can_cut(area: Rect2, vertical: bool, size_limit: int) -> bool:
	if vertical:
		return area.size.x >= size_limit
	else:
		return area.size.y >= size_limit

func room_cut(area: Rect2i, min_room_size: int, prefer_wide_side: bool = false) -> Array[Rect2i]:
	# Returns [area1, area2]
	var result: Array[Rect2i]
	
	# Cut along the widest side or random if both sides are equal or not prefer wide side
	var do_vertical_cut: bool = _choose_axis(area, prefer_wide_side)
	
	# Check if cut is possible
	if not _can_cut(area, do_vertical_cut, min_room_size*2):
		#Try other axis
		do_vertical_cut = not do_vertical_cut
		if not _can_cut(area, do_vertical_cut, min_room_size*2):
			return [] # Give up
	
	# Create areas
	var area1_width: int
	if do_vertical_cut:
		area1_width = randi_range(min_room_size, area.size.x-min_room_size)
		result.append(Rect2i(area.position, Vector2i(area1_width, area.size.y)))
		result.append(Rect2i(Vector2i(area.position.x+area1_width, area.position.y), Vector2i(area.size.x-area1_width, area.size.y)))

	else: # do horizontal cut
		area1_width = randi_range(min_room_size, area.size.y-min_room_size)
		result.append(Rect2i(area.position, Vector2i(area.size.x, area1_width)))
		result.append(Rect2i(Vector2i(area.position.x, area.position.y+area1_width), Vector2i(area.size.x, area.size.y-area1_width)))
	
	return result

func outside_merge(nodes: Array[AreaNode]):
	pass

func room_merge():
	pass

func corridor_merge():
	pass
