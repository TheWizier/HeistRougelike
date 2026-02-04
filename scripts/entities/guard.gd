class_name Guard
extends Entity

# Idea is to make all guards use this script and just change the exported properties
# to make different types

@export var number_of_patrol_points: int = 1
@export var vision_component: VisionComponent

# NOTE: Try to utilize composition where it makes sense
# Make Components that you can just add as nodes in scenes

enum State { Patrol, Chase, Search, Investigate, Dead }
# Patrol: walk between n points, if blocked -> Search (stationary guard n=1)
# Search: pathfind to a point or two in close proximity, done -> return to patrol or idle point
# Chase: pathfind to last seen player pos, if lost -> Search
# Investigate: move to a point, then Search
# Dead: do nothing disable all AI (OR maybe just delete / replace the entity instead)

var patrol_points: Array[Vector2i]
var _current_patrol_point_index:int = 0

var _state = State.Patrol
var _next_point: Vector2i

func _ready() -> void:
	add_to_group("guards")

func start_investigate(pos: Vector2i): # TODO split to component?
	_state = State.Investigate
	_next_point = pos
	
func _process(delta: float) -> void:
	# We can do smoth motion here first based on deltatime and move towards logical position
	# Actual turns are done in our own logic
	pass

func _take_turn() -> void:
	pass
