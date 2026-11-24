extends Area3D
# Hueso que lanza el Rey Esqueleto. Vuela recto (no persigue): se esquiva moviéndose.
# Desaparece al pegarle al héroe, al chocar con una pared, pilar, barril o puerta, o por tiempo.
# Si el héroe es invulnerable en ese momento, lo atraviesa (para que un abanico no se gaste en un solo golpe).

@export var rapidez := 7.5
@export var danio := 1.0
@export var vida_util := 4.0     # segundos antes de desaparecer solo

var direccion := Vector3.FORWARD
var _giro: Node3D
var _orientado := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 9           # 1 = mundo (paredes, pilares, barriles, puertas) + 8 = héroe

	var forma := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = 0.28
	forma.shape = esfera
	add_child(forma)

	_giro = Node3D.new()
	add_child(_giro)
	var hueso := Color("#E8DCC0")
	_caja(Vector3(0.1, 0.1, 0.5), Vector3.ZERO, hueso)                    # el hueso
	for z in [-0.25, 0.25]:                                               # las dos puntas
		_caja(Vector3(0.2, 0.12, 0.12), Vector3(0, 0, z), hueso)
	_caja(Vector3(0.16, 0.16, 0.16), Vector3.ZERO, Color("#D63A3A"), true)  # centro rojo brillante

	body_entered.connect(_on_cuerpo)


func _physics_process(delta: float) -> void:
	if not _orientado:
		look_at(global_position + direccion, Vector3.UP)
		_orientado = true
	global_position += direccion * rapidez * delta
	_giro.rotate_z(delta * 12.0)
	vida_util -= delta
	if vida_util <= 0.0:
		queue_free()


func _on_cuerpo(cuerpo: Node3D) -> void:
	if cuerpo is CharacterBody3D:
		var salud = cuerpo.get_node_or_null("Salud")
		if salud != null and salud.recibir_danio(danio, global_position):
			queue_free()                     # le dio al héroe
	elif cuerpo is StaticBody3D:
		queue_free()                         # chocó con el mundo


func _caja(tam: Vector3, pos: Vector3, color: Color, brilla := false) -> void:
	var m := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = tam
	m.mesh = caja
	m.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if brilla:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 2.5
	m.material_override = mat
	_giro.add_child(m)
