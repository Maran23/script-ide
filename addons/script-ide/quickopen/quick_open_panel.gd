@tool
extends PopupPanel

#region Settings and Shortcuts
## Editor setting path
const SCRIPT_IDE: StringName = &"plugin/script_ide/"
## Editor setting for the 'Tab cycle forward' shortcut
const TAB_CYCLE_FORWARD: StringName = SCRIPT_IDE + &"tab_cycle_forward"
## Editor setting for the 'Tab cycle backward' shortcut
const TAB_CYCLE_BACKWARD: StringName = SCRIPT_IDE + &"tab_cycle_backward"
#endregion

#region UI
@onready var filter_bar: TabBar = %FilterBar
@onready var search_option_btn: OptionButton = %SearchOptionBtn
@onready var filter_txt: LineEdit = %FilterTxt
@onready var files_list: ItemList = %FilesList
#endregion

var tab_cycle_forward_shc: Shortcut
var tab_cycle_backward_shc: Shortcut

var scenes: Array[FileData]
var scripts: Array[FileData]
var resources: Array[FileData]
var others: Array[FileData]

var is_rebuild_cache: bool = true

#region Plugin and Shortcut processing
func _ready() -> void:
	var editor_settings: EditorSettings = EditorInterface.get_editor_settings()
	tab_cycle_forward_shc = editor_settings.get_setting(TAB_CYCLE_FORWARD)
	tab_cycle_backward_shc = editor_settings.get_setting(TAB_CYCLE_BACKWARD)

	files_list.item_selected.connect(open_file)
	search_option_btn.item_selected.connect(rebuild_cache_and_ui.unbind(1))
	filter_txt.text_changed.connect(fill_files_list.unbind(1))

	filter_bar.tab_changed.connect(change_fill_files_list.unbind(1))

	about_to_popup.connect(on_show)

	var file_system: EditorFileSystem = EditorInterface.get_resource_filesystem()
	file_system.filesystem_changed.connect(schedule_rebuild)

	filter_txt.gui_input.connect(navigate_on_list.bind(files_list, open_file))

func _shortcut_input(event: InputEvent) -> void:
	if (!event.is_pressed() || event.is_echo()):
		return

	if (tab_cycle_forward_shc.matches_event(event)):
		get_viewport().set_input_as_handled()

		var new_tab: int = filter_bar.current_tab + 1
		if (new_tab == filter_bar.get_tab_count()):
			new_tab = 0
		filter_bar.current_tab = new_tab
	elif (tab_cycle_backward_shc.matches_event(event)):
		get_viewport().set_input_as_handled()

		var new_tab: int = filter_bar.current_tab - 1
		if (new_tab == -1):
			new_tab = filter_bar.get_tab_count() - 1
		filter_bar.current_tab = new_tab
#endregion

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
	var all_tab_not_pressed: bool = filter_bar.current_tab != 0
	rebuild_ui = is_rebuild_cache || all_tab_not_pressed

	if (is_rebuild_cache):
		rebuild_cache()

	if (rebuild_ui):
		if (all_tab_not_pressed):
			# Triggers the ui update.
			filter_bar.current_tab = 0
		else:
			fill_files_list()

	filter_txt.select_all()
	focus_and_select_first()

func rebuild_cache():
	is_rebuild_cache = false

	scenes.clear()
	scripts.clear()
	resources.clear()
	others.clear()

	build_file_cache()

func rebuild_cache_and_ui():
	rebuild_cache()
	fill_files_list()

	focus_and_select_first()

func focus_and_select_first():
	filter_txt.grab_focus()
	if (files_list.item_count > 0):
		files_list.select(0)

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

func change_fill_files_list():
	fill_files_list()

	focus_and_select_first()

func fill_files_list():
	files_list.clear()

	if (filter_bar.current_tab == 0):
		fill_files_list_with(scenes)
		fill_files_list_with(scripts)
		fill_files_list_with(resources)
		fill_files_list_with(others)
	elif (filter_bar.current_tab == 1):
		fill_files_list_with(scenes)
	elif (filter_bar.current_tab == 2):
		fill_files_list_with(scripts)
	elif (filter_bar.current_tab == 3):
		fill_files_list_with(resources)
	elif (filter_bar.current_tab == 4):
		fill_files_list_with(others)

func fill_files_list_with(files: Array[FileData]):
	var filter_text: String = filter_txt.text

	for file_data: FileData in files:
		var file: String = file_data.file
		if (filter_text.is_empty() || filter_text.is_subsequence_ofn(file)):
			var icon: Texture2D = EditorInterface.get_base_control().get_theme_icon(file_data.file_type, &"EditorIcons")

			files_list.add_item(file_data.file_name, icon)
			files_list.set_item_metadata(files_list.item_count - 1, file)
			files_list.set_item_tooltip(files_list.item_count - 1, file)

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
