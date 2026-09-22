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
