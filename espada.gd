extends Node

enum Estado { LISTA, ACTIVA, RECARGA }

@export var tecla = "espada"
@export var duracion = 0.2
@export var recarga = 0.4

@onready var pj = get_parent()

var estado = Estado.LISTA
var tiempo = 0.0


func _physics_process(delta):
	tiempo -= delta
	match estado:
		Estado.LISTA:
			if Input.is_action_just_pressed(tecla) and puede():
				empezar()
		Estado.ACTIVA:
			if tiempo <= 0.001:   # 0.001 y no 0: restar 1/60 no da exacto
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
	pj.empuje = Vector3.ZERO
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
