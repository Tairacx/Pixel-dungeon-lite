class_name Cofre
extends StaticBody3D
# Cofre que se abre con la tecla E al acercarse y regala un premio.
# No se rompe a espadazos: se abre una sola vez y queda abierto.
#
# Recompensa (elegible en el Inspector):
#   CORAZON   -> cura un corazón.
#   ATAQUE    -> sube el daño de la espada en "ataque_bonus".
#   ALEATORIO -> elige al azar entre los dos (probabilidad_ataque).
#
# Mientras el héroe está cerca aparece un aviso ("E" + "Abrir") encima del cofre.

enum Recompensa { CORAZON, ATAQUE, ALEATORIO }

@export var recompensa := Recompensa.CORAZON
@export var corazones := 1.0              # corazones que regala (1.0 = un corazón)
@export var ataque_bonus := 2             # daño extra si la recompensa es ATAQUE
@export var probabilidad_ataque := 0.12   # chance de ATAQUE si recompensa == ALEATORIO
@export var radio_interaccion := 1.6      # m: a esta distancia aparece el aviso y se puede abrir
@export var color_cuerpo := Color("#6B3E1F")
@export var color_tapa := Color("#7A4A24")
@export var color_detalle := Color("#C9A227")
@export var tamano := Vector3(0.85, 0.55, 0.65)

var abierto := false
var jugador_cerca := false

var _tapa_pivote: Node3D
var _aviso_e: Label3D
var _aviso_texto: Label3D
var _zona: Area3D


func _ready() -> void:
	if recompensa == Recompensa.ALEATORIO:
		recompensa = Recompensa.ATAQUE if randf() < probabilidad_ataque else Recompensa.CORAZON
	var vista := get_node_or_null("VistaEditor")
	if vista != null:
		vista.visible = false
	_asegurar_forma()
	_construir_cuerpo()
	_asegurar_zona()
	_crear_avisos()


func _physics_process(_delta: float) -> void:
	if not abierto and jugador_cerca and Input.is_action_just_pressed("abrir"):
		_abrir()


# ---------------------------------------------------------------------------
# Interacción
# ---------------------------------------------------------------------------
func _on_cuerpo_entra(cuerpo: Node3D) -> void:
	if cuerpo.is_in_group("jugador"):
		jugador_cerca = true
		_actualizar_aviso()


func _on_cuerpo_sale(cuerpo: Node3D) -> void:
	if cuerpo.is_in_group("jugador"):
		jugador_cerca = false
		_actualizar_aviso()


func _actualizar_aviso() -> void:
	var mostrar := jugador_cerca and not abierto
	_aviso_e.visible = mostrar
	_aviso_texto.visible = mostrar


func _abrir() -> void:
	var pj := get_tree().get_first_node_in_group("jugador") as Node3D
	if pj == null:
		return
	match recompensa:
		Recompensa.CORAZON:
			if not _abrir_corazon(pj):
				return
		Recompensa.ATAQUE:
			_abrir_ataque(pj)
	abierto = true
	_actualizar_aviso()
	_zona.set_deferred("monitoring", false)
	_animar_apertura()


func _abrir_corazon(pj: Node3D) -> bool:
	var salud := pj.get_node_or_null("Salud")
	if salud == null:
		return false
	if salud.vida >= float(salud.maxima):
		_avisar_hud("La vida ya está llena")
		return false
	var sano: float = salud.curar(corazones)
	if sano > 0.0:
		_avisar_hud("+" + str(snappedf(sano, 0.5)) + " de vida")
	return true


func _abrir_ataque(pj: Node3D) -> void:
	var apuntar := pj.get_node_or_null("Apuntar")
	if apuntar == null or not apuntar.has_method("subir_ataque"):
		_avisar_hud("No hay espada que mejorar")
		return
	apuntar.subir_ataque(ataque_bonus)
	_avisar_hud("+" + str(ataque_bonus) + " de ataque")


func _animar_apertura() -> void:
	var t := create_tween()
	t.tween_property(_tapa_pivote, "rotation:x", -1.9, 0.45)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _avisar_hud(texto: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("mostrar_aviso"):
		hud.mostrar_aviso(texto)


# ---------------------------------------------------------------------------
# Forma y dibujo (todo con mallas simples, como el resto del juego)
# ---------------------------------------------------------------------------
func _asegurar_forma() -> void:
	var forma := get_node_or_null("Forma") as CollisionShape3D
	if forma == null:
		forma = CollisionShape3D.new()
		forma.name = "Forma"
		add_child(forma)
	if forma.shape == null:
		var caja := BoxShape3D.new()
		caja.size = tamano
		forma.shape = caja
		forma.position = Vector3(0, tamano.y * 0.5, 0)


func _construir_cuerpo() -> void:
	var alto := tamano.y
	# Cuerpo de madera
	_caja(Vector3(tamano.x, alto, tamano.z), Vector3(0, alto * 0.5, 0), color_cuerpo)
	# Fleje metálico en la base
	_caja(Vector3(tamano.x * 1.02, 0.07, tamano.z * 1.02),
		Vector3(0, alto * 0.12, 0), color_detalle)
	# Cerradura al frente
	_caja(Vector3(0.12, 0.16, 0.05),
		Vector3(0, alto * 0.55, tamano.z * 0.5 + 0.02), color_detalle, Color("#4A2A08"))
	# Tapa con pivote en el borde trasero (para que gire al abrirse)
	_tapa_pivote = Node3D.new()
	_tapa_pivote.name = "TapaPivote"
	_tapa_pivote.position = Vector3(0, alto, -tamano.z * 0.5)
	add_child(_tapa_pivote)
	_caja_en(_tapa_pivote,
		Vector3(tamano.x * 1.04, 0.14, tamano.z * 1.02),
		Vector3(0, 0.07, tamano.z * 0.5), color_tapa)
	# Cierre metálico de la tapa
	_caja_en(_tapa_pivote,
		Vector3(0.14, 0.10, 0.06),
		Vector3(0, -0.02, tamano.z * 0.5 + 0.01), color_detalle)


func _asegurar_zona() -> void:
	_zona = get_node_or_null("ZonaInteraccion") as Area3D
	if _zona == null:
		_zona = Area3D.new()
		_zona.name = "ZonaInteraccion"
		add_child(_zona)
	_zona.collision_layer = 0
	_zona.collision_mask = 8          # solo detecta al Personaje (capa 8)
	var forma := _zona.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if forma == null:
		forma = CollisionShape3D.new()
		forma.name = "CollisionShape3D"
		_zona.add_child(forma)
	if forma.shape == null:
		var esfera := SphereShape3D.new()
		esfera.radius = radio_interaccion
		forma.shape = esfera
		forma.position = Vector3(0, tamano.y * 0.5, 0)
	_zona.body_entered.connect(_on_cuerpo_entra)
	_zona.body_exited.connect(_on_cuerpo_sale)


func _crear_avisos() -> void:
	_aviso_e = _label("E", 64, Color(1.0, 0.85, 0.3), Vector3(0, tamano.y + 0.55, 0))
	_aviso_texto = _label("Abrir", 32, Color(1.0, 0.96, 0.85), Vector3(0, tamano.y + 0.18, 0))


func _label(texto: String, tam_fuente: int, color: Color, pos: Vector3) -> Label3D:
	var etiqueta := Label3D.new()
	etiqueta.text = texto
	etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	etiqueta.no_depth_test = true
	etiqueta.font_size = tam_fuente
	etiqueta.pixel_size = 0.01
	etiqueta.modulate = color
	etiqueta.outline_size = 12
	etiqueta.outline_modulate = Color(0.1, 0.08, 0.05)
	etiqueta.position = pos
	etiqueta.visible = false
	add_child(etiqueta)
	return etiqueta


func _material(color: Color, emision := Color.BLACK) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if emision != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = emision
		mat.emission_energy_multiplier = 1.0
	return mat


func _caja(tam: Vector3, pos: Vector3, color: Color, emision := Color.BLACK) -> MeshInstance3D:
	var caja := BoxMesh.new()
	caja.size = tam
	var nodo := MeshInstance3D.new()
	nodo.mesh = caja
	nodo.position = pos
	nodo.material_override = _material(color, emision)
	add_child(nodo)
	return nodo


func _caja_en(padre: Node, tam: Vector3, pos: Vector3, color: Color,
		emision := Color.BLACK) -> MeshInstance3D:
	var caja := BoxMesh.new()
	caja.size = tam
	var nodo := MeshInstance3D.new()
	nodo.mesh = caja
	nodo.position = pos
	nodo.material_override = _material(color, emision)
	padre.add_child(nodo)
	return nodo
