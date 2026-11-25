extends Node
# Reproduce una animación de reposo en los modelos del menú (los esqueletos).
# RigEsqueleto crea el AnimationPlayer un instante antes; por eso esperamos un cuadro.

@export var animacion := "idle"


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var animador := get_parent().find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animador != null and animador.has_animation(animacion):
		animador.play(animacion)
