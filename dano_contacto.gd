extends Area3D
# Daño por contacto del enemigo: mientras el héroe esté dentro de esta área, le quita vida.
# La frecuencia la limita la invulnerabilidad del Salud del héroe (1 s por defecto).
# Capa 0 / máscara 8: solo ve al Personaje (que está en la capa 8).

@export var danio := 1.0   # en corazones: 0.5 = medio corazón


func _physics_process(_delta: float) -> void:
	for cuerpo in get_overlapping_bodies():
		var salud = cuerpo.get_node_or_null("Salud")
		if salud != null:
			salud.recibir_danio(danio, global_position)
