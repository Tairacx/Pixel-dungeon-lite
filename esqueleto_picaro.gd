extends "res://esqueleto_pequeno.gd"
# Esqueleto Pícaro: enemigo rápido (KayKit Skeleton_Rogue).
# Se acerca FLANQUEANDO (por el costado, no de frente) y embiste desde el ángulo
# ciego. Si la embestida falla, retrocede y espera el cooldown.
# La embestida se telegrafía con un destello rojo y sube el daño de contacto a 1
# corazón mientras dura.

@export_group("Embestida")
@export_range(0.0, 1.0, 0.05) var probabilidad_embestida := 0.4
@export var cooldown_embestida := 6.0        # s entre intentos de embestida
@export var distancia_embestida := 8.0       # m: solo embiste si el héroe está más cerca que esto
@export var rapidez_embestida := 9.0         # m/s del embestón
@export var aviso_embestida := 0.3           # s quieto antes de lanzarse (para poder esquivar)
@export var retirada_fallida := 0.6          # s que se aparta si la embestida no pegó
@export_group("Flanqueo")
@export var distancia_flanqueo := 4.0        # m: desde acá se abre de costado
@export var angulo_flanqueo := 55.0          # grados respecto de la línea recta

var _t_proximo_intento := 3.0
var _cargando := 0.0
var _embistiendo := 0.0
var _dir_embestida := Vector3.ZERO
var _luz_aviso: OmniLight3D
var _t_huida := 0.0
var _dist_min: float = INF


func _ready() -> void:
	super()
	_t_proximo_intento = cooldown_embestida * 0.5


# Se acerca por el costado; cuando ya está cerca, la base decide el rodeo.
func _direccion_persecucion(hacia: Vector3, dist: float, delta: float) -> Vector3:
	if dist > distancia_flanqueo:
		return hacia.rotated(Vector3.UP, _lado * deg_to_rad(angulo_flanqueo))
	return super(hacia, dist, delta)


func _physics_process(delta: float) -> void:
	if _cargando > 0.0:
		_cargando -= delta
		_querer_mover(Vector3.ZERO, 0.0, _hacia_heroe())   # se frena y lo encara
		_aplicar_movimiento(delta)
		_actualizar_garra()
		if _cargando <= 0.0:
			_lanzarse()
		return
	if _embistiendo > 0.0:
		_embistiendo -= delta
		_querer_mover(_dir_embestida, rapidez_embestida, _dir_embestida)
		_aplicar_movimiento(delta, false, false)   # la embestida es comprometida
		_dist_min = minf(_dist_min, _distancia())
		_actualizar_garra()   # la garra quedó apagada en la carga: se recalcula al avanzar
		if _embistiendo <= 0.0:
			_terminar_embestida()
		return
	if _t_huida > 0.0:
		_t_huida = maxf(_t_huida - delta, 0.0)
		retroceder(delta, 0.8)
		return

	# Comportamiento normal (patrulla / persecución / flanqueo) + dado de la embestida.
	super(delta)
	if objetivo == null or vida <= 0:
		return
	_t_proximo_intento -= delta
	if _t_proximo_intento > 0.0:
		return
	_t_proximo_intento = cooldown_embestida
	if randf() > probabilidad_embestida:
		return   # esta vez no: sigue pegando de manera normal
	var dist := _distancia()
	if dist <= distancia_embestida and _hay_linea_de_vision():
		_cargar()


func _hay_linea_de_vision() -> bool:
	return hay_linea_de_vision()


func _cargar() -> void:
	_cargando = aviso_embestida
	_dir_embestida = _hacia_heroe()
	if _dir_embestida == Vector3.ZERO:
		_cargando = 0.0
		return
	aturdir(aviso_embestida + 0.05)   # se frena mientras carga
	_aviso_rojo()


func _lanzarse() -> void:
	aturdido = 0.0   # el wind-up ya cumplió su función: que no se congele tras la embestida
	# La duración sale de la distancia real: 0.35 s fijos a 9 m/s son 3.15 m, y la
	# embestida se dispara hasta a 8 m, así que se quedaba corta. El tope evita
	# que una carga lejana se vuelva un viaje eterno.
	var recorrido := maxf(_distancia() - distancia_golpe * 0.5, 0.4)
	_embistiendo = clampf(recorrido / maxf(rapidez_embestida, 0.01), 0.2, 0.9)
	_dist_min = _distancia()
	basis = Basis.looking_at(_dir_embestida)
	var garra = get_node_or_null("Garra")
	if garra != null:
		garra.danio = 1.0            # embistiendo pega un corazón entero
	if _luz_aviso != null:
		_luz_aviso.visible = false


func _terminar_embestida() -> void:
	_embistiendo = 0.0
	var garra = get_node_or_null("Garra")
	if garra != null:
		garra.danio = 0.5            # vuelve al daño normal
	if _luz_aviso != null:
		_luz_aviso.visible = false
	if _dist_min > distancia_golpe:
		_t_huida = retirada_fallida   # falló: se aparta y espera el cooldown


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
