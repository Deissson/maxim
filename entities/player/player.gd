class_name Player
extends CharacterBody3D

@export_group("Scenes & UI")
@export var hud_scene: PackedScene

@export_group("Movement")
@export var walk_speed: float = 4.5
@export var sprint_speed: float = 8.0
@export var crouch_speed: float = 2.2         # Скорость на корточках
@export var exhausted_walk_speed: float = 3.0
@export var acceleration: float = 40.0
@export var deceleration: float = 30.0
@export var jump_velocity: float = 4.5

@export_group("Crouch Settings")
@export var standing_height: float = 1.8      # Полная высота коллайдера
@export var crouch_height: float = 0.9        # Высота вдвое меньше
@export var standing_camera_y: float = 1.6    # Уровень глаз стоя
@export var crouch_camera_y: float = 0.8      # Уровень глаз сидя
@export var crouch_transition_speed: float = 12.0 # Плавность смены высоты

@export_group("Stamina")
@export var max_stamina: float = 100.0
@export var stamina_drain_rate: float = 28.0 
@export var stamina_regen_rate: float = 45.0
@export var exhausted_regen_rate: float = 18.0
@export var jump_stamina_cost: float = 12.0  
@export var regen_delay_time: float = 0.35   
@export var exhausted_recovery_threshold: float = 0.5

@export_group("Camera Settings")
@export var normal_fov: float = 75.0
@export var exhausted_fov: float = 68.0
@export var fov_change_speed: float = 4.0
@export var mouse_sensitivity: float = 0.002
@export var min_pitch: float = -89.0
@export var max_pitch: float = 89.0

@export_group("Headbob Settings")
@export var bob_walk_freq: float = 10.0      # Частота шагов при ходьбе
@export var bob_sprint_freq: float = 14.0    # Частота при спринте
@export var bob_crouch_freq: float = 7.0     # Частота в приседе
@export var bob_walk_amp_y: float = 0.05     # Амплитуда вверх-вниз при ходьбе
@export var bob_walk_amp_x: float = 0.03     # Амплитуда влево-вправо при ходьбе
@export var bob_sprint_amp_y: float = 0.08   # Амплитуда вверх-вниз при спринте
@export var bob_sprint_amp_x: float = 0.05   # Амплитуда влево-вправо при спринте
@export var bob_crouch_amp: float = 0.02     # Амплитуда в приседе
@export var bob_reset_speed: float = 8.0     # Скорость возврата в центр при остановке

var _bob_timer: float = 0.0
var _initial_cam_pos: Vector3 = Vector3.ZERO

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Состояния
var current_stamina: float = 100.0
var _regen_timer: float = 0.0
var is_sprinting: bool = false
var is_exhausted: bool = false
var is_crouching: bool = false

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var ceiling_check: ShapeCast3D = get_node_or_null("CeilingCheck")
@onready var interaction_ray: RayCast3D = $CameraPivot/InteractionRay
@onready var needs_manager: NeedsManager = $NeedsManager

var current_hud: HUD
var current_interactable: Interactable = null


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	current_stamina = max_stamina
	if camera:
		camera.fov = normal_fov
		_initial_cam_pos = camera.position
	
	if ceiling_check:
		ceiling_check.add_exception(self)

	_init_hud()
	


func _init_hud() -> void:
	if not hud_scene:
		push_warning("Player: 'hud_scene' is not assigned in the Inspector.")
		return

	var hud_inst: Node = hud_scene.instantiate()
	if not hud_inst:
		return

	add_child(hud_inst)
	if hud_inst is HUD:
		current_hud = hud_inst
		current_hud.setup(needs_manager)
		var actions: PlayerActions = get_node_or_null("PlayerActions")
		if actions:
			current_hud.setup_actions(actions)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_handle_camera_rotation(event.relative)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and current_interactable:
		var target: Interactable = current_interactable
		target.interact(self)
		_check_interaction_target()


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_handle_crouch(delta)
	_handle_stamina(delta)
	_handle_jump()
	_handle_movement(delta)
	_handle_fov(delta)
	move_and_slide()

	_check_interaction_target()

func _handle_headbob(delta: float) -> void:
	if not camera:
		return

	var horizontal_velocity: Vector2 = Vector2(velocity.x, velocity.z)
	var speed: float = horizontal_velocity.length()

	# Покачивание работает только на полу и когда игрок реально двигается
	if is_on_floor() and speed > 0.5:
		# Выбираем частоту и амплитуду в зависимости от режима
		var freq: float = bob_walk_freq
		var amp_x: float = bob_walk_amp_x
		var amp_y: float = bob_walk_amp_y

		if is_crouching:
			freq = bob_crouch_freq
			amp_x = bob_crouch_amp
			amp_y = bob_crouch_amp
		elif is_sprinting:
			freq = bob_sprint_freq
			amp_x = bob_sprint_amp_x
			amp_y = bob_sprint_amp_y

		# Привязываем таймер к реальной скорости движения
		_bob_timer += delta * freq

		# Вычисляем смещение по формуле восьмёрки
		var target_x: float = _initial_cam_pos.x + cos(_bob_timer) * amp_x
		var target_y: float = _initial_cam_pos.y + sin(_bob_timer * 2.0) * amp_y

		camera.position.x = target_x
		camera.position.y = target_y
	else:
		# Плавный сброс камеры в нейтральное положение, если стоим или летим
		_bob_timer = 0.0
		camera.position.x = move_toward(camera.position.x, _initial_cam_pos.x, bob_reset_speed * delta)
		camera.position.y = move_toward(camera.position.y, _initial_cam_pos.y, bob_reset_speed * delta)


func _handle_crouch(delta: float) -> void:
	var wants_to_crouch: bool = Input.is_action_pressed("crouch")
	
	# Проверяем, можно ли встать (нет ли потолка над головой)
	var can_stand_up: bool = true
	if ceiling_check and ceiling_check.is_colliding():
		can_stand_up = false

	if wants_to_crouch:
		is_crouching = true
	elif can_stand_up:
		is_crouching = false

	# Целевая высота капсулы и положение камеры
	var target_capsule_height: float = crouch_height if is_crouching else standing_height
	var target_cam_y: float = crouch_camera_y if is_crouching else standing_camera_y

	# Плавное опускание камеры
	camera_pivot.position.y = lerpf(camera_pivot.position.y, target_cam_y, crouch_transition_speed * delta)

	# Изменение физического хитбокса
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule: CapsuleShape3D = collision_shape.shape as CapsuleShape3D
		capsule.height = lerpf(capsule.height, target_capsule_height, crouch_transition_speed * delta)
		# Центр капсулы должен подниматься ровно на половину высоты от пола
		collision_shape.position.y = capsule.height * 0.5


func _handle_stamina(delta: float) -> void:
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	
	if is_sprinting and horizontal_speed > 0.5:
		current_stamina = maxf(0.0, current_stamina - stamina_drain_rate * delta)
		_regen_timer = regen_delay_time
		if current_stamina <= 0.0 and not is_exhausted:
			is_sprinting = false
			is_exhausted = true
			if current_hud and current_hud.has_method("set_exhausted_vignette"):
				current_hud.set_exhausted_vignette(true)
	else:
		if _regen_timer > 0.0:
			_regen_timer -= delta
		else:
			var current_regen_rate: float = exhausted_regen_rate if is_exhausted else stamina_regen_rate
			current_stamina = minf(max_stamina, current_stamina + current_regen_rate * delta)
			
			if is_exhausted and current_stamina >= (max_stamina * exhausted_recovery_threshold):
				is_exhausted = false
				if current_hud and current_hud.has_method("set_exhausted_vignette"):
					current_hud.set_exhausted_vignette(false)

	if current_hud and current_hud.has_method("update_stamina"):
		current_hud.update_stamina(current_stamina, max_stamina)


func _handle_jump() -> void:
	# Нельзя прыгать в приседе, при истощении или нехватке стамины
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching:
		if not is_exhausted and current_stamina >= jump_stamina_cost:
			velocity.y = jump_velocity
			current_stamina -= jump_stamina_cost
			_regen_timer = regen_delay_time
			if current_stamina <= 0.0 and not is_exhausted:
				is_exhausted = true
				if current_hud and current_hud.has_method("set_exhausted_vignette"):
					current_hud.set_exhausted_vignette(true)


func _handle_movement(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward"
	)

	# В приседе спринт запрещен
	var wants_to_sprint: bool = Input.is_action_pressed("sprint") and input_dir.y < 0.0
	if wants_to_sprint and not is_exhausted and not is_crouching and current_stamina > 0.0:
		is_sprinting = true
	else:
		is_sprinting = false

	# Расчёт целевой скорости с учётом приседания
	var target_speed: float
	if is_crouching:
		target_speed = crouch_speed
	elif is_sprinting:
		target_speed = sprint_speed
	elif is_exhausted:
		target_speed = exhausted_walk_speed
	else:
		target_speed = walk_speed
	
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	if direction != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, direction.x * target_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * target_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)


func _handle_fov(delta: float) -> void:
	if not camera:
		return
	
	var target_fov: float = exhausted_fov if is_exhausted else normal_fov
	camera.fov = lerpf(camera.fov, target_fov, fov_change_speed * delta)


func _handle_camera_rotation(relative_motion: Vector2) -> void:
	rotate_y(-relative_motion.x * mouse_sensitivity)
	camera_pivot.rotate_x(-relative_motion.y * mouse_sensitivity)
	camera_pivot.rotation.x = clampf(
		camera_pivot.rotation.x,
		deg_to_rad(min_pitch),
		deg_to_rad(max_pitch)
	)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta


func _check_interaction_target() -> void:
	if interaction_ray and interaction_ray.is_colliding():
		var collider: Object = interaction_ray.get_collider()
		if collider is Interactable and not collider.is_queued_for_deletion():
			current_interactable = collider
			if current_hud:
				current_hud.set_interaction_prompt(collider.get_prompt(), true)
			return

	if current_interactable != null:
		current_interactable = null
		if current_hud:
			current_hud.set_interaction_prompt("", false)
