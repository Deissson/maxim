class_name Interactable
extends Area3D

## Override this property in inherited scenes/scripts or in the Inspector
@export var prompt_message: String = "Interact"


func _ready() -> void:
	# Ensure the area is placed on Layer 3 (Interactable) and masks nothing
	collision_layer = 4 # Layer 3 (1 << 2)
	collision_mask = 0


## Virtual method: Call this from the player when pressing 'E'
func interact(_player: CharacterBody3D) -> void:
	pass


## Virtual method: Customize prompt text dynamically (e.g. "Open Door" vs "Close Door")
func get_prompt() -> String:
	return prompt_message
