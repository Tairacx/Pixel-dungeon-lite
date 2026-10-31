class_name CamaraZonaB
extends Node3D
# Pivote de la cámara en tercera persona (zona B), controlada con el mouse.
# Estructura:  PivoteCamara (este script) -> SpringArm3D -> Camera3D
#  - El pivote sigue suave al héroe y NO gira con él.
#  - El mouse gira el pivote (izquierda/derecha) e inclina el SpringArm3D (arriba/abajo).
#  - El SpringArm3D acerca la cámara solo si una pared se interpone.
#  - Esc suelta el mouse; un clic lo vuelve a capturar.
# Si el repositorio ya tiene la CamaraSeguidora del equipo, se reemplaza todo esto por esa.

@export var objetivo: Node3D
@export var altura := 1.0            # m sobre los pies: hacia dónde mira la cámara
@export var k := 8.0                 # 1/s: qué tan rápido sigue al héroe
@export var sensibilidad := 0.003    # radianes por píxel de mouse
@export var inclinacion_min := -80.0 # grados (casi vertical)
@export var inclinacion_max := -10.0 # grados (casi horizontal)

@onready var brazo: SpringArm3D = $SpringArm3D


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_seguir(1.0)


func _process(delta: float) -> void:
	_seguir(1.0 - exp(-k * delta))


func _seguir(alpha: float) -> void:
	if objetivo == null:
		return
	var destino := objetivo.global_position + Vector3.UP * altura
	global_position = global_position.lerp(destino, alpha)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * sensibilidad
		brazo.rotation.x = clampf(brazo.rotation.x - event.relative.y * sensibilidad,
			deg_to_rad(inclinacion_min), deg_to_rad(inclinacion_max))
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
