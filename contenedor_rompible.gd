class_name ContenedorRompible
extends StaticBody3D
# Base de los objetos que se rompen a espadazos y sueltan recolectables.
# Apuntar.gd le pega llamando recibir_golpe(), igual que a un esqueleto.
#
# CajaRecursos y Barril heredan de aquí y solo cambian:
#   _construir_cuerpo() -> cómo se ve
#   corazones_al_romper / armas_al_romper -> qué suelta
#
# Al romperse avisa al grupo "rompibles": SistemaEventos hace el destello de luz.

signal evento(posicion: Vector3)
signal roto

@export var vida_maxima := 2
@export var corazones_al_romper := 1
@export var armas_al_romper := 1
@export var dispersion := 1.0                  # m: qué tanto se reparten los objetos
@export var escena_corazon: PackedScene = preload("res://recolectable_corazon.tscn")
@export var escena_arma: PackedScene = preload("res://recolectable_arma.tscn")
# Para agregar otros objetos sin tocar el código: arrastra sus escenas aquí.
@export var botin_extra: Array[PackedScene] = []

@export var color_cuerpo := Color("#8B5A2B")
@export var color_detalle := Color("#C9A227")
@export var tamano := Vector3(0.85, 0.90, 0.85)

var vida := 0
var _roto := false


func _enter_tree() -> void:
	add_to_group("rompibles")


func _ready() -> void:
	vida = vida_maxima
	var vista := get_node_or_null("VistaEditor")   # malla de referencia del editor
	if vista != null:
		vista.visible = false
	_construir()
	_asegurar_forma()


# La llama apuntar.gd cuando el rayo de la espada le da a este cuerpo.
func recibir_golpe(danio: int) -> void:
	if _roto:
		return
	vida = maxi(vida - danio, 0)
	if vida <= 0:
		_romper()
	else:
		_sacudir()


func _romper() -> void:
	_roto = true
	roto.emit()
	evento.emit(global_position)
	var botin: Array[PackedScene] = []
	_agregar_botin(botin, escena_corazon, corazones_al_romper)
	_agregar_botin(botin, escena_arma, armas_al_romper)
	for escena in botin_extra:
		if escena != null:
			botin.append(escena)
	_soltar(botin)
	_escombros()
	queue_free()


func _agregar_botin(lista: Array[PackedScene], escena: PackedScene, cantidad: int) -> void:
	if escena == null:
		return
	for i in maxi(cantidad, 0):
		lista.append(escena)


# Reparte el botín en círculo para que los objetos no caigan uno encima del otro.
func _soltar(botin: Array[PackedScene]) -> void:
	if botin.is_empty():
		return
	var padre := get_parent()
	if padre == null:
		return
	for i in botin.size():
		var objeto := botin[i].instantiate() as Node3D
		if objeto == null:
			continue
		var angulo := TAU * float(i) / float(botin.size()) + randf_range(-0.15, 0.15)
		var radio := randf_range(0.35, maxf(dispersion, 0.40))
		var destino: Vector3 = global_position + Vector3(
			cos(angulo) * radio, 0.50, sin(angulo) * radio)
		# Se coloca ANTES de entrar al árbol para que el recolectable guarde
		# su altura de flotación correcta en _ready().
		objeto.position = padre.to_local(destino)
		padre.add_child(objeto)


func _escombros() -> void:
	var padre := get_parent()
	if padre == null:
		return
	for i in 8:
		var trozo := RigidBody3D.new()
		trozo.collision_layer = 0
		trozo.collision_mask = 1
		var malla := MeshInstance3D.new()
		var caja := BoxMesh.new()
		var tam := Vector3(randf_range(0.07, 0.15), randf_range(0.07, 0.15),
			randf_range(0.07, 0.15))
		caja.size = tam
		malla.mesh = caja
		malla.material_override = _material(color_cuerpo if i % 3 != 0 else color_detalle)
		trozo.add_child(malla)
		var forma := CollisionShape3D.new()
		var caja_forma := BoxShape3D.new()
		caja_forma.size = tam
		forma.shape = caja_forma
		trozo.add_child(forma)
		padre.add_child(trozo)
		trozo.global_position = global_position + Vector3(
			randf_range(-0.20, 0.20), randf_range(0.35, 0.80), randf_range(-0.20, 0.20))
		trozo.apply_central_impulse(Vector3(
			randf_range(-1.5, 1.5), randf_range(1.0, 2.5), randf_range(-1.5, 1.5)))
		trozo.apply_torque_impulse(Vector3(
			randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)))
		get_tree().create_timer(1.8).timeout.connect(trozo.queue_free)


func _sacudir() -> void:
	var t := create_tween()
	t.tween_property(self, "scale", Vector3.ONE * 1.07, 0.05)
	t.tween_property(self, "scale", Vector3.ONE, 0.10)


# ---------------------------------------------------------------------------
# Forma de colisión y dibujo
# ---------------------------------------------------------------------------
func _asegurar_forma() -> void:
	var forma := get_node_or_null("Forma") as CollisionShape3D
	if forma == null:
		forma = CollisionShape3D.new()
		forma.name = "Forma"
		add_child(forma)
	if forma.shape == null:
		forma.shape = _forma_por_defecto()
		forma.position = Vector3(0, _altura_forma() * 0.5, 0)


func _forma_por_defecto() -> Shape3D:
	var caja := BoxShape3D.new()
	caja.size = tamano
	return caja


func _altura_forma() -> float:
	return tamano.y


func _construir() -> void:
	_construir_cuerpo()


func _construir_cuerpo() -> void:
	_caja(tamano, Vector3(0, tamano.y * 0.5, 0), color_cuerpo)


func _malla(malla: Mesh, pos: Vector3, color: Color, emision := Color.BLACK) -> MeshInstance3D:
	var nodo := MeshInstance3D.new()
	nodo.mesh = malla
	nodo.position = pos
	nodo.material_override = _material(color, emision)
	add_child(nodo)
	return nodo


func _caja(tam: Vector3, pos: Vector3, color: Color, emision := Color.BLACK) -> MeshInstance3D:
	var caja := BoxMesh.new()
	caja.size = tam
	return _malla(caja, pos, color, emision)


func _cilindro(radio: float, alto: float, pos: Vector3, color: Color,
		emision := Color.BLACK) -> MeshInstance3D:
	var cilindro := CylinderMesh.new()
	cilindro.top_radius = radio
	cilindro.bottom_radius = radio
	cilindro.height = alto
	cilindro.radial_segments = 12
	cilindro.rings = 1
	return _malla(cilindro, pos, color, emision)


func _material(color: Color, emision := Color.BLACK) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if emision != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = emision
		mat.emission_energy_multiplier = 1.0
	return mat
