class_name PlayerActions
extends Node

signal item_consumed(item: ConsumableItem, remaining: int)

@export var needs_manager: NeedsManager
@export var piss_particles: GPUParticles3D
@export var bladder_drain_per_sec: float = 25.0
@export var dopamine_per_sec_relief: float = 5.0
@export var smoke_scene: PackedScene
@export var smoke_spawn_point: Node3D

## Quick slots for items
@export var starting_items: Array[ConsumableItem] = []

var inventory: Array[ConsumableItem] = []
var active_item_index: int = -1
var item_cooldown_timer: float = 0.0
var is_pissing: bool = false


func _ready() -> void:
	for item in starting_items:
		if item:
			inventory.append(item.duplicate()) # Unique instance to track charges
	if not inventory.is_empty():
		active_item_index = 0


func _process(delta: float) -> void:
	if item_cooldown_timer > 0.0:
		item_cooldown_timer -= delta

	_handle_piss_tick(delta)


func _unhandled_input(event: InputEvent) -> void:
	# Quick-slot hotkeys
	if event.is_action_pressed("action_slot_1"):
		select_item(0)
	elif event.is_action_pressed("action_slot_2"):
		select_item(1)

	# Use active item (Vape or Food)
	if event.is_action_pressed("action_use_held"):
		use_active_item()

	# Toggle/Hold Piss
	if event.is_action_pressed("action_piss"):
		start_pissing()
	elif event.is_action_released("action_piss"):
		stop_pissing()

signal item_equipped(item: ConsumableItem, count: int)

func select_item(index: int) -> void:
	if index >= 0 and index < inventory.size():
		active_item_index = index
		var item: ConsumableItem = inventory[active_item_index]
		item_equipped.emit(item, item.max_charges if item.is_single_use else -1)
	elif inventory.is_empty():
		active_item_index = -1
		item_equipped.emit(null, 0)


func use_active_item() -> void:
	if active_item_index < 0 or active_item_index >= inventory.size():
		return
	if item_cooldown_timer > 0.0:
		return

	var current_item: ConsumableItem = inventory[active_item_index]

	# Emit smoke cloud if using the vape
	if current_item.item_name.to_lower().contains("vape"):
		_trigger_smoke_puff()

	# Apply stat gain
	needs_manager.modify_need(current_item.target_need, current_item.stat_delta)
	item_cooldown_timer = current_item.cooldown_seconds

	if current_item.is_single_use:
		current_item.max_charges -= 1
		var remaining: int = current_item.max_charges
		
		# Emit signal for single-use item
		item_consumed.emit(current_item, remaining)

		if current_item.max_charges <= 0:
			inventory.remove_at(active_item_index)
			active_item_index = 0 if not inventory.is_empty() else -1
	else:
		# Emit signal for reusable items (like vape, remaining is infinite / -1)
		item_consumed.emit(current_item, -1)



func _trigger_smoke_puff() -> void:
	if not smoke_scene:
		push_warning("PlayerActions: No smoke_scene assigned.")
		return

	var cloud: GPUParticles3D = smoke_scene.instantiate() as GPUParticles3D
	if not cloud:
		return

	get_tree().current_scene.add_child(cloud)

	if smoke_spawn_point:
		cloud.global_transform = smoke_spawn_point.global_transform
	else:
		# Fallback: query parent Player (CharacterBody3D) position safely
		var parent_3d := get_parent() as Node3D
		if parent_3d:
			cloud.global_position = parent_3d.global_position + Vector3(0, 1.4, 0)


func start_pissing() -> void:
	var current_bladder: float = needs_manager.values.get("bladder", 0.0)
	if current_bladder <= 1.0:
		return
	
	is_pissing = true
	if piss_particles:
		piss_particles.emitting = true


func stop_pissing() -> void:
	is_pissing = false
	if piss_particles:
		piss_particles.emitting = false


func _handle_piss_tick(delta: float) -> void:
	if not is_pissing:
		return

	var current_bladder: float = needs_manager.values.get("bladder", 0.0)
	if current_bladder <= 0.0:
		stop_pissing()
		return

	# Drain bladder and grant a dopamine kick for relieving pressure
	var drain_amount: float = bladder_drain_per_sec * delta
	needs_manager.modify_need("bladder", -drain_amount)
	needs_manager.modify_need("dopamine", dopamine_per_sec_relief * delta)


## Public API to pick up items from world interactables
func acquire_item(new_item: ConsumableItem) -> void:
	var copy: ConsumableItem = new_item.duplicate()
	inventory.append(copy)
	if active_item_index == -1:
		select_item(0)
	else:
		# Refresh UI if it's the current item
		var current: ConsumableItem = inventory[active_item_index]
		item_equipped.emit(current, current.max_charges if current.is_single_use else -1)
