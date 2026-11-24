class_name CamaraFija
extends Node3D
# Cámara fija cenital inclinada (2.5D top-down, estilo Zelda/Diablo).
# Sigue al héroe en POSICIÓN, pero la ROTACIÓN es fija: nunca gira con el mouse.
# Estructura: PivoteCamara (este script) -> SpringArm3D -> Camera3D

@export var objetivo: Node3D
@export var altura := 1.0          # m sobre los pies del héroe (a dónde apunta el pivote)
@export var inclinacion := 50.0    # grados: cuánto mira hacia abajo (45-60 = top-down 2.5D)
@export var distancia := 10.0      # m del brazo (qué tan lejos/alta queda la cámara)
@export var suavizado := 8.0       # 1/s: qué tan rápido sigue al héroe

@onready var brazo: SpringArm3D = get_node_or_null("SpringArm3D")


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	rotation = Vector3.ZERO
	if brazo != null:
		brazo.rotation = Vector3(deg_to_rad(-inclinacion), 0, 0)
		brazo.spring_length = distancia
		brazo.collision_mask = 0   # la cámara no se acerca sola: las paredes se transparentan
	_seguir(1.0)


func _process(delta: float) -> void:
	_seguir(1.0 - exp(-suavizado * delta))


func _seguir(alpha: float) -> void:
	if objetivo == null:
		return
	var destino := objetivo.global_position + Vector3.UP * altura
	global_position = global_position.lerp(destino, alpha)
