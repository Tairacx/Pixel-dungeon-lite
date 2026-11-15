class_name Barril
extends "res://contenedor_rompible.gd"
# Barril de vida: solo suelta corazones. Nunca armas.
# Se rompe con la espada (recibir_golpe) y avisa al SistemaEventos para el destello.


func _ready() -> void:
	armas_al_romper = 0
	corazones_al_romper = maxi(corazones_al_romper, 1)
	super()


func _construir_cuerpo() -> void:
	var alto := tamano.y
	var radio := tamano.x * 0.46
	# Cuerpo de madera
	_cilindro(radio, alto, Vector3(0, alto * 0.5, 0), color_cuerpo)
	# Aros de hierro
	for y in [alto * 0.15, alto * 0.50, alto * 0.85]:
		_cilindro(radio + 0.012, 0.075, Vector3(0, y, 0), color_detalle)
	# Tapa y base
	_cilindro(radio * 0.98, 0.05, Vector3(0, alto - 0.025, 0), color_detalle)
	_cilindro(radio * 0.98, 0.05, Vector3(0, 0.025, 0), color_detalle)


func _forma_por_defecto() -> Shape3D:
	var cilindro := CylinderShape3D.new()
	cilindro.radius = tamano.x * 0.46
	cilindro.height = tamano.y
	return cilindro


func _altura_forma() -> float:
	return tamano.y
