class_name UnionFind extends RefCounted

var parent := {}

func add(x):
	if not parent.has(x):
		parent[x] = x

func find(x):
	var cur = x
	while parent[cur] != cur:
		cur = parent[cur]
	
	var root = cur
	# Path compression
	# Makes future calls not have to travel the whole path
	cur = x
	while parent[cur] != cur:
		var next = parent[cur]
		parent[cur] = root
		cur = next
	
	return root
	

func union(a, b):
	var ra = find(a)
	var rb = find(b)
	if ra != rb:
		parent[rb] = ra

func connected(a, b) -> bool:
	return find(a) == find(b)
