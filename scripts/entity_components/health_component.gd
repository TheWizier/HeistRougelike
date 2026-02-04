class_name HealthComponent
extends Node2D

@export var max_hp: int
var hp: int

func _ready() -> void:
	hp = max_hp

func recieve_damage(dmg: int):
	hp -= dmg
	if hp <= 0:
		# Deletes the parent
		get_parent().queue_free()
