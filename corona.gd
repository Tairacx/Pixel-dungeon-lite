class_name Corona
extends Node
# Corona dorada que se cuelga del hueso "head" del esqueleto KayKit (Rey Esqueleto).
# Cuélgalo como hijo del enemigo/jefe. Todo se arma con cajas, como el resto del juego.

@export var color_corona := Color("#F2A33A")
@export var color_joya := Color("#D63A3A")
@export var altura := 0.38        # m sobre el origen del hueso "head"


func _ready() -> void:
	var modelo := get_parent().get_node_or_null("Modelo")
	if modelo == null:
		push_warning("Corona: no encontré el nodo Modelo.")
		return
	var agarre := _enganchar(modelo, "head")
	if agarre == null:
		push_warning("Corona: no encontré el hueso 'head'.")
		return
	# Aro dorado
	_caja(agarre, Vector3(0.34, 0.05, 0.34), Vector3(0, altura, 0), color_corona)
	# 5 picos
	for i in 5:
		var ang := TAU * i / 5.0
		var p := Vector3(sin(ang) * 0.15, altura + 0.055, cos(ang) * 0.15)
		var pico := _caja(agarre, Vector3(0.05, 0.09, 0.05), p, color_corona)
		pico.rotation = Vector3(0, ang, 0)
	# Joya al frente
	_caja(agarre, Vector3(0.04, 0.05, 0.04), Vector3(0, altura + 0.05, 0.15),
		color_joya, color_joya)


func _enganchar(modelo: Node, hueso: String) -> Node3D:
	var esq: Skeleton3D = modelo.find_child("Skeleton3D", true, false)
	if esq != null and esq.find_bone(hueso) != -1:
		var a := BoneAttachment3D.new()
		a.name = "Corona"
		esq.add_child(a)
		a.bone_name = hueso
		return a
	return null


func _caja(padre: Node, tam: Vector3, pos: Vector3, color: Color,
		emision := Color.BLACK) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = tam
	m.mesh = caja
	m.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	if emision != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = emision
		mat.emission_energy_multiplier = 1.5
	m.material_override = mat
	padre.add_child(m)
	return m
