@tool
class_name QuickOpenFilterConfig
extends Resource

signal config_changed

@export var enable_extension_filter: bool = true:
	set(value):
		if enable_extension_filter != value:
			enable_extension_filter = value
			config_changed.emit()

@export var excluded_extensions: PackedStringArray = ["import"]:
	set(value):
		if excluded_extensions != value:
			excluded_extensions = value
			config_changed.emit()

@export var enable_path_filter: bool = true:
	set(value):
		if enable_path_filter != value:
			enable_path_filter = value
			config_changed.emit()

@export var excluded_paths: PackedStringArray = ["res://.godot/"]:
	set(value):
		if excluded_paths != value:
			excluded_paths = value
			config_changed.emit()
