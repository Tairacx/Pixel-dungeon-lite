extends Node

signal golpe   # se emite en el instante en que la espada baja: ahí se aplica el daño

enum Estado { LISTA, ACTIVA, RECARGA }

@export var tecla = "espada"
@export var duracion = 0.42   # = lo que dura attack-melee-right
@export var momento_golpe = 0.22   # segundo de la animación en que la espada está abajo
@export var recarga = 0.1

@onready var pj = get_parent()

var estado = Estado.LISTA
var tiempo = 0.0
var _golpeo = false

func _physics_process(delta):
	tiempo -= delta
	match estado:
		Estado.LISTA:
			if Input.is_action_just_pressed(tecla) and puede():
				empezar()
		Estado.ACTIVA:
			if not _golpeo and (duracion - tiempo) >= momento_golpe:
				_golpeo = true
				golpe.emit()
			if tiempo <= 0.001:
				terminar()
		Estado.RECARGA:
			if tiempo <= 0.001:
				estado = Estado.LISTA

func puede():
	print("golpe de 1 a 1.25 m")
	return pj.is_on_floor()

func empezar():
	estado = Estado.ACTIVA
	tiempo = duracion
	_golpeo = false
	pj.empuje = pj.basis.z * 0.0
	pj.multiplicador = 0
	pj.accion = "attack-melee-right"
	print("empieza: ", tecla)

func terminar():
	estado = Estado.RECARGA
	tiempo = recarga
	pj.empuje = Vector3.ZERO
	pj.multiplicador = 1.0
	pj.accion = ""
	print("termina: ", tecla)
