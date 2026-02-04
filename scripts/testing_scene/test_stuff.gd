extends Node2D

var pathing_manager: PathingManager
@onready var level = $Level
@onready var level_generator: LevelGenerator = $Level/LevelGenerator

@export var level_generation_config: LevelGenerationConfig

var guard_scene = preload("res://scenes/guard.tscn")

var info: BSPGraph
var visualization_draw_queue: Array[Array] = []
@onready var dungeon_draw_timer: Timer = $DungeonDrawTimer
var already_drawm: Array[BSPAreaNode] = []

func _ready() -> void:

	#ready_test_pathing()
	#ready_test_bsp()
	
	ready_test_level_generation()

func ready_test_pathing():
	# not how it should be used but just to test
	# In actual use it should be from a tres file

	var test_tile_wall_def = TileDef.new(0, Vector2i(3, 28), false)

	var test_tile_wall = Tile.new(test_tile_wall_def)

	var level_data: LevelData = LevelData.new(Vector2i(3,3))
	level_data.set_cell(Vector2i(1,2), test_tile_wall)
	level_data.set_wall_between(Vector2i(0,1), Vector2i(1,1), test_tile_wall)
	
	print("GRID:")
	for y in range(level_data.expanded_size.y):
		var row = []
		for x in range(level_data.expanded_size.x):
			row.append(level_data._grid.cells[y][x])
		print(row)
	
	pathing_manager = PathingManager.new()
	
	var path = pathing_manager.get_path(Vector2i(0,0), Vector2i(0,1), level_data)
	print("PATH_0:")
	print(path)
	

	var guard1 = guard_scene.instantiate()
	guard1.level = level
	guard1.pos = Vector2i(1,1)
	level.add_child(guard1)

func ready_test_bsp():
	info = level_generator.generate_level_BSP(level_generation_config)
	
func ready_test_level_generation():
	level.generate_new_level(level_generation_config)
	level.draw_grid()
	pass


func _draw() -> void:
	pass
	# draw_pathfinding()
	# draw_level_gen()
	# draw_level_gen_animated()


func scale_rect(rect: Rect2i, factor: Vector2i) -> Rect2i:
	return Rect2i(rect.position*factor-Vector2i(180, 100), rect.size*factor)
		
		

var colour_dict: Dictionary[AreaTypes.Type, Color] = {
	AreaTypes.Type.ROAD: Color.DARK_GREEN,
	AreaTypes.Type.ROOM: Color.NAVY_BLUE,
	AreaTypes.Type.CORRIDOR: Color.CADET_BLUE,
}
	
func draw_level_gen():
	var areas := info.get_leaf_nodes()
	var size := Vector2i(10, 10)
	
	for area in areas:
		draw_rect(scale_rect(area.rect, size), colour_dict[area.area_type])
		draw_rect(scale_rect(area.rect, size), Color.BLACK, false)


func draw_level_gen_animated():
	var size := Vector2i(10, 10)
	for area in already_drawm:
		draw_rect(scale_rect(area.rect, size), colour_dict[area.area_type])
		draw_rect(scale_rect(area.rect, size), Color.BLACK, false)
	
	if visualization_draw_queue.is_empty():
		return
	for area in visualization_draw_queue.pop_front():
		draw_rect(scale_rect(area.rect, size), colour_dict[area.area_type])
		draw_rect(scale_rect(area.rect, size), Color.BLACK, false)
		already_drawm.push_back(area)
	
	

func draw_pathfinding():
	var points := pathing_manager.astar.get_point_ids()
	for point in points:
		draw_circle(pathing_manager.astar.get_point_position(point)*10-Vector2(50,50), 4, Color.WEB_MAROON)
		var connections = pathing_manager.astar.get_point_connections(point)
		for connection in connections:
			draw_line(pathing_manager.astar.get_point_position(point)*10-Vector2(50,50), pathing_manager.astar.get_point_position(connection)*10-Vector2(50,50), Color.WEB_MAROON,2)
			
	


func _on_level_generator_new_split_made(areas: Array[BSPAreaNode]) -> void:
	visualization_draw_queue.push_back(areas)


func _on_dungeon_draw_timer_timeout() -> void:
	queue_redraw()
