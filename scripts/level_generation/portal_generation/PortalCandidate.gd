class_name PortalCandidate extends RefCounted

var wall_pos: Vector2i
var area_a: AreaNode
var area_b: AreaNode

func _init(p_wall_pos, p_area_a, p_area_b) -> void:
	wall_pos = p_wall_pos
	area_a = p_area_a
	area_b = p_area_b
