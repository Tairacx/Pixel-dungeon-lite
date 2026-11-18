extends Node
# El daño de la espada: lanza un rayo corto hacia adelante, pero SOLO cuando la espada
# baja (Espada.golpe, en el momento justo de la animación). Un clic = un golpe.

@export var alcance = 1.6
@export_enum("Personaje", "Centro de la cámara", "Mouse") var desde = 0
@export var danio = 1
# Barrido lateral: el golpe alcanza todo lo que esté dentro de este arco frente al héroe
# (180° = de su lado izquierdo a su lado derecho). Solo se usa con desde = "Personaje".
@export_range(10.0, 360.0, 5.0) var arco_grados := 180.0

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
	if desde == 0:
		_barrido_lateral()
		return
	var impacto = lanzar_rayo()
	if impacto.is_empty():
		print("no le dio a nada en ", alcance, " m")
		return

	var d = snappedf(origen.distance_to(impacto.position), 0.01)
	print("le dio a ", impacto.collider.name, " a ", d, " m")

	if impacto.collider.has_method("recibir_golpe"):
		impacto.collider.recibir_golpe(danio)


# Golpe en arco: todo lo que esté a menos de "alcance" y dentro del arco frente al
# héroe recibe el golpe (una vez por cuerpo). Un muro entre el héroe y el objetivo lo protege.
func _barrido_lateral():
	origen = pj.global_position + Vector3(0, 0.8, 0)
	var adelante: Vector3 = -pj.global_basis.z
	adelante.y = 0.0
	adelante = adelante.normalized()
	var mitad_arco := deg_to_rad(arco_grados) * 0.5

	var esfera := SphereShape3D.new()
	esfera.radius = alcance
	var zona := PhysicsShapeQueryParameters3D.new()
	zona.shape = esfera
	zona.transform = Transform3D(Basis(), origen)
	zona.exclude = [pj.get_rid()]
	var espacio = pj.get_world_3d().direct_space_state

	var golpeados := {}   # un cuerpo con varias formas no recibe el golpe dos veces
	for cercano in espacio.intersect_shape(zona, 32):
		var cuerpo = cercano.collider
		if cuerpo == null or golpeados.has(cuerpo.get_instance_id()):
			continue
		if not cuerpo.has_method("recibir_golpe") or not (cuerpo is Node3D):
			continue

		# ¿Está dentro del arco? (se mide en el plano del suelo)
		var hacia: Vector3 = cuerpo.global_position - pj.global_position
		hacia.y = 0.0
		if hacia.length() > 0.05 and adelante.angle_to(hacia.normalized()) > mitad_arco:
			continue

		# ¿Hay un muro o algo sólido en medio?
		var punto := Vector3(cuerpo.global_position.x, origen.y, cuerpo.global_position.z)
		var vista := PhysicsRayQueryParameters3D.create(origen, punto)
		vista.exclude = [pj.get_rid()]
		var tapa = espacio.intersect_ray(vista)
		if not tapa.is_empty() and tapa.collider != cuerpo:
			continue

		golpeados[cuerpo.get_instance_id()] = true
		print("le dio a ", cuerpo.name, " a ", snappedf(origen.distance_to(punto), 0.01), " m")
		cuerpo.recibir_golpe(danio)

	if golpeados.is_empty():
		print("no le dio a nada en ", alcance, " m (arco ", arco_grados, "°)")


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
