class_name CajaRecursos
extends "res://contenedor_rompible.gd"
# Caja de recursos: al romperse suelta corazones de vida y armas para mejorar la espada.
# Se rompe con la espada (recibir_golpe) y avisa al SistemaEventos para el destello.


func _construir_cuerpo() -> void:
	var alto := tamano.y
	# Cuerpo de madera
	_caja(tamano, Vector3(0, alto * 0.5, 0), color_cuerpo)
	# Aros metálicos horizontales
	for y in [alto * 0.16, alto * 0.84]:
		_caja(Vector3(tamano.x * 1.02, 0.07, tamano.z * 1.02),
			Vector3(0, y, 0), color_detalle)
	# Esquinas metálicas
	for lado_x in [-1, 1]:
		for lado_z in [-1, 1]:
			_caja(Vector3(0.07, alto * 0.98, 0.07),
				Vector3(lado_x * (tamano.x * 0.5 - 0.035), alto * 0.5,
					lado_z * (tamano.z * 0.5 - 0.035)), color_detalle)
	# Cerradura al frente
	_caja(Vector3(0.12, 0.15, 0.05),
		Vector3(0, alto * 0.55, tamano.z * 0.5 + 0.02),
		color_detalle, Color("#4A2A08"))
