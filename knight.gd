extends Node3D
@export var speed := 2.0
@export var patrol_distance := 5.0
@export var arrival_distance := 0.3
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var hit_area: Area3D = $HitArea

var _start_position: Vector3
var _target_position: Vector3
var _going_forward := true

func _ready() -> void:
	_start_position = global_position
	_target_position = _start_position + Vector3(patrol_distance, 0, 0)
	hit_area.body_entered.connect(_on_hit_area_body_entered)

func _process(delta: float) -> void:
	var direction := (_target_position - global_position)
	direction.y = 0

	if direction.length() < arrival_distance:
		_going_forward = not _going_forward
		_target_position = _start_position if not _going_forward else _start_position + Vector3(patrol_distance, 0, 0)
		return

	direction = direction.normalized()
	global_position += direction * speed * delta
	look_at(global_position + direction, Vector3.UP)

	if anim_player.current_animation != "walk":
		anim_player.play("walk")

func _on_hit_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		call_deferred("_handle_player_hit")

func _handle_player_hit() -> void:
	hit_area.monitoring = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scene/start.tscn")
