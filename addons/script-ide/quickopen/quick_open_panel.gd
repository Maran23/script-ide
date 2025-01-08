@tool
extends PopupPanel

@onready var files_list: ItemList = %FilesList

@onready var all_btn: Button = %AllBtn
@onready var scene_btn: Button = %SceneBtn
@onready var gd_script_btn: Button = %GdScriptBtn
@onready var resource_btn: Button = %ResourceBtn
@onready var other_btn: Button = %OtherBtn

@onready var search_option_btn: OptionButton = %SearchOptionBtn
@onready var filter_txt: LineEdit = %FilterTxt

var scenes: Array[FileData]
var scripts: Array[FileData]
var resources: Array[FileData]
var others: Array[FileData]

var is_rebuild_cache: bool = true

func _ready() -> void:
	files_list.item_selected.connect(open_file)
	search_option_btn.item_selected.connect(rebuild_cache_and_ui.unbind(1))
	filter_txt.right_icon = EditorInterface.get_base_control().get_theme_icon(&"Search", &"EditorIcons")
	filter_txt.text_changed.connect(fill_files_list.unbind(1))

	all_btn.toggled.connect(fill_files_list_if_toggled)
	scene_btn.toggled.connect(fill_files_list_if_toggled)
	gd_script_btn.toggled.connect(fill_files_list_if_toggled)
	resource_btn.toggled.connect(fill_files_list_if_toggled)
	other_btn.toggled.connect(fill_files_list_if_toggled)

	about_to_popup.connect(on_show)

	var file_system: EditorFileSystem = EditorInterface.get_resource_filesystem()
	file_system.filesystem_changed.connect(schedule_rebuild)

	filter_txt.gui_input.connect(navigate_on_list.bind(files_list, open_file))

func open_file(index: int):
	hide()

	var file: String = files_list.get_item_metadata(index)

	if (ResourceLoader.exists(file)):
		var res: Resource = load(file)
		EditorInterface.edit_resource(res)

		if (res is PackedScene):
			EditorInterface.open_scene_from_path(file)

func schedule_rebuild():
	is_rebuild_cache = true

func on_show():
	if (search_option_btn.selected != 0):
		search_option_btn.selected = 0

		is_rebuild_cache = true

	var rebuild_ui: bool = false
	var all_btn_not_pressed: bool = all_btn.button_pressed != true
	rebuild_ui = is_rebuild_cache || all_btn_not_pressed

	if (is_rebuild_cache):
		rebuild_cache()

	if (rebuild_ui):
		if (all_btn_not_pressed):
			# Triggers the ui update.
			all_btn.button_pressed = true
		else:
			fill_files_list()

	filter_txt.select_all()
	filter_txt.grab_focus()

	if (files_list.item_count > 0):
		files_list.select(0)

func rebuild_cache():
	scenes.clear()
	scripts.clear()
	resources.clear()
	others.clear()

	build_file_cache()

func rebuild_cache_and_ui():
	rebuild_cache()
	fill_files_list()

func build_file_cache():
	var dir: EditorFileSystemDirectory = EditorInterface.get_resource_filesystem().get_filesystem()
	build_file_cache_dir(dir)

func build_file_cache_dir(dir: EditorFileSystemDirectory):
	for index: int in dir.get_subdir_count():
		build_file_cache_dir(dir.get_subdir(index))

	for index: int in dir.get_file_count():
		var file: String = dir.get_file_path(index)
		if (search_option_btn.get_selected_id() == 0 && file.begins_with("res://addons")):
			continue

		var last_delim: int =  file.rfind("/")

		var file_name: String = file.substr(last_delim + 1)
		var file_structure: String = &" - ."
		if (file_name.length() + 6 != file.length()):
			file_structure = " - " + file.substr(6, last_delim - 6) + ""

		file_name = file_name + file_structure

		var file_data: FileData = FileData.new()
		file_data.file = file
		file_data.file_name = file_name
		file_data.file_type = dir.get_file_type(index)

		if (file_data.file_type == &"Resource"):
			file_data.file_type = &"Object"

		match (file.get_extension()):
			&"tscn": scenes.append(file_data)
			&"gd": scripts.append(file_data)
			&"tres": resources.append(file_data)
			&"gdshader": resources.append(file_data)
			_: others.append(file_data)

func fill_files_list_if_toggled(is_toggled: bool):
	if (is_toggled):
		fill_files_list()

func fill_files_list():
	files_list.clear()

	if (all_btn.button_pressed):
		fill_files_list_with(scenes)
		fill_files_list_with(scripts)
		fill_files_list_with(resources)
		fill_files_list_with(others)
	elif (scene_btn.button_pressed):
		fill_files_list_with(scenes)
	elif (gd_script_btn.button_pressed):
		fill_files_list_with(scripts)
	elif (resource_btn.button_pressed):
		fill_files_list_with(resources)
	elif (other_btn.button_pressed):
		fill_files_list_with(others)

func fill_files_list_with(files: Array[FileData]):
	var filter_text: String = filter_txt.text

	for file_data: FileData in files:
		var file: String = file_data.file
		if (filter_text.is_empty() || filter_text.is_subsequence_ofn(file)):
			var icon: Texture2D = EditorInterface.get_base_control().get_theme_icon(file_data.file_type, &"EditorIcons")

			files_list.add_item(file_data.file_name, icon)
			files_list.set_item_metadata(files_list.item_count - 1, file)

func navigate_on_list(event: InputEvent, list: ItemList, submit: Callable):
	if (event.is_action_pressed(&"ui_text_submit")):
		var index: int = get_list_index(list)
		if (index == -1):
			return

		submit.call(index)
	elif (event.is_action_pressed(&"ui_down", true)):
		var index: int = get_list_index(list)
		if (index == list.item_count - 1):
			return

		navigate_list(list, index, 1)
	elif (event.is_action_pressed(&"ui_up", true)):
		var index: int = get_list_index(list)
		if (index <= 0):
			return

		navigate_list(list, index, -1)
	elif (event.is_action_pressed(&"ui_page_down", true)):
		var index: int = get_list_index(list)
		if (index == list.item_count - 1):
			return

		navigate_list(list, index, 5)
	elif (event.is_action_pressed(&"ui_page_up", true)):
		var index: int = get_list_index(list)
		if (index <= 0):
			return

		navigate_list(list, index, -5)
	elif (event is InputEventKey && list.item_count > 0 && !list.is_anything_selected()):
		list.select(0)

func get_list_index(list: ItemList) -> int:
	var items: PackedInt32Array = list.get_selected_items()

	if (items.is_empty()):
		return -1

	return items[0]

func navigate_list(list: ItemList, index: int, amount: int):
	index = clamp(index + amount, 0, list.item_count - 1)

	list.select(index)
	list.ensure_current_is_visible()
	list.accept_event()

class FileData:
	var file: String
	var file_name: String
	var file_type: StringName
