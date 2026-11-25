extends "res://esqueleto_pequeno.gd"
# Esqueleto Guerrero ELITE (KayKit Skeleton_Warrior, el modelo del Rey pero de tamaño
# normal). Tanque: 4 de vida, lento y pega más fuerte por contacto.
# Habilidad OCASIONAL: GOLPE SÍSMICO. Si el héroe está cerca, se detiene medio
# segundo con un anillo rojo creciendo en el piso (aviso para escapar) y después
# golpea la suelo: 1 corazón a todo lo que quede dentro del anillo.
# No lo usa siempre: tira los dados cada "cooldown_sismo" segundos.

@export_range(0.0, 1.0, 0.05) var probabilidad_sismo := 0.45
@export var cooldown_sismo := 8.0          # s entre intentos
@export var radio_sismo := 2.3             # m del área del golpe
@export var aviso_sismo := 0.5             # s de aviso antes de golpear
@export var danio_sismo := 1.0             # corazones del golpe sísmico

var _t_sismo := 3.0
var _cargando := 0.0
var _anillo: MeshInstance3D
var _luz_aviso: OmniLight3D


func _physics_process(delta: float) -> void:
	if _cargando > 0.0:
		_cargando -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		velocity += get_gravity() * delta
		move_and_slide()
		if _cargando <= 0.0:
			_golpear_suelo()
		return

	super(delta)   # patrulla / persecución / daño por contacto de siempre
	if objetivo == null or vida <= 0:
		return
	_t_sismo -= delta
	if _t_sismo > 0.0:
		return
	_t_sismo = cooldown_sismo
	if randf() > probabilidad_sismo:
		return   # esta vez no: sigue pegando de manera normal
	if global_position.distance_to(objetivo.global_position) <= radio_sismo + 0.7:
		_cargar_sismo()


func _cargar_sismo() -> void:
	_cargando = aviso_sismo
	aturdir(aviso_sismo + 0.05)   # quieto mientras carga
	if _anillo == null:
		_anillo = MeshInstance3D.new()
		_anillo.name = "AvisoSismo"
		var disco := QuadMesh.new()
		disco.size = Vector2(radio_sismo * 2.0, radio_sismo * 2.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.25, 0.25, 0.35)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.render_priority = 5
		disco.material = mat
		_anillo.mesh = disco
		_anillo.rotation_degrees = Vector3(-90, 0, 0)
		_anillo.position = Vector3(0, 0.06, 0)
		add_child(_anillo)
	_anillo.visible = true
	_anillo.scale = Vector3.ONE * 0.25
	var t := create_tween()
	t.tween_property(_anillo, "scale", Vector3.ONE, aviso_sismo)
	if _luz_aviso == null:
		_luz_aviso = OmniLight3D.new()
		_luz_aviso.name = "LuzSismo"
		_luz_aviso.light_color = Color("#FF5040")
		_luz_aviso.omni_range = 3.0
		_luz_aviso.position = Vector3(0, 1.2, 0)
		add_child(_luz_aviso)
	_luz_aviso.light_energy = 2.5
	var t2 := create_tween()
	t2.tween_property(_luz_aviso, "light_energy", 0.2, aviso_sismo)


func _golpear_suelo() -> void:
	aturdido = 0.0   # la carga ya cumplió su función: que no se congele tras el sísmico
	if _anillo != null:
		_anillo.visible = false
	if _luz_aviso != null:
		_luz_aviso.light_energy = 0.0
	if objetivo != null \
			and global_position.distance_to(objetivo.global_position) <= radio_sismo:
		var salud = objetivo.get_node_or_null("Salud")
		if salud != null:
			salud.recibir_danio(danio_sismo, global_position)


func _morir() -> void:
	if _anillo != null:
		_anillo.visible = false
	if _luz_aviso != null:
		_luz_aviso.light_energy = 0.0
	super()
