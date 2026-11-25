class_name Cofre
extends StaticBody3D
# Cofre que se abre con la tecla E al acercarse y regala un premio.
# No se rompe a espadazos: se abre una sola vez y queda abierto.
#
# Recompensa (elegible en el Inspector):
#   CORAZON   -> cura uno o dos corazones.
#   ATAQUE    -> sube el daño de la espada en "ataque_bonus".
#   ARMA      -> suelta un arma para mejorar la espada.
#   ALEATORIO -> elige al azar entre las tres anteriores, con estas probabilidades:
#                probabilidad_arma, después probabilidad_ataque, el resto corazón.
# Mientras el héroe está cerca aparece un aviso ("E" + "Abrir") encima del cofre.

enum Recompensa { CORAZON, ATAQUE, ALEATORIO, ARMA }

@export var recompensa := Recompensa.CORAZON
@export var corazones := 1.0              # corazones que regala (1.0 = un corazón)
@export var ataque_bonus := 2             # daño extra si la recompensa es ATAQUE
@export var probabilidad_ataque := 0.10   # chance de ATAQUE si recompensa == ALEATORIO
@export var probabilidad_arma := 0.05     # chance de ARMA si recompensa == ALEATORIO
@export var radio_interaccion := 1.6      # m: a esta distancia aparece el aviso y se puede abrir
@export var color_cuerpo := Color("#6B3E1F")
@export var color_tapa := Color("#7A4A24")
@export var color_detalle := Color("#C9A227")
@export var tamano := Vector3(0.85, 0.55, 0.65)

# Modelo Kenney "Mini Dungeon" (CC0): cofre con tapa animada ("open").
const MODELO_COFRE := preload("res://objetos/kenney/chest.glb")
# Medidas reales del GLB; el ancho manda la escala (uniforme, sin deformar).
const MEDIDAS_COFRE := Vector3(0.5, 0.45, 0.5)
const ESCENA_ARMA := preload("res://recolectable_arma.tscn")

var abierto := false
var jugador_cerca := false

var _modelo: Node3D
var _aviso_e: Label3D
var _aviso_texto: Label3D
var _zona: Area3D


func _ready() -> void:
	add_to_group("detalles_camara")   # la cámara destapa la pared si el cofre queda tapado
	if recompensa == Recompensa.ALEATORIO:
		var r := randf()
		if r < probabilidad_arma:
			recompensa = Recompensa.ARMA
		elif r < probabilidad_arma + probabilidad_ataque:
			recompensa = Recompensa.ATAQUE
		else:
			recompensa = Recompensa.CORAZON
	if recompensa == Recompensa.CORAZON and randf() < 0.25:
		corazones = 2.0
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
		Recompensa.ARMA:
			_abrir_arma(pj)
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


func _abrir_arma(pj: Node3D) -> void:
	# Si la espada ya está al máximo, el arma no serviría: damos ataque extra.
	var apuntar := pj.get_node_or_null("Apuntar")
	if apuntar != null and apuntar.has_method("al_maximo") and apuntar.al_maximo():
		_abrir_ataque(pj)
		return
	var padre := get_parent()
	if padre == null:
		return
	var arma := ESCENA_ARMA.instantiate()
	padre.add_child(arma)
	if arma is Node3D:
		arma.global_position = global_position + Vector3.UP * 0.8
	_avisar_hud("¡Arma encontrada!")


func _animar_apertura() -> void:
	# La tapa la anima el propio GLB ("open"). Si el modelo no la trae, no pasa nada.
	if _modelo == null:
		return
	var animador := _modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animador != null and animador.has_animation("open"):
		animador.play("open")


func _avisar_hud(texto: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("mostrar_aviso"):
		hud.mostrar_aviso(texto)


# ---------------------------------------------------------------------------
# Forma y modelo
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
	# Escala uniforme por el ancho: el cofre no se deforma y queda apoyado en el piso.
	_modelo = MODELO_COFRE.instantiate() as Node3D
	_modelo.name = "Modelo"
	_modelo.scale = Vector3.ONE * (tamano.x / MEDIDAS_COFRE.x)
	add_child(_modelo)


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
	# El modelo 3D es más alto que tamano.y: los avisos despegan del techo visible.
	var alto := maxf(tamano.y, MEDIDAS_COFRE.y * (tamano.x / MEDIDAS_COFRE.x))
	_aviso_e = _label("E", 64, Color(1.0, 0.85, 0.3), Vector3(0, alto + 0.55, 0))
	_aviso_texto = _label("Abrir", 32, Color(1.0, 0.96, 0.85), Vector3(0, alto + 0.18, 0))


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
