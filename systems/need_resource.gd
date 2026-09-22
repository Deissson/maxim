class_name NeedResource
extends Resource

@export var name: String = "Stat"
@export var max_value: float = 100.0
@export var default_value: float = 100.0
## Amount lost (or gained) per second
@export var rate_per_second: float = 1.0
## If true, value increases over time (e.g., Piss filling up). If false, it decreases (same for Hunger, Dopamine).
@export var fills_over_time: bool = false
