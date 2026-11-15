class_name Recolectable
extends Area3D
# Base de todos los objetos que se recogen al tocarlos.
# Flotan, giran y se acercan al héroe cuando está cerca (imán).
# Cada hijo decide qué pasa al recogerse sobrescribiendo:
#   _construir()        -> arma las mallas del objeto
#   puede_recoger(pj)   -> false = se queda en el piso (ej.: corazón con vida llena)
#   _aplicar(pj)        -> efecto real; devuelve el texto que muestra el HUD
#
# Capa 0 / máscara 8: solo detecta al Personaje (que está en la capa 8).

signal recogido(por: Node3D)

@export var retardo_recogida := 0.35   # s: evita recogerlo en el mismo cuadro en que aparece
@export var flotar_altura := 0.10      # m: cuánto sube y baja
@export var flotar_velocidad := 2.0    # rad/s del vaivén
@export var girar_velocidad := 1.4     # rad/s; 0 = no gira
@export var iman_distancia := 2.2      # m: desde aquí se acerca solo al héroe
@export var iman_rapidez := 7.0        # m/s

var _tiempo := 0.0
var _base_y := 0.0
var _listo := false
var _recogido := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 8
	monitoring = true
	_base_y = position.y
	_tiempo = randf() * TAU
	add_to_group("recolectables")
	var vista := get_node_or_null("VistaEditor")   # malla de referencia del editor
	if vista != null:
		vista.visible = false
	_construir()
	body_entered.connect(_on_body_entered)
	_listo = retardo_recogida <= 0.0
	if not _listo:
		get_tree().create_timer(retardo_recogida).timeout.connect(func(): _listo = true)


func _process(delta: float) -> void:
	if _recogido:
		return
	_tiempo += delta
	if girar_velocidad != 0.0:
		rotate_y(girar_velocidad * delta)

	var pj := _buscar_jugador()
	var atraido := false
	if pj != null and _listo and puede_recoger(pj):
		var objetivo: Vector3 = pj.global_position + Vector3.UP * 0.9
		var distancia := global_position.distance_to(objetivo)
		if distancia < iman_distancia:
			atraido = true
			global_position = global_position.move_toward(objetivo, iman_rapidez * delta)
			if distancia < 0.45:
				_recoger(pj)

	if not atraido:
		position.y = _base_y + sin(_tiempo * flotar_velocidad) * flotar_altura


func _on_body_entered(cuerpo: Node3D) -> void:
	if _recogido or not _listo:
		return
	if cuerpo.is_in_group("jugador"):
		_recoger(cuerpo)


func _buscar_jugador() -> Node3D:
	return get_tree().get_first_node_in_group("jugador") as Node3D


func _recoger(pj: Node3D) -> void:
	if _recogido or not puede_recoger(pj):
		return
	_recogido = true
	set_deferred("monitoring", false)
	var texto := _aplicar(pj)
	recogido.emit(pj)
	_avisar_hud(texto)
	_desaparecer()


func _desaparecer() -> void:
	set_process(false)
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "position:y", position.y + 0.45, 0.22)
	t.tween_property(self, "scale", Vector3.ONE * 0.05, 0.22)
	t.chain().tween_callback(queue_free)


func _avisar_hud(texto: String) -> void:
	if texto == "":
		return
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("mostrar_aviso"):
		hud.mostrar_aviso(texto)


# ---------------------------------------------------------------------------
# Enchufes para los hijos
# ---------------------------------------------------------------------------
func _construir() -> void:
	pass


func puede_recoger(_pj: Node3D) -> bool:
	return true


func _aplicar(_pj: Node3D) -> String:
	return ""


# ---------------------------------------------------------------------------
# Ayudas de dibujo (todo se arma con mallas simples, como el resto del juego)
# ---------------------------------------------------------------------------
func _malla(malla: Mesh, pos: Vector3, color: Color, emision := Color.BLACK) -> MeshInstance3D:
	var nodo := MeshInstance3D.new()
	nodo.mesh = malla
	nodo.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.55
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if emision != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = emision
		mat.emission_energy_multiplier = 1.1
	nodo.material_override = mat
	add_child(nodo)
	return nodo


func _caja(tam: Vector3, pos: Vector3, color: Color, emision := Color.BLACK) -> MeshInstance3D:
	var caja := BoxMesh.new()
	caja.size = tam
	return _malla(caja, pos, color, emision)
