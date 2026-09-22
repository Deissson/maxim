class_name NeedsManager
extends Node

signal need_changed(need_name: String, current_value: float, max_value: float)
signal need_depleted(need_name: String)
signal need_filled(need_name: String)

@export var dopamine_data: NeedResource
@export var hunger_data: NeedResource
@export var bladder_data: NeedResource

var values: Dictionary = {}


func _ready() -> void:
	_init_need("dopamine", dopamine_data)
	_init_need("hunger", hunger_data)
	_init_need("bladder", bladder_data)


func _physics_process(delta: float) -> void:
	_process_need("dopamine", dopamine_data, delta)
	_process_need("hunger", hunger_data, delta)
	_process_need("bladder", bladder_data, delta)


func _init_need(id: String, res: NeedResource) -> void:
	if res:
		values[id] = res.default_value
		need_changed.emit(id, values[id], res.max_value)


func _process_need(id: String, res: NeedResource, delta: float) -> void:
	if not res:
		return

	var old_val: float = values[id]
	if res.fills_over_time:
		values[id] = minf(values[id] + (res.rate_per_second * delta), res.max_value)
		if values[id] >= res.max_value and old_val < res.max_value:
			need_filled.emit(id)
	else:
		values[id] = maxf(values[id] - (res.rate_per_second * delta), 0.0)
		if values[id] <= 0.0 and old_val > 0.0:
			need_depleted.emit(id)

	if not is_equal_approx(old_val, values[id]):
		need_changed.emit(id, values[id], res.max_value)


## Public API to modify stats from items, actions, or triggers
func modify_need(id: String, amount: float) -> void:
	if not values.has(id):
		push_warning("Need '%s' not recognized." % id)
		return

	var res: NeedResource = _get_resource_by_id(id)
	if not res:
		return

	var old_val: float = values[id]
	values[id] = clampf(values[id] + amount, 0.0, res.max_value)
	
	if values[id] >= res.max_value and old_val < res.max_value:
		need_filled.emit(id)
	elif values[id] <= 0.0 and old_val > 0.0:
		need_depleted.emit(id)

	if not is_equal_approx(old_val, values[id]):
		need_changed.emit(id, values[id], res.max_value)


func get_need_value(id: String) -> float:
	return values.get(id, 0.0)


func get_need_percent(id: String) -> float:
	var res: NeedResource = _get_resource_by_id(id)
	if res and res.max_value > 0.0:
		return values.get(id, 0.0) / res.max_value
	return 0.0


func _get_resource_by_id(id: String) -> NeedResource:
	match id:
		"dopamine": return dopamine_data
		"hunger": return hunger_data
		"bladder": return bladder_data
		_: return null
