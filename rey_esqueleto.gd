extends Node
# Rey Esqueleto - viste al Perseguidor: hueso blanco, cráneo, corona y costillas.
# Cuélgalo como nodo hijo de Perseguidor (junto a su Arma). Todo se arma con cajas
# para que combine con el estilo pixel del juego.

@export var color_hueso := Color("#E8DCC0")
@export var color_sombra := Color("#1B1626")   # cuencas y nariz
@export var color_corona := Color("#F2A33A")
@export var color_ojos := Color("#D63A3A")
@export var corona := true       # los esqueletos pequeños no llevan corona
@export var costillas := true


func _ready() -> void:
	var modelo = get_parent().get_node("Modelo")
	_pintar_huesos(modelo)
	var cabeza = _enganchar(modelo, "head")
	var torso = _enganchar(modelo, "torso")
	if cabeza != null:
		_cara(cabeza)
		if corona:
			_corona(cabeza)
	if torso != null and costillas:
		_costillas(torso)
	print("ReyEsqueleto: listo en ", get_parent().name)


# 1) Todo el cuerpo del modelo pasa a ser hueso (sin la textura de piel/ropa).
func _pintar_huesos(modelo: Node) -> void:
	var hueso = StandardMaterial3D.new()
	hueso.albedo_color = color_hueso
	hueso.roughness = 0.9
	for malla in modelo.find_children("*", "MeshInstance3D", true, false):
		if malla.name in ["body-mesh", "head-mesh"]:
			malla.material_override = hueso


# 2) Cara de calavera: cuencas con brillo rojo, nariz y dientes.
func _cara(cabeza: Node3D) -> void:
	var z = 0.172   # cara del cráneo (el modelo mira hacia +Z)
	for lado in [-1, 1]:
		_caja(cabeza, Vector3(0.07, 0.07, 0.02), Vector3(0.065 * lado, 0.21, z), color_sombra)
		_caja(cabeza, Vector3(0.03, 0.03, 0.02), Vector3(0.065 * lado, 0.21, z + 0.008),
			color_ojos, color_ojos)
	_caja(cabeza, Vector3(0.04, 0.05, 0.02), Vector3(0, 0.145, z), color_sombra)   # nariz
	for i in range(5):                                                              # dientes
		_caja(cabeza, Vector3(0.022, 0.035, 0.02), Vector3(-0.056 + 0.028 * i, 0.075, z), color_sombra if i % 2 == 0 else color_hueso)


# 3) Corona: aro dorado con 5 picos.
func _corona(cabeza: Node3D) -> void:
	var y = 0.385
	_caja(cabeza, Vector3(0.40, 0.05, 0.40), Vector3(0, y, 0), color_corona)
	for i in range(5):
		var ang = TAU * i / 5.0
		var p = Vector3(sin(ang) * 0.17, y + 0.06, cos(ang) * 0.17)
		var pico = _caja(cabeza, Vector3(0.06, 0.10, 0.06), p, color_corona)
		pico.rotation_degrees = Vector3(0, rad_to_deg(ang), 0)
	_caja(cabeza, Vector3(0.05, 0.05, 0.05), Vector3(0, y + 0.06, 0.17), color_ojos, color_ojos)  # joya


# 4) Costillas: barras horizontales sobre el pecho.
func _costillas(torso: Node3D) -> void:
	for i in range(4):
		_caja(torso, Vector3(0.20, 0.018, 0.012), Vector3(0, 0.03 + 0.04 * i, 0.075), color_sombra)
	_caja(torso, Vector3(0.018, 0.17, 0.012), Vector3(0, 0.10, 0.076), color_sombra)   # esternón


func _caja(padre: Node3D, tam: Vector3, pos: Vector3, color: Color, emision := Color.BLACK) -> MeshInstance3D:
	var m = MeshInstance3D.new()
	var caja = BoxMesh.new()
	caja.size = tam
	m.mesh = caja
	m.position = pos
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	if emision != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = emision
		mat.emission_energy_multiplier = 1.5
	m.material_override = mat
	padre.add_child(m)
	return m


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
