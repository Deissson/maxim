class_name SmokeCloud
extends GPUParticles3D

func _ready() -> void:
	# Clean up automatically once all particles expire
	finished.connect(queue_free)
	emitting = true
