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

var _stamina_tween: Tween
var _crosshair_tween: Tween	
var _vignette_tween: Tween

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
