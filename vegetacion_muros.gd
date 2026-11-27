extends Node
# Autoload "Vegetacion": agrega musgo/vegetación procedural a los muros de la
# mazmorra sin tocar ninguna escena ni el script de paredes transparentes.
#
# Cómo funciona:
#   - Busca MeshInstance3D cuyo material de superficie sea StandardMaterial3D
#     con la textura de muro (pared_piedra.png / muro_ladrillo.png).
#   - Les asigna `material_overlay` con musgo_muro.gdshader. El overlay se dibuja
#     encima de la piedra y NO reemplaza `surface_material_override` ni el
#     `material_override` que pone paredes_transparentes.gd al destapar muros;
#     por eso el musgo y el muro se destapan juntos.
#   - Cada muro lleva su propio ShaderMaterial (no uno compartido) porque el
#     `fade` es por instancia; en GL Compatibility un `instance uniform` no llega
#     al pass del overlay. El fade se copia al crear el musgo y después lo
#     mantiene paredes_transparentes.gd cuando cambia (nada por cuadro acá).
#   - Todo lo demás (héroe, enemigos, pisos, props) queda intacto porque no usa
#     esa textura.

const RUTA_SHADER := "res://musgo_muro.gdshader"
const SUFIJOS_MURO: Array[String] = ["pared_piedra.png", "muro_ladrillo.png"]
const INTERVALO_REPASO := 0.25   # s: como mucho 4 escaneos por segundo

var _shader: Shader
var _procesadas: Dictionary = {}          # get_instance_id() -> true
var _sucio := true                        # hay que volver a escanear el árbol
var _timer: Timer


func _ready() -> void:
	_shader = load(RUTA_SHADER)
	# Los escaneos se hacen con un Timer de un solo disparo en vez de _process:
	# así el autoload no trabaja en cada cuadro y queda pausable con el juego.
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = INTERVALO_REPASO
	_timer.timeout.connect(_repasar)
	add_child(_timer)
	# Los muros pueden aparecer o cambiar de escena en cualquier momento
	# (Level_1, sala_jefe, menú): nos avisamos y repasamos con calma.
	get_tree().node_added.connect(_al_agregar_nodo)
	get_tree().tree_changed.connect(_al_cambiar_arbol)
	_marcar_sucio()


# Programa un repaso dentro de INTERVALO_REPASO. Si ya hay uno pendiente no se
# reinicia: los avisos en ráfaga se juntan en un solo escaneo.
func _marcar_sucio() -> void:
	_sucio = true
	if _timer != null and _timer.is_stopped():
		_timer.start()


func _al_agregar_nodo(_nodo: Node) -> void:
	_marcar_sucio()


func _al_cambiar_arbol() -> void:
	_marcar_sucio()


func _repasar() -> void:
	if not _sucio:
		return
	_sucio = false
	var raiz := get_tree().current_scene
	if raiz == null:
		raiz = get_tree().root
	if raiz != null:
		_procesar(raiz)


func _procesar(nodo: Node) -> void:
	if nodo is MeshInstance3D and _es_muro(nodo):
		_poner_musgo(nodo)
	for hijo in nodo.get_children():
		_procesar(hijo)


# Un muro es una malla con la piedra (o el ladrillo del jefe) como material de
# superficie. Se mira el override de superficie, el override global y, por las
# dudas, el material propio de la malla.
func _es_muro(malla: MeshInstance3D) -> bool:
	var mat: Material = null
	# Ojo: get_surface_override_material() tira error si la malla no tiene
	# overrides cargados (varias mallas del juego no los usan).
	if malla.get_surface_override_material_count() > 0:
		mat = malla.get_surface_override_material(0)
	if mat == null:
		mat = malla.material_override
	if mat == null and malla.mesh != null and malla.mesh.get_surface_count() > 0:
		mat = malla.mesh.surface_get_material(0)
	if not (mat is StandardMaterial3D):
		return false
	var textura: Texture2D = (mat as StandardMaterial3D).albedo_texture
	if textura == null:
		return false
	var ruta := str(textura.resource_path)
	for sufijo in SUFIJOS_MURO:
		if ruta.ends_with(sufijo):
			return true
	return false


func _poner_musgo(malla: MeshInstance3D) -> void:
	var id := malla.get_instance_id()
	if _procesadas.has(id):
		return
	_procesadas[id] = true

	# Material propio de este muro: el fade de la transparencia es por instancia.
	var musgo := ShaderMaterial.new()
	musgo.shader = _shader
	# Si el muro ya está destapado cuando le ponemos el musgo, arrancamos con el
	# fade que tiene ahora. Los cambios posteriores los avisa paredes_transparentes.gd.
	musgo.set_shader_parameter("fade", _fade_actual(malla))
	# Solo el overlay: el material de la piedra y el de la transparencia siguen
	# siendo los dueños de la malla.
	malla.material_overlay = musgo
	# Al descargarse la escena el muro se libera: sacamos su ID de _procesadas
	# para que una recarga vuelva a vestirlo (si no, el Dictionary solo crece).
	malla.tree_exiting.connect(_olvidar.bind(id), CONNECT_ONE_SHOT)


# `fade` que paredes_transparentes.gd deja por instancia en el muro (0 = muro
# invisible, 1 = opaco). Fuera del fade el muro no tiene override de shader y el
# musgo queda opaco.
func _fade_actual(malla: MeshInstance3D) -> float:
	if malla.material_override is ShaderMaterial:
		var valor = malla.get_instance_shader_parameter("fade")
		if valor is float:
			return valor
	return 1.0


func _olvidar(id: int) -> void:
	_procesadas.erase(id)
