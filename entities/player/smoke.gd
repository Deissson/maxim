class_name SmokeCloud
extends GPUParticles3D


func setup_puff(scale_multiplier: float, amount_multiplier: float, is_cough: bool = false) -> void:
	scale = Vector3.ONE * clampf(scale_multiplier, 0.3, 3.0)
	amount = clampi(int(amount * amount_multiplier), 15, 180)
	if is_cough:
		explosiveness = 1.0
		lifetime = 1.2


func _ready() -> void:
	# Clean up automatically once all particles expire
	finished.connect(queue_free)
	emitting = true
