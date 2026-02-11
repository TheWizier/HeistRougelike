class_name AreaMerging extends RefCounted # TODO if purely static then dont extend RefCounted

static func create_areas_from_bsp_leaves(bsp_leaves: Array[BSPAreaNode], config: LevelGenerationConfig):
	var level_nodes: Array[AreaNode] = bsp_leaves_to_area_nodes(bsp_leaves)
	build_area_node_neighbors(level_nodes)
	merge_rooms_into_roads(level_nodes, config.outside_merge_prob)
	merge_random_nodes_of_same_type(level_nodes, AreaTypes.Type.ROOM, config.room_merge_prob)
	merge_random_nodes_of_same_type(level_nodes, AreaTypes.Type.CORRIDOR, config.corridor_merge_prob)
	merge_random_nodes_of_same_type(level_nodes, AreaTypes.Type.ROAD, 1)
	return level_nodes


# Build neighbor lists for AreaNodes based on shared edges
static func build_area_node_neighbors(nodes: Array[AreaNode]) -> void:
	# This works on the assumtion that all nodes are still only 1 rect
	for i in range(nodes.size()):
		for j in range(i + 1, nodes.size()):
			var a := nodes[i]
			var b := nodes[j]

			if _rects_share_edge(a.geometry[0], b.geometry[0]):
				a.neighbours.append(b)
				b.neighbours.append(a)


static func _rects_share_edge(a: Rect2i, b: Rect2i) -> bool:
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


# Convert BSP leaves into AreaNodes
static func bsp_leaves_to_area_nodes(leaves: Array[BSPAreaNode]) -> Array[AreaNode]:
	var nodes: Array[AreaNode] = []
	for leaf in leaves:
		var node := AreaNode.new(leaf.area_type)
		node.geometry.append(leaf.rect)
		nodes.append(node)
	return nodes


static func merge_rooms_into_roads(nodes: Array[AreaNode], chance := 0.05) -> void:
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
		merge_nodes(node, room, nodes)
		node.area_type = AreaTypes.Type.ROAD


static func merge_random_nodes_of_same_type(nodes: Array[AreaNode], area_type: AreaTypes.Type, merge_chance: float, max_node_count = 999999) -> void:
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


static func merge_nodes(a: AreaNode, b: AreaNode, all_nodes: Array[AreaNode]) -> void:
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


static func add_neighbour(a: AreaNode, b: AreaNode) -> void:
	if b == a:
		return
	if b not in a.neighbours:
		a.neighbours.append(b)
