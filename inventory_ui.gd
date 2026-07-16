extends CanvasLayer

var items: Array = [
	{
		"name": "Lighter",
		"desc": "A cheap metal lighter.\nThe wheel is stiff from years of use.",
		"scene": "res://lighter.tscn"
	}
]

var current_index: int = 0

@onready var item_name_label = $Control/Panel/ItemName
@onready var item_desc_label = $Control/Panel/ItemDesc
@onready var item_viewport = $Control/Panel/SubViewportContainer/SubViewport
@onready var item_mesh = $Control/Panel/SubViewportContainer/SubViewport/ItemMesh
@onready var dots_container = $Control/Panel/DotsContainer
@onready var bg_panel = $Control/Panel
@onready var player = get_parent()

var dot_nodes: Array = []
var rotation_speed: float = 60.0
var is_open: bool = false

func _ready():
	visible = false
	$Control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$Control/Panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	item_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_build_dots()

func open():
	is_open = true
	visible = true
	_show_item(current_index)

func close():
	is_open = false
	visible = false
	if player and player.has_method("on_inventory_closed"):
		player.on_inventory_closed()

func add_item(item: Dictionary):
	items.append(item)
	_build_dots()
	if items.size() == 1:
		current_index = 0
	if is_open:
		_show_item(current_index)

func remove_item(index: int):
	if index >= 0 and index < items.size():
		items.remove_at(index)
		current_index = clamp(current_index, 0, max(items.size() - 1, 0))
		_build_dots()
		_show_item(current_index)

func _input(event):
	if not is_open or items.is_empty():
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_A or event.keycode == KEY_LEFT:
			_navigate(-1)
		elif event.keycode == KEY_D or event.keycode == KEY_RIGHT:
			_navigate(1)

func _navigate(direction: int):
	if items.is_empty():
		return
	if player and player.has_method("_hide_all_items"):
		player._hide_all_items()
	current_index = (current_index + direction + items.size()) % items.size()
	_show_item(current_index)

func _show_item(index: int):
	for child in item_mesh.get_children():
		child.queue_free()
	if items.is_empty():
		item_name_label.text = "EMPTY"
		item_desc_label.text = "There are no items in your inventory."
		_update_dots(-1)
		return
	var item = items[index]
	item_name_label.text = item.get("name", "???").to_upper()
	item_desc_label.text = item.get("desc", "")
	_update_dots(index)
	var scene_path = item.get("scene", "")
	if scene_path == "":
		return
	if not ResourceLoader.exists(scene_path):
		push_error("Cena não encontrada: " + scene_path)
		return
	var obj = load(scene_path).instantiate()
	item_mesh.add_child(obj)
	if obj is Node3D:
		obj.position = Vector3.ZERO
		obj.rotation = Vector3.ZERO
		obj.scale = Vector3.ONE
		obj.visible = true
	_apply_unshaded_material(obj)

func _apply_unshaded_material(node: Node):
	if node is MeshInstance3D:
		var mat = node.get_active_material(0)
		if not mat:
			mat = StandardMaterial3D.new()
		var unique_mat = mat.duplicate()
		if unique_mat is StandardMaterial3D:
			unique_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			node.material_override = unique_mat
	for child in node.get_children():
		_apply_unshaded_material(child)

func _process(delta):
	if not is_open or items.is_empty():
		return
	if item_mesh and is_instance_valid(item_mesh):
		item_mesh.rotate_y(deg_to_rad(rotation_speed * delta))

func _build_dots():
	for dot in dot_nodes:
		dot.queue_free()
	dot_nodes.clear()
	for i in items.size():
		var dot = ColorRect.new()
		dot.custom_minimum_size = Vector2(10, 10)
		dots_container.add_child(dot)
		dot_nodes.append(dot)
	_update_dots(current_index)

func _update_dots(active: int):
	for i in dot_nodes.size():
		if i == active:
			dot_nodes[i].color = Color(0.9, 0.7, 0.3)
		else:
			dot_nodes[i].color = Color(0.2, 0.16, 0.1)
