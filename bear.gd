extends Node3D

@export var base_speed := 2.5        
@export var max_chase_speed := 3.8   
@export var patrol_distance := 5.0
@export var arrival_distance := 0.5
@export var detection_range := 25.0  
@export var obstacle_avoidance_dist := 1.8 
@export var attack_radius := 1.1     
@export var rotation_speed := 6.0    

@onready var walk_audio: AudioStreamPlayer3D = $walk
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var physics_body: CharacterBody3D
var hit_area: Area3D

var _start_position: Vector3
var _target_position: Vector3
var _going_forward := true
var _player: CharacterBody3D = null

func _ready() -> void:
	top_level = true
	
	_start_position = global_position
	_target_position = _start_position + Vector3(patrol_distance, 0, 0)
	
	physics_body = CharacterBody3D.new()
	physics_body.top_level = true
	add_child(physics_body)
	physics_body.global_position = _start_position
	
	var collision_shape := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.45 
	capsule_shape.height = 1.8
	collision_shape.shape = capsule_shape
	physics_body.add_child(collision_shape)
	collision_shape.position.y = 0.9
	
	hit_area = Area3D.new()
	var attack_shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = attack_radius
	attack_shape.shape = sphere_shape
	hit_area.add_child(attack_shape)
	physics_body.add_child(hit_area) 
	hit_area.position.y = 0.9
	
	hit_area.body_entered.connect(_on_hit_area_body_entered)
	
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]

func _physics_process(delta: float) -> void:
	if not physics_body.is_on_floor():
		physics_body.velocity += physics_body.get_gravity() * delta
	else:
		physics_body.velocity.y = 0

	if not _player:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			_player = players[0]

	var current_speed = base_speed
	var movement_direction := Vector3.ZERO
	
	var distance_to_player := 9999.0
	if _player:
		distance_to_player = physics_body.global_position.distance_to(_player.global_position)
		
	if _player and distance_to_player <= detection_range:
		movement_direction = (_player.global_position - physics_body.global_position)
		movement_direction.y = 0
		
		if distance_to_player > 3.0:
			var speed_factor = 1.0 - clamp(distance_to_player / detection_range, 0.0, 1.0)
			current_speed = lerp(base_speed, max_chase_speed, speed_factor)
		else:
			current_speed = 1.0 
	else:
		movement_direction = (_target_position - physics_body.global_position)
		movement_direction.y = 0

		if movement_direction.length() < arrival_distance:
			_going_forward = not _going_forward
			_target_position = _start_position if not _going_forward else _start_position + Vector3(patrol_distance, 0, 0)

	var is_moving := false

	if movement_direction.length() > 0.05:
		movement_direction = movement_direction.normalized()
		
		var avoidance_dir = _check_for_obstacles_three_rays(movement_direction)
		if avoidance_dir != Vector3.ZERO:
			movement_direction = (movement_direction + avoidance_dir * 1.8).normalized()
		
		physics_body.velocity.x = movement_direction.x * current_speed
		physics_body.velocity.z = movement_direction.z * current_speed
		physics_body.move_and_slide()
		
		global_position = global_position.lerp(physics_body.global_position, 20.0 * delta)
		
		if Vector2(physics_body.velocity.x, physics_body.velocity.z).length() > 0.1:
			is_moving = true
			var target_look_dir = Vector3(physics_body.velocity.x, 0, physics_body.velocity.z).normalized()
			var target_basis := Basis.looking_at(-target_look_dir, Vector3.UP)
			global_transform.basis = global_transform.basis.slerp(target_basis, rotation_speed * delta)
	else:
		physics_body.velocity.x = move_toward(physics_body.velocity.x, 0, current_speed)
		physics_body.velocity.z = move_toward(physics_body.velocity.z, 0, current_speed)
		physics_body.move_and_slide()
		
		global_position = global_position.lerp(physics_body.global_position, 20.0 * delta)

	if is_moving:
		if walk_audio and not walk_audio.playing:
			walk_audio.play()
	else:
		if walk_audio and walk_audio.playing:
			walk_audio.stop()

	if anim_player and anim_player.has_animation("walk") and anim_player.current_animation != "walk":
		anim_player.play("walk")

func _check_for_obstacles_three_rays(forward_dir: Vector3) -> Vector3:
	var space_state = get_world_3d().direct_space_state
	if not space_state:
		return Vector3.ZERO
		
	var origin = physics_body.global_position + Vector3(0, 0.7, 0)
	
	var left_dir = forward_dir.rotated(Vector3.UP, deg_to_rad(40))
	var right_dir = forward_dir.rotated(Vector3.UP, deg_to_rad(-40))
	
	var dirs_to_check = [forward_dir, left_dir, right_dir]
	var accumulated_avoidance := Vector3.ZERO
	var obstacle_detected := false
	
	for dir in dirs_to_check:
		var target = origin + (dir * obstacle_avoidance_dist)
		var query = PhysicsRayQueryParameters3D.create(origin, target)
		
		query.exclude = [physics_body.get_rid(), hit_area.get_rid()]
		if _player:
			query.exclude.append(_player.get_rid())
			
		var result = space_state.intersect_ray(query)
		
		if not result.is_empty():
			obstacle_detected = true
			var wall_normal = result.normal
			var side_dir = dir.cross(Vector3.UP).normalized()
			if wall_normal.dot(side_dir) > 0:
				accumulated_avoidance += side_dir
			else:
				accumulated_avoidance -= side_dir
				
	if obstacle_detected:
		return accumulated_avoidance.normalized()
		
	return Vector3.ZERO

func _on_hit_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		call_deferred("_handle_player_hit")

func _handle_player_hit() -> void:
	hit_area.monitoring = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scene/start.tscn")
