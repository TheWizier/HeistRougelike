class_name BSPSplitting extends RefCounted

enum CutType { ROOM, CORRIDOR }


static func validate_config(config: LevelGenerationConfig):
	# TODO: Make this more lenient if the algorithm can support it after it is done
	var possible_edge_size: int
	if config.edge_count_max > 1:
		possible_edge_size = config.edge_width_max*2
	else:
		possible_edge_size = config.edge_width_max

	var min_required_size = possible_edge_size + config.min_room_size*config.building_count_max + config.road_width_max*config.building_count_max-1
	
	assert(config.level_size.x > min_required_size and config.level_size.y > min_required_size)


static func generate_level_BSP(config: LevelGenerationConfig) -> BSPGraph:
	var signal_areas: Array[BSPAreaNode] 
	if OS.is_debug_build():
		validate_config(config)
	
	var starting_area: Rect2i = Rect2i(Vector2i(0,0), config.level_size)
	var result: BSPGraph = BSPGraph.new()
	result.root = BSPAreaNode.new(starting_area, AreaTypes.Type.ROOM)
	
	var area_queue: Array[BSPAreaNode] = []
	
	# Edge cuts
	var directions: Array[Facing.Direction] = [Facing.Direction.UP, Facing.Direction.RIGHT, Facing.Direction.DOWN, Facing.Direction.LEFT]
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
	
	return result


static func edge_cut(area: Rect2i, direction: Facing.Direction, cut_width: int) -> Array[Rect2i]:
	# Returns [main_area, edge]
	var result: Array[Rect2i]
	match direction:
		Facing.Direction.UP:
			result.append(Rect2i(Vector2i(area.position.x, area.position.y+cut_width), Vector2i(area.size.x, area.size.y-cut_width)))
			result.append(Rect2i(area.position, Vector2i(area.size.x, cut_width)))
		Facing.Direction.DOWN:
			result.append(Rect2i(area.position, Vector2i(area.size.x, area.size.y-cut_width)))
			result.append(Rect2i(Vector2i(area.position.x, area.position.y+area.size.y-cut_width), Vector2i(area.size.x, cut_width)))
		Facing.Direction.RIGHT:
			result.append(Rect2i(area.position, Vector2i(area.size.x-cut_width, area.size.y)))
			result.append(Rect2i(Vector2i(area.position.x+area.size.x-cut_width, area.position.y), Vector2i(cut_width, area.size.y)))
		Facing.Direction.LEFT:
			result.append(Rect2i(Vector2i(area.position.x+cut_width, area.position.y), Vector2i(area.size.x-cut_width, area.size.y)))
			result.append(Rect2i(area.position, Vector2i(cut_width, area.size.y)))
	return result


static func room_cut(area: Rect2i, min_room_size: int, prefer_wide_side: bool = false) -> Array[Rect2i]:
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


static func road_cut(area: Rect2i, road_width: int, min_room_size: int, prefer_wide_side: bool = false) -> Array[Rect2i]:
	# Returns [area1, road, area2]
	var result: Array[Rect2i]
	
	# Cut along the widest side or random if both sides are equal or not prefer wide side
	var do_vertical_cut: bool = _choose_axis(area, prefer_wide_side)
	
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


static func _choose_axis(area: Rect2i, prefer_wide_side: bool):
	# Returns true for vertical false for horizontal
	# Cut along the widest side or random if both sides are equal or not prefer wide side
	if area.size.x == area.size.y or not prefer_wide_side:
		return randi_range(0, 1)
	else:
		return area.size.x > area.size.y


static func _can_cut(area: Rect2, vertical: bool, size_limit: int) -> bool:
	if vertical:
		return area.size.x >= size_limit
	else:
		return area.size.y >= size_limit
