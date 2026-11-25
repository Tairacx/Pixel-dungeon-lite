class_name Barril
extends "res://contenedor_rompible.gd"
# Barril de contenido aleatorio: casi siempre corazones y, de vez en cuando, un arma.
# Se rompe con la espada (recibir_golpe) y avisa al SistemaEventos para el destello.

# Modelo Kenney "Mini Dungeon" (CC0). Ya viene apoyado en el piso (Y = 0).
const MODELO_BARRIL := preload("res://objetos/kenney/barrel.glb")
# Medidas reales del GLB, solo para escalarlo a "tamano".
const MEDIDAS_BARRIL := Vector3(0.5176, 0.4762, 0.5176)

# Probabilidades del contenido. El resto de los casos da 1 o 2 corazones.
@export_range(0.0, 1.0, 0.01) var probabilidad_arma := 0.04
@export_range(0.0, 1.0, 0.01) var probabilidad_arma_y_corazon := 0.02
@export_range(0.0, 1.0, 0.01) var probabilidad_dos_corazones := 0.30


func _ready() -> void:
	add_to_group("detalles_camara")   # la cámara destapa la pared si el barril queda tapado
	# Contenido aleatorio en cada barril:
	#   2%  -> 1 corazón + 1 arma
	#   4%  -> 1 arma
	#   resto -> 1 corazón (70%) o 2 corazones (30%)
	var r := randf()
	if r < probabilidad_arma_y_corazon:
		corazones_al_romper = 1
		armas_al_romper = 1
	elif r < probabilidad_arma_y_corazon + probabilidad_arma:
		corazones_al_romper = 0
		armas_al_romper = 1
	else:
		armas_al_romper = 0
		corazones_al_romper = 2 if randf() < probabilidad_dos_corazones else 1
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
