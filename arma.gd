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

# Tajo lateral: durante el ataque la espada barre en horizontal frente al héroe, de su
# derecha a su izquierda, sin depender de la animación del brazo.
@export var barrido_grados := 200.0     # ángulo total del tajo (centrado al frente)
@export var barrido_duracion := 0.18    # s que tarda en cruzar (centrado en el momento del golpe)
@export var entrada_salida := 0.07      # s para pasar de la pose de reposo al tajo y de vuelta

var espada: Node3D
var nivel := 0
var _hoja: MeshInstance3D
var _luz: OmniLight3D
var _mano: Node3D
var _atacando := false
var _t := 0.0
var _duracion := 0.42
var _momento := 0.2
var _ataque: Node          # el nodo Espada (leemos el paso del combo)
var _paso := 0             # 0 = tajo, 1 = vuelta, 2 = remate


func _ready() -> void:
	var modelo = get_parent().get_node("Modelo")
	var mano = _enganchar(modelo, "arm-right")
	if mano == null:
		return
	espada = _construir()
	espada.position = posicion
	espada.rotation_degrees = rotacion_grados
	mano.add_child(espada)
	_mano = mano
	print("Arma: espada colgada de la mano en ", get_parent().name)
	var ataque = get_parent().get_node_or_null("Espada")   # los enemigos no tienen este nodo
	if ataque != null and ataque.has_signal("ataque_iniciado"):
		_ataque = ataque
		ataque.ataque_iniciado.connect(_on_ataque_iniciado)


func _on_ataque_iniciado(duracion: float, momento: float) -> void:
	_atacando = true
	_t = 0.0
	_duracion = duracion
	_momento = momento
	_paso = 0
	if _ataque != null and "paso_actual" in _ataque:
		_paso = int(_ataque.paso_actual)


func _process(delta: float) -> void:
	if not _atacando or espada == null or _mano == null:
		return
	_t += delta
	if _t >= _duracion:
		_atacando = false
		espada.position = posicion                  # vuelve a quedar en la mano
		espada.rotation_degrees = rotacion_grados
		return

	# Pose normal (sujeta a la mano) y pose de tajo; se mezclan al entrar y al salir.
	var reposo := _mano.global_transform * Transform3D(
		Basis.from_euler(Vector3(deg_to_rad(rotacion_grados.x), deg_to_rad(rotacion_grados.y),
		deg_to_rad(rotacion_grados.z))), posicion)
	var tajo := _transform_paso()
	var peso := minf(clampf(_t / entrada_salida, 0.0, 1.0),
		clampf((_duracion - _t) / entrada_salida, 0.0, 1.0))
	espada.global_transform = reposo.interpolate_with(tajo, peso)


# Elige el movimiento según el paso del combo.
func _transform_paso() -> Transform3D:
	match _paso:
		1:
			return _transform_tajo_inverso()
		2:
			return _transform_remate()
		_:
			return _transform_tajo()


# La espada en horizontal, con la hoja apuntando hacia donde barre: de la derecha del
# héroe (antes del golpe) a su izquierda (después), cruzando el frente en "momento".
func _transform_tajo() -> Transform3D:
	var pj3 := get_parent() as Node3D
	var u := clampf((_t - (_momento - barrido_duracion * 0.5)) / barrido_duracion, 0.0, 1.0)
	u = u * u * (3.0 - 2.0 * u)                     # arranca y frena suave
	var mitad := deg_to_rad(barrido_grados) * 0.5
	var angulo := lerpf(-mitad, mitad, u)           # negativo = derecha, positivo = izquierda
	var frente: Vector3 = -pj3.global_basis.z
	frente.y = 0.0
	var dir := frente.normalized().rotated(Vector3.UP, angulo)
	var escala := _mano.global_basis.x.length()     # el modelo está escalado x2.6
	var eje_y := dir                                 # la hoja apunta hacia afuera
	var eje_z := Vector3.UP                          # plano de la hoja horizontal (corta de lado)
	var eje_x := eje_y.cross(eje_z)
	var origen_mano: Vector3 = _mano.global_transform * posicion
	return Transform3D(Basis(eje_x, eje_y, eje_z).scaled(Vector3.ONE * escala), origen_mano)


# Paso 2 del combo: la vuelta, de la izquierda del héroe a su derecha.
func _transform_tajo_inverso() -> Transform3D:
	var pj3 := get_parent() as Node3D
	var u := clampf((_t - (_momento - barrido_duracion * 0.5)) / barrido_duracion, 0.0, 1.0)
	u = u * u * (3.0 - 2.0 * u)
	var mitad := deg_to_rad(barrido_grados) * 0.5
	var angulo := lerpf(mitad, -mitad, u)           # ahora empieza a la izquierda
	var frente: Vector3 = -pj3.global_basis.z
	frente.y = 0.0
	var dir := frente.normalized().rotated(Vector3.UP, angulo)
	var escala := _mano.global_basis.x.length()
	var eje_y := dir
	var eje_z := Vector3.UP
	var eje_x := eje_y.cross(eje_z)
	var origen_mano: Vector3 = _mano.global_transform * posicion
	return Transform3D(Basis(eje_x, eje_y, eje_z).scaled(Vector3.ONE * escala), origen_mano)


# Paso 3 del combo: el remate. La espada se levanta por encima de la cabeza y cae
# con todo el peso al frente (plano de la hoja vertical, mirando al héroe de frente).
func _transform_remate() -> Transform3D:
	var pj3 := get_parent() as Node3D
	var caida := barrido_duracion * 1.4
	var u := clampf((_t - (_momento - caida)) / caida, 0.0, 1.0)
	u = u * u * (3.0 - 2.0 * u)
	var frente: Vector3 = -pj3.global_basis.z
	frente.y = 0.0
	frente = frente.normalized()
	var derecha := frente.cross(Vector3.UP).normalized()
	# Arranca apuntando arriba y atrás (+110°) y termina al frente y abajo (-35°).
	var angulo := lerpf(deg_to_rad(110.0), deg_to_rad(-35.0), u)
	var dir := (frente * cos(angulo) + Vector3.UP * sin(angulo)).normalized()
	var escala := _mano.global_basis.x.length()
	var origen: Vector3 = pj3.global_position + Vector3.UP * 1.7 + frente * 0.15
	var eje_y := dir
	var eje_z := derecha
	var eje_x := eje_y.cross(eje_z)
	return Transform3D(Basis(eje_x, eje_y, eje_z).scaled(Vector3.ONE * escala), origen)


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
