extends MeshInstance3D
# Estela (onda expansiva) del tajo: la cinta de luz que dibuja el recorrido de la
# hoja y se desvanece detrás.
#
# Por qué una cinta procedural y no las opciones "modernas":
#   - Trail3D es de Godot 4.8 y acá corre 4.7.2: no existe.
#   - Las particle trails de GPUParticles3D no funcionan en GL Compatibility, y ese
#     renderizador es requisito del curso (no se puede cambiar).
# Entonces, cada cuadro se muestrean dos puntos de la hoja (base y punta) y se
# reconstruye una cinta (ribbon) con ImmediateMesh. Es barato (≤ 16 muestras) y no
# depende del renderizador.
#
# La crea arma.gd como hija de EspadaVisual y le pasa los valores del Inspector.
# Todo lo de acá es visual: si no hay hoja o no hay nodo Espada, no hace nada.

const RUTA_SHADER := "res://estela_espada.gdshader"
const TOPE_MUESTRAS := 16          # techo duro de seguridad (por costo)

@export_group("Referencias")
@export var arma: Node             # Arma que nos creó (lo completa arma.gd)
@export var largo_hoja := 0.4      # unidades del modelo (arma.gd la copia)
@export var inicio_hoja := 0.065   # dónde arranca la hoja dentro de EspadaVisual

@export_group("Cinta")
@export_range(2, 16) var muestras := 14   # muestras vivas (cada una = 2 vértices)
@export var vida := 0.18                  # s que vive cada muestra
@export var cola := 0.12                  # s que tarda la cola en apagarse al terminar
@export var paso_minimo := 0.02           # m: si la hoja casi no se movió, no muestrea
@export_range(0.0, 1.0) var ancho_cola := 0.3   # ancho que conserva la punta de la cola

@export_group("Color")
@export var color_nuevo := Color("#FFF4D2")   # filo recién cortado (blanco cálido)
@export var color_medio := Color("#F2A33A")   # dorado de la paleta
@export var color_cola := Color("#A9661B")    # ámbar apagado
@export var color_remate := Color("#FFD98A")  # el remate del combo se ve más cálido
@export var ancho_remate := 1.35              # y con una cinta más ancha
@export_range(1, 4) var pasos_alfa := 3       # escalones de alfa (look pixel-art)
@export var intensidad := 1.0
@export_range(0.0, 1.0) var suavizado := 0.6  # borde de la cinta: 0 duro, 1 humo

@export_group("Destello del impacto")
@export var destello_golpe := true
@export var color_destello := Color("#FFE7B0")
@export var tam_destello := 0.5
@export var dur_destello := 0.12

var _visual: Node3D            # EspadaVisual: la hoja que seguimos
var _nodo_espada: Node         # Personaje/Espada: estado del ataque y señales
var _salud: Node               # Personaje/Salud: avisa si el héroe muere en pleno tajo
var _malla: ImmediateMesh
var _destello: MeshInstance3D
var _mat_destello: Material

var _bases := PackedVector3Array()     # punto de la base de la hoja por muestra
var _puntas := PackedVector3Array()    # punto de la punta de la hoja por muestra
var _edades := PackedFloat32Array()    # edad de cada muestra, en segundos
var _fundido := 1.0                    # 1 = visible, 0 = apagado (cola del tajo)
var _timer_ataque := 0.0               # cuenta atrás de ataque_iniciado
var _destello_t := 0.0
var _paso := 0                         # paso del combo (2 = remate)
var vertices := 0                      # vértices de la última reconstrucción (informativo)


func _ready() -> void:
	# La cinta vive en coordenadas de mundo: no hereda el movimiento de la hoja, así
	# las muestras viejas quedan clavadas donde cortó la espada.
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false

	_malla = ImmediateMesh.new()
	mesh = _malla
	material_override = _crear_material(false)

	_crear_destello()

	if arma == null:
		arma = _buscar_arma()
	_visual = _buscar_visual()
	if arma != null:
		_enganchar_ataque()
		_enganchar_salud()

	# Sin nodo Espada (por ejemplo, la espada de un enemigo) no hay ataque que seguir.
	set_process(_nodo_espada != null)


func _process(delta: float) -> void:
	if _visual == null:
		_visual = _buscar_visual()      # por si la espada se construyó más tarde
		if _visual == null:
			set_process(false)
			return

	# 1) Envejecer las muestras y soltar las que ya cumplieron su vida.
	for i in _edades.size():
		_edades[i] = _edades[i] + delta
	while not _edades.is_empty() and _edades[0] > maxf(vida, 0.01):
		_edades.remove_at(0)
		_bases.remove_at(0)
		_puntas.remove_at(0)

	# 2) ¿Sigue el ataque en curso? Vale tanto el temporizador de ataque_iniciado
	#    como el estado de Espada (si el tajo ya venía empezado).
	if _timer_ataque > 0.0:
		_timer_ataque -= delta
	var activo := _timer_ataque > 0.0 or _ataque_activo()
	if activo:
		_fundido = 1.0
		_muestrear()
	else:
		_fundido = maxf(_fundido - delta / maxf(cola, 0.01), 0.0)

	# 3) Destello del impacto y reconstrucción de la cinta.
	_animar_destello(delta)
	_reconstruir()

	# 4) Sin ataque y sin cola pendiente: se apaga hasta el próximo tajo.
	if not activo and _destello_t <= 0.0 and (_edades.is_empty() or _fundido <= 0.0):
		_edades.clear()
		_bases.clear()
		_puntas.clear()
		_malla.clear_surfaces()
		vertices = 0
		visible = false
		set_process(false)


# Guarda una muestra con los dos puntos de la hoja en este cuadro.
func _muestrear() -> void:
	var xf := _visual.global_transform
	var base := xf * Vector3(0.0, inicio_hoja, 0.0)
	var punta := xf * Vector3(0.0, inicio_hoja + largo_hoja, 0.0)
	var n := _puntas.size()
	# Si la hoja casi no se movió no ensuciamos la cinta con triángulos de área cero.
	if n > 0 and punta.distance_to(_puntas[n - 1]) < paso_minimo:
		return
	_bases.append(base)
	_puntas.append(punta)
	_edades.append(0.0)
	var tope := mini(muestras, TOPE_MUESTRAS)
	while _edades.size() > tope:
		_edades.remove_at(0)
		_bases.remove_at(0)
		_puntas.remove_at(0)


func _reconstruir() -> void:
	_malla.clear_surfaces()
	var n := _edades.size()
	if n < 2:
		vertices = 0
		visible = false
		return

	var ancho_punta := ancho_remate if _paso == 2 else 1.0
	_malla.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(n - 1):
		# f = frescura: 1 en la muestra nueva, 0 en la punta de la cola.
		var f0 := clampf(1.0 - _edades[i] / maxf(vida, 0.01), 0.0, 1.0)
		var f1 := clampf(1.0 - _edades[i + 1] / maxf(vida, 0.01), 0.0, 1.0)
		var c0 := _color(f0)
		var c1 := _color(f1)
		# La cinta se afina hacia atrás: la base se corre hacia la punta de la hoja.
		var a0 := lerpf(ancho_cola, 1.0, f0) * ancho_punta
		var a1 := lerpf(ancho_cola, 1.0, f1) * ancho_punta
		var b0 := _bases[i].lerp(_puntas[i], 1.0 - a0)
		var b1 := _bases[i + 1].lerp(_puntas[i + 1], 1.0 - a1)
		var p0 := _puntas[i]
		var p1 := _puntas[i + 1]
		var u0 := float(i) / float(n - 1)
		var u1 := float(i + 1) / float(n - 1)
		# Dos triángulos por tramo (el material es cull_disabled: no importa el orden).
		_vertice(b0, c0, Vector2(u0, 0.0))
		_vertice(p0, c0, Vector2(u0, 1.0))
		_vertice(b1, c1, Vector2(u1, 0.0))
		_vertice(p0, c0, Vector2(u0, 1.0))
		_vertice(p1, c1, Vector2(u1, 1.0))
		_vertice(b1, c1, Vector2(u1, 0.0))
	_malla.surface_end()
	vertices = (n - 1) * 6      # dos triángulos (6 vértices) por tramo de cinta
	visible = true


func _vertice(p: Vector3, c: Color, uv: Vector2) -> void:
	# En ImmediateMesh los atributos se cargan ANTES del vértice al que pertenecen.
	_malla.surface_set_color(c)
	_malla.surface_set_uv(uv)
	_malla.surface_add_vertex(p)


# Tres tonos de la paleta con el alfa en escalones: se lee pixel-art y no como un
# degradé gigante. UV.y cruza el ancho de la hoja (0 = base, 1 = punta).
func _color(f: float) -> Color:
	var c: Color
	if f > 0.66:
		c = color_remate if _paso == 2 else color_nuevo
	elif f > 0.33:
		c = color_medio
	else:
		c = color_cola
	c.a = ceilf(clampf(f, 0.0, 1.0) * float(pasos_alfa)) / float(pasos_alfa)
	c.a *= _fundido
	return c


# ---------------------------------------------------------------------------
# Ataque y enganches
# ---------------------------------------------------------------------------

func _ataque_activo() -> bool:
	# Espada.Estado.ACTIVA == 1. Leemos el valor por nombre para no acoplar los scripts.
	var v = _propiedad(_nodo_espada, "estado")
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return int(v) == 1
	return false


func _on_ataque_iniciado(duracion: float, _momento: float) -> void:
	_enganchar_salud()     # si Salud apareció después, lo enganchamos ahora
	_timer_ataque = maxf(duracion, 0.01)
	var v = _propiedad(_nodo_espada, "paso_actual")
	_paso = int(v) if (typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT) else 0
	_fundido = 1.0
	set_process(true)


func _on_golpe() -> void:
	if not destello_golpe or _destello == null or _visual == null:
		return
	var punta: Vector3 = _visual.global_transform * Vector3(0.0, inicio_hoja + largo_hoja, 0.0)
	_destello.position = punta       # el padre (esta estela) está en coordenadas de mundo
	_destello.visible = true
	_destello_t = maxf(dur_destello, 0.01)
	set_process(true)


func _animar_destello(delta: float) -> void:
	if _destello_t <= 0.0:
		return
	_destello_t -= delta
	var k := 1.0 - clampf(_destello_t / maxf(dur_destello, 0.01), 0.0, 1.0)
	if _destello_t <= 0.0:
		_destello.visible = false
		return
	# Crece mientras se apaga: una chispa de un par de cuadros en el punto de impacto.
	_destello.scale = Vector3.ONE * (tam_destello * lerpf(0.45, 1.0, k))
	if _mat_destello is ShaderMaterial:
		(_mat_destello as ShaderMaterial).set_shader_parameter("intensidad", lerpf(1.6, 0.0, k))
	elif _mat_destello is StandardMaterial3D:
		var m := _mat_destello as StandardMaterial3D
		var c := m.albedo_color
		c.a = 1.0 - k
		m.albedo_color = c


# ---------------------------------------------------------------------------
# Referencias (todas con guardas: la estela nunca debe romper el arma)
# ---------------------------------------------------------------------------

func _buscar_arma() -> Node:
	# Si nadie nos pasó el Arma, la buscamos desde el héroe.
	var pj := get_tree().get_first_node_in_group("jugador")
	if pj != null:
		return pj.get_node_or_null("Arma")
	return null


func _buscar_visual() -> Node3D:
	var v = _propiedad(arma, "espada")
	return v if v is Node3D else null


func _enganchar_ataque() -> void:
	var pj := arma.get_parent()
	if pj == null:
		return
	var n := pj.get_node_or_null("Espada")     # los enemigos no tienen este nodo
	if n == null:
		return
	if n.has_signal("ataque_iniciado"):
		n.ataque_iniciado.connect(_on_ataque_iniciado)
	if n.has_signal("golpe"):
		n.golpe.connect(_on_golpe)
	_nodo_espada = n


# Engancha la muerte del héroe: Salud apaga el physics process de Espada y el
# tajo puede quedar en ACTIVA para siempre (la estela seguiría procesando y
# reconstruyendo la cinta para nada). Los enemigos no tienen Salud: se ignora.
func _enganchar_salud() -> void:
	if _salud != null or arma == null:
		return
	var pj := arma.get_parent()
	if pj == null:
		return
	var s := pj.get_node_or_null("Salud")
	if s == null or not s.has_signal("murio"):
		return
	if not s.murio.is_connected(_on_heroe_murio):
		s.murio.connect(_on_heroe_murio)
	_salud = s


# El héroe murió en pleno tajo: apagamos la estela del todo hasta el próximo
# ataque (que no va a haber, pero no dejamos trabajo por cuadro).
func _on_heroe_murio() -> void:
	_edades.clear()
	_bases.clear()
	_puntas.clear()
	_timer_ataque = 0.0
	_fundido = 0.0
	vertices = 0
	if _malla != null:
		_malla.clear_surfaces()
	if _destello != null:
		_destello.visible = false
	_destello_t = 0.0
	visible = false
	set_process(false)


# Lee una propiedad por nombre sin arriesgar errores si el nodo no la tiene.
func _propiedad(objeto: Object, nombre: String):
	if objeto == null:
		return null
	for p in objeto.get_property_list():
		if p.name == nombre:
			return objeto.get(nombre)
	return null


# ---------------------------------------------------------------------------
# Materiales
# ---------------------------------------------------------------------------

func _crear_material(es_destello: bool = false) -> Material:
	var sh := _listo_shader()
	if sh == null:
		# Plan B si el shader no carga: aditivo simple con color de vértice.
		return _material_alternativo(color_destello if es_destello else Color.WHITE)
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("es_destello", es_destello)
	m.set_shader_parameter("suavizado", suavizado)
	m.set_shader_parameter("intensidad", 1.6 if es_destello else intensidad)
	if es_destello:
		m.set_shader_parameter("tinte", color_destello)
	return m


func _listo_shader() -> Shader:
	var sh = load(RUTA_SHADER)
	return sh if sh is Shader else null


func _material_alternativo(tinte: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = tinte
	return m


func _crear_destello() -> void:
	_destello = MeshInstance3D.new()
	_destello.name = "DestelloGolpe"
	_destello.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_destello.visible = false
	_mat_destello = _crear_material(true)
	_destello.material_override = _mat_destello
	if _mat_destello is ShaderMaterial:
		_destello.mesh = QuadMesh.new()       # el shader lo orienta hacia la cámara
	else:
		_destello.mesh = SphereMesh.new()     # sin shader, se ve desde cualquier ángulo
	_destello.scale = Vector3.ONE * tam_destello
	add_child(_destello)
