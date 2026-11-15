class_name RigEsqueleto
extends Node
# Monta las animaciones de KayKit sobre el Modelo (Skeleton_Minion/Warrior.glb).
# El .glb de KayKit solo trae el rig (huesos); las animaciones viven en los
# Rig_Medium_*.glb. Se fusionan en una biblioteca y se renombran para que el
# juego siga usando "idle", "walk" y "die".

const ANIM_GENERAL := "res://esqueletos/Rig_Medium_General.glb"
const ANIM_MOVIMIENTO := "res://esqueletos/Rig_Medium_MovementBasic.glb"


func _ready() -> void:
	var modelo := get_parent().get_node_or_null("Modelo")
	if modelo == null:
		push_warning("RigEsqueleto: no encontré el nodo Modelo.")
		return
	_montar_animaciones(modelo)


func _montar_animaciones(modelo: Node) -> void:
	if modelo.get_node_or_null("AnimationPlayer") != null:
		return   # ya montado
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	modelo.add_child(ap)
	var destino := AnimationLibrary.new()   # una sola biblioteca con todo
	for ruta in [ANIM_GENERAL, ANIM_MOVIMIENTO]:
		var escena: PackedScene = load(ruta)
		var inst := escena.instantiate()
		var src: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
		if src != null:
			for lib in src.get_animation_library_list():
				var origen := src.get_animation_library(lib)
				for nombre in origen.get_animation_list():
					if not destino.has_animation(nombre):
						destino.add_animation(nombre, origen.get_animation(nombre))
		inst.queue_free()
	ap.add_animation_library("", destino)
	_renombrar(ap, "Idle_A", "idle")
	_renombrar(ap, "Walking_A", "walk")
	_renombrar(ap, "Death_A", "die")


func _renombrar(ap: AnimationPlayer, de: String, a: String) -> void:
	for lib in ap.get_animation_library_list():
		var l := ap.get_animation_library(lib)
		if l.has_animation(de):
			l.rename_animation(de, a)
