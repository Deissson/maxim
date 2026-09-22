class_name PickupItem
extends Interactable

@export var item_data: ConsumableItem
@export var rotation_speed: float = 2.0
@export var bobbing_speed: float = 3.0
@export var bobbing_height: float = 0.05

@onready var visual_root: Node3D = get_node_or_null("VisualRoot")

var _initial_y: float = 0.0
var _time_elapsed: float = 0.0


func _ready() -> void:
	if visual_root:
		_initial_y = visual_root.position.y


func _process(delta: float) -> void:
	if visual_root:
		# Spin
		visual_root.rotate_y(rotation_speed * delta)
		# Subtle vertical bobbing
		_time_elapsed += delta * bobbing_speed
		visual_root.position.y = _initial_y + sin(_time_elapsed) * bobbing_height


func get_prompt() -> String:
	if item_data:
		return "Take %s" % item_data.item_name
	return "Take Item"


func interact(player: CharacterBody3D) -> void:
	if not item_data:
		return

	# Disable collision immediately so the raycast stops detecting it this exact frame
	collision_layer = 0
	set_deferred("monitoring", false)

	var actions: PlayerActions = player.get_node_or_null("PlayerActions")
	if actions:
		actions.acquire_item(item_data)

	queue_free()
