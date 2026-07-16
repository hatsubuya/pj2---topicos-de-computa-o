extends Area3D
var player_inside = false
@onready var label = $Label3D
func _ready():
	label.visible = false
	connect("body_entered", _on_body_entered)
	connect("body_exited", _on_body_exited)
func _on_body_entered(body):
	if body is CharacterBody3D:
		player_inside = true
		label.visible = true
func _on_body_exited(body):
	if body is CharacterBody3D:
		player_inside = false
		label.visible = false
func _input(event):
	if player_inside and event is InputEventKey and event.pressed and event.keycode == KEY_E:
		var player = get_tree().get_first_node_in_group("player")
		player.inventory_ui.add_item({
			"name": "Gun",
			"desc": "A handgun with a few rounds left.",
			"scene": "res://assets/gun.tscn"
		})
		queue_free()
