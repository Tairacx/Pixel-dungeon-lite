extends "res://esqueleto_pequeno.gd"
# Esqueleto Pícaro: enemigo rápido (KayKit Skeleton_Rogue).
# Comportamiento normal: patrulla y persigue para pegar cuerpo a cuerpo, como el
# pequeño de siempre pero más veloz.
# Habilidad OCASIONAL: EMBESTIDA. Si el héroe está a la vista y cerca, se detiene
# un instante (aviso), hace un destello rojo y embiste en línea recta; mientras
# embiste su daño de contacto sube de ½ a 1 corazón. No la usa siempre: tira los
# dados cada "cooldown_embestida" segundos y solo si sale "probabilidad_embestida".

@export_range(0.0, 1.0, 0.05) var probabilidad_embestida := 0.4
@export var cooldown_embestida := 6.0        # s entre intentos de embestida
@export var distancia_embestida := 8.0       # m: solo embiste si el héroe está más cerca que esto
@export var rapidez_embestida := 9.0          # m/s del embestón
@export var aviso_embestida := 0.3           # s quieto antes de lanzarse (para poder esquivar)

var _t_proximo_intento := 3.0
var _cargando := 0.0
var _embistiendo := 0.0
var _dir_embestida := Vector3.ZERO
var _luz_aviso: OmniLight3D


func _ready() -> void:
	super()
	_t_proximo_intento = cooldown_embestida * 0.5


func _physics_process(delta: float) -> void:
	if _cargando > 0.0:
		_cargando -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		velocity += get_gravity() * delta
		move_and_slide()
		if _cargando <= 0.0:
			_lanzarse()
		return
	if _embistiendo > 0.0:
		_embistiendo -= delta
		velocity += get_gravity() * delta
		velocity.x = _dir_embestida.x * rapidez_embestida
		velocity.z = _dir_embestida.z * rapidez_embestida
		move_and_slide()
		if _embistiendo <= 0.0:
			_terminar_embestida()
		return

	# Comportamiento normal (patrulla / persecución) + dado de la embestida.
	super(delta)
	if objetivo == null or vida <= 0:
		return
	_t_proximo_intento -= delta
	if _t_proximo_intento > 0.0:
		return
	_t_proximo_intento = cooldown_embestida
	if randf() > probabilidad_embestida:
		return   # esta vez no: sigue pegando de manera normal
	var dist := global_position.distance_to(objetivo.global_position)
	if dist <= distancia_embestida and _hay_linea_de_vision():
		_cargar()


func _hay_linea_de_vision() -> bool:
	var espacio := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 0.9, objetivo.global_position + Vector3.UP * 0.9)
	q.exclude = [get_rid(), (objetivo as CollisionObject3D).get_rid()]   # sin excluir al héroe, el rayo chocaba contra él
	return espacio.intersect_ray(q).is_empty()


func _cargar() -> void:
	_cargando = aviso_embestida
	aturdir(aviso_embestida + 0.05)   # se frena mientras carga
	_dir_embestida = objetivo.global_position - global_position
	_dir_embestida.y = 0.0
	_dir_embestida = _dir_embestida.normalized()
	_aviso_rojo()


func _lanzarse() -> void:
	aturdido = 0.0   # el wind-up ya cumplió su función: que no se congele tras la embestida
	_embistiendo = 0.35
	basis = Basis.looking_at(_dir_embestida)
	var garra = get_node_or_null("Garra")
	if garra != null:
		garra.danio = 1.0            # embistiendo pega un corazón entero
	if _luz_aviso != null:
		_luz_aviso.visible = false


func _terminar_embestida() -> void:
	var garra = get_node_or_null("Garra")
	if garra != null:
		garra.danio = 0.5            # vuelve al daño normal
	if _luz_aviso != null:
		_luz_aviso.visible = false


# Destello rojo sobre la cabeza: la señal de que viene la embestida.
func _aviso_rojo() -> void:
	if _luz_aviso == null:
		_luz_aviso = OmniLight3D.new()
		_luz_aviso.name = "AvisoEmbestida"
		_luz_aviso.light_color = Color("#FF4040")
		_luz_aviso.omni_range = 2.0
		_luz_aviso.position = Vector3(0, 1.4, 0)
		add_child(_luz_aviso)
	_luz_aviso.light_energy = 2.0
	_luz_aviso.visible = true
	var t := create_tween()
	t.tween_property(_luz_aviso, "light_energy", 0.3, aviso_embestida)


func _morir() -> void:
	if _embistiendo > 0.0:
		_terminar_embestida()
	super()
