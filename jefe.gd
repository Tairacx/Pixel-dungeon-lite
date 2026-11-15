extends "res://perseguidor.gd"
# El Perseguidor de siempre (patrulla y persecución heredadas), pero con vida.
# perseguidor.gd no se toca: esta clase solo le agrega vida y la función recibir_golpe().

signal vida_cambiada(vida: int, maxima: int)
signal murio

@export var vida_maxima := 5
var vida := 5


func _ready() -> void:
	vida = vida_maxima
	add_to_group("jefe")   # el HUD busca a este grupo para dibujar su barra de vida


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
