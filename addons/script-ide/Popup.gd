## Popup that redirects all events to the listener.
extends PopupPanel

var input_listener: Callable

func _input(event: InputEvent) -> void:
	input_listener.call(event)
