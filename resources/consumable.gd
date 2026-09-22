class_name ConsumableItem
extends Resource

@export var item_name: String = "Item"
@export var target_need: String = "dopamine" # "dopamine", "hunger", "bladder"
@export var stat_delta: float = 20.0
@export var cooldown_seconds: float = 1.0
@export var is_single_use: bool = false
@export var max_charges: int = 1 # Ignored if not single-use

@export_group("Visuals")
@export var mesh: Mesh                      # Сюда кидаешь любой меш (BoxMesh, CylinderMesh или меш из .glb)
@export var material: Material              # Цвет / текстура
@export var hold_scale: Vector3 = Vector3.ONE # Чтобы подогнать размер под руку

@export_group("Hold / Inhale Mechanic")
@export var is_hold_based: bool = false
@export var max_hold_time: float = 3.0           # Максимальное время удержания до кашля
@export var sweet_spot_start: float = 1.8        # Секунда начала "зелёной зоны"
@export var sweet_spot_duration: float = 0.6     # Длительность окна идеального попадания
@export var cough_penalty_dopamine: float = 15.0 # Снижение дофамина при передержке / кашле
@export var min_smoke_scale: float = 0.5         # Минимальный размер дыма при слабой затяжке
@export var max_smoke_scale: float = 2.2         # Максимальный размер облака дыма при идеальной затяжке
