@tool
extends EditorPlugin

# NOTE: Those variables can be customized to your needs.
## First shortcut to trigger the Outline popup.
const OUTLINE_POPUP_TRIGGER: Key = KeyModifierMask.KEY_MASK_CTRL + Key.KEY_O
## Second shortcut to trigger the Outline popup.
const OUTLINE_POPUP_TRIGGER_ALT: Key = KeyModifierMask.KEY_MASK_META + Key.KEY_O
## Position of the Outline popup. True = Right side, False = Left side.
const OUTLINE_POSITION_RIGHT: bool = true
## Hide private methods and constants. All methods/constants starting with '_' are considered as private-
const HIDE_PRIVATE_MEMBERS: bool = false

const POPUP_SCRIPT: GDScript = preload("res://addons/script-ide/Popup.gd")

var keywords: Dictionary = {}

# Icons
const keyword_icon: Texture2D = preload("res://addons/script-ide/icon/keyword.svg")
const func_icon: Texture2D = preload("res://addons/script-ide/icon/func.svg")
const func_get_icon: Texture2D = preload("res://addons/script-ide/icon/func_get.svg")
const func_set_icon: Texture2D = preload("res://addons/script-ide/icon/func_set.svg")
const property_icon: Texture2D = preload("res://addons/script-ide/icon/property.svg")
const export_icon: Texture2D = preload("res://addons/script-ide/icon/export.svg")
const signal_icon: Texture2D = preload("res://addons/script-ide/icon/signal.svg")
const constant_icon: Texture2D = preload("res://addons/script-ide/icon/constant.svg")
const class_icon: Texture2D = preload("res://addons/script-ide/icon/class.svg")

# Existing controls we modify
var outline_parent: Node
var scripts_tab_container: TabContainer
var scripts_tab_bar: TabBar
var scripts_item_list: ItemList
var split_container: HSplitContainer
var old_outline: ItemList
var filter_txt: LineEdit
var sort_btn: Button

# Own controls we add
var outline: ItemList
var filter_box: HBoxContainer
var class_btn: Button
var constant_btn: Button
var signal_btn: Button
var property_btn: Button
var export_btn: Button
var func_btn: Button
var engine_func_btn: Button
var floating_btn: Button

var outline_cache: OutlineCache

var old_script_editor_base: ScriptEditorBase

var tab_state: TabContainerState = TabContainerState.new()
var last_tab_selected: int = -1
var last_tab_hovered: int = -1

var outline_container: Node
var popup: PopupPanel

var old_script_type: StringName

## Change the Godot script UI and transform into an IDE like UI
func _enter_tree() -> void:
	# Update on save
	var file_system: EditorFileSystem = get_editor_interface().get_resource_filesystem()
	file_system.script_classes_updated.connect(schedule_update, CONNECT_DEFERRED)
	
	# Attach listener to script editor
	var script_editor: ScriptEditor = get_editor_interface().get_script_editor()
	script_editor.editor_script_changed.connect(attach_script_listener)
	
	# Make tab container visible
	scripts_tab_container = find_or_null(script_editor.find_children("*", "TabContainer", true, false))
	if (scripts_tab_container != null):
		scripts_tab_bar = get_tab_bar_of(scripts_tab_container)
		tab_state.save(scripts_tab_container, scripts_tab_bar)
		
		scripts_tab_container.tabs_visible = true
		scripts_tab_container.drag_to_rearrange_enabled = true

		if (scripts_tab_bar != null):
			scripts_tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_ACTIVE_ONLY
			scripts_tab_bar.select_with_rmb = true
			scripts_tab_bar.drag_to_rearrange_enabled = true
			scripts_tab_bar.tab_close_pressed.connect(on_tab_close)
			scripts_tab_bar.tab_rmb_clicked.connect(on_tab_rmb)
			scripts_tab_bar.tab_selected.connect(on_tab_selected)
			scripts_tab_bar.tab_hovered.connect(on_tab_hovered)
			scripts_tab_bar.mouse_exited.connect(on_tab_bar_mouse_exited)
			scripts_tab_bar.active_tab_rearranged.connect(on_active_tab_rearranged)
			scripts_tab_bar.gui_input.connect(on_tab_bar_gui_input)
			
	# Make script item list invisible
	scripts_item_list = find_or_null(script_editor.find_children("*", "ItemList", true, false))
	if (scripts_item_list != null):
		scripts_item_list.get_parent().visible = false
	
	# Remove existing outline and add own outline
	split_container = find_or_null(script_editor.find_children("*", "HSplitContainer", true, false))
	if (split_container != null):
		outline_container = split_container.get_child(0)
		
		if (OUTLINE_POSITION_RIGHT):
			split_container.move_child(outline_container, 1)
		
		old_outline = find_or_null(outline_container.find_children("*", "ItemList", true, false), 1)
		outline_parent = old_outline.get_parent()
		outline_parent.remove_child(old_outline)
		
		outline = ItemList.new()
		outline.allow_reselect = true
		outline.size_flags_vertical = Control.SIZE_EXPAND_FILL
		outline_parent.add_child(outline)
		
		outline.item_selected.connect(scroll_to_index)
		
		# Add a filter box for all kind of script objects
		filter_box = HBoxContainer.new()
		
		engine_func_btn = create_filter_btn(keyword_icon, "Engine callbacks")
		filter_box.add_child(engine_func_btn)
		
		func_btn = create_filter_btn(func_icon, "Functions")
		filter_box.add_child(func_btn)
		
		signal_btn = create_filter_btn(signal_icon, "Signals")
		filter_box.add_child(signal_btn)
		
		export_btn = create_filter_btn(export_icon, "Exported properties")
		filter_box.add_child(export_btn)
	
		property_btn = create_filter_btn(property_icon, "Properties")
		filter_box.add_child(property_btn)
		
		class_btn = create_filter_btn(class_icon, "Classes")
		filter_box.add_child(class_btn)
		
		constant_btn = create_filter_btn(constant_icon, "Constants")
		filter_box.add_child(constant_btn)
		
		outline.get_parent().add_child(filter_box)
		outline.get_parent().move_child(filter_box, outline.get_index())
		
		# Callback when the filter changed
		filter_txt = find_or_null(outline_container.find_children("*", "LineEdit", true, false), 1)
		filter_txt.text_changed.connect(update_outline.unbind(1))
		
		# Callback when the sorting changed
		sort_btn = find_or_null(outline_container.find_children("*", "Button", true, false))
		sort_btn.pressed.connect(update_outline)
			
	attach_script_listener(script_editor.get_current_script())

## Restore the old Godot script UI and free everything we created
func _exit_tree() -> void:
	var file_system: EditorFileSystem = get_editor_interface().get_resource_filesystem()
	file_system.script_classes_updated.disconnect(schedule_update)
	
	var script_editor: ScriptEditor = get_editor_interface().get_script_editor()
	script_editor.editor_script_changed.disconnect(attach_script_listener)
	
	if (old_script_editor_base):
		old_script_editor_base.edited_script_changed.disconnect(update_outline)
	
	if (split_container != null):
		if (split_container != outline_container.get_parent()):
			split_container.add_child(outline_container)
		split_container.move_child(outline_container, 0)
		
		filter_txt.text_changed.disconnect(update_outline)
		sort_btn.pressed.disconnect(update_outline)
		
		outline.item_selected.disconnect(scroll_to_index)
		
		outline_parent.remove_child(filter_box)
		outline_parent.remove_child(outline)
		outline_parent.add_child(old_outline)

		filter_box.free()
		outline.free()
	
	if (scripts_tab_container != null):
		tab_state.restore(scripts_tab_container, scripts_tab_bar)
		
		if (scripts_tab_bar):
			scripts_tab_bar.mouse_exited.disconnect(on_tab_bar_mouse_exited)
			scripts_tab_bar.gui_input.disconnect(on_tab_bar_gui_input)
			scripts_tab_bar.tab_close_pressed.disconnect(on_tab_close)
			scripts_tab_bar.tab_rmb_clicked.disconnect(on_tab_rmb)
			scripts_tab_bar.tab_selected.disconnect(on_tab_selected)
			scripts_tab_bar.tab_hovered.disconnect(on_tab_hovered)
			scripts_tab_bar.active_tab_rearranged.disconnect(on_active_tab_rearranged)

	if (scripts_item_list != null):
		scripts_item_list.get_parent().visible = true
		
	if (popup != null):
		popup.hide()
		
## Lazy pattern to update the editor only once per frame
func _process(delta: float) -> void:
	update_editor()
	set_process(false)
	
## Add navigation to the Outline
func _input(event: InputEvent) -> void:
	if (!filter_txt.has_focus()):
		return
	
	if (event.is_action_pressed("ui_text_submit")):
		var items: PackedInt32Array = outline.get_selected_items()
		
		if (items.is_empty()):
			return
			
		var index: int = items[0]
		scroll_to_index(index)
	
	if (event.is_action_pressed("ui_down", true)):
		var items: PackedInt32Array = outline.get_selected_items()
		
		var index: int
		if (items.is_empty()):
			index = -1
		else:
			index = items[0]
		
		if (index == outline.item_count - 1):
			return
			
		index += 1
		
		outline.select(index)
		outline.ensure_current_is_visible()
		get_viewport().set_input_as_handled()
	elif (event.is_action_pressed("ui_up", true)):
		var items: PackedInt32Array = outline.get_selected_items()
		
		var index: int
		if (items.is_empty()):
			index = outline.item_count
		else:
			index = items[0]
		
		if (index == 0):
			return
			
		index -= 1
		outline.select(index)
		outline.ensure_current_is_visible()
		get_viewport().set_input_as_handled()
	
## Triggers the Outline popup
func _unhandled_key_input(event: InputEvent) -> void:
	if !(event is InputEventKey):
		return
	
	if (event.get_keycode_with_modifiers() == OUTLINE_POPUP_TRIGGER || event.get_keycode_with_modifiers() == OUTLINE_POPUP_TRIGGER_ALT):
		var button_flags: Array[bool] = []
		for child in filter_box.get_children():
			var btn: Button = child
			button_flags.append(btn.button_pressed)
			
			btn.button_pressed = true
	
		var old_text: String = filter_txt.text
		filter_txt.text = ""
		
		update_outline()

		popup = POPUP_SCRIPT.new()
		popup.input_listener = _input
		
		outline_container.reparent(popup)

		var script_editor: ScriptEditor = get_editor_interface().get_script_editor()
		popup.popup_hide.connect(func():
			outline_container.reparent(split_container)
			if (!OUTLINE_POSITION_RIGHT):
				split_container.move_child(outline_container, 0)
			
			filter_txt.text = old_text
			
			var index: int = 0
			for flag in button_flags:
				var btn: Button = filter_box.get_child(index)
				btn.button_pressed = flag
				index += 1
			
			update_outline()
			
			popup.queue_free()
			popup = null
		)
		
		var window_rect: Rect2
		if (script_editor.get_parent().get_parent() is Window):
			# Popup mode
			var window: Window = script_editor.get_parent().get_parent()
			window_rect = window.get_visible_rect()
		else:
			window_rect = get_editor_interface().get_base_control().get_rect()
		
		var size: Vector2i = Vector2i(400, 550)
		var x: int = window_rect.size.x / 2 - size.x / 2
		var y: int = window_rect.size.y / 2 - size.y / 2
		var position: Vector2i = Vector2i(x, y)
		
		popup.popup_exclusive_on_parent(script_editor, Rect2i(position, size))
		
		filter_txt.grab_focus()
		
## Schedules an update on the frame
func schedule_update():
	set_process(true)
	
func scroll_to_index(selected_idx: int):
	if (popup != null):
		popup.hide.call_deferred()
	
	var script_editor: ScriptEditor = get_editor_interface().get_script_editor()
	var script: Script = script_editor.get_current_script()
	if (!script):
		return
	
	var text: String = outline.get_item_text(selected_idx)
	var metadata: Dictionary = outline.get_item_metadata(selected_idx)
	var modifier: String = metadata["modifier"]
	var type: String = metadata["type"]
	
	var type_with_text: String = type + " " + text
	if (type == "func"):
		type_with_text = type_with_text + "("

	var source_code: String = script.get_source_code()
	var lines: PackedStringArray = source_code.split("\n")
	
	var index: int = 0
	for line in lines:
		# Easy case, like 'var abc'
		if (line.begins_with(type_with_text)):
			goto_line(index)
			return
		
		# We have an modifier, e.g. 'static'
		if (modifier != "" && line.begins_with(modifier)):
			if (line.begins_with(modifier + " " + type_with_text)):
				goto_line(index)
				return
			# Special case: An 'enum' is treated different.
			elif (modifier == "enum" && line.contains("enum " + text)):
				goto_line(index)
				return
		
		# Hard case, probably something like '@onready var abc'
		if (type == "var" && line.contains(type_with_text)):
			goto_line(index)
			return
		
		index += 1
		
	push_error(type_with_text + " or " + modifier + " not found in source code")

func goto_line(index: int):
	var script_editor: ScriptEditor = get_editor_interface().get_script_editor()
	script_editor.goto_line(index)
	
	var code_edit: CodeEdit = script_editor.get_current_editor().get_base_editor()
	code_edit.set_caret_line(index)
	code_edit.set_caret_column(0)
	code_edit.set_v_scroll(index)
	code_edit.set_h_scroll(0)

func create_filter_btn(icon: Texture2D, title: String) -> Button:
	var btn: Button = Button.new()
	btn.toggle_mode = true
	btn.button_pressed = true
	btn.icon = icon
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.tooltip_text = title
	
	btn.pressed.connect(update_outline)
	
	btn.add_theme_color_override("icon_pressed_color", Color.WHITE)
	btn.add_theme_color_override("icon_hover_color", Color.WHITE)
	btn.add_theme_color_override("icon_focus_color", Color.WHITE)
	
	var style_box_empty: StyleBoxEmpty = StyleBoxEmpty.new()
	style_box_empty.set_content_margin_all(4 * get_editor_scale())
	btn.add_theme_stylebox_override("normal", style_box_empty)
	
	var style_box: StyleBoxFlat = StyleBoxFlat.new()
	style_box.draw_center = false
	style_box.border_color = Color(0.41, 0.61, 0.91)
	style_box.set_border_width_all(1 * get_editor_scale())
	style_box.set_corner_radius_all(3 * get_editor_scale())
	btn.add_theme_stylebox_override("focus", style_box)
	
	return btn

func register_virtual_methods(clazz: String) -> void:
	for method in ClassDB.class_get_method_list(clazz):
		if method.flags & METHOD_FLAG_VIRTUAL > 0:
			keywords[method.name] = 0

func attach_script_listener(script: Script):
	if (old_script_editor_base != null):
		old_script_editor_base.edited_script_changed.disconnect(update_outline)
	
	var script_editor: ScriptEditor = get_editor_interface().get_script_editor()
	var script_editor_base: ScriptEditorBase = script_editor.get_current_editor()
	
	if (script_editor_base != null):
		script_editor_base.edited_script_changed.connect(update_outline)
		
		old_script_editor_base = script_editor_base
		
	update_keywords(script)
	schedule_update()
	
func update_keywords(script: Script):
	if (script == null):
		return
	
	var new_script_type: StringName = script.get_instance_base_type()
	if (old_script_type != new_script_type):
		old_script_type = new_script_type
		
		keywords.clear()
		keywords["_static_init"] = 0
		register_virtual_methods(script.get_instance_base_type())
		
func update_editor():
	update_tabs()
	update_outline_cache()
	update_outline()

func update_tabs():
	if !scripts_tab_container or !scripts_item_list:
		return

	for item_idx in scripts_item_list.item_count:
		var tab_idx = get_item_list_tab_idx(item_idx)
		if tab_idx != -1:
			scripts_tab_container.set_tab_title(tab_idx, scripts_item_list.get_item_text(item_idx))
			scripts_tab_container.set_tab_icon(tab_idx, scripts_item_list.get_item_icon(item_idx))

func update_outline_cache():
	outline_cache = null
	
	var script_editor: ScriptEditor = get_editor_interface().get_script_editor()
	var script: Script = script_editor.get_current_script()
	if (!script):
		return
		
	update_keywords(script)
		
	outline_cache = OutlineCache.new()
	
	# Functions
	for dict in script.get_script_method_list():
		var func_name: String = dict["name"]
		
		if HIDE_PRIVATE_MEMBERS && func_name.begins_with("_"):
			continue

		if (keywords.has(func_name)):
			outline_cache.engine_funcs.append(func_name)
		else:
			outline_cache.funcs.append(func_name)
	
	# Properties / Exports
	for dict in script.get_script_property_list():
		var property: String = dict["name"]
		if HIDE_PRIVATE_MEMBERS && property.begins_with("_"):
			continue
		
		var usage: int = dict["usage"]

		if (usage == PROPERTY_USAGE_SCRIPT_VARIABLE | PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR):
			outline_cache.exports.append(property)
		elif (usage == PROPERTY_USAGE_SCRIPT_VARIABLE):
			outline_cache.properties.append(property)
		else:
			continue
		
	# Signals
	for dict in script.get_script_signal_list():
		var signal_name: String = dict["name"]
		
		outline_cache.signals.append(signal_name)
	
	# Constants/Classes
	for name_key in script.get_script_constant_map():
		if HIDE_PRIVATE_MEMBERS && name_key.begins_with("_"):
			continue
		
		var object: Variant = script.get_script_constant_map().get(name_key)
		if (object is GDScript && object.get_instance_base_type() == "RefCounted"):
			outline_cache.classes.append(name_key)
		else:
			outline_cache.constants.append(name_key)
			
func get_icon(func_name: String) -> Texture2D:
	var icon: Texture2D = func_icon
	if (func_name.begins_with("get")):
		icon = func_get_icon
	elif (func_name.begins_with("set")):
		icon = func_set_icon
			
	return icon
	
func update_outline():
	outline.clear()
	
	if (outline_cache == null):
		return
	
	# Classes
	if (class_btn.button_pressed):
		add_to_outline(outline_cache.classes, class_icon, "class")
	
	# Constants
	if (constant_btn.button_pressed):
		add_to_outline(outline_cache.constants, constant_icon, "const", "enum")
	
	# Properties
	if (property_btn.button_pressed):
		add_to_outline(outline_cache.properties, property_icon, "var")
		
	# Exports
	if (export_btn.button_pressed):
		add_to_outline(outline_cache.exports, export_icon, "var", "@export")
		
	# Signals
	if (signal_btn.button_pressed):
		add_to_outline(outline_cache.signals, signal_icon, "signal")
		
	# Functions
	if (func_btn.button_pressed):
		add_to_outline_ext(outline_cache.funcs, get_icon, "func", "static")
		
	# Engine functions
	if (engine_func_btn.button_pressed):
		add_to_outline(outline_cache.engine_funcs, keyword_icon, "func")

func add_to_outline(items: Array[String], icon: Texture2D, type: String, modifier: String = ""):
	add_to_outline_ext(items, func(str: String): return icon, type, modifier)
			
func add_to_outline_ext(items: Array[String], icon_callable: Callable, type: String, modifier: String = ""):
	var text: String = filter_txt.get_text()
	var move_index: int = 0
	
	if (is_sorted()):
		items = items.duplicate()
		items.sort_custom(func(a, b): return a.naturalnocasecmp_to(b) < 0)
	
	for item in items:
		if (text.is_empty() || text.is_subsequence_ofn(item)):
			var icon: Texture2D = icon_callable.call(item)
			outline.add_item(item, icon, true)
			
			var dict: Dictionary = {
				"type": type,
				"modifier": modifier
			}
			outline.set_item_metadata(outline.item_count - 1, dict)
			outline.set_item_tooltip_enabled(outline.item_count - 1, false)
			outline.move_item(outline.item_count - 1, move_index)
			
			move_index += 1
			
func is_sorted() -> bool:
	return get_editor_interface().get_editor_settings().get_setting("text_editor/script_list/sort_members_outline_alphabetically")
	
func on_tab_bar_mouse_exited():
	last_tab_hovered = -1

func on_tab_hovered(idx: int):
	last_tab_hovered = idx

func on_tab_bar_gui_input(event: InputEvent):
	if last_tab_hovered == -1:
		return
		
	if event is InputEventMouseMotion:
		scripts_tab_bar.tooltip_text = get_res_path(last_tab_hovered)
	
	if event is InputEventMouseButton:
		if event.is_pressed() and event.button_index == MOUSE_BUTTON_MIDDLE:
			simulate_item_clicked(last_tab_hovered, MOUSE_BUTTON_MIDDLE)

func get_res_path(idx: int) -> String:
	var tab_control: Control = scripts_tab_container.get_tab_control(idx)
	if (tab_control == null):
		return ''
	
	var path_var: Variant = tab_control.get("metadata/_edit_res_path")
	if (path_var == null):
		return ''
	
	return path_var

func on_active_tab_rearranged(idx_to: int):
	var control: Control = scripts_tab_container.get_tab_control(last_tab_selected)
	if (!control):
		return
		
	scripts_tab_container.move_child(control, idx_to)
	scripts_tab_container.current_tab = scripts_tab_container.current_tab
	trigger_script_editor_update_script_names()

func on_tab_selected(tab_idx: int):
	last_tab_selected = tab_idx

	var item_idx: int = find_list_item_idx_by_tab_idx(tab_idx)
	if (item_idx == -1):
		return
		
	if (!scripts_item_list.is_selected(item_idx)):
		scripts_item_list.select(item_idx)
		scripts_item_list.item_selected.emit(item_idx)
		
		var path: String = get_res_path(tab_idx)
		var is_gd_script: bool = path != '' && path.ends_with(".gd")
		filter_box.visible = is_gd_script
		outline.visible = is_gd_script

func on_tab_rmb(tab_idx: int):
	simulate_item_clicked(tab_idx, MOUSE_BUTTON_RIGHT)

func on_tab_close(tab_idx: int):
	simulate_item_clicked(tab_idx, MOUSE_BUTTON_MIDDLE)

func simulate_item_clicked(tab_idx: int, mouse_idx: int):
	if (!scripts_item_list):
		return
		
	var item_idx: int = find_list_item_idx_by_tab_idx(tab_idx)
	if item_idx == -1:
		return
		
	scripts_item_list.item_clicked.emit(item_idx, scripts_item_list.get_local_mouse_position(), mouse_idx)

func get_item_list_tab_idx(item_idx: int) -> int:
	var metadata: Variant = scripts_item_list.get_item_metadata(item_idx)
	if !(metadata is int):
		return -1
	else:
		return metadata

func find_list_item_idx_by_tab_idx(tab_idx: int) -> int:
	for i in scripts_item_list.item_count:
		if scripts_item_list.get_item_metadata(i) == tab_idx:
			return i
	
	return -1

func trigger_script_editor_update_script_names():
	var script_editor: ScriptEditor = get_editor_interface().get_script_editor()
	# for now it is the only way to trigger script_editor._update_script_names
	script_editor.notification(Control.NOTIFICATION_THEME_CHANGED)

func get_editor_scale() -> float:
	return get_editor_interface().get_editor_scale()
	
static func find_or_null(arr: Array[Node], index: int = 0) -> Node:
	if arr.is_empty():
		return null
	
	return arr[index]

static func get_tab_bar_of(src: Node) -> TabBar:
	for child in src.get_children(true):
		if child is TabBar:
			return child
	
	return null
	
class OutlineCache:
	var classes: Array[String] = []
	var constants: Array[String] = []
	var signals: Array[String] = []
	var exports: Array[String] = []
	var properties: Array[String] = []
	var funcs: Array[String] = []
	var engine_funcs: Array[String] = []

class TabContainerState:
	var tabs_visible: bool
	var drag_to_rearrange_enabled: bool
	var tab_close_display_policy: TabBar.CloseButtonDisplayPolicy
	var select_with_rmb: bool
	
	func save(src: TabContainer, tab_bar: TabBar):
		if src:
			tabs_visible = src.tabs_visible
		if tab_bar:
			drag_to_rearrange_enabled = tab_bar.drag_to_rearrange_enabled
			tab_close_display_policy = tab_bar.tab_close_display_policy
		select_with_rmb = tab_bar.select_with_rmb
	
	func restore(src: TabContainer, tab_bar: TabBar):
		if src:
			src.tabs_visible = tabs_visible
		if tab_bar:
			tab_bar.drag_to_rearrange_enabled = drag_to_rearrange_enabled
			tab_bar.tab_close_display_policy = tab_close_display_policy
			tab_bar.select_with_rmb = select_with_rmb
