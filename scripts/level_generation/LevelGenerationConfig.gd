class_name LevelGenerationConfig extends Resource

@export var level_size: Vector2i = Vector2i(12,12)

@export_range(1, 4) var edge_count_min: int = 1
@export_range(1, 4) var edge_count_max: int = 4
@export var edge_width_min: int = 1
@export var edge_width_max: int = 2
@export var corridor_width_min: int = 1
@export var corridor_width_max: int = 1
@export var road_width_min: int = 0
@export var road_width_max: int = 2
@export var building_count_min = 1
@export var building_count_max = 2

@export var min_room_size: int = 2
@export var min_corridor_cut_len: int = 4

@export var outside_merge_prob: float = 0.02
@export var road_and_edge_merge_prob: float = 1.0
@export var corridor_merge_prob: float = 0.9
@export var room_merge_prob: float = 0.4
@export var corridor_prob: float = 0.5
@export var max_room_merge_count = 6

@export var portal_placement_percentage: float = 0.125
@export var portal_repair_chance: float = 1.0

@export var start_inside: bool = false

@export var vault_rooms_min: int = 1
@export var vault_rooms_max: int = 1
