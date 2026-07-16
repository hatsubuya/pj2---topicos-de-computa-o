extends Area3D
class_name node_3dww

@export var target_scene: String = "res://Scene/start.tscn" 
@export var prompt_text: String = "Pressione E para interagir"

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.set_current_interactable(self)

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.clear_current_interactable(self)

func interact() -> void:
	if target_scene != "":
		get_tree().change_scene_to_file(target_scene)
