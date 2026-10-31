class_name CicloDia
extends Node

# Reloj del sol: solo lleva la hora y hace las cuentas. No toca ninguna luz.
const NARANJA := Color("#3F3552")   # Piedra: el color bajo de la luz principal

@export var hora := 12.0            # h, al empezar
@export var duracion_dia := 48.0    # s reales que dura un día de 24 h
@export var pausado := true         # la luz de la Sala 1 es fija


func avanzar(dt: float) -> void:
	if not pausado:
		hora = fposmod(hora + 24.0 * dt / duracion_dia, 24.0)


static func elevacion(h: float) -> float:
	return (h - 6.0) * 15.0          # 6 h → 0°, 12 h → 90°, 18 h → 180°


static func factor_sol(h: float) -> float:
	return maxf(0.0, sin(deg_to_rad(elevacion(h))))


static func color_sol(h: float) -> Color:
	return NARANJA.lerp(Color.WHITE, factor_sol(h))
