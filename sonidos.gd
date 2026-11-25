extends Node
# Sonidos.gd - únicos SFX además del crepitar de las antorchas (antorcha.tscn):
# los slices de espada que añadiste en sonidos/.
#   - dragon-studio-sword-slice-2-393845.mp3 -> golpe final del combo (paso 2)
#   - dragon-studio-sword-slice-393847.mp3   -> golpes 1 y 2 (pasos 0 y 1)
# Si añades más archivos a sonidos/, dime cuál va en cada parte del combo y lo añado aquí.

const SLICE_FINAL := "res://sonidos/dragon-studio-sword-slice-2-393845.mp3"
const SLICE_INICIAL := "res://sonidos/dragon-studio-sword-slice-393847.mp3"
const VOCES := 4

@export_range(0.0, 1.0, 0.05) var volumen := 0.9

var _flujos: Dictionary = {}
var _voces: Array[AudioStreamPlayer] = []


func _ready() -> void:
	for ruta in [SLICE_FINAL, SLICE_INICIAL]:
		var flujo = load(ruta)
		if flujo == null:
			push_warning("Sonidos: no se pudo cargar " + ruta)
		else:
			_flujos[ruta] = flujo
	for i in VOCES:
		var p := AudioStreamPlayer.new()
		p.name = "Slice_%02d" % i
		add_child(p)
		_voces.append(p)
	call_deferred("_conectar")


func _conectar() -> void:
	var arbol := get_tree()
	if arbol == null or arbol.current_scene == null:
		return
	var pj := arbol.current_scene.get_node_or_null("Personaje")
	if pj == null:
		return
	var espada = pj.get_node_or_null("Espada")
	if espada != null and espada.has_signal("ataque_iniciado"):
		espada.ataque_iniciado.connect(_on_ataque_iniciado)


func _on_ataque_iniciado(_duracion: float, _momento: float) -> void:
	var arbol := get_tree()
	if arbol == null or arbol.current_scene == null:
		return
	var pj := arbol.current_scene.get_node_or_null("Personaje")
	if pj == null:
		return
	var espada = pj.get_node_or_null("Espada")
	var paso := 0
	if espada != null and "paso_actual" in espada:
		paso = espada.paso_actual
	_reproducir(SLICE_FINAL if paso == 2 else SLICE_INICIAL)


func _reproducir(ruta: String) -> void:
	var flujo = _flujos.get(ruta)
	if flujo == null:
		return
	for p in _voces:
		if not p.playing:
			_asignar(p, flujo)
			p.play()
			return
	var mas_antigua := _voces[0]
	for p in _voces:
		if p.get_playback_position() > mas_antigua.get_playback_position():
			mas_antigua = p
	_asignar(mas_antigua, flujo)
	mas_antigua.play()


func _asignar(p: AudioStreamPlayer, flujo) -> void:
	p.stream = flujo
	p.volume_db = linear_to_db(maxf(volumen, 0.0001))
	p.pitch_scale = 1.0
