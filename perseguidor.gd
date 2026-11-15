extends CharacterBody3D
# Tarea C - Nivel 3: el Perseguidor patrulla, ve al héroe y lo persigue.
# Histéresis: empieza a perseguir a radio_ver y lo suelta a radio_perder (más grande).

enum Estado { PATRULLA, PERSEGUIR }

@export var objetivo: Node3D
@export var rapidez = 2.5           # m/s  (80 px/s ÷ 32 px/m)
@export var radio_ver = 8.0         # m  (256 px)
@export var radio_perder = 12.0     # m  (384 px)
@export var puntos: Array[Vector3] = [
	Vector3(-8, 0, 6), Vector3(8, 0, 6)]
@onready var anim = $Modelo/AnimationPlayer

# Aturdimiento: al recibir un golpe el enemigo se detiene unos instantes.
@export var aturdimiento := 0.4   # segundos que queda quieto

var estado = Estado.PATRULLA
var punto = 0
var aturdido := 0.0               # temporizador del aturdimiento (0 = no aturdido)


func _physics_process(delta):
	if aturdido > 0.0:
		aturdido -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	velocity += get_gravity() * delta
	var distancia = global_position.distance_to(objetivo.global_position)

	match estado:
		Estado.PATRULLA:
			if distancia < radio_ver:
				estado = Estado.PERSEGUIR
				print("lo vio a ", snappedf(distancia, 0.01), " m")
			ir_a(puntos[punto])
			if global_position.distance_to(puntos[punto]) < 0.3:
				punto = (punto + 1) % puntos.size()
		Estado.PERSEGUIR:
			if distancia > radio_perder:
				estado = Estado.PATRULLA
				print("lo perdió a ", snappedf(distancia, 0.01), " m")
			ir_a(objetivo.global_position)

	move_and_slide()


func ir_a(p):
	var hacia = p - global_position
	hacia.y = 0.0
	if hacia.length() < 0.05:
		return
	var dir = hacia.normalized()
	velocity.x = dir.x * rapidez
	velocity.z = dir.z * rapidez
	basis = Basis.looking_at(dir)
	anim.play("walk")


func aturdir(segundos: float) -> void:
	aturdido = maxf(aturdido, segundos)
