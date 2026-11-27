extends CharacterBody3D
# Tarea C - Nivel 3: el Perseguidor patrulla, ve al héroe y lo persigue.
# Histéresis: empieza a perseguir a radio_ver y lo suelta a radio_perder (más grande).
#
# Comportamiento "inteligente" que heredan todos los enemigos:
#  - reacciona 0.3-0.7 s antes de lanzarse (no es un resorte);
#  - rodea al héroe de costado si está más cerca que `distancia_preferida`,
#    alternando de lado cada 1.5-3 s;
#  - cada `tiempo_ataque` hace un envión recto para golpear y después vuelve a rodear;
#  - se separa de los otros esqueletos para no apilarse;
#  - esquiva paredes con dos rayos cortos y retrocede si está acorralado;
#  - leash: no se aleja más de `leash` m del punto donde apareció.

enum Estado { PATRULLA, PERSEGUIR }

@export var objetivo: Node3D
@export var rapidez: float = 2.5    # m/s  (80 px/s ÷ 32 px/m)
@export var radio_ver: float = 8.0  # m  (256 px)
@export var radio_perder: float = 12.0   # m  (384 px)
@export var puntos: Array[Vector3] = [
	Vector3(-8, 0, 6), Vector3(8, 0, 6)]
@onready var anim = $Modelo/AnimationPlayer

# Aturdimiento: al recibir un golpe el enemigo se detiene unos instantes.
@export var aturdimiento := 0.4   # segundos que queda quieto

@export_group("Rodeo")
@export var distancia_preferida := 1.8   # m: más cerca que esto, circula de costado
@export var distancia_golpe := 1.5       # m: la Garra solo lastima dentro de esta distancia
@export var tiempo_ataque := 1.8         # s entre enviones para golpear
@export var duracion_ataque := 0.55      # s que dura el envión
@export var rapidez_rodeo := 0.7         # fracción de `rapidez` al circular
@export var cambio_lado_min := 1.5       # s mínimos antes de cambiar de lado
@export var cambio_lado_max := 3.0

@export_group("Separación")
@export var separacion_radio := 1.1      # m: a menos distancia se empujan
@export var separacion_fuerza := 2.4     # m/s de empuje suave

@export_group("Paredes y leash")
@export var evitar_paredes := true
@export var sonda_pared := 0.9           # m que miran los dos rayos laterales
@export var leash := 18.0                # m desde el punto de aparición

@export_group("Reacción")
@export var reaccion_min := 0.3          # s de pausa al detectar al héroe
@export var reaccion_max := 0.7

var estado = Estado.PATRULLA
var punto = 0
var aturdido := 0.0               # temporizador del aturdimiento (0 = no aturdido)

var _origen := Vector3.ZERO       # punto donde apareció (para el leash)
var _origen_listo := false
var _reaccion := 0.0             # pausa antes de lanzarse
var _lado := 1.0                 # 1 = circula por la izquierda, -1 = por la derecha
var _t_lado := 0.0
var _t_ataque := 0.0             # cuenta atrás para el próximo envión
var _ataque := 0.0               # > 0 mientras dura el envión
var _dir_mov := Vector3.ZERO     # movimiento pedido por el estado
var _vel_mov := 0.0
var _mirar := Vector3.ZERO       # hacia dónde quiere mirar (ZERO = hacia donde camina)


func _physics_process(delta: float) -> void:
	if not _origen_listo:
		_origen = global_position
		_origen_listo = true
		_t_lado = randf_range(cambio_lado_min, cambio_lado_max)
		_t_ataque = randf_range(0.4, maxf(tiempo_ataque, 0.5))
	if aturdido > 0.0:
		aturdido = maxf(aturdido - delta, 0.0)
		velocity.x = 0.0
		velocity.z = 0.0
		velocity += get_gravity() * delta
		move_and_slide()
		_actualizar_garra()
		return
	_pensar(delta)
	_aplicar_movimiento(delta)
	_actualizar_garra()


# Decide el movimiento del cuadro. Las subclases pueden tomar el control
# devolviendo true desde _pensar_propio() (lo hacen el mago y el jefe).
func _pensar(delta: float) -> void:
	_dir_mov = Vector3.ZERO
	_vel_mov = 0.0
	_mirar = Vector3.ZERO
	if objetivo == null:
		return
	var dist := _distancia()

	# Detección / pérdida con histéresis y leash.
	if estado == Estado.PATRULLA:
		# Fuera del leash no se vuelve a enganchar: si no, el estado oscilaría
		# cada cuadro (lo vio / lo perdió) porque el héroe sigue en radio_ver.
		# Se mira también al HÉROE: si quedó fuera del territorio, perseguirlo
		# solo hace que el leash lo suelte en el acto (oscilación con pausa).
		if not _lejos_del_origen() and not _heroe_fuera_del_leash() and _detecta(dist):
			estado = Estado.PERSEGUIR
			_reaccion = randf_range(reaccion_min, reaccion_max)
			_lado = 1.0 if randf() < 0.5 else -1.0
			_t_lado = randf_range(cambio_lado_min, cambio_lado_max)
			print("lo vio a ", snappedf(dist, 0.01), " m")
	elif dist > radio_perder or _lejos_del_origen():
		estado = Estado.PATRULLA
		_reaccion = 0.0
		print("lo perdió a ", snappedf(dist, 0.01), " m")

	if estado == Estado.PATRULLA:
		_patrullar()
		return

	# Reacción: se frena y lo encara antes de lanzarse.
	if _reaccion > 0.0:
		_reaccion = maxf(_reaccion - delta, 0.0)
		_mirar = _hacia_heroe()
		return

	if _pensar_propio(delta):
		return
	_perseguir(dist, delta)


# Gancho para las subclases con movimiento propio (mago y jefe).
func _pensar_propio(_delta: float) -> bool:
	return false


func _detecta(dist: float) -> bool:
	if dist > radio_ver:
		return false
	if dist < radio_ver * 0.5:
		return true                       # tan cerca lo siente aunque haya una columna
	return hay_linea_de_vision()


func _patrullar() -> void:
	if puntos.is_empty():
		return
	var meta: Vector3 = puntos[punto]
	if global_position.distance_to(meta) < 0.35:
		punto = (punto + 1) % puntos.size()
		meta = puntos[punto]
	var dir := _hacia(meta)
	if dir == Vector3.ZERO:
		return
	_querer_mover(dir, rapidez)


func _perseguir(dist: float, delta: float) -> void:
	var hacia := _hacia_heroe()
	if hacia == Vector3.ZERO:
		return
	# El envión: cada tanto se lanza derecho a golpear; si no, rodea.
	if dist <= distancia_preferida + 0.2:
		if _ataque > 0.0:
			_ataque = maxf(_ataque - delta, 0.0)
		else:
			_t_ataque = maxf(_t_ataque - delta, 0.0)
			if _t_ataque <= 0.0:
				_ataque = duracion_ataque
				_t_ataque = randf_range(tiempo_ataque * 0.8, tiempo_ataque * 1.3)
	var dir := _direccion_persecucion(hacia, dist, delta)
	var vel: float = rapidez
	if dist < distancia_preferida and _ataque <= 0.0:
		vel *= rapidez_rodeo
	_querer_mover(dir, vel, hacia)


# Dirección al perseguir. Por defecto: de frente lejos, tangente de cerca.
# La sobrescriben el esqueleto pequeño (zigzag) y el pícaro (flanqueo).
func _direccion_persecucion(hacia: Vector3, dist: float, delta: float) -> Vector3:
	if dist > distancia_preferida or _ataque > 0.0:
		return hacia
	var lado := _rodear_lado(delta)
	var tangente := hacia.rotated(Vector3.UP, lado * PI * 0.5)
	return (tangente * 0.85 + hacia * 0.15).normalized()


func _rodear_lado(delta: float) -> float:
	_t_lado -= delta
	if _t_lado <= 0.0:
		_lado = -_lado
		_t_lado = randf_range(cambio_lado_min, cambio_lado_max)
	return _lado


# --- Movimiento -----------------------------------------------------------

func _querer_mover(dir: Vector3, vel: float, mirar := Vector3.ZERO) -> void:
	_dir_mov = dir
	_vel_mov = vel
	_mirar = mirar


func _aplicar_movimiento(delta: float, con_separacion := true, con_paredes := true) -> void:
	velocity += get_gravity() * delta
	var dir := _dir_mov
	if dir.length() < 0.01 or _vel_mov < 0.01:
		velocity.x = 0.0
		velocity.z = 0.0
		_mirar_si_hace_falta()
		_animar(false)
		move_and_slide()
		return
	dir = dir.normalized()
	if con_paredes and evitar_paredes:
		dir = _esquivar_paredes(dir)
	var v := dir * _vel_mov
	if con_separacion:
		var empuje := _separacion()
		if empuje.length() > 1.0:
			empuje = empuje.normalized()
		v += empuje * separacion_fuerza
	velocity.x = v.x
	velocity.z = v.z
	var mirar := _mirar if _mirar != Vector3.ZERO else dir
	basis = Basis.looking_at(mirar)
	_animar(true)
	move_and_slide()


func _mirar_si_hace_falta() -> void:
	if _mirar != Vector3.ZERO:
		basis = Basis.looking_at(_mirar)


func _animar(caminando: bool) -> void:
	if anim == null:
		return
	var nombre := "walk" if caminando else "idle"
	if anim.has_animation(nombre) and anim.current_animation != nombre:
		anim.play(nombre)


# Retrocede alejándose del héroe (paso atrás de las retiradas).
func retroceder(delta: float, fraccion: float = 0.6) -> void:
	var hacia := _hacia_heroe()
	if hacia == Vector3.ZERO:
		_querer_mover(Vector3.ZERO, 0.0)
		_aplicar_movimiento(delta)
		_actualizar_garra()          # huyendo de espaldas: la garra no debe quedar activa
		return
	_querer_mover(-hacia, rapidez * fraccion, -hacia)
	_aplicar_movimiento(delta)
	_actualizar_garra()              # reevalúa con la orientación nueva (de espaldas al héroe)


# --- Separación entre esqueletos -----------------------------------------

func _separacion() -> Vector3:
	var empuje := Vector3.ZERO
	for grupo in ["esqueletos", "jefe"]:
		for otro in get_tree().get_nodes_in_group(grupo):
			if otro == self or not (otro is Node3D):
				continue
			var d: Vector3 = global_position - (otro as Node3D).global_position
			d.y = 0.0
			var l := d.length()
			if l < separacion_radio and l > 0.001:
				empuje += d / l * (1.0 - l / separacion_radio)
	return empuje


# --- Paredes --------------------------------------------------------------

func _esquivar_paredes(dir: Vector3) -> Vector3:
	var izq := _choca_pared(dir.rotated(Vector3.UP, 0.9))
	var der := _choca_pared(dir.rotated(Vector3.UP, -0.9))
	if izq and der:
		return -dir                          # acorralado: retrocede
	if izq:
		return dir.rotated(Vector3.UP, -0.5)  # hay pared a la izquierda: dobla a la derecha
	if der:
		return dir.rotated(Vector3.UP, 0.5)
	return dir


func _choca_pared(dir: Vector3) -> bool:
	var espacio := get_world_3d().direct_space_state
	var desde := global_position + Vector3.UP * 0.7
	var q := PhysicsRayQueryParameters3D.create(desde, desde + dir * sonda_pared)
	q.collide_with_areas = false
	var excluir: Array[RID] = [get_rid()]
	for i in range(4):
		q.exclude = excluir
		var golpe := espacio.intersect_ray(q)
		if golpe.is_empty():
			return false
		var cuerpo = golpe.get("collider")
		if cuerpo is StaticBody3D or cuerpo is GridMap:
			return true
		if not (cuerpo is CollisionObject3D):
			return false
		excluir.append((cuerpo as CollisionObject3D).get_rid())
	return false


func hay_linea_de_vision() -> bool:
	if objetivo == null:
		return false
	var espacio := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 0.9, objetivo.global_position + Vector3.UP * 0.9)
	q.collide_with_areas = false
	var excluir: Array[RID] = [get_rid()]
	if objetivo is CollisionObject3D:
		excluir.append((objetivo as CollisionObject3D).get_rid())
	for i in range(4):
		q.exclude = excluir
		var golpe := espacio.intersect_ray(q)
		if golpe.is_empty():
			return true                      # llegó sin paredes en el medio
		var cuerpo = golpe.get("collider")
		if cuerpo is StaticBody3D or cuerpo is GridMap:
			return false
		if not (cuerpo is CollisionObject3D):
			return true
		excluir.append((cuerpo as CollisionObject3D).get_rid())
	return true


# --- Ayudas ---------------------------------------------------------------

func _distancia() -> float:
	if objetivo == null:
		return INF
	return global_position.distance_to(objetivo.global_position)


func _hacia_heroe() -> Vector3:
	if objetivo == null:
		return Vector3.ZERO
	return _hacia(objetivo.global_position)


func _hacia(p: Vector3) -> Vector3:
	var d := p - global_position
	d.y = 0.0
	if d.length() < 0.02:
		return Vector3.ZERO
	return d.normalized()


func _lejos_del_origen() -> bool:
	return global_position.distance_to(_origen) > leash


# ¿El héroe quedó fuera del territorio del enemigo? Con leash alto da igual,
# pero evita que un enemigo bloqueado en el borde lo enganche y lo suelte sin parar.
func _heroe_fuera_del_leash() -> bool:
	if objetivo == null:
		return true
	return _origen.distance_to(objetivo.global_position) > leash


# La Garra solo lastima si el enemigo está encarando al héroe y a distancia corta.
# La línea de visión se consulta SOLO después de cumplir distancia y orientación:
# un rayo por enemigo y por cuadro sería caro con toda la sala mirando al héroe.
func _actualizar_garra() -> void:
	var garra := get_node_or_null("Garra")
	if garra == null or not is_instance_valid(garra):
		return
	var activa := false
	if objetivo != null and _distancia() <= distancia_golpe:
		var hacia := _hacia_heroe()
		activa = hacia != Vector3.ZERO \
			and (-global_basis.z).normalized().dot(hacia) > 0.35 \
			and hay_linea_de_vision()
	garra.set_physics_process(activa)


# Movimiento directo a un punto (lo usaba el nivel 3 de siempre).
func ir_a(p: Vector3) -> void:
	var dir := _hacia(p)
	if dir == Vector3.ZERO:
		return
	_querer_mover(dir, rapidez)
	_aplicar_movimiento(get_physics_process_delta_time())


func aturdir(segundos: float) -> void:
	aturdido = maxf(aturdido, segundos)
