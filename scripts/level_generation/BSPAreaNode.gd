class_name BSPAreaNode extends Resource

@export var rect: Rect2i
@export var area_type: AreaTypes.Type
@export var children: Array[BSPAreaNode]

# p_ for parameter to avoid using self. and getting shadowing warnings
func _init(p_rect: Rect2i, p_area_type: AreaTypes.Type) -> void:
	rect = p_rect
	area_type = p_area_type
	children = []
