class_name Antorcha
extends Node3D
# Antorcha de pared (boceto del equipo): modelo de hierro + fuego pixel art (spritesheet 4x4)
# + chispas (GPUParticles3D) + luz parpadeante (LuzParpadeante) + sonido de fuego.
# Estructura:  Antorcha -> Modelo / Fuego / Chispas / Luz / Sonido
# El "frente" de la antorcha es +Z local: la placa va pegada a la pared (plano z = 0).
# Lo que cambia entre una antorcha y otra se ajusta aquí, en el Inspector de la instancia.

@export var semilla := 7           # misma semilla = mismo parpadeo en todos los PC
@export var sombras := true        # false en pasillos (ahorra proyección de sombras)
@export var alcance := 12.0        # omni_range de la luz

@onready var luz: LuzParpadeante = $Luz
@onready var sonido: AudioStreamPlayer3D = $Sonido


func _ready() -> void:
	luz.semilla = semilla
	luz.ruido.seed = semilla       # la luz ya hizo su _ready (los hijos van primero): se vuelve a sembrar
	luz.shadow_enabled = sombras
	luz.omni_range = alcance
	if sonido.stream != null:
		sonido.finished.connect(sonido.play)      # bucle del crepitar
		sonido.play(randf() * maxf(sonido.stream.get_length() - 0.1, 0.0))   # cada una arranca en un punto distinto
