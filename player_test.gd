extends CharacterBody3D

const SPEED = 5.0
const SPRINT_SPEED = 8.0
const CROUCH_SPEED = 2.5
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.003
const CROUCH_HEIGHT_OFFSET = -0.5
const KEY_ROTATION_SPEED = 1.5 

@onready var camera: Camera3D = $Camera3D
@onready var gun = $Camera3D/gun
@onready var shooter_kit = $Camera3D/ShooterKit3D
@onready var pause_menu = preload("res://pause_menu.tscn").instantiate()
@onready var inventory_ui = $InventoryUI
@onready var animation_lighter = $lighter/AnimationPlayer
@onready var lighter = $lighter
@onready var light = $OmniLight3D
@onready var flashlight = $flashlight
@onready var click_sound = $click
@onready var walk_sound = $walk

var camera_base_y: float
var current_interactable: Area3D = null
var interact_label: Label
var instruction_label: Label 
var inventory_open := false
var lock_active := false
var _jump_requested := false
var is_on := false
var looping := false
var gun_base_position: Vector3
var gun_base_rotation: Vector3

var minimap_container: SubViewportContainer
var minimap_viewport: SubViewport
var minimap_camera: Camera3D
var player_marker: ColorRect

var stamina_bar: ProgressBar
var max_stamina := 100.0
var current_stamina := 100.0
var stamina_drain := 30.0 
var stamina_regen := 20.0 
var stamina_exhausted := false 

var lightning_container: HBoxContainer

const RECOIL_KICK_Z := 0.06
const RECOIL_KICK_ROTATION_X := 0.05
const RECOIL_RECOVERY_SPEED := 8.0
var muzzle_light: OmniLight3D
var muzzle_flash_timer := 0.0
const MUZZLE_FLASH_DURATION := 0.05
const MUZZLE_FLASH_ENERGY := 8.0
const MUZZLE_FLASH_RANGE := 3.0
const MUZZLE_LOCAL_OFFSET_Z := -1.5

const MAG_CAPACITY := 7
const CHAMBER_CAPACITY := 1
const AMMO_CAPACITY := MAG_CAPACITY + CHAMBER_CAPACITY
var current_ammo := AMMO_CAPACITY
var ammo_label: Label

var collected_lock_digits: Array = []
var lock_digits_label: Label

class LightningIcon extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(16, 22)

	func _draw() -> void:
		var points := PackedVector2Array([
			Vector2(10, 0),
			Vector2(2, 11),
			Vector2(7, 11),
			Vector2(4, 22),
			Vector2(14, 9),
			Vector2(9, 9)
		])
		var colors := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
		draw_polygon(points, colors)

func _ready() -> void:
	var xr_interface = XRServer.find_interface("MobileVR")
	if xr_interface and xr_interface.initialize():
		get_viewport().use_xr = true
		xr_interface.iod = 0.06
		xr_interface.display_to_lens_distance = 0.04
		xr_interface.display_width = 0.12

	add_to_group("player")
	get_tree().paused = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera_base_y = camera.position.y
	
	add_child(pause_menu)
	pause_menu.visible = false
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu.visibility_changed.connect(_on_pause_menu_visibility_changed)
	
	_build_interact_prompt()
	_build_ammo_label()
	_build_instruction_label()
	_build_minimap() 
	_build_stamina_bar() 
	_build_lightning_icons()
	_build_lock_digits_label()
	collected_lock_digits = GameState.collected_lock_digits.duplicate()
	_update_lock_digits_label()
	
	if inventory_ui:
		inventory_ui.visible = false
	_hide_all_items()
	
	gun_base_position = gun.position
	gun_base_rotation = gun.rotation
	shooter_kit.Shoot.connect(_on_gun_shoot)
	
	muzzle_light = OmniLight3D.new()
	gun.add_child(muzzle_light)
	muzzle_light.position = Vector3(5, 5, MUZZLE_LOCAL_OFFSET_Z)
	muzzle_light.light_color = Color(1.0, 0.75, 0.3)
	muzzle_light.omni_range = MUZZLE_FLASH_RANGE
	muzzle_light.light_energy = MUZZLE_FLASH_ENERGY
	muzzle_light.visible = false

func enter_lock_mode() -> void:
	lock_active = true
	if instruction_label:
		instruction_label.text = "Encontre a combinação do cadeado"

func exit_lock_mode() -> void:
	lock_active = false

func _build_lock_digits_label() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	lock_digits_label = Label.new()
	lock_digits_label.text = ""
	lock_digits_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	lock_digits_label.position = Vector2(-160, 20)
	layer.add_child(lock_digits_label)
	_update_lock_digits_label()

func _update_lock_digits_label() -> void:
	if collected_lock_digits.is_empty():
		lock_digits_label.text = ""
		return
	var parts: Array = []
	for d in collected_lock_digits:
		parts.append(str(d))
	lock_digits_label.text = "Combinação: " + " ".join(parts)

func collect_lock_digit(value: int) -> void:
	collected_lock_digits.append(value)
	GameState.collected_lock_digits = collected_lock_digits.duplicate()
	_update_lock_digits_label()

func _build_minimap() -> void:
	var map_size := Vector2(220, 220)
	var minimap_layer := CanvasLayer.new()
	add_child(minimap_layer)
	minimap_container = SubViewportContainer.new()
	minimap_container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	minimap_container.position = Vector2(20, -(map_size.y + 20)) 
	minimap_container.custom_minimum_size = map_size
	minimap_layer.add_child(minimap_container)
	minimap_viewport = SubViewport.new()
	minimap_viewport.size = map_size
	minimap_viewport.world_3d = get_viewport().world_3d 
	minimap_container.add_child(minimap_viewport)
	minimap_camera = Camera3D.new()
	minimap_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	minimap_camera.size = 25.0
	minimap_camera.rotation_degrees = Vector3(-90, 0, 0)
	minimap_viewport.add_child(minimap_camera)
	var marker_overlay := CanvasLayer.new()
	add_child(marker_overlay)
	player_marker = ColorRect.new()
	player_marker.color = Color(1.0, 0.1, 0.1, 1.0)
	player_marker.custom_minimum_size = Vector2(10, 10)
	player_marker.set_anchors_preset(Control.PRESET_CENTER)
	player_marker.grow_horizontal = Control.GROW_DIRECTION_BOTH
	player_marker.grow_vertical = Control.GROW_DIRECTION_BOTH
	player_marker.position = minimap_container.position + (map_size / 2.0) - Vector2(5, 5)
	marker_overlay.add_child(player_marker)

func _build_stamina_bar() -> void:
	var stamina_layer := CanvasLayer.new()
	add_child(stamina_layer)
	stamina_bar = ProgressBar.new()
	stamina_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	stamina_bar.position = Vector2(20, -255)
	stamina_bar.custom_minimum_size = Vector2(220, 10)
	stamina_bar.show_percentage = false
	stamina_bar.max_value = max_stamina
	stamina_bar.value = current_stamina
	var style_bg := StyleBoxFlat.new()
	style_bg.bg_color = Color(0.1, 0.1, 0.1, 0.6) 
	style_bg.corner_detail = 1
	var style_fg := StyleBoxFlat.new()
	style_fg.bg_color = Color(1.0, 1.0, 1.0, 1.0) 
	style_fg.corner_detail = 1
	stamina_bar.add_theme_stylebox_override("background", style_bg)
	stamina_bar.add_theme_stylebox_override("fill", style_fg)
	stamina_layer.add_child(stamina_bar)

func _build_lightning_icons() -> void:
	var icons_layer := CanvasLayer.new()
	add_child(icons_layer)
	lightning_container = HBoxContainer.new()
	lightning_container.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	lightning_container.position = Vector2(20, -285)
	lightning_container.add_theme_constant_override("theme_override_constants/separation", 8)
	icons_layer.add_child(lightning_container)
	for i in range(3):
		var ray := LightningIcon.new()
		lightning_container.add_child(ray)

func _build_instruction_label() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	instruction_label = Label.new()
	instruction_label.text = "Investigue o local"
	instruction_label.visible = true
	instruction_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	instruction_label.position.y += 30
	var font_settings := LabelSettings.new()
	var custom_font := SystemFont.new()
	custom_font.font_names = PackedStringArray(["Sans-Serif", "Arial"])
	font_settings.font = custom_font
	font_settings.font_size = 24
	instruction_label.label_settings = font_settings
	layer.add_child(instruction_label)

func _update_instruction_visibility() -> void:
	if not instruction_label:
		return
	var should_show = not ((pause_menu and pause_menu.visible) or inventory_open)
	instruction_label.visible = should_show
	if minimap_container:
		minimap_container.visible = should_show
	if player_marker:
		player_marker.visible = should_show
	if stamina_bar:
		stamina_bar.visible = should_show
	if lightning_container:
		lightning_container.visible = should_show

func _build_ammo_label() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ammo_label = Label.new()
	ammo_label.text = ""
	ammo_label.visible = false
	ammo_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ammo_label.position = Vector2(-120, -60)
	layer.add_child(ammo_label)
	_update_ammo_label()

func _update_ammo_label() -> void:
	var chamber_ammo: int = clamp(current_ammo, 0, CHAMBER_CAPACITY)
	var mag_ammo: int = current_ammo - chamber_ammo
	ammo_label.text = "%d+%02d/00" % [chamber_ammo, mag_ammo]

func _hide_all_items() -> void:
	lighter.visible = false
	light.visible = false
	is_on = false
	looping = false
	flashlight.visible = false
	gun.visible = false
	shooter_kit.Enabled = false
	ammo_label.visible = false

func _on_gun_shoot() -> void:
	gun.position.z += RECOIL_KICK_Z
	gun.rotation.x -= RECOIL_KICK_ROTATION_X
	muzzle_light.visible = true
	muzzle_flash_timer = MUZZLE_FLASH_DURATION
	current_ammo = max(current_ammo - 1, 0)
	_update_ammo_label()
	if current_ammo <= 0:
		shooter_kit.Enabled = false

func _build_interact_prompt() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	interact_label = Label.new()
	interact_label.text = ""
	interact_label.visible = false
	interact_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	interact_label.position.y -= 80
	layer.add_child(interact_label)

func set_current_interactable(zone: Area3D) -> void:
	current_interactable = zone
	interact_label.text = zone.prompt_text
	interact_label.visible = true

func clear_current_interactable(zone: Area3D) -> void:
	if current_interactable == zone:
		current_interactable = null
		interact_label.visible = false

func _on_pause_menu_visibility_changed() -> void:
	get_tree().paused = pause_menu.visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if pause_menu.visible else Input.MOUSE_MODE_CAPTURED
	_update_instruction_visibility()

func _open_inventory() -> void:
	inventory_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if inventory_ui:
		inventory_ui.visible = true
		inventory_ui.open()
	_update_instruction_visibility()

func _close_inventory() -> void:
	inventory_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if inventory_ui:
		inventory_ui.close()
		inventory_ui.visible = false
	_update_instruction_visibility()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F11:
			if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-89), deg_to_rad(89))
		
	if lock_active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			pause_menu.visible = not pause_menu.visible
		elif event.physical_keycode == KEY_I and not get_tree().paused:
			if inventory_open:
				_close_inventory()
			else:
				_open_inventory()
		elif event.physical_keycode == KEY_F and not get_tree().paused and not inventory_open:
			_toggle_selected_item()
		elif event.physical_keycode == KEY_SPACE and not get_tree().paused and not inventory_open:
			_jump_requested = true
		elif event.physical_keycode == KEY_V and not get_tree().paused and not inventory_open:
			_attack()
		elif event.physical_keycode == KEY_E and not get_tree().paused and not inventory_open:
			if current_interactable:
				current_interactable.interact()

func _toggle_selected_item() -> void:
	var selected_name := ""
	if inventory_ui and not inventory_ui.items.is_empty():
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
	elif selected_name == "Gun":
		gun.visible = not gun.visible
		shooter_kit.Enabled = gun.visible and current_ammo > 0
		ammo_label.visible = gun.visible
		_update_ammo_label()

func _attack() -> void:
	pass

func _process(delta: float) -> void:
	if inventory_open:
		return
	var rot_dir = 0.0
	if Input.is_physical_key_pressed(KEY_LEFT):
		rot_dir += 1.0
	if Input.is_physical_key_pressed(KEY_RIGHT):
		rot_dir -= 1.0
	if rot_dir != 0.0:
		rotate_y(rot_dir * KEY_ROTATION_SPEED * delta)

	if is_on and not looping:
		var t = animation_lighter.current_animation_position
		if t >= 8.0:
			looping = true
	if looping:
		var t = animation_lighter.current_animation_position
		if t > 8.0:
			animation_lighter.seek(5.0, true)
	gun.position = gun.position.lerp(gun_base_position, RECOIL_RECOVERY_SPEED * delta)
	gun.rotation.x = lerp(gun.rotation.x, gun_base_rotation.x, RECOIL_RECOVERY_SPEED * delta)
	if muzzle_flash_timer > 0.0:
		muzzle_flash_timer -= delta
		if muzzle_flash_timer <= 0.0:
			muzzle_light.visible = false
	if gun.visible and current_ammo <= 0 and shooter_kit.FireInput != "":
		if Input.is_action_just_pressed(shooter_kit.FireInput):
			click_sound.play()

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	if inventory_open:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	if lock_active:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	if not is_on_floor():
		velocity += get_gravity() * delta
	if _jump_requested and is_on_floor():
		velocity.y = JUMP_VELOCITY
	_jump_requested = false
	
	var input_dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		input_dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S):
		input_dir.y += 1
	if Input.is_physical_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D):
		input_dir.x += 1
	input_dir = input_dir.normalized()
	
	var is_moving := input_dir != Vector2.ZERO
	var crouching := Input.is_physical_key_pressed(KEY_CTRL)
	var shift_pressed := Input.is_physical_key_pressed(KEY_SHIFT)
	var sprinting := shift_pressed and is_moving and not crouching and not stamina_exhausted
	
	if sprinting:
		current_stamina -= stamina_drain * delta
		if current_stamina <= 0.0:
			current_stamina = 0.0
			stamina_exhausted = true 
	else:
		current_stamina += stamina_regen * delta
		if current_stamina >= max_stamina:
			current_stamina = max_stamina
		if stamina_exhausted and current_stamina >= 20.0:
			stamina_exhausted = false
			
	if stamina_bar:
		stamina_bar.value = current_stamina
	
	var current_speed := SPEED
	if crouching:
		current_speed = CROUCH_SPEED
	elif sprinting:
		current_speed = SPRINT_SPEED
		
	camera.position.y = camera_base_y + (CROUCH_HEIGHT_OFFSET if crouching else 0.0)
	
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
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
	
	if minimap_camera:
		minimap_camera.global_position = global_position + Vector3(0, 15.0, 0)
