class_name SistemaEventos
extends Node
# Tarea B · Niveles 2 y 3 — Hacer que las luces respondan al juego.
#  Nivel 2: escucha a TODOS los nodos del grupo "disparadores" y hace un destello
#           que se apaga con el alfa exponencial (independiente de los FPS).
#  Nivel 3: una luz que sigue una variable del juego (los corazones del héroe).

# ---- Nivel 2: el destello ----
@export var luz_evento: OmniLight3D
@export var pico_destello := 4.0
@export var k_destello := 6.0      # 1/s: qué tan rápido se apaga

# ---- Nivel 3: la luz que sigue una variable ----
@export var luz_variable: Light3D  # la luz que sigue la variable
@export var color_bajo := Color(0.5, 0.8, 1.0)
@export var color_alto := Color(1.0, 0.2, 0.2)
@export var k_variable := 4.0
@export var corazones_max := 5
@export var depurar := false       # true = imprime las energías (para las capturas)

var variable := 0.0                # de 0 a 1: 0 = tranquilo, 1 = peligro
var corazones := 5


func _ready() -> void:
	corazones = corazones_max
	for d in get_tree().get_nodes_in_group("disparadores"):
		d.evento.connect(_on_evento)       # la función que escucha, sin paréntesis
	luz_evento.light_energy = 0.0
	_actualizar_variable()


func _process(delta: float) -> void:
	# Nivel 2: el destello decae hacia 0
	luz_evento.light_energy = decaer(luz_evento.light_energy, 0.0, k_destello, delta)

	# Nivel 3: color por interpolación y energía que persigue a la deseada
	if luz_variable != null:
		var v := clampf(variable, 0.0, 1.0)
		luz_variable.light_color = color_bajo.lerp(color_alto, v)
		var deseada := 1.0 + 3.0 * v
		luz_variable.light_energy = decaer(luz_variable.light_energy, deseada, k_variable, delta)

	if depurar:
		print("destello ", snappedf(luz_evento.light_energy, 0.001),
			"  variable ", snappedf(variable, 0.01),
			"  energía_var ", snappedf(luz_variable.light_energy, 0.001) if luz_variable else 0.0)


# El aviso llegó: el destello salta a donde pasó, 1.5 m más arriba.
func _on_evento(posicion: Vector3) -> void:
	luz_evento.global_position = posicion + Vector3.UP * 1.5
	luz_evento.light_energy = pico_destello


# ---- Variable del juego: los corazones ----
# Si la mecánica real existe, ella llama set_corazones(...). Mientras no:
# J quita un corazón (más peligro) y K cura uno (las flechas mueven al héroe).
func set_corazones(c: int) -> void:
	corazones = clampi(c, 0, corazones_max)
	_actualizar_variable()


func _actualizar_variable() -> void:
	variable = 1.0 - float(corazones) / float(corazones_max)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_J:
			set_corazones(corazones - 1)
		elif event.keycode == KEY_K:
			set_corazones(corazones + 1)


# ---- Funciones puras ----
# "lo que falta" = destino - actual; se recorre una fracción alfa de eso por frame.
static func decaer(actual: float, base: float, k: float, dt: float) -> float:
	var alpha := alpha_exponencial(k, dt)
	return actual + (base - actual) * alpha


# alfa = 1 - e^(-k·dt). Si el repo ya trae CamaraSeguidora.alpha_exponencial (Taller 2),
# esta línea se puede cambiar por esa llamada: es la misma cuenta.
static func alpha_exponencial(k: float, dt: float) -> float:
	return 1.0 - exp(-k * dt)
