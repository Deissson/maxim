class_name Door
extends Interactable

@export var is_open: bool = false
@export var open_rotation_deg: float = 90.0

@onready var hinge: Node3D = $Hinge

var _tween: Tween


func get_prompt() -> String:
	return "Close Door" if is_open else "Open Door"


func interact(_player: CharacterBody3D) -> void:
	print("Door interact called! Current state: ", is_open)
	is_open = not is_open
	var target_deg: float = open_rotation_deg if is_open else 0.0
	print("Target degrees: ", target_deg, " Hinge node: ", hinge)

	if not hinge:
		push_error("Hinge node not found on Door!")
		return

	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(hinge, "rotation_degrees:y", target_deg, 0.4)
