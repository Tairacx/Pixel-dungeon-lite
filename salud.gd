extends Node
# Vida del héroe, en corazones. Es un nodo hijo del Personaje (Personaje/Salud).
# Quien haga daño llama:  salud.recibir_danio(cantidad, desde_donde)
# El HUD y la luz de corazones (SistemaEventos) escuchan los cambios.

signal cambio(vida: float, maxima: int)   # cada vez que cambia la vida
signal dano_recibido(cantidad: float)     # solo cuando de verdad perdió vida
signal curado(cantidad: float)            # solo cuando de verdad recuperó vida
signal murio

@export var maxima := 5
@export var invulnerable_tras_golpe := 1.0   # s sin recibir daño después de un golpe
@export var empuje := 7.0                    # m/s hacia atrás al recibir un golpe
@export var sistema_eventos: Node            # opcional: SistemaEventos (la luz sigue a los corazones)

@onready var pj = get_parent()
@onready var modelo = pj.get_node_or_null("Modelo")

var vida := 5.0   # en corazones; 0.5 = medio corazón
var muerto := false
var _inv := 0.0


func _ready() -> void:
	vida = float(maxima)
	if sistema_eventos == null:
		sistema_eventos = get_tree().current_scene.get_node_or_null("SistemaEventos")
	_avisar()


func _process(delta: float) -> void:
	if _inv > 0.0:
		_inv = maxf(_inv - delta, 0.0)
		if modelo != null and not muerto:
			# parpadeo mientras es invulnerable
			modelo.visible = _inv <= 0.0 or int(_inv * 14.0) % 2 == 0


# Devuelve true si el golpe entró (false si era invulnerable o ya estaba muerto).
func recibir_danio(cantidad := 1.0, desde := Vector3.ZERO) -> bool:
	if muerto or _inv > 0.0:
		return false
	vida = maxf(vida - cantidad, 0.0)
	_inv = invulnerable_tras_golpe
	dano_recibido.emit(cantidad)
	_avisar()
	if vida <= 0.0:
		_morir()
	else:
		_empujar(desde)
	return true


# Cura sin pasarse del máximo. Devuelve cuánta vida se recuperó de verdad
# (0.0 si ya estaba llena o si el héroe está muerto). La usan los recolectables.
func curar(cantidad := 1.0) -> float:
	if muerto or cantidad <= 0.0:
		return 0.0
	var antes := vida
	vida = minf(vida + cantidad, float(maxima))
	var sano := vida - antes
	if sano > 0.0:
		_avisar()
		curado.emit(sano)
	return sano


func _empujar(desde: Vector3) -> void:
	if desde == Vector3.ZERO:
		return
	var dir = pj.global_position - desde
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	pj.empuje = dir.normalized() * empuje
	get_tree().create_timer(0.15).timeout.connect(func(): pj.empuje = Vector3.ZERO)


func _morir() -> void:
	muerto = true
	pj.empuje = Vector3.ZERO
	pj.multiplicador = 0.0
	if modelo != null:
		modelo.visible = true
	# Sin _physics_process el personaje deja de mandarse animaciones y de moverse.
	pj.set_physics_process(false)
	for nombre in ["Espada", "Apuntar"]:
		var nodo = pj.get_node_or_null(nombre)
		if nodo != null:
			nodo.set_physics_process(false)
	var anim = pj.get_node_or_null("Modelo/AnimationPlayer")
	if anim != null and anim.has_animation("die"):
		anim.play("die")
	murio.emit()


func _avisar() -> void:
	cambio.emit(vida, maxima)
	if sistema_eventos != null:
		sistema_eventos.corazones_max = maxima
		sistema_eventos.set_corazones(vida)
