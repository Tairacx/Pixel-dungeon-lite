class_name ParedesTransparentes
extends Node
# Funde (con dithering) los muros que se interponen entre la cámara y el héroe.
# Aplica el material muro_dither.gdshader solo a los muros que tapan, y les anima el
# parámetro "fade" por instancia. Los muros que dejan de tapar vuelven al material original.

@export var camara: Camera3D
@export var objetivo: Node3D
@export_range(0.0, 1.0, 0.05) var fade_min := 0.15   # opacidad cuando el muro tapa
@export var velocidad := 9.0                          # 1/s: qué tan rápido aparece/desaparece
@export var radio_sondeo := 0.7                       # m: dispersión de los rayos alrededor del héroe

const SHADER := preload("res://muro_dither.gdshader")
const TEXTURA := preload("res://muro_ladrillo.png")

var _mat: ShaderMaterial
var _mallas: Array[MeshInstance3D] = []
var _fades: Dictionary = {}   # MeshInstance3D -> fade actual


func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("albedo_tex", TEXTURA)
	_mat.set_shader_parameter("uv_scale", 0.5)
	var raiz := get_tree().current_scene
	if raiz == null:
		raiz = get_parent()
	if raiz != null:
		_recolectar(raiz)


func _recolectar(nodo: Node) -> void:
	if nodo is MeshInstance3D and _es_muro(nodo):
		_mallas.append(nodo)
	for h in nodo.get_children():
		_recolectar(h)


func _es_muro(malla: MeshInstance3D) -> bool:
	var mat = malla.get_surface_override_material(0)
	if mat == null and malla.mesh != null and malla.mesh.get_surface_count() > 0:
		mat = malla.mesh.surface_get_material(0)
	if mat is StandardMaterial3D:
		var tex: Texture2D = mat.albedo_texture
		return tex != null and str(tex.resource_path).ends_with("muro_ladrillo.png")
	return false


func _process(delta: float) -> void:
	if camara == null or objetivo == null:
		return
	var ocultar := _buscar_ocultos()
	for malla in ocultar:
		if not _fades.has(malla):
			malla.material_override = _mat
			malla.set_instance_shader_parameter("fade", 1.0)
			_fades[malla] = 1.0
	for malla in _fades.keys():
		var target: float = fade_min if ocultar.has(malla) else 1.0
		var f: float = _fades[malla]
		f = lerpf(f, target, 1.0 - exp(-velocidad * delta))
		_fades[malla] = f
		malla.set_instance_shader_parameter("fade", f)
		if target >= 1.0 and f >= 0.995:
			malla.material_override = null
			_fades.erase(malla)


func _buscar_ocultos() -> Dictionary:
	var ocultos := {}
	var espacio := camara.get_world_3d().direct_space_state
	var base := objetivo.global_position + Vector3.UP * 0.9
	var puntos := [base]
	for i in 4:
		var ang := TAU * float(i) / 4.0
		puntos.append(base + Vector3(cos(ang), 0.0, sin(ang)) * radio_sondeo)
	for p in puntos:
		var excluir: Array[RID] = [objetivo.get_rid()]
		for _j in 4:
			var q := PhysicsRayQueryParameters3D.create(camara.global_position, p)
			q.exclude = excluir
			var choque := espacio.intersect_ray(q)
			if choque.is_empty():
				break
			var cuerpo = choque.collider
			if cuerpo is StaticBody3D and not cuerpo.has_method("recibir_golpe") and not (cuerpo is Cofre):
				var malla := cuerpo.get_node_or_null("MeshInstance3D") as MeshInstance3D
				if malla != null and _mallas.has(malla):
					ocultos[malla] = true
			excluir.append(choque.rid)
	return ocultos
