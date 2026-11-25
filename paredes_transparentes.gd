class_name ParedesTransparentes
extends Node
# Funde (con dithering) SOLO los muros que tapan algo importante:
#   - al héroe (cintura, torso y cabeza), o
#   - un detalle del mapa (cofres, barriles/cajas, corazones/armas).
# El resto de los muros queda opaco: no desaparece todo lo que se acerca.
# En un pasillo este-oeste se destapa únicamente la pared del lado de la cámara;
# en los pasillos norte-sur no hace falta destapar nada.
#
# La detección usa las cajas (AABB) de los muros, no los rayos de física: las
# colisiones de los muros son más bajas que la malla y algunos tapaban sin que
# el rayo los detectara.

@export var camara: Camera3D
@export var objetivo: Node3D
@export_range(0.0, 1.0, 0.05) var fade_min := 0.15   # opacidad cuando el muro tapa
@export var velocidad := 9.0                          # 1/s: qué tan rápido aparece/desaparece
@export var radio_detalles := 4.0                     # m: cofres/barriles cercanos al héroe
@export var intervalo_chequeo := 0.1                  # s: cada cuánto se recalcula

const SHADER := preload("res://muro_dither.gdshader")
const TEXTURA := preload("res://pared_piedra.png")

var _mat: ShaderMaterial
var _muros: Array = []        # [{ "malla": MeshInstance3D, "caja": AABB }]
var _fades: Dictionary = {}   # MeshInstance3D -> fade actual
var _tapan: Dictionary = {}   # MeshInstance3D -> true si ahora tapa algo
var _espera := 0.0


func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("albedo_tex", TEXTURA)
	_mat.set_shader_parameter("uv_scale", 0.33333)
	var raiz := get_tree().current_scene
	if raiz == null:
		raiz = get_parent()
	if raiz != null:
		_recolectar(raiz)
	for m in _muros:
		var malla: MeshInstance3D = m["malla"]
		if malla.mesh != null:
			m["caja"] = malla.global_transform * malla.mesh.get_aabb()


func _recolectar(nodo: Node) -> void:
	if nodo is MeshInstance3D and _es_muro(nodo):
		_muros.append({"malla": nodo, "caja": AABB()})
	for h in nodo.get_children():
		_recolectar(h)


func _es_muro(malla: MeshInstance3D) -> bool:
	var mat = malla.get_surface_override_material(0)
	if mat == null and malla.mesh != null and malla.mesh.get_surface_count() > 0:
		mat = malla.mesh.surface_get_material(0)
	if mat is StandardMaterial3D:
		var tex: Texture2D = mat.albedo_texture
		return tex != null and (str(tex.resource_path).ends_with("pared_piedra.png")
			or str(tex.resource_path).ends_with("muro_ladrillo.png"))
	return false


func _process(delta: float) -> void:
	if camara == null or objetivo == null:
		return
	_espera -= delta
	if _espera <= 0.0:
		_espera = maxf(intervalo_chequeo, 0.02)
		_calcular_tapan()
	_animar(delta)


func _calcular_tapan() -> void:
	var desde := camara.global_position
	var base := objetivo.global_position
	_tapan = {}

	# 1) El héroe: torso y cabeza. Las piernas solas no alcanzan para destapar
	#    una pared (si no, al aparecer ya desaparecería la pared del sur).
	for alto in [0.9, 1.4]:
		_marcar_tapan(desde, base + Vector3.UP * alto)

	# 2) Los cofres y barriles cercanos al héroe (no los de otras salas).
	#    Si hay una pared entre el héroe y el detalle, es de otra sala: no cuenta.
	var vistos := {}
	var pecho := base + Vector3.UP * 0.9
	for nodo in get_tree().get_nodes_in_group("detalles_camara"):
		if not is_instance_valid(nodo) or not (nodo is Node3D):
			continue
		if vistos.has(nodo.get_instance_id()):
			continue
		vistos[nodo.get_instance_id()] = true
		var punto: Vector3 = nodo.global_position + Vector3.UP * 0.3
		if punto.distance_to(base) > radio_detalles:
			continue
		if _hay_muro_entre(pecho, punto):
			continue
		if camara.is_position_in_frustum(punto):
			_marcar_tapan(desde, punto)


func _hay_muro_entre(desde: Vector3, hasta: Vector3) -> bool:
	for m in _muros:
		var caja: AABB = m["caja"]
		if caja.intersects_segment(desde, hasta) != null:
			return true
	return false


func _marcar_tapan(desde: Vector3, punto: Vector3) -> void:
	for m in _muros:
		var malla: MeshInstance3D = m["malla"]
		if _tapan.has(malla):
			continue
		var caja: AABB = m["caja"]
		if caja.intersects_segment(desde, punto) != null:
			_tapan[malla] = true


func _animar(delta: float) -> void:
	for malla in _tapan:
		if not _fades.has(malla):
			malla.material_override = _mat
			malla.set_instance_shader_parameter("fade", 1.0)
			_fades[malla] = 1.0
	for malla in _fades.keys():
		var target: float = fade_min if _tapan.has(malla) else 1.0
		var f: float = _fades[malla]
		f = lerpf(f, target, 1.0 - exp(-velocidad * delta))
		_fades[malla] = f
		malla.set_instance_shader_parameter("fade", f)
		if target >= 1.0 and f >= 0.995:
			malla.material_override = null
			_fades.erase(malla)
