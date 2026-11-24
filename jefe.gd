extends "res://perseguidor.gd"
# El Perseguidor de siempre (patrulla y persecución heredadas), pero con vida.
# perseguidor.gd no se toca: esta clase solo le agrega vida y la función recibir_golpe().

signal vida_cambiada(vida: int, maxima: int)
signal murio

@export var vida_maxima := 5
var vida := 5

const Hueso = preload("res://hueso_proyectil.gd")

# --- Ataques a distancia: el Rey lanza huesos y se vuelve más agresivo al perder vida ---
@export_group("Ataques a distancia")
@export var disparos_activos := true
@export var alcance_disparo := 14.0                       # m: desde qué distancia lanza huesos
@export var tiempos_entre_disparos: Array[float] = [3.2, 2.4, 1.7]   # s entre ataques: fase 1, 2 y 3
@export var aviso_disparo := 0.7                          # s que se queda quieto brillando antes de lanzar
@export var danio_hueso := 1.0                            # corazones que quita cada hueso
@export var velocidad_hueso := 7.5                        # m/s

var _espera := 3.0          # el primer ataque llega 3 s después de verte
var _cargando := 0.0
var _rondas := 0
var _fase_anterior := 0
var _energia_luz := -1.0


func _ready() -> void:
	vida = vida_maxima
	add_to_group("jefe")   # el HUD busca a este grupo para dibujar su barra de vida


func _physics_process(delta: float) -> void:
	super(delta)                    # patrulla y persecución de siempre
	_ataque_a_distancia(delta)


# Fase 0: vida > 66 %  -> 1 hueso directo
# Fase 1: vida 33-66 % -> abanico de 3 huesos
# Fase 2: vida < 33 %  -> abanico de 5 y, en rondas alternas, un anillo de 10 huesos
func _fase() -> int:
	var f := float(vida) / float(maxi(vida_maxima, 1))
	if f > 0.66:
		return 0
	elif f > 0.33:
		return 1
	return 2


func _ataque_a_distancia(delta: float) -> void:
	if not disparos_activos or vida <= 0 or objetivo == null:
		return
	if _cargando > 0.0:                # está avisando: quieto y brillando
		_cargando -= delta
		if _cargando <= 0.0:
			_lanzar()
		return
	if global_position.distance_to(objetivo.global_position) > alcance_disparo:
		return
	_espera -= delta
	if _espera <= 0.0:
		_empezar_aviso()


func _empezar_aviso() -> void:
	_cargando = aviso_disparo
	aturdir(aviso_disparo + 0.05)      # se detiene mientras carga
	if anim.has_animation("idle"):
		anim.play("idle")
	_mirar_al_heroe()
	var luz := get_parent().get_node_or_null("LuzReyEsqueleto") as OmniLight3D
	if luz != null:                    # la luz roja del Rey brilla: es la señal para esquivar
		if _energia_luz < 0.0:
			_energia_luz = luz.light_energy
		var t := create_tween()
		t.tween_property(luz, "light_energy", _energia_luz * 3.5, aviso_disparo)
		t.tween_property(luz, "light_energy", _energia_luz, 0.25)


func _mirar_al_heroe() -> void:
	var dir := objetivo.global_position - global_position
	dir.y = 0.0
	if dir.length() > 0.05:
		basis = Basis.looking_at(dir.normalized())


func _lanzar() -> void:
	var fase := _fase()
	_espera = tiempos_entre_disparos[mini(fase, tiempos_entre_disparos.size() - 1)]
	_rondas += 1
	if fase != _fase_anterior:
		_fase_anterior = fase
		_avisar("¡El Rey Esqueleto se enfurece!" if fase == 2 else "¡El Rey Esqueleto lanza más huesos!")
	_mirar_al_heroe()

	var dir := objetivo.global_position - global_position
	dir.y = 0.0
	var base := dir.normalized()
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
		var hueso := Hueso.new()
		hueso.direccion = base.rotated(Vector3.UP, deg_to_rad(a))
		hueso.rapidez = velocidad_hueso
		hueso.danio = danio_hueso
		get_tree().current_scene.add_child(hueso)
		hueso.global_position = global_position + Vector3(0, 1.0, 0) + hueso.direccion * 0.8


func _avisar(texto: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("mostrar_aviso"):
		hud.mostrar_aviso(texto)


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
	set_physics_process(false)        # deja de patrullar y de perseguir
	if has_node("Garra"):
		$Garra.queue_free()           # y de hacer daño por contacto
	if anim.has_animation("die"):
		anim.play("die")
	get_tree().create_timer(2.0).timeout.connect(queue_free)
