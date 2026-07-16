extends InteractionZone
class_name LockPuzzle

signal Solved

@onready var l1: Node3D = find_child("l1", true, false)
@onready var l2: Node3D = find_child("l2", true, false)
@onready var l3: Node3D = find_child("l3", true, false)
@onready var l4: Node3D = find_child("l4", true, false)

@onready var lock_camera: Camera3D = find_child("Camera3D", true, false)

const CORRECT_CODE := [1, 7, 2, 6]
const INITIAL_DIGITS := [1, 2, 3, 4]
const ROTATION_STEP_DEG := 36.0
const OPEN_DROP_OFFSET := Vector3(0, -0.3, 0)
const OPEN_SPEED := 4.0

var cylinders: Array
var current_digits := INITIAL_DIGITS.duplicate()
var selected_index := 0
var lock_mode_active := false
var solved := false
var opening := false
var base_position: Vector3
var player_ref: CharacterBody3D = null

var _previous_camera: Camera3D = null
var _frame_activated := -1

func _ready() -> void:
	super._ready()
	cylinders = [l1, l2, l3, l4]
	base_position = position
	print("[LockPuzzle] _ready() -> l1:", l1, " l2:", l2, " l3:", l3, " l4:", l4)
	
	if lock_camera:

		await get_tree().process_frame
		lock_camera.current = false
	else:
		push_warning("[LockPuzzle] Nenhuma Camera3D foi encontrada como filha de " + name + ". Adicione uma para focar no cadeado!")

func _on_body_entered(body: Node3D) -> void:
	super._on_body_entered(body)
	if body.is_in_group("player"):
		player_ref = body
		print("[LockPuzzle] player_ref definido: ", player_ref)

func _on_body_exited(body: Node3D) -> void:
	super._on_body_exited(body)
	if body.is_in_group("player"):
		if lock_mode_active:
			_exit_lock_mode()
		player_ref = null

func interact() -> void:
	print("[LockPuzzle] interact() chamado. solved=", solved, " lock_mode_active=", lock_mode_active)
	if solved:
		return
	if not lock_mode_active:
		_enter_lock_mode()

func _enter_lock_mode() -> void:
	lock_mode_active = true
	_frame_activated = Engine.get_process_frames() 
	selected_index = 0
	
	_previous_camera = get_viewport().get_camera_3d()
	
	if lock_camera:
		lock_camera.make_current()
		
	print("[LockPuzzle] Entrando no modo de trava. player_ref=", player_ref)
	if player_ref:
		player_ref.enter_lock_mode()

func _exit_lock_mode() -> void:
	lock_mode_active = false
	
	if _previous_camera and is_instance_valid(_previous_camera):
		_previous_camera.make_current()
	
	if lock_camera:
		lock_camera.current = false
		
	print("[LockPuzzle] Saindo do modo de trava.")
	if player_ref:
		player_ref.exit_lock_mode()

func _input(event: InputEvent) -> void:
	if not lock_mode_active:
		return
		
	if Engine.get_process_frames() == _frame_activated:
		return
		
	print("[LockPuzzle] _input recebido: ", event)
	if event is InputEventKey and event.pressed and not event.echo:
		print("[LockPuzzle] Tecla fisica pressionada: ", event.physical_keycode)
		match event.physical_keycode:
			KEY_ESCAPE, KEY_E:
				get_viewport().set_input_as_handled() # Consome o input para não reativar o E
				_exit_lock_mode()
			KEY_UP:
				get_viewport().set_input_as_handled()
				selected_index = (selected_index - 1 + 4) % 4
				print("[LockPuzzle] selected_index = ", selected_index, " (subiu na coluna)")
			KEY_DOWN:
				get_viewport().set_input_as_handled()
				selected_index = (selected_index + 1) % 4
				print("[LockPuzzle] selected_index = ", selected_index, " (desceu na coluna)")
			KEY_LEFT:
				get_viewport().set_input_as_handled()
				_rotate_digit(selected_index, -1)
			KEY_RIGHT:
				get_viewport().set_input_as_handled()
				_rotate_digit(selected_index, 1)

func _rotate_digit(index: int, direction: int) -> void:
	current_digits[index] = (current_digits[index] - direction + 10) % 10
	
	cylinders[index].rotation.z += deg_to_rad(ROTATION_STEP_DEG * direction)
	
	print("[LockPuzzle] Girando cilindro ", index, " -> digito:", current_digits[index], " rotation.z:", cylinders[index].rotation.z)
	_check_code()

func _check_code() -> void:
	print("[LockPuzzle] Codigo atual: ", current_digits, " esperado: ", CORRECT_CODE)
	if current_digits == CORRECT_CODE:
		_on_solved()

func _on_solved() -> void:
	solved = true
	_exit_lock_mode()
	monitoring = false
	monitorable = false
	opening = true
	Solved.emit()
	print("[LockPuzzle] RESOLVIDO!")
	get_tree().change_scene_to_file("res://stage1.tscn")

func _process(delta: float) -> void:
	if opening:
		position = position.lerp(base_position + OPEN_DROP_OFFSET, OPEN_SPEED * delta)
