extends Node
# El daño de la espada: lanza un rayo corto hacia adelante, pero SOLO cuando la espada
# baja (Espada.golpe, en el momento justo de la animación). Un clic = un golpe.

@export var alcance = 1.6
@export_enum("Personaje", "Centro de la cámara", "Mouse") var desde = 0
@export var danio = 1

# Mejoras que dan las armas recolectables (recolectable_arma.gd).
@export var max_mejoras := 4
@export var danio_por_mejora := 1
@export var alcance_por_mejora := 0.12

@onready var pj = get_parent()
var origen = Vector3.ZERO
var mejoras := 0


func _ready():
	var espada = pj.get_node_or_null("Espada")
	if espada == null:
		push_warning("Apuntar: no encontré el nodo Espada; no habrá daño.")
		return
	espada.golpe.connect(_on_golpe)


# Sube el nivel de la espada. Devuelve false si ya está al máximo.
func mejorar(cantidad := 1) -> bool:
	if mejoras >= max_mejoras:
		return false
	var antes := mejoras
	mejoras = mini(mejoras + cantidad, max_mejoras)
	var subidas := mejoras - antes
	danio += danio_por_mejora * subidas
	alcance += alcance_por_mejora * float(subidas)
	var arma := pj.get_node_or_null("Arma")
	if arma != null and arma.has_method("aplicar_mejora"):
		arma.aplicar_mejora(mejoras)
	print("Arma mejorada al nivel ", mejoras, " · daño ", danio, " · alcance ",
		snappedf(alcance, 0.01), " m")
	return true


func al_maximo() -> bool:
	return mejoras >= max_mejoras


# Sube solo el daño (ataque), sin tocar el alcance ni el nivel de mejora.
# La usan los cofres de ataque. Devuelve el daño nuevo.
func subir_ataque(cantidad: int) -> int:
	danio += cantidad
	print("Ataque +", cantidad, " · daño ", danio)
	return danio


func _on_golpe():
	var impacto = lanzar_rayo()
	if impacto.is_empty():
		print("no le dio a nada en ", alcance, " m")
		return

	var d = snappedf(origen.distance_to(impacto.position), 0.01)
	print("le dio a ", impacto.collider.name, " a ", d, " m")

	if impacto.collider.has_method("recibir_golpe"):
		impacto.collider.recibir_golpe(danio)


func lanzar_rayo():
	var hacia
	if desde == 0:
		origen = pj.global_position + Vector3(0, 0.8, 0)
		hacia = origen - pj.global_basis.z * alcance
	else:
		var cam = get_viewport().get_camera_3d()
		var punto = get_viewport().get_visible_rect().size / 2
		if desde == 2:
			punto = get_viewport().get_mouse_position()
		origen = cam.project_ray_origin(punto)
		hacia = origen + cam.project_ray_normal(punto) * alcance

	var consulta = PhysicsRayQueryParameters3D.create(origen, hacia)
	consulta.exclude = [pj.get_rid()]
	return pj.get_world_3d().direct_space_state.intersect_ray(consulta)
