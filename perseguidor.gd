extends CharacterBody3D
# Tarea C - Nivel 2: el Perseguidor sigue al héroe en línea recta y se detiene cerca.

@export var objetivo: Node3D
@export var rapidez = 2.5            # m/s  (80 px/s ÷ 32 px/m)
@export var distancia_parar = 1.0    # m: a esta distancia deja de acercarse
@onready var anim = $Modelo/AnimationPlayer


func _physics_process(delta):
	velocity += get_gravity() * delta

	var hacia = objetivo.global_position - global_position
	hacia.y = 0.0
	var distancia = hacia.length()

	if distancia > distancia_parar:
		var dir = hacia.normalized()
		velocity.x = dir.x * rapidez
		velocity.z = dir.z * rapidez
		basis = Basis.looking_at(dir)
		anim.play("walk")
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		anim.play("idle")

	move_and_slide()

	if Engine.get_physics_frames() % 30 == 0:
		print("distancia ", snappedf(distancia, 0.01))
