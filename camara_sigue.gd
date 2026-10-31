extends Camera3D

@export var objetivo: Node3D
@export var distancia = Vector3(0, 12, 5)


func _ready():
	top_level = true
	# Se orienta UNA vez, mirando al objetivo.
	look_at_from_position(objetivo.global_position + distancia,
		objetivo.global_position)


func _physics_process(_delta):
	global_position = objetivo.global_position + distancia

	if _en_prueba() and Engine.get_physics_frames() % 30 == 0:
		print("cámara ", global_position.snappedf(0.01))


func _en_prueba() -> bool:
	var p = objetivo.get("prueba")
	return p != null and p != 0
