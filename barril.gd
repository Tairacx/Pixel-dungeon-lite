class_name Barril
extends "res://contenedor_rompible.gd"
# Barril de vida: solo suelta corazones. Nunca armas.
# Se rompe con la espada (recibir_golpe) y avisa al SistemaEventos para el destello.

# Modelo Kenney "Mini Dungeon" (CC0). Ya viene apoyado en el piso (Y = 0).
const MODELO_BARRIL := preload("res://objetos/kenney/barrel.glb")
# Medidas reales del GLB, solo para escalarlo a "tamano".
const MEDIDAS_BARRIL := Vector3(0.5176, 0.4762, 0.5176)


func _ready() -> void:
	armas_al_romper = 0
	corazones_al_romper = maxi(corazones_al_romper, 1)
	super()


func _construir_cuerpo() -> void:
	# El GLB se estira por eje: redondo en planta y de la altura pedida.
	var modelo := MODELO_BARRIL.instantiate() as Node3D
	modelo.name = "Modelo"
	modelo.scale = Vector3(tamano.x / MEDIDAS_BARRIL.x, tamano.y / MEDIDAS_BARRIL.y,
		tamano.z / MEDIDAS_BARRIL.z)
	add_child(modelo)


func _forma_por_defecto() -> Shape3D:
	var cilindro := CylinderShape3D.new()
	cilindro.radius = tamano.x * 0.46
	cilindro.height = tamano.y
	return cilindro


func _altura_forma() -> float:
	return tamano.y
