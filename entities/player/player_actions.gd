class_name PlayerActions
extends Node

signal item_consumed(item: ConsumableItem, remaining: int)
signal item_equipped(item: ConsumableItem, count: int)
signal forced_urination_started()
signal forced_urination_ended()
signal inhale_started(vape_item: ConsumableItem)
signal inhale_progress(progress_pct: float, in_sweet_spot: bool)
signal inhale_finished(outcome: String, hold_time: float)
signal player_coughed()

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
var is_forced_pissing: bool = false

# Hold-based Inhalation State
var is_inhaling: bool = false
var inhale_timer: float = 0.0
var current_vape: ConsumableItem = null
var chain_vape_buildup: float = 0.0


func _ready() -> void:
	for item in starting_items:
		if item:
			inventory.append(item.duplicate()) # Unique instance to track charges
	if not inventory.is_empty():
		active_item_index = 0


func _process(delta: float) -> void:
	if item_cooldown_timer > 0.0:
		item_cooldown_timer -= delta

	# Постепенное снижение насыщения лёгких (восстановление от частых затяжек)
	if chain_vape_buildup > 0.0:
		chain_vape_buildup = maxf(0.0, chain_vape_buildup - delta * 0.33)

	_handle_inhalation_tick(delta)
	_handle_piss_tick(delta)


func _unhandled_input(event: InputEvent) -> void:
	# Quick-slot hotkeys
	if event.is_action_pressed("action_slot_1"):
		select_item(0)
	elif event.is_action_pressed("action_slot_2"):
		select_item(1)

	# Использование предмета: для вейпа — зажатие (inhalation), для еды — одиночный клик
	if event.is_action_pressed("action_use_held"):
		var item: ConsumableItem = get_active_item()
		if item and item.is_hold_based:
			start_inhaling()
		else:
			use_active_item()
	elif event.is_action_released("action_use_held"):
		if is_inhaling:
			release_inhalation()

	# Toggle/Hold Piss
	if event.is_action_pressed("action_piss"):
		start_pissing()
	elif event.is_action_released("action_piss"):
		stop_pissing()


func get_active_item() -> ConsumableItem:
	if active_item_index >= 0 and active_item_index < inventory.size():
		return inventory[active_item_index]
	return null


func select_item(index: int) -> void:
	if is_inhaling:
		is_inhaling = false
		current_vape = null
		inhale_finished.emit("cancelled", inhale_timer)

	if index >= 0 and index < inventory.size():
		active_item_index = index
		var item: ConsumableItem = inventory[active_item_index]
		item_equipped.emit(item, item.max_charges if item.is_single_use else -1)
	elif inventory.is_empty():
		active_item_index = -1
		item_equipped.emit(null, 0)


func start_inhaling() -> void:
	if item_cooldown_timer > 0.0 or is_inhaling:
		return
	var item: ConsumableItem = get_active_item()
	if not item or not item.is_hold_based:
		return

	is_inhaling = true
	inhale_timer = 0.0
	current_vape = item
	inhale_started.emit(current_vape)


func _handle_inhalation_tick(delta: float) -> void:
	if not is_inhaling or not current_vape:
		return

	inhale_timer += delta
	var max_time: float = maxf(current_vape.max_hold_time, 0.1)
	var progress_pct: float = inhale_timer / max_time

	var in_sweet_spot: bool = inhale_timer >= current_vape.sweet_spot_start and inhale_timer <= (current_vape.sweet_spot_start + current_vape.sweet_spot_duration)

	# Передержка: удержание дольше максимума вызывает кашель!
	if inhale_timer >= max_time:
		trigger_vape_cough(false)
		return

	inhale_progress.emit(progress_pct, in_sweet_spot)


func release_inhalation() -> void:
	if not is_inhaling or not current_vape:
		return

	var vape: ConsumableItem = current_vape
	var hold_time: float = inhale_timer
	is_inhaling = false
	current_vape = null

	var in_sweet_spot: bool = hold_time >= vape.sweet_spot_start and hold_time <= (vape.sweet_spot_start + vape.sweet_spot_duration)

	# Накопление перепотребления (chain vaping)
	chain_vape_buildup += 1.0
	if chain_vape_buildup >= 3.0:
		trigger_vape_cough(true)
		return

	var outcome: String = "weak"
	var stat_gain: float = 0.0
	var smoke_scale: float = vape.min_smoke_scale
	var smoke_amount_mult: float = 0.5

	if in_sweet_spot:
		outcome = "perfect"
		# Идеальная затяжка: полный стат + бонус за точность
		stat_gain = vape.stat_delta + 5.0
		smoke_scale = vape.max_smoke_scale
		smoke_amount_mult = 1.6
	else:
		outcome = "weak"
		# Слишком короткая затяжка: частичный прирост и мелкий дым
		var ratio: float = clampf(hold_time / maxf(vape.sweet_spot_start, 0.1), 0.1, 0.85)
		stat_gain = vape.stat_delta * 0.5 * ratio
		smoke_scale = lerpf(vape.min_smoke_scale, 1.0, ratio)
		smoke_amount_mult = lerpf(0.4, 0.9, ratio)

	# Применение эффекта
	if needs_manager:
		needs_manager.modify_need(vape.target_need, stat_gain)

	item_cooldown_timer = vape.cooldown_seconds
	_trigger_smoke_puff(smoke_scale, smoke_amount_mult, false)
	inhale_finished.emit(outcome, hold_time)


func trigger_vape_cough(is_chain_overconsume: bool = false) -> void:
	var vape: ConsumableItem = current_vape if current_vape else get_active_item()
	var penalty: float = vape.cough_penalty_dopamine if vape else 15.0
	var hold_time: float = inhale_timer

	is_inhaling = false
	current_vape = null

	# Штраф к дофамину за передержку или чрезмерное употребление
	if needs_manager:
		needs_manager.modify_need("dopamine", -penalty)

	# Увеличенный кулдаун после кашля
	item_cooldown_timer = (vape.cooldown_seconds if vape else 1.5) * 2.0

	# Кашляющий хлопок дыма
	_trigger_smoke_puff(1.2, 0.7, true)

	player_coughed.emit()
	inhale_finished.emit("cough", hold_time)


func use_active_item() -> void:
	if active_item_index < 0 or active_item_index >= inventory.size():
		return
	if item_cooldown_timer > 0.0:
		return

	var current_item: ConsumableItem = inventory[active_item_index]

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
			if not inventory.is_empty():
				active_item_index = clampi(active_item_index, 0, inventory.size() - 1)
				select_item(active_item_index)
			else:
				active_item_index = -1
				item_equipped.emit(null, 0)
	else:
		# Emit signal for reusable items
		item_consumed.emit(current_item, -1)


func _trigger_smoke_puff(smoke_scale: float = 1.0, amount_mult: float = 1.0, is_cough: bool = false) -> void:
	if not smoke_scene:
		push_warning("PlayerActions: No smoke_scene assigned.")
		return

	var cloud: GPUParticles3D = smoke_scene.instantiate() as GPUParticles3D
	if not cloud:
		return

	if cloud.has_method("setup_puff"):
		cloud.setup_puff(smoke_scale, amount_mult, is_cough)

	if smoke_spawn_point:
		cloud.global_transform = smoke_spawn_point.global_transform
	else:
		# Fallback: query parent Player (CharacterBody3D) position safely
		var parent_3d := get_parent() as Node3D
		if parent_3d:
			cloud.global_position = parent_3d.global_position + Vector3(0, 1.4, 0)

	var target_parent: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root
	if target_parent:
		target_parent.add_child(cloud)


func trigger_involuntary_urination() -> void:
	if is_forced_pissing:
		return
	is_forced_pissing = true
	forced_urination_started.emit()
	start_pissing()
	# Humiliation penalty on self-wetting
	if needs_manager:
		needs_manager.modify_need("dopamine", -30.0)


func start_pissing() -> void:
	var current_bladder: float = needs_manager.values.get("bladder", 0.0)
	if current_bladder <= 1.0 and not is_forced_pissing:
		return
	
	is_pissing = true
	if piss_particles:
		piss_particles.emitting = true


func stop_pissing() -> void:
	if is_forced_pissing:
		return # Cannot voluntarily hold back forced incontinence!
	is_pissing = false
	if piss_particles:
		piss_particles.emitting = false


func _handle_piss_tick(delta: float) -> void:
	if not is_pissing:
		return

	var current_bladder: float = needs_manager.values.get("bladder", 0.0)
	# Forced urination ends once bladder drops down to 50%
	if is_forced_pissing and current_bladder <= 50.0:
		is_forced_pissing = false
		forced_urination_ended.emit()
		stop_pissing()
		return

	if current_bladder <= 0.0:
		if is_forced_pissing:
			is_forced_pissing = false
			forced_urination_ended.emit()
		stop_pissing()
		return

	# Drain bladder
	var drain_amount: float = bladder_drain_per_sec * delta
	needs_manager.modify_need("bladder", -drain_amount)
	# Only grant dopamine relief kick when voluntarily relieving pressure, not when wetting oneself
	if not is_forced_pissing:
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
