extends Node
# Pantalla: agranda el juego a pantalla completa sin salir de la partida.
#   F11 o Alt+Enter -> alterna ventana / pantalla completa
#
# El escalado del mundo y de la interfaz lo hace [display] en project.godot:
#   window/stretch/mode="canvas_items"  -> la interfaz crece con la ventana
#   window/stretch/aspect="expand"      -> sin barras negras al cambiar de forma
# Al agrandar la ventana, todo se ve más grande en vez de quedar chiquito.

var _tamano_ventana := Vector2i.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # sigue funcionando en pausa o derrota


func _unhandled_input(evento: InputEvent) -> void:
	if not (evento is InputEventKey) or not evento.pressed or evento.echo:
		return
	if evento.keycode == KEY_F11 \
			or (evento.keycode == KEY_ENTER and evento.alt_pressed):
		alternar_pantalla_completa()
		get_viewport().set_input_as_handled()


func alternar_pantalla_completa() -> void:
	var ventana := get_window()
	if es_pantalla_completa():
		ventana.mode = Window.MODE_WINDOWED
		if _tamano_ventana != Vector2i.ZERO:
			ventana.size = _tamano_ventana
	else:
		_tamano_ventana = ventana.size
		ventana.mode = Window.MODE_FULLSCREEN


func es_pantalla_completa() -> bool:
	var modo := get_window().mode
	return modo == Window.MODE_FULLSCREEN or modo == Window.MODE_EXCLUSIVE_FULLSCREEN
