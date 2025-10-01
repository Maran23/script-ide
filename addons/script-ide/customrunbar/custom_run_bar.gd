@tool
class_name CustomRunBar extends Control

@export var buttons_container : HBoxContainer 

func duplicate_engine_run_bar(engine_run_bar_buttons_container : Control) -> void:
	for i in engine_run_bar_buttons_container.get_children().size():
		var current_custom_run_bar_button: CustomRunBarButton = CustomRunBarButton.new()
		var current_engine_run_bar_button = engine_run_bar_buttons_container.get_child(i)
		
		if current_engine_run_bar_button is Button:
			current_custom_run_bar_button.mimic_engine_button(current_engine_run_bar_button)
			buttons_container.add_child(current_custom_run_bar_button)
		pass
	pass
	
