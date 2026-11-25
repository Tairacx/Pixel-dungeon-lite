extends "res://esqueleto_pequeno.gd"
# Esqueleto Mago: enemigo a distancia (KayKit Skeleton_Mage).
# Normal: mantiene la distancia con el héroe y le tira un hueso mágico cada tanto.
# Habilidad OCASIONAL: RÁFAGA. Tira los dados cada "cooldown_ráfaga" segundos y si
# sale, lanza un abanico de 3 huesos en vez de uno solo. No la usa siempre.

const Hueso = preload("res://hueso_proyectil.gd")

@export_range(0.0, 1.0, 0.05) var probabilidad_ráfaga := 0.35
@export var cooldown_ráfaga := 7.0         # s entre intentos de ráfaga
@export var distancia_min := 3.5           # más cerca que esto: se aleja
@export var distancia_max := 7.0           # más lejos que esto: se acerca
@export var danio_hueso := 0.5             # corazones que quita cada hueso
@export var velocidad_hueso := 6.0

var _t_proximo_disparo := 2.0
var _t_proxima_ráfaga := 4.0


func _physics_process(delta: float) -> void:
	if vida <= 0 or objetivo == null:
		super(delta)
		return
	var dist := global_position.distance_to(objetivo.global_position)

	# Movimiento: mantiene el rango cómodo para tirar huesos.
	if dist < distancia_min:
		alejarse(delta)
	elif dist > distancia_max:
		super(delta)                 # persigue/ patrulla de siempre
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		velocity += get_gravity() * delta
		move_and_slide()
		mirar_al_heroe()

	# Disparo normal: un hueso cada "t_proximo_disparo" segundos.
	_t_proximo_disparo -= delta
	if _t_proximo_disparo <= 0.0 and dist <= distancia_max + 2.0:
		_t_proximo_disparo = 2.6
		_t_proxima_ráfaga -= 1.0
		# El dado de la ráfaga: a veces, en vez del hueso simple, lanza el abanico.
		if _t_proxima_ráfaga <= 0.0 and randf() < probabilidad_ráfaga:
			_t_proxima_ráfaga = cooldown_ráfaga
			_ráfaga()
		else:
			_lanzar(0.0)


func mirar_al_heroe() -> void:
	var dir := objetivo.global_position - global_position
	dir.y = 0.0
	if dir.length() > 0.05:
		basis = Basis.looking_at(dir.normalized())


func alejarse(delta: float) -> void:
	var dir := global_position - objetivo.global_position
	dir.y = 0.0
	dir = dir.normalized()
	mirar_al_heroe()
	velocity += get_gravity() * delta
	velocity.x = dir.x * rapidez
	velocity.z = dir.z * rapidez
	move_and_slide()


func _ráfaga() -> void:
	mirar_al_heroe()
	for angulo in [-18.0, 0.0, 18.0]:
		_lanzar(angulo)


func _lanzar(angulo: float) -> void:
	var dir := objetivo.global_position - global_position
	dir.y = 0.0
	dir = dir.normalized().rotated(Vector3.UP, deg_to_rad(angulo))
	var hueso := Hueso.new()
	hueso.direccion = dir
	hueso.rapidez = velocidad_hueso
	hueso.danio = danio_hueso
	get_tree().current_scene.add_child(hueso)
	hueso.global_position = global_position + Vector3(0, 1.0, 0) + dir * 0.8
