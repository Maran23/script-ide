## Registered plugin class for script-ide.
## This plugin mainly 'modifies' the outline code that is inside 'script_editor_plugin.cpp'.
## The internals of the C++ code are therefore important in order to make this plugin work
## without interfering with the Godot Engine.
@tool
extends EditorPlugin

## Editor setting path
const SCRIPT_IDE: StringName = &"plugin/script_ide/"
## Editor setting for the outline position
const OUTLINE_POSITION_RIGHT: StringName = SCRIPT_IDE + &"outline_position_right"
## Editor setting to control whether private members (annotated with '_' should be hidden or not)
const HIDE_PRIVATE_MEMBERS: StringName = SCRIPT_IDE + &"hide_private_members"
## Editor setting to control whether the script list should be visible or not
const SCRIPT_LIST_VISIBLE: StringName = SCRIPT_IDE + &"script_list_visible"
## Editor setting for the 'Open Outline Popup' shortcut
const OPEN_OUTLINE_POPUP: StringName = SCRIPT_IDE + &"open_outline_popup"
## Editor setting for the 'Open Scripts Popup' shortcut
const OPEN_SCRIPTS_POPUP: StringName = SCRIPT_IDE + &"open_scripts_popup"

#region Outline icons
const keyword_icon: Texture2D = preload("res://addons/script-ide/icon/keyword.svg")
const func_icon: Texture2D = preload("res://addons/script-ide/icon/func.svg")
const func_get_icon: Texture2D = preload("res://addons/script-ide/icon/func_get.svg")
const func_set_icon: Texture2D = preload("res://addons/script-ide/icon/func_set.svg")
const property_icon: Texture2D = preload("res://addons/script-ide/icon/property.svg")
const export_icon: Texture2D = preload("res://addons/script-ide/icon/export.svg")
const signal_icon: Texture2D = preload("res://addons/script-ide/icon/signal.svg")
const constant_icon: Texture2D = preload("res://addons/script-ide/icon/constant.svg")
const class_icon: Texture2D = preload("res://addons/script-ide/icon/class.svg")
#endregion

const GETTER: StringName = &"get"
const SETTER: StringName = &"set"
const UNDERSCORE: StringName = &"_"
const INLINE: StringName = &"@"

const POPUP_SCRIPT: GDScript = preload("res://addons/script-ide/Popup.gd")

#region Editor settings
var is_outline_right: bool = true
var is_script_list_visible: bool = false
var hide_private_members: bool = false
var open_outline_popup_shc: Shortcut
var open_scripts_popup_shc: Shortcut
#endregion

var suppress_settings_sync: bool = false

#region Existing controls we modify
var outline_container: Control
var outline_parent: Control
var scripts_tab_container: TabContainer
var scripts_tab_bar: TabBar
var script_filter_txt: LineEdit
var scripts_item_list: ItemList
var panel_container: VSplitContainer

var split_container: HSplitContainer
var old_outline: ItemList
var outline_filter_txt: LineEdit
var sort_btn: Button
#endregion

#region Own controls we add
var outline: ItemList
var outline_popup: PopupPanel
var filter_box: HBoxContainer

var scripts_popup: PopupPanel

var class_btn: Button
var constant_btn: Button
var signal_btn: Button
var property_btn: Button
var export_btn: Button
var func_btn: Button
var engine_func_btn: Button
#endregion

var keywords: Dictionary = {} # Basically used as Set, since Godot has none. [String, int = 0]
var outline_cache: OutlineCache
var tab_state: TabStateCache

var old_script_editor_base: ScriptEditorBase
var old_script_type: StringName

var selected_tab: int = -1
var last_tab_hovered: int = -1
var sync_script_list: bool

#region Enter / Exit -> Plugin setup
## Change the Godot script UI and transform into an IDE like UI
func _enter_tree() -> void:
	is_outline_right = get_setting(OUTLINE_POSITION_RIGHT, is_outline_right)
	hide_private_members = get_setting(HIDE_PRIVATE_MEMBERS, hide_private_members)
	is_script_list_visible = get_setting(SCRIPT_LIST_VISIBLE, is_script_list_visible)

	var editor_settings: EditorSettings = get_editor_settings()
	if (!editor_settings.has_setting(OPEN_OUTLINE_POPUP)):
		var shortcut: Shortcut = Shortcut.new()
		var event: InputEventKey = InputEventKey.new()
		event.device = -1
		event.ctrl_pressed = true
		event.keycode = KEY_O

		var event2: InputEventKey = InputEventKey.new()
		event2.device = -1
		event2.meta_pressed = true
		event2.keycode = KEY_O

		shortcut.events = [ event, event2 ]
		editor_settings.set_setting(OPEN_OUTLINE_POPUP, shortcut)
		editor_settings.set_initial_value(OPEN_OUTLINE_POPUP, shortcut, false)

	if (!editor_settings.has_setting(OPEN_SCRIPTS_POPUP)):
		var shortcut: Shortcut = Shortcut.new()
		var event: InputEventKey = InputEventKey.new()
		event.device = -1
		event.ctrl_pressed = true
		event.keycode = KEY_U

		var event2: InputEventKey = InputEventKey.new()
		event2.device = -1
		event2.meta_pressed = true
		event2.keycode = KEY_U

		shortcut.events = [ event, event2 ]
		editor_settings.set_setting(OPEN_SCRIPTS_POPUP, shortcut)
		editor_settings.set_initial_value(OPEN_SCRIPTS_POPUP, shortcut, false)

	open_outline_popup_shc = editor_settings.get_setting(OPEN_OUTLINE_POPUP)
	open_scripts_popup_shc = editor_settings.get_setting(OPEN_SCRIPTS_POPUP)

	# Update on filesystem changed (e.g. save operation).
	var file_system: EditorFileSystem = get_editor_interface().get_resource_filesystem()
	file_system.filesystem_changed.connect(schedule_update)

	var script_editor: ScriptEditor = get_editor_interface().get_script_editor()

	# Change script item list visibility
	scripts_item_list = find_or_null(script_editor.find_children("*", "ItemList", true, false))
	if (scripts_item_list != null):
		update_script_list_visibility()

		script_filter_txt = find_or_null(scripts_item_list.get_parent().find_children("*", "LineEdit", true, false))

	# Make tab container visible
	scripts_tab_container = find_or_null(script_editor.find_children("*", "TabContainer", true, false))
	if (scripts_tab_container != null):
		scripts_tab_bar = scripts_tab_container.get_tab_bar()

		tab_state = TabStateCache.new()
		tab_state.save(scripts_tab_container, scripts_tab_bar)

		if (scripts_item_list != null):
			create_set_scripts_popup()

		scripts_tab_container.tabs_visible = true
		scripts_tab_container.drag_to_rearrange_enabled = true

		if (scripts_tab_bar != null):
			scripts_tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_ACTIVE_ONLY
			scripts_tab_bar.drag_to_rearrange_enabled = true
			scripts_tab_bar.select_with_rmb = true
			scripts_tab_bar.tab_close_pressed.connect(on_tab_close)
			scripts_tab_bar.tab_rmb_clicked.connect(on_tab_rmb)
			scripts_tab_bar.tab_hovered.connect(on_tab_hovered)
			scripts_tab_bar.mouse_exited.connect(on_tab_bar_mouse_exited)
			scripts_tab_bar.active_tab_rearranged.connect(on_active_tab_rearranged)
			scripts_tab_bar.gui_input.connect(on_tab_bar_gui_input)

			scripts_tab_bar.tab_changed.connect(on_tab_changed)

	# Remove existing outline and add own outline
	split_container = find_or_null(script_editor.find_children("*", "HSplitContainer", true, false))
	if (split_container != null):
		outline_container = split_container.get_child(0)

		if (is_outline_right):
			update_outline_position()

		old_outline = find_or_null(outline_container.find_children("*", "ItemList", true, false), 1)
		outline_parent = old_outline.get_parent()
		outline_parent.remove_child(old_outline)

		outline = ItemList.new()
		outline.allow_reselect = true
		outline.size_flags_vertical = Control.SIZE_EXPAND_FILL
		outline_parent.add_child(outline)

		outline.item_selected.connect(scroll_outline)

		# Add a filter box for all kind of members
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
		outline_filter_txt = find_or_null(outline_container.find_children("*", "LineEdit", true, false), 1)
		outline_filter_txt.text_changed.connect(update_outline.unbind(1))

		# Callback when the sorting changed
		sort_btn = find_or_null(outline_container.find_children("*", "Button", true, false))
		sort_btn.pressed.connect(update_outline)

	get_editor_settings().settings_changed.connect(sync_settings)

	on_tab_changed(scripts_tab_bar.current_tab)

## Restore the old Godot script UI and free everything we created
func _exit_tree() -> void:
	var file_system: EditorFileSystem = get_editor_interface().get_resource_filesystem()
	file_system.filesystem_changed.disconnect(schedule_update)

	if (old_script_editor_base != null):
		old_script_editor_base.edited_script_changed.disconnect(update_selected_tab)

	if (split_container != null):
		if (split_container != outline_container.get_parent()):
			split_container.add_child(outline_container)

		# Try to restore the previous split offset.
		if (is_outline_right):
			var split_offset: float = split_container.get_child(1).size.x
			split_container.split_offset = split_offset

		split_container.move_child(outline_container, 0)

		outline_filter_txt.text_changed.disconnect(update_outline)
		sort_btn.pressed.disconnect(update_outline)

		outline.item_selected.disconnect(scroll_outline)

		outline_parent.remove_child(filter_box)
		outline_parent.remove_child(outline)
		outline_parent.add_child(old_outline)
		outline_parent.move_child(old_outline, 2)

		filter_box.free()
		outline.free()

	if (scripts_tab_container != null):
		tab_state.restore(scripts_tab_container, scripts_tab_bar)

		scripts_tab_container.pre_popup_pressed.disconnect(prepare_scripts_popup)
		scripts_tab_container.set_popup(null)
		scripts_popup.free()

		if (scripts_tab_bar != null):
			scripts_tab_bar.mouse_exited.disconnect(on_tab_bar_mouse_exited)
			scripts_tab_bar.gui_input.disconnect(on_tab_bar_gui_input)
			scripts_tab_bar.tab_close_pressed.disconnect(on_tab_close)
			scripts_tab_bar.tab_rmb_clicked.disconnect(on_tab_rmb)
			scripts_tab_bar.tab_hovered.disconnect(on_tab_hovered)
			scripts_tab_bar.active_tab_rearranged.disconnect(on_active_tab_rearranged)

			scripts_tab_bar.tab_changed.disconnect(on_tab_changed)

	if (scripts_item_list != null):
		scripts_item_list.get_parent().visible = true

	if (outline_popup != null):
		outline_popup.free()

	get_editor_settings().settings_changed.disconnect(sync_settings)
#endregion

## Lazy pattern to update the editor only once per frame
func _process(delta: float) -> void:
	update_editor()
	set_process(false)

#region Input handling -> Popup
## Add navigation to the ItemList when the corresponding filter LineEdit is focused.
func _input(event: InputEvent) -> void:
	if (outline_filter_txt.has_focus()):
		navigate_on_list(event, outline, scroll_outline)
	elif (script_filter_txt.has_focus()):
		navigate_on_list(event, scripts_item_list, select_script)

## Triggers the Outline popup
func _unhandled_key_input(event: InputEvent) -> void:
	if !(event is InputEventKey):
		return

	if (open_outline_popup_shc.matches_event(event)):
		get_viewport().set_input_as_handled()

		open_outline_popup()
	elif (open_scripts_popup_shc.matches_event(event)):
		get_viewport().set_input_as_handled()

		open_scripts_popup()
#endregion

## Schedules an update on the frame
func schedule_update():
	set_process(true)

## Updates all parts of the editor needed to be synchronized with the file system.
func update_editor():
	update_script_text_filter()

	if (sync_script_list):
		sync_tab_with_script_list()
		sync_script_list = false

	update_tabs()
	update_outline_cache()
	update_outline()

func create_set_scripts_popup():
	panel_container = scripts_item_list.get_parent().get_parent()

	scripts_popup = POPUP_SCRIPT.new()
	scripts_popup.input_listener = _input

	scripts_tab_container.pre_popup_pressed.connect(prepare_scripts_popup)

	scripts_popup.popup_hide.connect(hide_scripts_popup)

	var script_editor: ScriptEditor = get_editor_interface().get_script_editor()
	script_editor.add_child(scripts_popup)

	scripts_tab_container.set_popup(scripts_popup)

func prepare_scripts_popup():
	scripts_popup.size.x = outline.size.x
	scripts_popup.size.y = panel_container.size.y - scripts_tab_bar.size.y

	scripts_item_list.get_parent().reparent(scripts_popup)
	scripts_item_list.get_parent().visible = true

	script_filter_txt.grab_focus()

func hide_scripts_popup():
	script_filter_txt.text = ""

	update_script_list_visibility()

	scripts_item_list.get_parent().reparent(panel_container)
	panel_container.move_child(scripts_item_list.get_parent(), 0)

func navigate_on_list(event: InputEvent, list: ItemList, submit: Callable):
	if (event.is_action_pressed(&"ui_text_submit")):
		var index: int = get_list_index(list)
		if (index == -1):
			return

		submit.call(index)
	elif (event.is_action_pressed(&"ui_down", true)):
		var index: int = get_list_index(list)
		if (index == outline.item_count - 1):
			return

		navigate_list(list, index, 1)
	elif (event.is_action_pressed(&"ui_up", true)):
		var index: int = get_list_index(list)
		if (index <= 0):
			return

		navigate_list(list, index, -1)
	elif (event.is_action_pressed(&"ui_page_down", true)):
		var index: int = get_list_index(list)
		if (index == outline.item_count - 1):
			return

		navigate_list(list, index, 5)
	elif (event.is_action_pressed(&"ui_page_up", true)):
		var index: int = get_list_index(list)
		if (index <= 0):
			return

		navigate_list(list, index, -5)

func get_center_editor_rect() -> Rect2i:
	var script_editor: ScriptEditor = get_editor_interface().get_script_editor()

	var size: Vector2i = Vector2i(400, 500)
	var x: int
	var y: int

	if (script_editor.get_parent().get_parent() is Window):
		# Floating editor.
		var window: Window = script_editor.get_parent().get_parent()
		var window_rect: Rect2 = window.get_visible_rect()

		x = window_rect.size.x / 2 - size.x / 2
		y = window_rect.size.y / 2 - size.y / 2
	else:
		x = script_editor.global_position.x + script_editor.size.x / 2 - size.x / 2
		y = script_editor.global_position.y + script_editor.size.y / 2 - size.y / 2

	return Rect2i(Vector2i(x, y), size)

func open_outline_popup():
	var button_flags: Array[bool] = []
	for child: Node in filter_box.get_children():
		var btn: Button = child
		button_flags.append(btn.button_pressed)

		btn.button_pressed = true

	var old_text: String = outline_filter_txt.text
	outline_filter_txt.text = ""

	if (outline_popup == null):
		outline_popup = POPUP_SCRIPT.new()
		outline_popup.input_listener = _input

	var outline_initially_closed: bool = !outline_container.visible
	if (outline_initially_closed):
		outline_container.visible = true

	outline_container.reparent(outline_popup)

	outline_popup.popup_hide.connect(on_outline_popup_hidden.bind(outline_initially_closed, old_text, button_flags))

	outline_popup.get_parent().remove_child(outline_popup)
	outline_popup.popup_exclusive_on_parent(get_editor_interface().get_script_editor(), get_center_editor_rect())

	outline_filter_txt.grab_focus()

	update_outline()

func on_outline_popup_hidden(outline_initially_closed: bool, old_text: String, button_flags: Array[bool]):
	outline_popup.popup_hide.disconnect(on_outline_popup_hidden)

	if outline_initially_closed:
		outline_container.visible = false

	outline_container.reparent(split_container)
	if (!is_outline_right):
		split_container.move_child(outline_container, 0)

	outline_filter_txt.text = old_text

	var index: int = 0
	for flag: bool in button_flags:
		var btn: Button = filter_box.get_child(index)
		btn.button_pressed = flag
		index += 1

	update_outline()

func open_scripts_popup():
	scripts_item_list.get_parent().reparent(scripts_popup)
	scripts_item_list.get_parent().visible = true

	scripts_popup.get_parent().remove_child(scripts_popup)
	scripts_popup.popup_exclusive_on_parent(get_editor_interface().get_script_editor(), get_center_editor_rect())

	script_filter_txt.grab_focus()

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

## Removes the script filter text and emits the signal so that the Tabs stay
## and we do not break anything there.
func update_script_text_filter():
	if (script_filter_txt.text != ""):
		script_filter_txt.text = ""
		script_filter_txt.text_changed.emit("")

func get_current_script() -> Script:
	var script_editor: ScriptEditor = get_editor_interface().get_script_editor()
	return script_editor.get_current_script()

func select_script(selected_idx: int):
	if (scripts_popup != null && scripts_popup.visible):
		scripts_popup.hide.call_deferred()

	scripts_item_list.item_selected.emit(selected_idx)

func scroll_outline(selected_idx: int):
	if (outline_popup != null && outline_popup.visible):
		outline_popup.hide.call_deferred()

	var script: Script = get_current_script()
	if (!script):
		return

	var text: String = outline.get_item_text(selected_idx)
	var metadata: Dictionary = outline.get_item_metadata(selected_idx)
	var modifier: StringName = metadata[&"modifier"]
	var type: StringName = metadata[&"type"]

	var type_with_text: String = type + " " + text
	if (type == &"func"):
		type_with_text = type_with_text + "("

	var source_code: String = script.get_source_code()
	var lines: PackedStringArray = source_code.split("\n")

	var index: int = 0
	for line: String in lines:
		# Easy case, like 'var abc'
		if (line.begins_with(type_with_text)):
			goto_line(index)
			return

		# We have an modifier, e.g. 'static'
		if (modifier != &"" && line.begins_with(modifier)):
			if (line.begins_with(modifier + " " + type_with_text)):
				goto_line(index)
				return
			# Special case: An 'enum' is treated different.
			elif (modifier == &"enum" && line.contains("enum " + text)):
				goto_line(index)
				return

		# Hard case, probably something like '@onready var abc'
		if (type == &"var" && line.contains(type_with_text)):
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
	btn.icon = icon
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.tooltip_text = title

	var property: StringName = as_setting(title)
	btn.set_meta(&"property", property)
	btn.button_pressed = get_setting(property, true)

	btn.toggled.connect(on_filter_button_pressed.bind(btn))

	btn.add_theme_color_override(&"icon_pressed_color", Color.WHITE)
	btn.add_theme_color_override(&"icon_hover_color", Color.WHITE)
	btn.add_theme_color_override(&"icon_focus_color", Color.WHITE)

	var style_box_empty: StyleBoxEmpty = StyleBoxEmpty.new()
	style_box_empty.set_content_margin_all(4 * get_editor_scale())
	btn.add_theme_stylebox_override(&"normal", style_box_empty)

	var style_box: StyleBoxFlat = StyleBoxFlat.new()
	style_box.draw_center = false
	style_box.border_color = get_editor_accent_color()
	style_box.set_border_width_all(1 * get_editor_scale())
	style_box.set_corner_radius_all(get_editor_corner_radius() * get_editor_scale())
	btn.add_theme_stylebox_override(&"focus", style_box)

	return btn

func on_filter_button_pressed(pressed: bool, btn: Button):
	set_setting(btn.get_meta(&"property"), pressed)

	update_outline()

func update_outline_position():
	if (is_outline_right):
		# Try to restore the previous split offset.
		var split_offset: float = split_container.get_child(1).size.x
		split_container.split_offset = split_offset
		split_container.move_child(outline_container, 1)
	else:
		split_container.move_child(outline_container, 0)

func update_script_list_visibility():
	scripts_item_list.get_parent().visible = is_script_list_visible

func sync_settings():
	if (suppress_settings_sync):
		return

	var changed_settings: PackedStringArray = get_editor_settings().get_changed_settings()
	for setting: String in changed_settings:
		if (!setting.begins_with(SCRIPT_IDE)):
			continue

		if (setting == OUTLINE_POSITION_RIGHT):
			# Update outline position.
			var new_outline_right: bool = get_setting(OUTLINE_POSITION_RIGHT, is_outline_right)
			if (new_outline_right != is_outline_right):
				is_outline_right = new_outline_right

				update_outline_position()
		elif (setting == HIDE_PRIVATE_MEMBERS):
			# Update cache and outline to reflect the private members setting.
			var new_hide_private_members: bool = get_setting(HIDE_PRIVATE_MEMBERS, hide_private_members)
			if (new_hide_private_members != hide_private_members):
				hide_private_members = new_hide_private_members

				update_outline_cache()
				update_outline()
		elif (setting == OPEN_OUTLINE_POPUP):
			# Update outline popup shortcut.
			open_outline_popup_shc = get_editor_settings().get_setting(OPEN_OUTLINE_POPUP)
		elif (setting == OPEN_OUTLINE_POPUP):
			# Update scripts popup shortcut.
			open_scripts_popup_shc = get_editor_settings().get_setting(OPEN_SCRIPTS_POPUP)
		elif (setting == SCRIPT_LIST_VISIBLE):
			# Update the script list visibility
			var new_script_list_visible: bool = get_setting(SCRIPT_LIST_VISIBLE, is_script_list_visible)
			if (new_script_list_visible != is_script_list_visible):
				is_script_list_visible = new_script_list_visible

				update_script_list_visibility()
		else:
			# Update filter buttons.
			for btn_node: Node in filter_box.get_children():
				var btn: Button = btn_node
				var property: StringName = btn.get_meta(&"property")

				btn.button_pressed = get_setting(property, btn.button_pressed)

func as_setting(property: String) -> StringName:
	return SCRIPT_IDE + property.to_lower().replace(" ", "_")

func get_setting(property: StringName, alt: bool) -> bool:
	var editor_settings: EditorSettings = get_editor_settings()
	if (editor_settings.has_setting(property)):
		return editor_settings.get_setting(property)
	else:
		editor_settings.set_setting(property, alt)
		editor_settings.set_initial_value(property, alt, false)
		return alt

func set_setting(property: StringName, value: bool):
	var editor_settings: EditorSettings = get_editor_settings()

	suppress_settings_sync = true
	editor_settings.set_setting(property, value)
	suppress_settings_sync = false

func on_tab_changed(idx: int):
	selected_tab = idx;

	if (old_script_editor_base != null):
		old_script_editor_base.edited_script_changed.disconnect(update_selected_tab)
		old_script_editor_base = null

	var script_editor: ScriptEditor = get_editor_interface().get_script_editor()
	var script_editor_base: ScriptEditorBase = script_editor.get_current_editor()

	if (script_editor_base != null):
		script_editor_base.edited_script_changed.connect(update_selected_tab)

		old_script_editor_base = script_editor_base

	sync_script_list = true
	schedule_update()

func update_selected_tab():
	if (selected_tab == -1):
		return

	if (scripts_item_list.item_count == 0):
		return

	scripts_tab_container.set_tab_title(selected_tab, scripts_item_list.get_item_text(selected_tab))
	scripts_tab_container.set_tab_icon(selected_tab, scripts_item_list.get_item_icon(selected_tab))

func update_tabs():
	for index: int in scripts_tab_container.get_tab_count():
		scripts_tab_container.set_tab_title(index, scripts_item_list.get_item_text(index))
		scripts_tab_container.set_tab_icon(index, scripts_item_list.get_item_icon(index))

#region Outline (cache) update
func update_keywords(script: Script):
	if (script == null):
		return

	var new_script_type: StringName = script.get_instance_base_type()
	if (old_script_type != new_script_type):
		old_script_type = new_script_type

		keywords.clear()
		keywords["_static_init"] = 0
		register_virtual_methods(new_script_type)

func register_virtual_methods(clazz: String):
	for method: Dictionary in ClassDB.class_get_method_list(clazz):
		if method.flags & METHOD_FLAG_VIRTUAL > 0:
			keywords[method.name] = 0

func update_outline_cache():
	outline_cache = null

	var script: Script = get_current_script()
	if (!script):
		return

	update_keywords(script)

	# Check if built-in script. In this case we need to duplicate it for whatever reason.
	if (script.get_path().contains(".tscn::GDScript")):
		script = script.duplicate()

	outline_cache = OutlineCache.new()

	# Collect all script members.
	for_each_script_member(script, func(array: Array[String], item: String): array.append(item))

	# Remove script members that only exist in the base script (which includes the base of the base etc.).
	# Note: The method that only collects script members without including the base script(s)
	# is not exposed to GDScript.
	var base_script: Script = script.get_base_script()
	if (base_script != null):
		for_each_script_member(base_script, func(array: Array[String], item: String): array.erase(item))

func for_each_script_member(script: Script, consumer: Callable):
	# Functions / Methods
	for dict: Dictionary in script.get_script_method_list():
		var func_name: String = dict[&"name"]

		if (keywords.has(func_name)):
			consumer.call(outline_cache.engine_funcs, func_name)
		else:
			if hide_private_members && func_name.begins_with(UNDERSCORE):
				continue

			# Inline getter/setter will normally be shown as '@...getter', '@...setter'.
			# Since we already show the variable itself, we will skip those.
			if (func_name.begins_with(INLINE)):
				continue

			consumer.call(outline_cache.funcs, func_name)

	# Properties / Exported variables
	for dict: Dictionary in script.get_script_property_list():
		var property: String = dict[&"name"]
		if hide_private_members && property.begins_with(UNDERSCORE):
			continue

		var usage: int = dict[&"usage"]

		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			if (usage & PROPERTY_USAGE_STORAGE && usage & PROPERTY_USAGE_EDITOR):
				consumer.call(outline_cache.exports, property)
			else:
				consumer.call(outline_cache.properties, property)

	# Static variables (are separated for whatever reason)
	for dict: Dictionary in script.get_property_list():
		var property: String = dict[&"name"]
		if hide_private_members && property.begins_with(UNDERSCORE):
			continue

		var usage: int = dict[&"usage"]

		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			consumer.call(outline_cache.properties, property)

	# Signals
	for dict: Dictionary in script.get_script_signal_list():
		var signal_name: String = dict["name"]

		consumer.call(outline_cache.signals, signal_name)

	# Constants / Classes
	for name_key: String in script.get_script_constant_map():
		if hide_private_members && name_key.begins_with(UNDERSCORE):
			continue

		var object: Variant = script.get_script_constant_map().get(name_key)
		# Inner classes have no source code, while a const of type GDScript has.
		if (object is GDScript && !object.has_source_code()):
			consumer.call(outline_cache.classes, name_key)
		else:
			consumer.call(outline_cache.constants, name_key)

func update_outline():
	outline.clear()

	if (outline_cache == null):
		return

	# Classes
	if (class_btn.button_pressed):
		add_to_outline(outline_cache.classes, class_icon, &"class")

	# Constants
	if (constant_btn.button_pressed):
		add_to_outline(outline_cache.constants, constant_icon, &"const", &"enum")

	# Properties
	if (property_btn.button_pressed):
		add_to_outline(outline_cache.properties, property_icon, &"var")

	# Exports
	if (export_btn.button_pressed):
		add_to_outline(outline_cache.exports, export_icon, &"var", &"@export")

	# Signals
	if (signal_btn.button_pressed):
		add_to_outline(outline_cache.signals, signal_icon, &"signal")

	# Functions
	if (func_btn.button_pressed):
		add_to_outline_ext(outline_cache.funcs, get_icon, &"func", &"static")

	# Engine functions
	if (engine_func_btn.button_pressed):
		add_to_outline(outline_cache.engine_funcs, keyword_icon, &"func")

func add_to_outline(items: Array[String], icon: Texture2D, type: String, modifier: StringName = &""):
	add_to_outline_ext(items, func(str: String): return icon, type, modifier)

func add_to_outline_ext(items: Array[String], icon_callable: Callable, type: String, modifier: StringName = &""):
	var text: String = outline_filter_txt.get_text()
	var move_index: int = 0

	if (is_sorted()):
		items = items.duplicate()
		items.sort_custom(func(a, b): return a.naturalnocasecmp_to(b) < 0)

	for item: String in items:
		if (text.is_empty() || text.is_subsequence_ofn(item)):
			var icon: Texture2D = icon_callable.call(item)
			outline.add_item(item, icon, true)

			var dict: Dictionary = {
				&"type": type,
				&"modifier": modifier
			}
			outline.set_item_metadata(outline.item_count - 1, dict)
			outline.move_item(outline.item_count - 1, move_index)

			move_index += 1

func get_icon(func_name: String) -> Texture2D:
	var icon: Texture2D = func_icon
	if (func_name.begins_with(GETTER)):
		icon = func_get_icon
	elif (func_name.begins_with(SETTER)):
		icon = func_set_icon

	return icon
#endregion

func sync_tab_with_script_list():
	# For some reason the selected tab is wrong. Looks like a Godot bug.
	if (selected_tab >= scripts_item_list.item_count):
		selected_tab = scripts_tab_bar.current_tab

	# Hide filter and outline for non .gd scripts.
	var is_script: bool = get_current_script() != null
	filter_box.visible = is_script
	outline.visible = is_script

	# Sync with script item list.
	if (selected_tab != -1 && scripts_item_list.item_count > 0 && !scripts_item_list.is_selected(selected_tab)):
		scripts_item_list.select(selected_tab)
		scripts_item_list.item_selected.emit(selected_tab)

		scripts_item_list.ensure_current_is_visible()

#region Tab Handling
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
			update_script_text_filter()
			simulate_item_clicked(last_tab_hovered, MOUSE_BUTTON_MIDDLE)

func on_active_tab_rearranged(idx_to: int):
	var control: Control = scripts_tab_container.get_tab_control(selected_tab)
	if (!control):
		return

	scripts_tab_container.move_child(control, idx_to)
	scripts_tab_container.current_tab = scripts_tab_container.current_tab
	selected_tab = scripts_tab_container.current_tab

func get_res_path(idx: int) -> String:
	var tab_control: Control = scripts_tab_container.get_tab_control(idx)
	if (tab_control == null):
		return ''

	var path_var: Variant = tab_control.get(&"metadata/_edit_res_path")
	if (path_var == null):
		return ''

	return path_var

func on_tab_rmb(tab_idx: int):
	simulate_item_clicked(tab_idx, MOUSE_BUTTON_RIGHT)

func on_tab_close(tab_idx: int):
	update_script_text_filter()
	simulate_item_clicked(tab_idx, MOUSE_BUTTON_MIDDLE)

func simulate_item_clicked(tab_idx: int, mouse_idx: int):
	script_filter_txt.text = ""

	scripts_item_list.item_clicked.emit(tab_idx, scripts_item_list.get_local_mouse_position(), mouse_idx)
#endregion

func get_editor_scale() -> float:
	return get_editor_interface().get_editor_scale()

func get_editor_corner_radius() -> int:
	return get_editor_interface().get_editor_settings().get_setting("interface/theme/corner_radius")

func get_editor_accent_color() -> Color:
	return get_editor_interface().get_editor_settings().get_setting("interface/theme/accent_color")

func is_sorted() -> bool:
	return get_editor_settings().get_setting("text_editor/script_list/sort_members_outline_alphabetically")

func get_editor_settings() -> EditorSettings:
	return get_editor_interface().get_editor_settings()

static func find_or_null(arr: Array[Node], index: int = 0) -> Node:
	if arr.is_empty():
		return null

	return arr[index]

## Cache for everything inside the outline.
class OutlineCache:
	var classes: Array[String] = []
	var constants: Array[String] = []
	var signals: Array[String] = []
	var exports: Array[String] = []
	var properties: Array[String] = []
	var funcs: Array[String] = []
	var engine_funcs: Array[String] = []

## Contains everything we modify on the Tab Control. Used to save and restore the behaviour
## to keep the Godot Engine in a clean state when the plugin is disabled.
class TabStateCache:
	var tabs_visible: bool
	var drag_to_rearrange_enabled: bool
	var tab_bar_drag_to_rearrange_enabled: bool
	var tab_close_display_policy: TabBar.CloseButtonDisplayPolicy
	var select_with_rmb: bool

	func save(tab_container: TabContainer, tab_bar: TabBar):
		if (tab_container != null):
			tabs_visible = tab_container.tabs_visible
			drag_to_rearrange_enabled = tab_container.drag_to_rearrange_enabled
		if (tab_bar != null):
			tab_bar_drag_to_rearrange_enabled = tab_bar.drag_to_rearrange_enabled
			tab_close_display_policy = tab_bar.tab_close_display_policy
			select_with_rmb = tab_bar.select_with_rmb

	func restore(tab_container: TabContainer, tab_bar: TabBar):
		if (tab_container != null):
			tab_container.tabs_visible = tabs_visible
			tab_container.drag_to_rearrange_enabled = drag_to_rearrange_enabled
		if (tab_bar != null):
			tab_bar.drag_to_rearrange_enabled = drag_to_rearrange_enabled
			tab_bar.tab_close_display_policy = tab_close_display_policy
			tab_bar.select_with_rmb = select_with_rmb
