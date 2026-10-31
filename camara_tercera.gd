extends Node3D
# Cámara en tercera persona (estilo Roblox): se queda a una distancia fija
# detrás del héroe y NO gira con él. Solo se gira manteniendo el clic derecho.
# Estructura:  PivoteCamara (este script) -> SpringArm3D -> Camera3D

@export var objetivo: Node3D
@export var altura := 1.2            # m sobre los pies: a dónde mira la cámara
@export var suavizado := 8.0         # 1/s: qué tan rápido sigue al héroe
@export var sensibilidad := 0.0025   # radianes por píxel de mouse
@export var inclinacion_min := -60.0 # grados (casi desde arriba)
@export var inclinacion_max := 15.0  # grados (casi a ras del suelo)

@onready var brazo: SpringArm3D = $SpringArm3D

var _arrastrando := false


func _ready() -> void:
	if objetivo == null:
		return
	global_position = objetivo.global_position + Vector3.UP * altura
	brazo.add_excluded_object(objetivo.get_rid())


func _process(delta: float) -> void:
	if objetivo == null:
		return
	var destino := objetivo.global_position + Vector3.UP * altura
	global_position = global_position.lerp(destino, 1.0 - exp(-suavizado * delta))


func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_RIGHT:
		# Mantener el clic derecho "toma" el mouse, como en Roblox.
		_arrastrando = evento.pressed
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if evento.pressed else Input.MOUSE_MODE_VISIBLE
	elif evento is InputEventKey and evento.pressed and evento.keycode == KEY_ESCAPE:
		_arrastrando = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif evento is InputEventMouseMotion and _arrastrando:
		rotation.y -= evento.relative.x * sensibilidad
		brazo.rotation.x = clampf(brazo.rotation.x - evento.relative.y * sensibilidad,
			deg_to_rad(inclinacion_min), deg_to_rad(inclinacion_max))
