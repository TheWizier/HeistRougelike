class_name BSPGraph extends Resource

var root: BSPAreaNode

func get_leaf_nodes() -> Array[BSPAreaNode]:
	var leaves: Array[BSPAreaNode] = []
	var node_queue: Array[BSPAreaNode] = [root]
	
	var cur_node: BSPAreaNode
	while not node_queue.is_empty():
		cur_node = node_queue.pop_front()
		if cur_node.children.is_empty():
			leaves.append(cur_node)
		else:
			node_queue.append_array(cur_node.children)
			
	return leaves
# Could contain metadata like creator if we add level editor?
