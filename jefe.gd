extends "res://perseguidor.gd"
# El Perseguidor de siempre (patrulla y persecución heredadas), pero con vida y
# TRES patrones telegrafiados que se eligen por distancia y nunca se repiten seguidos:
#   LLUVIA    - abanico/anillo de huesos (el ataque de siempre).
#   EMBESTIDA - se planta, brilla y embiste en línea recta 0.4 s (se esquiva).
#   ONDA      - golpe de suelo con anillo rojo (como el sismo del guerrero, más grande).
# Después de cada ataque retrocede o circula 1-2 s: no se queda pegado al héroe.
# Las fases (por % de vida) cambian cadencia, velocidad y patrones disponibles.
# El aviso de furia es SIN texto: pulso de LuzReyEsqueleto.

signal vida_cambiada(vida: int, maxima: int)
signal murio

@export var vida_maxima := 15
var vida := 15

const Hueso = preload("res://hueso_proyectil.gd")

enum Patron { NINGUNO, LLUVIA, EMBESTIDA, ONDA }

@export_group("Lluvia de huesos")
@export var disparos_activos := true
@export var alcance_disparo := 14.0                       # m: desde qué distancia ataca
@export var tiempos_entre_disparos: Array[float] = [3.6, 2.8, 2.0]   # s entre ataques por fase
@export var aviso_disparo := 0.7                          # s de aviso antes de lanzar
@export var danio_hueso := 1.0                            # corazones que quita cada hueso
@export var velocidad_hueso := 7.5                        # m/s

@export_group("Embestida")
@export var aviso_embestida := 0.55                       # s de aviso antes de salir
@export var duracion_embestida := 0.4                     # s que dura el envión
@export var velocidad_embestida := 8.5                    # m/s
@export var danio_embestida := 1.0

@export_group("Onda de suelo")
@export var aviso_onda := 0.9                             # s de aviso del anillo
@export var radio_onda := 3.4                             # m del área del golpe
@export var danio_onda := 1.0

@export_group("Ritmo")
@export var distancia_minima := 2.6        # más cerca que esto: se abre
@export var distancia_onda := 4.0          # más cerca que esto: prefiere la onda
@export var distancia_embestida_max := 8.0 # más cerca que esto: prefiere embestir
@export var tiempo_reposo_min := 1.0       # s de reposicionamiento tras atacar
@export var tiempo_reposo_max := 2.0

var _espera := 3.0          # el primer ataque llega 3 s después de verte
var _patron := Patron.NINGUNO
var _t_aviso := 0.0
var _t_dash := 0.0
var _dir_dash := Vector3.ZERO
var _golpe_dash := false
var _t_reposo := 0.0
var _ultimo_patron := Patron.NINGUNO
var _rondas := 0
var _fase_anterior := 0
var _energia_luz := -1.0
var _onda: MeshInstance3D


func _ready() -> void:
	vida = vida_maxima
	add_to_group("jefe")   # el HUD busca a este grupo para dibujar su barra de vida
	distancia_golpe = maxf(distancia_golpe, 2.4)   # es grande: su Garra alcanza más lejos


func _physics_process(delta: float) -> void:
	if vida <= 0:
		return
	if aturdido > 0.0:
		# El aturdimiento lo frena, pero no cancela el ataque que ya estaba cargando.
		super(delta)
		return
	if _t_dash > 0.0:
		_en_dash(delta)
		return
	if _t_aviso > 0.0:
		_en_aviso(delta)
		return
	super(delta)                 # movimiento propio + detección de la base
	_decidir_ataque(delta)


# Fase 0: vida > 66 %  -> 1 hueso / abanico simple
# Fase 1: vida 33-66 % -> abanico de 3 y entra la embestida
# Fase 2: vida < 33 %  -> abanico de 5 / anillo, embestida más rápida y onda
func _fase() -> int:
	var f := float(vida) / float(maxi(vida_maxima, 1))
	if f > 0.66:
		return 0
	elif f > 0.33:
		return 1
	return 2


# --- Movimiento -----------------------------------------------------------

func _pensar_propio(delta: float) -> bool:
	if vida <= 0:
		return false
	if _t_reposo > 0.0:                  # después de atacar: se reacomoda
		_t_reposo = maxf(_t_reposo - delta, 0.0)
		_reposicionar(delta)
		return true
	var hacia := _hacia_heroe()
	if hacia == Vector3.ZERO:
		return false
	if _distancia() < distancia_minima:
		_querer_mover(-hacia, rapidez * 0.9 * _escala_fase(), hacia)
	else:
		_querer_mover(hacia, rapidez * 0.55 * _escala_fase(), hacia)
	return true


func _reposicionar(delta: float) -> void:
	var hacia := _hacia_heroe()
	if hacia == Vector3.ZERO:
		return
	var tangente := hacia.rotated(Vector3.UP, _rodear_lado(delta) * PI * 0.5)
	var dir := (tangente * 0.8 - hacia * 0.35).normalized()   # circula abriéndose
	_querer_mover(dir, rapidez * _escala_fase(), hacia)


func _escala_fase() -> float:
	return 1.0 + 0.12 * float(_fase())


# --- Ataques --------------------------------------------------------------

func _decidir_ataque(delta: float) -> void:
	# Solo ataca si está persiguiendo de verdad y viendo al héroe: sin esto
	# golpeaba a través de las paredes (la distancia es en línea recta).
	if not disparos_activos or objetivo == null or estado != Estado.PERSEGUIR:
		return
	_espera = maxf(_espera - delta, 0.0)
	if _espera > 0.0:
		return
	if _distancia() > alcance_disparo or not hay_linea_de_vision():
		return
	_elegir_patron()


func _elegir_patron() -> void:
	var dist := _distancia()
	var fase := _fase()
	# Disponibilidad REAL por fase (lo que dice la cabecera), no solo peso:
	#   fase 0 -> lluvia; fase 1 suma EMBESTIDA; fase 2 suma ONDA.
	# Cada copia en la lista es un boleto más. La distancia decide el peso:
	# de cerca manda la onda, a media distancia la embestida y lejos no queda
	# otra que los huesos (por eso LLUVIA pesa uno y el resto dos o tres).
	var opciones: Array[int] = [Patron.LLUVIA]
	if fase >= 1 and dist <= distancia_embestida_max:
		opciones.append(Patron.EMBESTIDA)
		opciones.append(Patron.EMBESTIDA)
	if fase >= 2 and dist <= distancia_onda:
		opciones.append(Patron.ONDA)
		opciones.append(Patron.ONDA)
		opciones.append(Patron.ONDA)
	var elegido: int = opciones[randi() % opciones.size()]
	if elegido == _ultimo_patron and opciones.size() > 1:
		for opcion in opciones:
			if opcion != _ultimo_patron:
				elegido = opcion
				break
	_ultimo_patron = elegido
	match elegido:
		Patron.EMBESTIDA:
			_patron = Patron.EMBESTIDA
			_t_aviso = maxf(aviso_embestida * (1.0 - 0.1 * float(fase)), 0.25)
			_pulso_luz(2.5)
		Patron.ONDA:
			_patron = Patron.ONDA
			_t_aviso = aviso_onda
			_crear_anillo_onda()
			_pulso_luz(3.0)
		_:
			_patron = Patron.LLUVIA
			_t_aviso = maxf(aviso_disparo * (1.0 - 0.08 * float(fase)), 0.35)
			_pulso_luz(3.5)


# Aviso: quieto, encarando al héroe y con la luz roja creciendo.
func _en_aviso(delta: float) -> void:
	_t_aviso = maxf(_t_aviso - delta, 0.0)
	_querer_mover(Vector3.ZERO, 0.0, _hacia_heroe())
	_aplicar_movimiento(delta)
	_actualizar_garra()
	if _t_aviso <= 0.0:
		_soltar_ataque()


func _soltar_ataque() -> void:
	match _patron:
		Patron.LLUVIA:
			_lanzar_lluvia()
		Patron.EMBESTIDA:
			_empezar_dash()
		Patron.ONDA:
			_golpear_onda()
		_:
			_fin_ataque()


func _en_dash(delta: float) -> void:
	_t_dash = maxf(_t_dash - delta, 0.0)
	_querer_mover(_dir_dash, velocidad_embestida * _escala_fase(), _dir_dash)
	_aplicar_movimiento(delta, false, false)   # la embestida es comprometida
	_actualizar_garra()
	# Revalidación: el héroe pudo cubrirse durante el aviso.
	if not _golpe_dash and _distancia() <= 2.0 and hay_linea_de_vision():
		_golpe_dash = true
		_danar_heroe(danio_embestida)
	if _t_dash <= 0.0:
		_fin_ataque()


func _empezar_dash() -> void:
	_dir_dash = _hacia_heroe()
	if _dir_dash == Vector3.ZERO:
		_fin_ataque()
		return
	_t_dash = duracion_embestida
	_golpe_dash = false
	basis = Basis.looking_at(_dir_dash)


func _lanzar_lluvia() -> void:
	var fase := _fase()
	var base := _hacia_heroe()
	if base == Vector3.ZERO:
		base = -global_basis.z.normalized()
	var angulos: Array[float] = [0.0]
	if fase == 1:
		angulos = [-18.0, 0.0, 18.0]
	elif fase == 2:
		if _rondas % 2 == 0:
			angulos = [-32.0, -16.0, 0.0, 16.0, 32.0]
		else:
			angulos = []
			for i in range(10):
				angulos.append(36.0 * i)       # anillo: sale en todas direcciones
	for a in angulos:
		_lanzar_hueso(base.rotated(Vector3.UP, deg_to_rad(a)))
	_fin_ataque()


func _lanzar_hueso(dir: Vector3) -> void:
	var hueso := Hueso.new()
	hueso.direccion = dir
	hueso.rapidez = velocidad_hueso
	hueso.danio = danio_hueso
	get_tree().current_scene.add_child(hueso)
	hueso.global_position = global_position + Vector3(0, 1.0, 0) + dir * 0.8


func _crear_anillo_onda() -> void:
	if _onda == null:
		_onda = MeshInstance3D.new()
		_onda.name = "AvisoOnda"
		add_child(_onda)
	# El jefe cuelga de un nodo escalado: se compensa para que el anillo mida `radio_onda`.
	var esc := maxf(global_transform.basis.get_scale().x, 0.01)
	var disco := CylinderMesh.new()
	disco.top_radius = radio_onda / esc
	disco.bottom_radius = radio_onda / esc
	disco.height = 0.02
	disco.radial_segments = 48
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.25, 0.25, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.render_priority = 5
	disco.material = mat
	_onda.mesh = disco
	# Sin rotar: el CylinderMesh ya apoya el disco en el plano XZ (horizontal).
	# Girarlo -90° lo dejaba vertical y no coincidía con el daño radial en el piso.
	_onda.position = Vector3(0, 0.06 / esc, 0)
	_onda.visible = true
	_onda.scale = Vector3.ONE * 0.3
	var t := create_tween()
	t.tween_property(_onda, "scale", Vector3.ONE, aviso_onda)


func _golpear_onda() -> void:
	if _onda != null:
		_onda.visible = false
	# Revalidación: si se cubrió durante el aviso del anillo, no le pega.
	if _distancia() <= radio_onda and hay_linea_de_vision():
		_danar_heroe(danio_onda)
	_fin_ataque()


func _fin_ataque() -> void:
	_patron = Patron.NINGUNO
	_rondas += 1
	_espera = tiempos_entre_disparos[mini(_fase(), tiempos_entre_disparos.size() - 1)]
	_t_reposo = randf_range(tiempo_reposo_min, tiempo_reposo_max)
	var f := _fase()
	if f != _fase_anterior:
		_fase_anterior = f
		_latido_fase()       # cambió de fase: feedback sin texto


# --- Feedback sin texto ---------------------------------------------------

func _luz_rey() -> OmniLight3D:
	if get_parent() == null:
		return null
	return get_parent().get_node_or_null("LuzReyEsqueleto") as OmniLight3D


func _pulso_luz(factor: float) -> void:
	var luz := _luz_rey()
	if luz == null:
		return
	# La luz cuelga de JefePerseguidor (padre del jefe), no del enemigo: sin esto
	# el pulso se quedaba brillando en el punto de aparición.
	luz.global_position = global_position + Vector3.UP * 1.4
	if _energia_luz < 0.0:
		_energia_luz = luz.light_energy
	var t := create_tween()
	t.tween_property(luz, "light_energy", _energia_luz * factor, _t_aviso)
	t.tween_property(luz, "light_energy", _energia_luz, 0.2)


# Rugido de furia: tres latidos de su luz roja (nada de texto en el HUD).
func _latido_fase() -> void:
	var luz := _luz_rey()
	if luz == null:
		return
	luz.global_position = global_position + Vector3.UP * 1.4   # sigue al jefe
	if _energia_luz < 0.0:
		_energia_luz = luz.light_energy
	luz.light_energy = _energia_luz
	var t := create_tween()
	t.tween_property(luz, "light_energy", _energia_luz * 5.0, 0.12)
	t.tween_property(luz, "light_energy", _energia_luz, 0.35)


func _danar_heroe(cantidad: float) -> void:
	if objetivo == null:
		return
	var salud = objetivo.get_node_or_null("Salud")
	if salud != null:
		salud.recibir_danio(cantidad, global_position)


# La llama apuntar.gd (la espada del héroe) cuando su rayo le da al jefe.
func recibir_golpe(danio: int) -> void:
	if vida <= 0:
		return
	vida = maxi(vida - danio, 0)
	print("jefe: ", vida, " / ", vida_maxima)
	vida_cambiada.emit(vida, vida_maxima)
	aturdir(aturdimiento)
	if vida == 0:
		_morir()


func _morir() -> void:
	murio.emit()
	set_physics_process(false)        # deja de patrullar y de atacar
	if has_node("Garra"):
		$Garra.queue_free()           # y de hacer daño por contacto
	if _onda != null:
		_onda.visible = false
	if anim.has_animation("die"):
		anim.play("die")
	get_tree().create_timer(2.0).timeout.connect(queue_free)
