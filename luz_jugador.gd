class_name LuzJugador
extends OmniLight3D
# Tarea C · Niveles 1 y 3 — La luz del jugador (la antorcha del héroe).
# Es hija del Personaje: se mueve con él sin ninguna cuenta de seguimiento.
# La luz puntual reparte su energía en una esfera; con atenuación 2 llega 1/d².

@export var rango := 5.0           # m: límite del motor; el borde útil queda a 3 m
@export var altura := 1.55         # m sobre los pies: la antorcha en la mano
@export var lado := 0.45           # m a un costado: fuera del cuerpo del héroe
@export var energia := 2.5         # medido: 2.5/3² ≈ 0.104 lineal a 3 m con el Range 5
@export var exponente := 2.0       # 2 = 1/d², como una luz puntual real


func _ready() -> void:
	position = Vector3(lado, altura, 0.0)   # relativa al Jugador, no al mundo
	omni_range = rango
	omni_attenuation = exponente
	light_energy = energia


# Función pura: fracción de luz que llega a la distancia d con 1/d^exponente.
static func atenuacion(d: float, exp: float = 2.0) -> float:
	return 1.0 / pow(maxf(d, 0.0001), exp)


# Función pura del nivel 3: brillo especular de Blinn-Phong.
# h es el vector medio entre la luz y el ojo; el punto brillante es n · h.
static func blinn_phong(normal: Vector3, hacia_luz: Vector3,
		hacia_ojo: Vector3, brillo: float) -> float:
	var n := normal.normalized()
	var l := hacia_luz.normalized()
	var v := hacia_ojo.normalized()
	var h := (l + v).normalized()
	return pow(maxf(0.0, n.dot(h)), brillo)
