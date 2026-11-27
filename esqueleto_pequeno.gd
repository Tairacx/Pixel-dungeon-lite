extends "res://perseguidor.gd"
# Esqueleto pequeño: enemigo común de las salas.
# Patrulla alrededor del punto donde lo pongas, persigue al héroe si lo ve y muere en pocos golpes.
# Hereda de perseguidor.gd (patrulla, rodeo y persecución); aquí se agrega la vida y
# su sello propio: se acerca en zigzag y hace una micro-retirada después de golpear.
# La espada del héroe (apuntar.gd) lo daña llamando recibir_golpe().

signal vida_cambiada(vida: int, maxima: int)
signal murio

@export var vida_maxima := 2
@export var radio_patrulla := 1.8      # m: patrulla de un lado a otro de donde lo pongas
@export var altura_barra := 1.55       # m: altura de su barrita de vida

@export_group("Astucia")
@export var micro_retirada := 0.4      # s que se aparta después de golpear
@export var zigzag_angulo := 20.0      # grados del serpenteo al acercarse
@export var zigzag_periodo := 0.7      # s de un lado al otro del zigzag

const ANCHO_BARRA := 0.7

var vida := 2
var _muerto := false
var _barra: Node3D
var _relleno: QuadMesh
var _t_retirada := 0.0
var _t_retirada_lista := 0.0
var _fase_zigzag := 0.0


func _physics_process(delta: float) -> void:
	# Micro-retirada: pega y se aparta un instante (lee como inteligente y da respiro).
	if not _muerto and _t_retirada > 0.0:
		_t_retirada = maxf(_t_retirada - delta, 0.0)
		retroceder(delta, 0.7)
		return
	super(delta)
	if _muerto or objetivo == null:
		return
	_t_retirada_lista = maxf(_t_retirada_lista - delta, 0.0)
	if _t_retirada_lista <= 0.0 and aturdido <= 0.0 and _distancia() <= distancia_golpe - 0.1:
		_t_retirada = micro_retirada
		_t_retirada_lista = 1.4


# Serpentea mientras se acerca: el acercamiento no es una línea recta.
func _direccion_persecucion(hacia: Vector3, dist: float, delta: float) -> Vector3:
	var dir := super(hacia, dist, delta)
	if dist > distancia_preferida:
		_fase_zigzag += delta * TAU / maxf(zigzag_periodo, 0.1)
		dir = dir.rotated(Vector3.UP, sin(_fase_zigzag) * deg_to_rad(zigzag_angulo))
	return dir


func _ready() -> void:
	vida = vida_maxima
	_fase_zigzag = randf() * TAU
	add_to_group("esqueletos")
	if objetivo == null:
		objetivo = get_tree().current_scene.get_node_or_null("Personaje")
	if objetivo == null:
		push_warning("EsqueletoPequeno: no encontré al Personaje; se queda quieto.")
		set_physics_process(false)
		return
	# perseguidor.gd usa puntos del MUNDO: se arman alrededor de donde está puesto.
	var centro := global_position
	var ruta: Array[Vector3] = [centro + Vector3(radio_patrulla, 0, 0),
		centro - Vector3(radio_patrulla, 0, 0)]
	puntos = ruta
	_crear_barra()


# La llama apuntar.gd (la espada del héroe) cuando su rayo le da.
func recibir_golpe(danio: int) -> void:
	if _muerto:
		return
	vida = maxi(vida - danio, 0)
	vida_cambiada.emit(vida, vida_maxima)
	_actualizar_barra()
	_parpadear()
	aturdir(aturdimiento)
	if vida == 0:
		_morir()


func _morir() -> void:
	_muerto = true
	murio.emit()
	set_physics_process(false)
	velocity = Vector3.ZERO
	if _barra != null:
		_barra.visible = false
	if has_node("Garra"):
		$Garra.queue_free()                 # ya no hace daño por contacto
	$CollisionShape3D.set_deferred("disabled", true)
	if anim.has_animation("die"):
		anim.play("die")
	get_tree().create_timer(1.5).timeout.connect(queue_free)


func _parpadear() -> void:
	var modelo := get_node_or_null("Modelo")
	if modelo == null:
		return
	modelo.visible = false
	await get_tree().create_timer(0.07).timeout
	if is_instance_valid(modelo):
		modelo.visible = true


# Barrita sobre la cabeza: aparece al recibir el primer golpe.
func _crear_barra() -> void:
	_barra = Node3D.new()
	_barra.position = Vector3(0, altura_barra, 0)
	_barra.visible = false
	add_child(_barra)
	_barra.add_child(_quad(Vector2(ANCHO_BARRA + 0.06, 0.12), Color("#1B1626"), 0))
	var rell := _quad(Vector2(ANCHO_BARRA, 0.08), Color("#D63A3A"), 1)
	_relleno = rell.mesh
	_barra.add_child(rell)


func _quad(tam: Vector2, color: Color, prioridad: int) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = tam
	m.mesh = q
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.render_priority = prioridad
	m.material_override = mat
	return m


func _actualizar_barra() -> void:
	if _barra == null or _relleno == null:
		return
	_barra.visible = vida > 0
	var w := ANCHO_BARRA * float(vida) / float(maxi(vida_maxima, 1))
	_relleno.size = Vector2(maxf(w, 0.001), 0.08)
	_relleno.center_offset = Vector3(-(ANCHO_BARRA - w) / 2.0, 0, 0)   # se vacía hacia la izquierda
