extends Node
# Arma.gd - arma visual que se cuelga de la mano derecha del modelo.
# Se usa como nodo hijo del Personaje (espada normal) y del Perseguidor (espada grande).
# No toca la lógica de daño: eso lo siguen haciendo espada.gd y apuntar.gd.

@export var largo_hoja := 0.30          # unidades del modelo (x2.6 = metros en el juego)
@export var ancho_hoja := 0.045
@export var color_hoja := Color("#E8DCC0")
@export var color_guarda := Color("#F2A33A")
@export var color_empunadura := Color("#3F3552")
@export var brillo := Color("#000000")  # emisión de la hoja (el Perseguidor usa rojo)
@export var posicion := Vector3(-0.24, 0, 0)       # dónde queda respecto a arm-right
@export var rotacion_grados := Vector3(90.0, 0.0, 0.0)  # 90 en X = la hoja apunta hacia adelante

var espada: Node3D
var nivel := 0
var _hoja: MeshInstance3D
var _luz: OmniLight3D


func _ready() -> void:
	var modelo = get_parent().get_node("Modelo")
	var mano = _enganchar(modelo, "arm-right")
	if mano == null:
		return
	espada = _construir()
	espada.position = posicion
	espada.rotation_degrees = rotacion_grados
	mano.add_child(espada)
	print("Arma: espada colgada de la mano en ", get_parent().name)


func _construir() -> Node3D:
	var raiz = Node3D.new()
	raiz.name = "EspadaVisual"
	# Empuñadura (donde cierra el puño) y pomo
	_caja(raiz, Vector3(0.022, 0.09, 0.022), Vector3(0, 0.0, 0), color_empunadura)
	_caja(raiz, Vector3(0.04, 0.025, 0.04), Vector3(0, -0.055, 0), color_guarda)
	# Guarda (cruceta)
	_caja(raiz, Vector3(ancho_hoja * 2.6, 0.02, 0.04), Vector3(0, 0.055, 0), color_guarda)
	# Hoja
	var hoja = _caja(raiz, Vector3(ancho_hoja, largo_hoja, 0.014),
		Vector3(0, 0.065 + largo_hoja / 2.0, 0), color_hoja, brillo)
	_hoja = hoja
	# Punta (prisma triangular)
	var punta = MeshInstance3D.new()
	var prisma = PrismMesh.new()
	prisma.size = Vector3(ancho_hoja, ancho_hoja * 1.4, 0.014)
	punta.mesh = prisma
	punta.position = Vector3(0, 0.065 + largo_hoja + ancho_hoja * 0.7, 0)
	punta.material_override = hoja.material_override
	raiz.add_child(punta)
	return raiz


func _caja(padre: Node3D, tam: Vector3, pos: Vector3, color: Color, emision := Color.BLACK) -> MeshInstance3D:
	var m = MeshInstance3D.new()
	var caja = BoxMesh.new()
	caja.size = tam
	m.mesh = caja
	m.position = pos
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if emision != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = emision
		mat.emission_energy_multiplier = 0.8
	m.material_override = mat
	padre.add_child(m)
	return m


# Lo llama Apuntar.mejorar() cuando el héroe recoge un arma.
# Cambia el brillo de la hoja y enciende una luz pequeña; no toca el daño.
func aplicar_mejora(n: int) -> void:
	nivel = n
	if _hoja == null:
		return
	var mat := _hoja.material_override as StandardMaterial3D
	if mat == null:
		return
	if n <= 0:
		mat.emission_enabled = false
		return
	var colores := [Color("#46D9FF"), Color("#FFC94A"), Color("#FF6AD5"), Color("#FF4A4A")]
	var tono: Color = colores[clampi(n - 1, 0, colores.size() - 1)]
	mat.emission_enabled = true
	mat.emission = tono
	mat.emission_energy_multiplier = 0.9 + 0.35 * float(n)
	if _luz == null:
		_luz = OmniLight3D.new()
		_luz.name = "LuzMejora"
		_luz.omni_range = 1.8
		_luz.omni_attenuation = 2.0
		_luz.position = Vector3(0, 0.065 + largo_hoja * 0.6, 0)
		if espada != null:
			espada.add_child(_luz)
		else:
			add_child(_luz)
	_luz.light_color = tono
	_luz.light_energy = 0.35 + 0.20 * float(n)


# Cuelga un nodo de un HUESO del esqueleto (los huesos no son nodos normales).
func _enganchar(modelo: Node, hueso: String) -> Node3D:
	for esq in modelo.find_children("*", "Skeleton3D", true, false):
		if esq.find_bone(hueso) != -1:
			var agarre = BoneAttachment3D.new()
			agarre.name = "Agarre_" + hueso
			esq.add_child(agarre)
			agarre.bone_name = hueso
			return agarre
	var nodo = modelo.find_child(hueso, true, false)   # por si el modelo no trae esqueleto
	if nodo is Node3D:
		return nodo
	push_warning("No encontré el hueso '" + hueso + "' en el modelo")
	return null
