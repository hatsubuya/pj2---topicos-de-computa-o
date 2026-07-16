extends CharacterBody3D
@onready var animation_lighter = $lighter/AnimationPlayer
@onready var lighter = $lighter
@onready var light = $OmniLight3D
@onready var camera = $Camera3D
@onready var inventory_ui = $InventoryUI
@onready var flashlight = $flashlight
@onready var click_sound = $click
@onready var walk_sound = $walk
const SPEED = 15.0
const RUN_SPEED = 30.0
const JUMP_VELOCITY = 4.5
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var mouse_sens = 0.003
var is_on = false
var looping = false
var inventory_open = false
func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	lighter.visible = false
	light.visible = false
	flashlight.visible = false
	if inventory_ui:
		inventory_ui.visible = false
	var global = flashlight.global_transform
	flashlight.get_parent().remove_child(flashlight)
	camera.add_child(flashlight)
	flashlight.global_transform = global
func _hide_all_items():
	lighter.visible = false
	light.visible = false
	is_on = false
	looping = false
	flashlight.visible = false
func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if inventory_open:
			_close_inventory()
		else:
			_open_inventory()
		return
	if inventory_open:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		var selected_name = ""
		if not inventory_ui.items.is_empty():
			selected_name = inventory_ui.items[inventory_ui.current_index].get("name", "")
		if selected_name == "Lighter":
			if not is_on:
				is_on = true
				looping = false
				lighter.visible = true
				light.visible = true
				animation_lighter.play("Take 001")
				animation_lighter.seek(0.0, true)
			else:
				is_on = false
				looping = false
				animation_lighter.play("Take 001")
				animation_lighter.seek(8.0, true)
				lighter.visible = false
				light.visible = false
		elif selected_name == "Flashlight":
			flashlight.visible = not flashlight.visible
			click_sound.play()
	if event is InputEventMouseButton:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sens)
		camera.rotate_x(-event.relative.y * mouse_sens)
		camera.rotation.x = clamp(
			camera.rotation.x,
			deg_to_rad(-80),
			deg_to_rad(80)
		)
func _process(delta):
	if inventory_open:
		return
	if is_on and not looping:
		var t = animation_lighter.current_animation_position
		if t >= 8.0:
			looping = true
	if looping:
		var t = animation_lighter.current_animation_position
		if t > 8.0:
			animation_lighter.seek(5.0, true)
func _physics_process(delta):
	if inventory_open:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_key_pressed(KEY_A):
		input_dir.x = -1
	if Input.is_key_pressed(KEY_D):
		input_dir.x = 1
	if Input.is_key_pressed(KEY_W):
		input_dir.y = -1
	if Input.is_key_pressed(KEY_S):
		input_dir.y = 1
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var current_speed = RUN_SPEED if Input.is_action_pressed("run") else SPEED
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
		if not walk_sound.playing:
			walk_sound.play()
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
		if walk_sound.playing:
			walk_sound.stop()
	move_and_slide()
func _open_inventory():
	inventory_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if inventory_ui:
		inventory_ui.visible = true
		inventory_ui.open()
func _close_inventory():
	inventory_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if inventory_ui:
		inventory_ui.close()
func on_inventory_closed():
	inventory_ui.visible = false
