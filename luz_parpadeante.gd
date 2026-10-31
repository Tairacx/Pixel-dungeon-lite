class_name LuzParpadeante
extends OmniLight3D
# Tarea B · Nivel 1 — La luz con vida (antorchas de la sala sellada).
# Parpadea con RUIDO (suave), no con randf() (que saltaría cada frame).
# Con la misma semilla el parpadeo es idéntico en todos los PC.

@export var energia_base := 2.0
@export var amplitud := 0.3        # 0.3 = sube o baja hasta un 30 %
@export var velocidad := 4.0       # qué tan rápido recorre el ruido
@export var semilla := 7
@export var depurar := false       # true = imprime la energía (para las capturas)

var ruido := FastNoiseLite.new()
var t := 0.0


func _ready() -> void:
	ruido.seed = semilla
	ruido.frequency = 1.0          # sin esto casi no cambia (viene en 0.01)


func _process(delta: float) -> void:
	t += delta
	light_energy = energia(energia_base, amplitud, ruido.get_noise_1d(t * velocidad))
	if depurar:
		print(name, " energía ", snappedf(light_energy, 0.01))


# Función pura: energía = base × (1 + amplitud × ruido), nunca negativa.
static func energia(base: float, amp: float, valor_ruido: float) -> float:
	return maxf(0.0, base * (1.0 + amp * valor_ruido))
