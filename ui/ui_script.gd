class_name HUD
extends CanvasLayer

@onready var dopamine_bar: ProgressBar = $Bars/VBoxContainer/DopamineBar
@onready var hunger_bar: ProgressBar = $Bars/VBoxContainer/HungerBar
@onready var piss_bar: ProgressBar = $Bars/VBoxContainer/PissBar
@onready var interaction_prompt: Label = $CenterContainer/InteractionPrompt
@onready var item_display_label: Label = $MarginContainer/ItemDisplay
@onready var crosshair: ColorRect = $Crosshair 
@onready var stamina_bar: ProgressBar = $StaminaBar 
@onready var vignette: ColorRect = $Vignette 
@onready var inhale_bar: Control = get_node_or_null("InhaleBar")
@onready var inhale_sweet_spot: ColorRect = get_node_or_null("InhaleBar/SweetSpot")
@onready var inhale_progress_fill: ColorRect = get_node_or_null("InhaleBar/ProgressFill")

var _stamina_tween: Tween
var _crosshair_tween: Tween	
var _vignette_tween: Tween
var _inhale_tween: Tween

var is_starving: bool = false
var is_depressed: bool = false
var is_bladder_critical: bool = false
var _bladder_flash_timer: float = 0.0
var _current_crosshair_highlight: bool = false

func update_stamina(value: float, max_value: float) -> void:
	if not stamina_bar:
		return

	stamina_bar.max_value = max_value
	stamina_bar.value = value

	# Если стамина потрачена (хотя бы немного) — показываем
	if value < max_value:
		_fade_stamina_bar(1.0)
	else:
		# Если полностью полная — скрываем
		_fade_stamina_bar(0.0)

func set_exhausted_vignette(is_exhausted: bool) -> void:
	if not vignette or not vignette.material:
		return

	var mat: ShaderMaterial = vignette.material as ShaderMaterial
	if not mat:
		return

	if _vignette_tween and _vignette_tween.is_valid():
		_vignette_tween.kill()

	# Обычная мягкая виньетка: интенсивность 0.45, при истощении сгущается до 0.9
	var target_intensity: float = 0.9 if is_exhausted else 0.35

	_vignette_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_vignette_tween.tween_property(mat, "shader_parameter/intensity", target_intensity, 0.8)


func update_consequences(delta: float, starving: bool, depressed: bool, bladder_val: float, max_bladder: float) -> void:
	is_starving = starving
	is_depressed = depressed
	is_bladder_critical = (bladder_val / maxf(max_bladder, 1.0)) >= 0.9

	# Bladder bar flashes when full/critical
	if piss_bar:
		if is_bladder_critical:
			_bladder_flash_timer += delta * 6.0
			piss_bar.modulate.a = 0.4 + (sin(_bladder_flash_timer) + 1.0) * 0.3
		else:
			piss_bar.modulate.a = 1.0


func _fade_stamina_bar(target_alpha: float) -> void:
	# Если текущая прозрачность уже стремится к нужной, не перезапускаем
	if is_equal_approx(stamina_bar.modulate.a, target_alpha):
		return

	if _stamina_tween and _stamina_tween.is_valid():
		_stamina_tween.kill()

	_stamina_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Быстро проявляется за 0.15с, мягко исчезает за 0.5с
	var duration: float = 0.15 if target_alpha > 0.0 else 0.5
	_stamina_tween.tween_property(stamina_bar, "modulate:a", target_alpha, duration)

func setup_actions(actions: PlayerActions) -> void:
	actions.item_consumed.connect(_on_item_consumed)
	if actions.has_signal("item_equipped"):
		actions.item_equipped.connect(_on_item_equipped)
	if actions.has_signal("inhale_started"):
		actions.inhale_started.connect(_on_inhale_started)
	if actions.has_signal("inhale_progress"):
		actions.inhale_progress.connect(_on_inhale_progress)
	if actions.has_signal("inhale_finished"):
		actions.inhale_finished.connect(_on_inhale_finished)

	# Push initial equipped item state immediately
	if actions.active_item_index >= 0 and actions.active_item_index < actions.inventory.size():
		var item: ConsumableItem = actions.inventory[actions.active_item_index]
		_update_item_text(item, item.max_charges if item.is_single_use else -1)
	else:
		_update_item_text(null, 0)


func _on_inhale_started(vape_item: ConsumableItem) -> void:
	if not inhale_bar or not vape_item:
		return

	if _inhale_tween and _inhale_tween.is_valid():
		_inhale_tween.kill()

	var total_w: float = inhale_bar.size.x
	var max_time: float = maxf(vape_item.max_hold_time, 0.1)
	var start_ratio: float = clampf(vape_item.sweet_spot_start / max_time, 0.0, 1.0)
	var dur_ratio: float = clampf(vape_item.sweet_spot_duration / max_time, 0.0, 1.0 - start_ratio)

	if inhale_sweet_spot:
		inhale_sweet_spot.position.x = total_w * start_ratio
		inhale_sweet_spot.size.x = total_w * dur_ratio
		inhale_sweet_spot.color = Color(0.18, 0.85, 0.62, 0.55)

	if inhale_progress_fill:
		inhale_progress_fill.size.x = 0.0
		inhale_progress_fill.color = Color(0.95, 0.95, 0.95, 0.95)

	_inhale_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_inhale_tween.tween_property(inhale_bar, "modulate:a", 1.0, 0.1)


func _on_inhale_progress(progress_pct: float, in_sweet_spot: bool) -> void:
	if not inhale_bar or not inhale_progress_fill:
		return

	var total_w: float = inhale_bar.size.x
	inhale_progress_fill.size.x = total_w * clampf(progress_pct, 0.0, 1.0)

	if in_sweet_spot:
		inhale_progress_fill.color = Color(0.2, 0.95, 0.7, 1.0)
	elif progress_pct > 0.9:
		# Danger zone before coughing
		inhale_progress_fill.color = Color(0.95, 0.25, 0.25, 1.0)
	else:
		inhale_progress_fill.color = Color(0.95, 0.95, 0.95, 0.95)


func _on_inhale_finished(outcome: String, _hold_time: float) -> void:
	if not inhale_bar:
		return

	if _inhale_tween and _inhale_tween.is_valid():
		_inhale_tween.kill()

	_inhale_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	match outcome:
		"perfect":
			if inhale_progress_fill:
				inhale_progress_fill.color = Color(1.0, 0.85, 0.2, 1.0) # Gold flash
			_inhale_tween.tween_property(inhale_bar, "modulate:a", 0.0, 0.35).set_delay(0.1)
		"cough":
			if inhale_progress_fill:
				inhale_progress_fill.color = Color(1.0, 0.15, 0.15, 1.0) # Red flash
			_inhale_tween.tween_property(inhale_bar, "modulate:a", 0.0, 0.4).set_delay(0.15)
		_: # "weak"
			_inhale_tween.tween_property(inhale_bar, "modulate:a", 0.0, 0.2)


func _on_item_consumed(item: ConsumableItem, remaining: int) -> void:
	_update_item_text(item, remaining)

func _on_item_equipped(item: ConsumableItem, count: int) -> void:
	_update_item_text(item, count)

func _update_item_text(item: ConsumableItem, count: int) -> void:
	if not item_display_label:
		return
	if item == null or count == 0:
		item_display_label.text = "Equipped: None"
		return

	if count < 0:
		item_display_label.text = "Equipped: %s (Infinite)" % item.item_name
	else:
		item_display_label.text = "Equipped: %s (x%d)" % [item.item_name, count]

func _animate_crosshair(highlighted: bool) -> void:
	if not crosshair:
		return

	if highlighted == _current_crosshair_highlight and _crosshair_tween and _crosshair_tween.is_valid():
		return
	_current_crosshair_highlight = highlighted

	if _crosshair_tween and _crosshair_tween.is_valid():
		_crosshair_tween.kill()

	_crosshair_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Обычный размер 4x4, при наведении на дверь/предмет увеличивается до 7x7 и становится ярче
	var target_scale: Vector2 = Vector2(1.75, 1.75) if highlighted else Vector2(1.0, 1.0)
	var target_color: Color = Color(1.0, 1.0, 1.0, 1.0) if highlighted else Color(1.0, 1.0, 1.0, 0.6)

	# Настраиваем точку вращения/масштабирования в центр прицела (pivot_offset)
	crosshair.pivot_offset = crosshair.size * 0.5
	_crosshair_tween.parallel().tween_property(crosshair, "scale", target_scale, 0.12)
	_crosshair_tween.parallel().tween_property(crosshair, "color", target_color, 0.12)

func set_interaction_prompt(prompt_text: String, show_prompt: bool) -> void:
	if interaction_prompt:
		interaction_prompt.text = "[E] %s" % prompt_text
		interaction_prompt.visible = show_prompt	
	# Динамическая реакция прицела
		_animate_crosshair(show_prompt)



func setup(needs_manager: NeedsManager) -> void:
	# Connect to the manager signals
	needs_manager.need_changed.connect(_on_need_changed)
	# 2. Push initial values immediately
	for need_id: String in needs_manager.values.keys():
		var current_val: float = needs_manager.values[need_id]
		var res: NeedResource = needs_manager._get_resource_by_id(need_id)
		if res:
			_on_need_changed(need_id, current_val, res.max_value)


func _on_need_changed(need_name: String, current_value: float, max_value: float) -> void:
	var target_bar: ProgressBar = null
	match need_name:
		"dopamine": target_bar = dopamine_bar
		"hunger": target_bar = hunger_bar
		"bladder": target_bar = piss_bar

	if target_bar:
		target_bar.max_value = max_value
		target_bar.value = current_value
