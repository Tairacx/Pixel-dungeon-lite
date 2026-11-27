extends "res://esqueleto_pequeno.gd"
# Esqueleto Mago: enemigo a distancia (KayKit Skeleton_Mage).
# Mantiene entre 3.5 y 7 m del héroe CIRCULANDO de costado (no se queda quieto),
# telegrafía cada hueso ~0.35 s antes (brillo rojo) y huye en diagonal si el héroe
# se le acerca a menos de 2.5 m. La ráfaga en abanico solo sale con línea de visión.

const Hueso = preload("res://hueso_proyectil.gd")

@export_group("Distancia")
@export var distancia_min := 3.5           # más cerca que esto: se aleja circulando
@export var distancia_max := 7.0           # más lejos que esto: se acerca
@export var distancia_huida := 2.5         # más cerca que esto: huye en diagonal
@export_group("Huesos")
@export_range(0.0, 1.0, 0.05) var probabilidad_ráfaga := 0.35
@export var cooldown_ráfaga := 7.0         # s entre intentos de ráfaga
@export var aviso_disparo := 0.35          # s de brillo antes de lanzar (telegrafía)
@export var danio_hueso := 0.5             # corazones que quita cada hueso
@export var velocidad_hueso := 6.0

var _t_proximo_disparo := 2.0
var _t_proxima_ráfaga := 4.0
var _aviso := 0.0
var _pendiente_rafaga := false
var _luz_baculo: OmniLight3D


func _physics_process(delta: float) -> void:
	# Un golpe durante el aviso cancela el disparo (se puede interrumpir).
	if aturdido > 0.0:
		_aviso = 0.0
		_pendiente_rafaga = false
		super(delta)
		return
	if _aviso > 0.0:
		_aviso = maxf(_aviso - delta, 0.0)
		_querer_mover(Vector3.ZERO, 0.0, _hacia_heroe())   # quieto, encarando y brillando
		_aplicar_movimiento(delta)
		_actualizar_garra()
		if _aviso <= 0.0:
			_lanzar_pendiente()
		return
	super(delta)   # patrulla, detección y reacción de la base


# Movimiento propio: mantiene el rango cómodo mientras circula.
func _pensar_propio(delta: float) -> bool:
	if objetivo == null or vida <= 0:
		return false
	var dist := _distancia()
	var hacia := _hacia_heroe()
	if hacia == Vector3.ZERO:
		return false
	if dist < distancia_huida:
		_huir(delta, hacia)
	elif dist < distancia_min:
		_circular(delta, hacia, true)
	elif dist > distancia_max:
		_querer_mover(hacia, rapidez)
	else:
		_circular(delta, hacia, false)
	_actualizar_disparo(delta, dist)
	return true


func _circular(delta: float, hacia: Vector3, alejandose: bool) -> void:
	var tangente := hacia.rotated(Vector3.UP, _rodear_lado(delta) * PI * 0.5)
	if alejandose:
		tangente = (tangente * 0.7 - hacia * 0.7).normalized()
	_querer_mover(tangente, rapidez * 0.65, hacia)


# Huye en diagonal: se abre y gira, no corre de espaldas en línea recta.
func _huir(delta: float, hacia: Vector3) -> void:
	var tangente := hacia.rotated(Vector3.UP, _rodear_lado(delta) * PI * 0.5)
	var dir := (-hacia * 0.8 + tangente * 0.7).normalized()
	_querer_mover(dir, rapidez * 1.15, -dir)


func _actualizar_disparo(delta: float, dist: float) -> void:
	_t_proximo_disparo = maxf(_t_proximo_disparo - delta, 0.0)
	if _t_proximo_disparo > 0.0:
		return
	if dist > distancia_max + 2.0 or dist < 1.2:
		return
	if not hay_linea_de_vision():
		_t_proximo_disparo = 0.4          # reintenta en un rato
		return
	_t_proximo_disparo = 2.6
	_t_proxima_ráfaga = maxf(_t_proxima_ráfaga - 1.0, 0.0)
	var rafaga := _t_proxima_ráfaga <= 0.0 and randf() < probabilidad_ráfaga
	if rafaga:
		_t_proxima_ráfaga = cooldown_ráfaga
	_empezar_aviso(rafaga)


# Telegrafía el hueso: se queda quieto encarando y se le enciende el báculo.
func _empezar_aviso(rafaga: bool) -> void:
	_aviso = aviso_disparo
	_pendiente_rafaga = rafaga
	if _luz_baculo == null:
		_luz_baculo = OmniLight3D.new()
		_luz_baculo.name = "AvisoHueso"
		_luz_baculo.light_color = Color("#FF5040")
		_luz_baculo.omni_range = 2.4
		_luz_baculo.position = Vector3(0, 1.5, 0)
		add_child(_luz_baculo)
	_luz_baculo.light_energy = 2.4
	var t := create_tween()
	t.tween_property(_luz_baculo, "light_energy", 0.0, aviso_disparo)


func _lanzar_pendiente() -> void:
	if _pendiente_rafaga:
		_ráfaga()
	else:
		_lanzar(0.0)
	_pendiente_rafaga = false


func mirar_al_heroe() -> void:
	var dir := objetivo.global_position - global_position
	dir.y = 0.0
	if dir.length() > 0.05:
		basis = Basis.looking_at(dir.normalized())


func _ráfaga() -> void:
	mirar_al_heroe()
	for angulo in [-18.0, 0.0, 18.0]:
		_lanzar(angulo)


func _lanzar(angulo: float) -> void:
	if objetivo == null:
		return
	var dir := objetivo.global_position - global_position
	dir.y = 0.0
	if dir.length() < 0.05:
		return
	dir = dir.normalized().rotated(Vector3.UP, deg_to_rad(angulo))
	var hueso := Hueso.new()
	hueso.direccion = dir
	hueso.rapidez = velocidad_hueso
	hueso.danio = danio_hueso
	get_tree().current_scene.add_child(hueso)
	hueso.global_position = global_position + Vector3(0, 1.0, 0) + dir * 0.8
