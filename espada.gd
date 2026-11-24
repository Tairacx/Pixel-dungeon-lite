extends Node

signal golpe   # se emite en el instante en que la espada cruza al frente: ahí se aplica el daño
signal ataque_iniciado(duracion, momento_golpe)   # arma.gd mueve la espada de lado con esto

enum Estado { LISTA, ACTIVA, RECARGA }

@export var tecla = "espada"
# Pose del cuerpo mientras ataca: QUIETA (la mano no hace ningún tajo). El tajo lateral
# lo hace la espada misma (arma.gd). Si pones "" el cuerpo sigue con idle.
@export var animacion = "holding-right"
@export var duracion = 0.42   # segundos que dura el ataque completo
@export var momento_golpe = 0.2   # segundo en que la espada cruza por el frente y hace el daño
@export var recarga = 0.1

@export_group("Movimiento del cuerpo")
@export var giro_cuerpo := 40.0     # grados: el torso se carga a la derecha y gira a la izquierda
@export var inclinacion := 12.0     # grados que se inclina hacia adelante al golpear
@export var avance := 0.15          # m que da un pasito hacia adelante al golpear
@export var preparacion := 0.09     # s antes del golpe en que arranca el tajo (= medio tajo)

@onready var pj = get_parent()

var estado = Estado.LISTA
var tiempo = 0.0
var _golpeo = false
var _t_cuerpo := -1.0          # >= 0 mientras el cuerpo hace el movimiento de ataque
var _modelo: Node3D
var _base := Transform3D.IDENTITY

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

# Movimiento del cuerpo: el modelo (hijo del héroe) gira, se inclina y da un paso; así la pose
# no se ve tiesa. Los números de cada instante son (tiempo, giro, inclinación, avance).
func _process(delta):
	if _t_cuerpo < 0.0 or _modelo == null:
		return
	_t_cuerpo += delta
	if _t_cuerpo >= duracion:
		_restaurar_cuerpo()
		return
	var a = momento_golpe - preparacion   # arranca el tajo
	var b = momento_golpe + preparacion   # termina el tajo
	var claves = [
		[0.0, 0.0, 0.0, 0.0],
		[a, -giro_cuerpo, inclinacion * 0.3, -avance * 0.3],   # carga hacia atrás/derecha
		[b, giro_cuerpo, inclinacion, avance],                  # golpe: giro, inclinación, paso
		[duracion, 0.0, 0.0, 0.0],                              # vuelve al reposo
	]
	var v = _interpolar(claves, _t_cuerpo)
	var giro = Basis(Vector3.UP, deg_to_rad(v[0]))              # + = hacia la izquierda
	var inclina = Basis(Vector3.RIGHT, deg_to_rad(-v[1]))       # - = hacia adelante
	_modelo.transform = Transform3D(giro * inclina * _base.basis,
		_base.origin + Vector3(0, 0, -v[2]))


func _interpolar(claves, t):
	for i in range(claves.size() - 1):
		var k0 = claves[i]
		var k1 = claves[i + 1]
		if t <= k1[0]:
			var u = clampf((t - k0[0]) / maxf(k1[0] - k0[0], 0.001), 0.0, 1.0)
			u = u * u * (3.0 - 2.0 * u)   # suaviza el arranque y el freno
			return [lerpf(k0[1], k1[1], u), lerpf(k0[2], k1[2], u), lerpf(k0[3], k1[3], u)]
	var ultima = claves[claves.size() - 1]
	return [ultima[1], ultima[2], ultima[3]]


func _restaurar_cuerpo():
	_t_cuerpo = -1.0
	if _modelo != null:
		_modelo.transform = _base


func puede():
	print("golpe de 1 a 1.25 m")
	return pj.is_on_floor()

func empezar():
	estado = Estado.ACTIVA
	tiempo = duracion
	_golpeo = false
	pj.empuje = pj.basis.z * 0.0
	pj.multiplicador = 0
	pj.accion = animacion
	ataque_iniciado.emit(duracion, momento_golpe)
	_modelo = pj.get_node_or_null("Modelo")
	if _modelo != null:
		if _t_cuerpo < 0.0:
			_base = _modelo.transform   # solo se guarda si no estaba a medio movimiento
		_t_cuerpo = 0.0
	print("empieza: ", tecla)

func terminar():
	_restaurar_cuerpo()
	estado = Estado.RECARGA
	tiempo = recarga
	pj.empuje = Vector3.ZERO
	pj.multiplicador = 1.0
	pj.accion = ""
	print("termina: ", tecla)
