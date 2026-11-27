class_name ArmaRecolectable
extends "res://recolectable.gd"
# Arma que se recoge para mejorar la espada del héroe.
# Cada arma sube un nivel: más daño y un poco más de alcance (Apuntar.mejorar()).
# Cuando la espada ya está al máximo, el arma no se recoge y queda en el piso.

@export var mejoras := 1

@export var color_hoja := Color("#BFE9FF")
@export var color_brillo := Color("#46D9FF")
@export var color_guarda := Color("#F2A33A")
@export var color_mango := Color("#3F3552")


func _construir() -> void:
	# Mango
	_caja(Vector3(0.06, 0.20, 0.06), Vector3(0, -0.22, 0), color_mango)
	# Pomo
	_caja(Vector3(0.09, 0.07, 0.09), Vector3(0, -0.34, 0), color_guarda)
	# Guarda (cruceta)
	_caja(Vector3(0.30, 0.05, 0.08), Vector3(0, -0.10, 0), color_guarda)
	# Hoja
	_caja(Vector3(0.10, 0.48, 0.035), Vector3(0, 0.15, 0), color_hoja, color_brillo)
	# Pico de la hoja
	_caja(Vector3(0.06, 0.09, 0.035), Vector3(0, 0.43, 0), color_hoja, color_brillo)


func puede_recoger(pj: Node3D) -> bool:
	var apuntar := pj.get_node_or_null("Apuntar")
	if apuntar == null or not apuntar.has_method("mejorar"):
		return false
	return not apuntar.al_maximo()


func _aplicar(pj: Node3D) -> String:
	var apuntar := pj.get_node_or_null("Apuntar")
	if apuntar == null or not apuntar.has_method("mejorar"):
		return ""
	var antes: int = apuntar.mejoras
	if not apuntar.mejorar(mejoras):
		return ""
	return "Espada +" + str(apuntar.mejoras - antes)
