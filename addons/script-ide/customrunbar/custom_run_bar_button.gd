@tool
class_name CustomRunBarButton extends Button

var engine_button : Button
	
func mimic_engine_button(engine_button : Button):
	self.engine_button = engine_button
	icon = engine_button.icon
	flat = engine_button.flat
	tooltip_text = engine_button.tooltip_text
	focus_mode = engine_button.focus_mode
	
	pressed.connect(_on_pressed)
	
func _on_pressed():
	engine_button.pressed.emit()