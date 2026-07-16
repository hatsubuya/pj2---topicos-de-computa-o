extends CharacterBody3D
const SPEED = 3.5
const DETECTION_RADIUS = 20.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var player = null
func _ready():
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
	if not player:
		return
	var dist = global_position.distance_to(player.global_position)
	if dist < DETECTION_RADIUS:
		var dir = (player.global_position - global_position)
		dir.y = 0
		dir = dir.normalized()
		velocity.x = dir.x * SPEED
		velocity.z = dir.z * SPEED
		if dir != Vector3.ZERO:
			rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 0.1)
		if dist < 4.5:
			set_physics_process(false)
			get_tree().change_scene_to_file("res://main.tscn")
	else:
		velocity.x = 0
		velocity.z = 0
	move_and_slide()
