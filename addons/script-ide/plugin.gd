## Copyright (c) 2023-present Marius Hanl under the MIT License.
## The editor plugin entrypoint for Script-IDE.
##
## Some features interfere with the editor code that is inside 'script_editor_plugin.cpp'.
## That is, the original structure is changed by this plugin, in order to support everything.
## The internals of the native C++ code are therefore important in order to make this plugin work
## without interfering with the Engine itself (and their Node's).
##
## Script-IDE does not use global class_name's in order to not clutter projects using it.
## Especially since this is an editor only plugin, we do not want this plugin in the final game.
## Therefore, components that references the plugin is untyped.
@tool
extends EditorPlugin

const BUILT_IN_SCRIPT: StringName = &"::GDScript"
const QUICK_OPEN_INTERVAL: int = 400

const MULTILINE_TAB_BAR: PackedScene = preload("tabbar/multiline_tab_bar.tscn")
const MultilineTabBar := preload("tabbar/multiline_tab_bar.gd")

const QUICK_OPEN_SCENE: PackedScene = preload("quickopen/quick_open_panel.tscn")
const QuickOpenPopup := preload("quickopen/quick_open_panel.gd")

const OVERRIDE_SCENE: PackedScene = preload("override/override_panel.tscn")
const OverridePopup := preload("override/override_panel.gd")

const Outline := preload("uid://db0be00ai3tfi")
const SplitCodeEdit := preload("uid://boy48rhhyrph")

#region Settings and Shortcuts
## Editor setting path
const SCRIPT_IDE: StringName = &"plugin/script_ide/"
## Editor setting for the outline position
const OUTLINE_POSITION_RIGHT: StringName = SCRIPT_IDE + &"outline_position_right"
## Editor setting to control the order of the outline
const OUTLINE_ORDER: StringName = SCRIPT_IDE + &"outline_order"
## Editor setting to control whether private members (annotated with '_' should be hidden or not)
const HIDE_PRIVATE_MEMBERS: StringName = SCRIPT_IDE + &"hide_private_members"
## Editor setting to control whether we want to auto navigate to the script
## in the filesystem (dock) when selected
const AUTO_NAVIGATE_IN_FS: StringName = SCRIPT_IDE + &"auto_navigate_in_filesystem_dock"
## Editor setting to control whether the script list should be visible or not
const SCRIPT_LIST_VISIBLE: StringName = SCRIPT_IDE + &"script_list_visible"
## Editor setting to control whether the script tabs should be visible or not.
const SCRIPT_TABS_VISIBLE: StringName = SCRIPT_IDE + &"script_tabs_visible"
## Editor setting to control where the script tabs should be.
const SCRIPT_TABS_POSITION_TOP: StringName = SCRIPT_IDE + &"script_tabs_position_top"
## Editor setting to control if all script tabs should have close button.
const SCRIPT_TABS_CLOSE_BUTTON_ALWAYS: StringName = SCRIPT_IDE + &"script_tabs_close_button_always"
## Editor setting to control if all tabs should be shown in a single line.
const SCRIPT_TABS_SINGLELINE: StringName = SCRIPT_IDE + &"script_tabs_singleline"

## Editor setting for the 'Open Outline Popup' shortcut
const OPEN_OUTLINE_POPUP: StringName = SCRIPT_IDE + &"open_outline_popup"
## Editor setting for the 'Open Scripts Popup' shortcut
const OPEN_SCRIPTS_POPUP: StringName = SCRIPT_IDE + &"open_scripts_popup"
## Editor setting for the 'Open Scripts Popup' shortcut
const OPEN_QUICK_SEARCH_POPUP: StringName = SCRIPT_IDE + &"open_quick_search_popup"
## Editor setting for the 'Open Override Popup' shortcut
const OPEN_OVERRIDE_POPUP: StringName = SCRIPT_IDE + &"open_override_popup"
## Editor setting for the 'Tab cycle forward' shortcut
const TAB_CYCLE_FORWARD: StringName = SCRIPT_IDE + &"tab_cycle_forward"
## Editor setting for the 'Tab cycle backward' shortcut
const TAB_CYCLE_BACKWARD: StringName = SCRIPT_IDE + &"tab_cycle_backward"

## Engine editor setting for the icon saturation, so our icons can react.
const ICON_SATURATION: StringName = &"interface/theme/icon_saturation"
## Engine editor setting for the show members functionality.
const SHOW_MEMBERS: StringName = &"text_editor/script_list/show_members_overview"
## We track the user setting, so we can restore it properly.
var show_members: bool = true
#endregion

#region Editor settings
var is_outline_right: bool = true
var is_hide_private_members: bool = false

var is_script_tabs_visible: bool = true
var is_script_tabs_top: bool = true
var is_script_tabs_close_button_always: bool = false
var is_script_tabs_singleline: bool = false

var is_auto_navigate_in_fs: bool = true
var is_script_list_visible: bool = false

var outline_order: PackedStringArray

var open_outline_popup_shc: Shortcut
var open_scripts_popup_shc: Shortcut
var open_quick_search_popup_shc: Shortcut
var open_override_popup_shc: Shortcut
var tab_cycle_forward_shc: Shortcut
var tab_cycle_backward_shc: Shortcut
#endregion

#region Existing controls we modify
var script_editor_split_container: HSplitContainer
var files_panel: Control

var old_scripts_tab_container: TabContainer
var old_scripts_tab_bar: TabBar

var script_filter_txt: LineEdit
var scripts_item_list: ItemList
var script_panel_split_container: VSplitContainer

var old_outline: ItemList
var outline_filter_txt: LineEdit
var sort_btn: Button
#endregion

#region Own controls we add
var outline: Outline
var outline_popup: PopupPanel
var multiline_tab_bar: MultilineTabBar
var scripts_popup: PopupPanel
var quick_open_popup: QuickOpenPopup
var override_popup: OverridePopup

var tab_splitter: HSplitContainer
#endregion

#region Plugin variables
var keywords: Dictionary[String, bool] = {} # Used as Set.

var old_script_editor_base: ScriptEditorBase
var old_script_type: StringName

var is_script_changed: bool = false
var file_to_navigate: String = &""

var quick_open_tween: Tween

var suppress_settings_sync: bool = false
#endregion

#region Plugin Enter / Exit setup
## Change the Engine script UI and transform into an IDE like UI
func _enter_tree() -> void:
	init_settings()
	init_shortcuts()

	# Update on filesystem changed (e.g. save operation).
	var file_system: EditorFileSystem = EditorInterface.get_resource_filesystem()
	file_system.filesystem_changed.connect(schedule_update)

	# Sync settings changes for this plugin.
	get_editor_settings().settings_changed.connect(sync_settings)

	var script_editor: ScriptEditor = EditorInterface.get_script_editor()
	script_editor_split_container = find_or_null(script_editor.find_children("*", "HSplitContainer", true, false))
	files_panel = script_editor_split_container.get_child(0)

	# The 'Filter Scripts' Panel
	var upper_files_panel: Control = files_panel.get_child(0)
	# The 'Filter Methods' Panel
	var lower_files_panel: Control = files_panel.get_child(1)

	# Change script item list visibility (based on settings).
	scripts_item_list = find_or_null(upper_files_panel.find_children("*", "ItemList", true, false))
	scripts_item_list.allow_reselect = true
	scripts_item_list.item_selected.connect(hide_scripts_popup.unbind(1))
	update_script_list_visibility()

	# Add script filter navigation.
	script_filter_txt = find_or_null(scripts_item_list.get_parent().find_children("*", "LineEdit", true, false))
	script_filter_txt.gui_input.connect(navigate_on_list.bind(scripts_item_list, select_script))

	# --- Outline Start --- #
	old_outline = find_or_null(lower_files_panel.find_children("*", "ItemList", true, false))
	lower_files_panel.remove_child(old_outline)

	outline = Outline.new()
	outline.plugin = self

	# Add navigation to the filter and text filtering.
	outline_filter_txt = find_or_null(lower_files_panel.find_children("*", "LineEdit", true, false))
	outline_filter_txt.gui_input.connect(navigate_on_list.bind(outline, scroll_outline))
	outline_filter_txt.text_changed.connect(update_outline.unbind(1))

	outline.outline_filter_txt = outline_filter_txt
	lower_files_panel.add_child(outline)

	outline.item_selected.connect(scroll_outline)

	outline.get_parent().add_child(outline.filter_box)
	outline.get_parent().move_child(outline.filter_box, outline.get_index())

	# Add callback when the sorting changed.
	sort_btn = find_or_null(lower_files_panel.find_children("*", "Button", true, false))
	sort_btn.pressed.connect(update_outline)

	update_outline_order()
	update_outline_position()
	# --- Outline End --- #

	# --- Tabs Start --- #
	old_scripts_tab_container = find_or_null(script_editor.find_children("*", "TabContainer", true, false))
	old_scripts_tab_bar = old_scripts_tab_container.get_tab_bar()

	var tab_container_parent: Control = old_scripts_tab_container.get_parent()
	tab_splitter = HSplitContainer.new()
	tab_splitter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_splitter.size_flags_vertical = Control.SIZE_EXPAND_FILL

	tab_container_parent.add_child(tab_splitter)
	tab_container_parent.move_child(tab_splitter, 0)
	old_scripts_tab_container.reparent(tab_splitter)

	# When something changed, we need to sync our own tab container.
	old_scripts_tab_container.child_order_changed.connect(notify_order_changed)

	multiline_tab_bar = MULTILINE_TAB_BAR.instantiate()
	multiline_tab_bar.plugin = self
	multiline_tab_bar.scripts_item_list = scripts_item_list
	multiline_tab_bar.script_filter_txt = script_filter_txt
	multiline_tab_bar.scripts_tab_container = old_scripts_tab_container

	tab_container_parent.add_theme_constant_override(&"separation", 0)
	tab_container_parent.add_child(multiline_tab_bar)

	multiline_tab_bar.split_btn.toggled.connect(toggle_split_view.unbind(1))
	update_tabs_position()
	update_tabs_close_button()
	update_tabs_visibility()
	update_singleline_tabs()

	# Create and set script popup.
	script_panel_split_container = scripts_item_list.get_parent().get_parent()
	create_set_scripts_popup()
	# --- Tabs End --- #

	old_scripts_tab_bar.tab_changed.connect(on_tab_changed)
	on_tab_changed(old_scripts_tab_bar.current_tab)

## Restore the old Engine script UI and free everything we created
func _exit_tree() -> void:
	var file_system: EditorFileSystem = EditorInterface.get_resource_filesystem()
	file_system.filesystem_changed.disconnect(schedule_update)
	get_editor_settings().settings_changed.disconnect(sync_settings)

	if (tab_splitter != null):
		var tab_container_parent: Control = tab_splitter.get_parent()
		old_scripts_tab_container.reparent(tab_container_parent)
		tab_container_parent.move_child(old_scripts_tab_container, 1)
		tab_splitter.free()

	if (script_editor_split_container != null):
		if (script_editor_split_container != files_panel.get_parent()):
			script_editor_split_container.add_child(files_panel)

		# Try to restore the previous split offset.
		if (is_outline_right):
			var split_offset: float = script_editor_split_container.get_child(1).size.x
			script_editor_split_container.split_offset = split_offset

		script_editor_split_container.move_child(files_panel, 0)

		outline_filter_txt.gui_input.disconnect(navigate_on_list)
		outline_filter_txt.text_changed.disconnect(update_outline)
		sort_btn.pressed.disconnect(update_outline)

		outline.item_selected.disconnect(scroll_outline)

		var outline_parent: Control = outline.get_parent()
		outline_parent.remove_child(outline.filter_box)
		outline_parent.remove_child(outline)
		outline_parent.add_child(old_outline)
		outline_parent.move_child(old_outline, -2)

		outline.filter_box.free()
		outline.free()

	if (old_scripts_tab_bar != null):
		old_scripts_tab_bar.tab_changed.disconnect(on_tab_changed)

	if (old_scripts_tab_container != null):
		old_scripts_tab_container.child_order_changed.disconnect(notify_order_changed)
		old_scripts_tab_container.get_parent().remove_theme_constant_override(&"separation")
		old_scripts_tab_container.get_parent().remove_child(multiline_tab_bar)

	if (multiline_tab_bar != null):
		multiline_tab_bar.free_tabs()
		multiline_tab_bar.free()
		scripts_popup.free()

	if (scripts_item_list != null):
		scripts_item_list.allow_reselect = false
		scripts_item_list.item_selected.disconnect(hide_scripts_popup)
		scripts_item_list.get_parent().visible = true

		if (script_filter_txt != null):
			script_filter_txt.gui_input.disconnect(navigate_on_list)

	if (outline_popup != null):
		outline_popup.free()
	if (quick_open_popup != null):
		quick_open_popup.free()
	if (override_popup != null):
		override_popup.free()

	if (!show_members):
		set_setting(SHOW_MEMBERS, show_members)
#endregion

#region Plugin and Shortcut processing
## Lazy pattern to update the editor only once per frame
func _process(delta: float) -> void:
	update_editor()
	set_process(false)

## Process the user defined shortcuts
func _shortcut_input(event: InputEvent) -> void:
	if (!event.is_pressed() || event.is_echo()):
		return

	if (open_outline_popup_shc.matches_event(event)):
		get_viewport().set_input_as_handled()
		open_outline_popup()
	elif (open_scripts_popup_shc.matches_event(event)):
		get_viewport().set_input_as_handled()
		open_scripts_popup()
	elif (open_quick_search_popup_shc.matches_event(event)):
		if (quick_open_tween != null && quick_open_tween.is_running()):
			get_viewport().set_input_as_handled()
			if (quick_open_tween != null):
				quick_open_tween.kill()

			quick_open_tween = create_tween()
			quick_open_tween.tween_interval(0.1)
			quick_open_tween.tween_callback(open_quick_search_popup)
			quick_open_tween.tween_callback(func(): quick_open_tween = null)
		else:
			quick_open_tween = create_tween()
			quick_open_tween.tween_interval(QUICK_OPEN_INTERVAL / 1000.0)
			quick_open_tween.tween_callback(func(): quick_open_tween = null)
	elif (open_override_popup_shc.matches_event(event)):
		get_viewport().set_input_as_handled()
		open_override_popup()

## May cancels the quick search shortcut timer.
func _input(event: InputEvent) -> void:
	if (event is InputEventKey):
		if (!open_quick_search_popup_shc.matches_event(event)):
			if (quick_open_tween != null):
				quick_open_tween.kill()
				quick_open_tween = null
#endregion

#region Settings and Shortcut initialization

## Initializes all settings.
## Every setting can be changed while this plugin is active, which will override them.
func init_settings():
	is_outline_right = get_setting(OUTLINE_POSITION_RIGHT, is_outline_right)
	is_hide_private_members = get_setting(HIDE_PRIVATE_MEMBERS, is_hide_private_members)
	is_script_list_visible = get_setting(SCRIPT_LIST_VISIBLE, is_script_list_visible)
	is_auto_navigate_in_fs = get_setting(AUTO_NAVIGATE_IN_FS, is_auto_navigate_in_fs)
	is_script_tabs_visible = get_setting(SCRIPT_TABS_VISIBLE, is_script_tabs_visible)
	is_script_tabs_top = get_setting(SCRIPT_TABS_POSITION_TOP, is_script_tabs_top)
	is_script_tabs_close_button_always = get_setting(SCRIPT_TABS_CLOSE_BUTTON_ALWAYS, is_script_tabs_close_button_always)
	is_script_tabs_singleline = get_setting(SCRIPT_TABS_SINGLELINE, is_script_tabs_singleline)

	outline_order = get_outline_order()

	# Users may disabled this, but with this plugin, we want to show the new Outline.
	# So we need to reenable it, but restore the old value on exit.
	show_members = get_setting(SHOW_MEMBERS, true)
	if (!show_members):
		set_setting(SHOW_MEMBERS, true)

## Initializes all shortcuts.
## Every shortcut can be changed while this plugin is active, which will override them.
func init_shortcuts():
	var editor_settings: EditorSettings = get_editor_settings()
	if (!editor_settings.has_setting(OPEN_OUTLINE_POPUP)):
		var shortcut: Shortcut = Shortcut.new()
		var event: InputEventKey = InputEventKey.new()
		event.device = -1
		event.command_or_control_autoremap = true
		event.keycode = KEY_O

		shortcut.events = [ event ]
		editor_settings.set_setting(OPEN_OUTLINE_POPUP, shortcut)

	if (!editor_settings.has_setting(OPEN_SCRIPTS_POPUP)):
		var shortcut: Shortcut = Shortcut.new()
		var event: InputEventKey = InputEventKey.new()
		event.device = -1
		event.command_or_control_autoremap = true
		event.keycode = KEY_U

		shortcut.events = [ event ]
		editor_settings.set_setting(OPEN_SCRIPTS_POPUP, shortcut)

	if (!editor_settings.has_setting(OPEN_QUICK_SEARCH_POPUP)):
		var shortcut: Shortcut = Shortcut.new()
		var event: InputEventKey = InputEventKey.new()
		event.device = -1
		event.keycode = KEY_SHIFT

		shortcut.events = [ event ]
		editor_settings.set_setting(OPEN_QUICK_SEARCH_POPUP, shortcut)

	if (!editor_settings.has_setting(OPEN_OVERRIDE_POPUP)):
		var shortcut: Shortcut = Shortcut.new()
		var event: InputEventKey = InputEventKey.new()
		event.device = -1
		event.keycode = KEY_INSERT
		event.alt_pressed = true

		shortcut.events = [ event ]
		editor_settings.set_setting(OPEN_OVERRIDE_POPUP, shortcut)

	if (!editor_settings.has_setting(TAB_CYCLE_FORWARD)):
		var shortcut: Shortcut = Shortcut.new()
		var event: InputEventKey = InputEventKey.new()
		event.device = -1
		event.keycode = KEY_TAB
		event.ctrl_pressed = true

		shortcut.events = [ event ]
		editor_settings.set_setting(TAB_CYCLE_FORWARD, shortcut)

	if (!editor_settings.has_setting(TAB_CYCLE_BACKWARD)):
		var shortcut: Shortcut = Shortcut.new()
		var event: InputEventKey = InputEventKey.new()
		event.device = -1
		event.keycode = KEY_TAB
		event.shift_pressed = true
		event.ctrl_pressed = true

		shortcut.events = [ event ]
		editor_settings.set_setting(TAB_CYCLE_BACKWARD, shortcut)

	open_outline_popup_shc = editor_settings.get_setting(OPEN_OUTLINE_POPUP)
	open_scripts_popup_shc = editor_settings.get_setting(OPEN_SCRIPTS_POPUP)
	open_quick_search_popup_shc = editor_settings.get_setting(OPEN_QUICK_SEARCH_POPUP)
	open_override_popup_shc = editor_settings.get_setting(OPEN_OVERRIDE_POPUP)
	tab_cycle_forward_shc = editor_settings.get_setting(TAB_CYCLE_FORWARD)
	tab_cycle_backward_shc = editor_settings.get_setting(TAB_CYCLE_BACKWARD)
#endregion

## Schedules an update on the next frame.
func schedule_update():
	set_process(true)

## Updates all parts of the editor that are needed to be synchronized with the file system change.
func update_editor():
	if (file_to_navigate != &""):
		EditorInterface.select_file(file_to_navigate)
		EditorInterface.get_script_editor().get_current_editor().get_base_editor().grab_focus()
		file_to_navigate = &""

	update_keywords()

	if (is_script_changed):
		multiline_tab_bar.tab_changed()
		outline.tab_changed()
		is_script_changed = false
	else:
		# We saved / filesystem changed. so need to update everything.
		multiline_tab_bar.update_tabs()
		outline.update()

func on_tab_changed(index: int):
	if (old_script_editor_base != null):
		old_script_editor_base.edited_script_changed.disconnect(update_selected_tab)
		old_script_editor_base = null

	var script_editor: ScriptEditor = EditorInterface.get_script_editor()
	var script_editor_base: ScriptEditorBase = script_editor.get_current_editor()

	if (script_editor_base != null):
		script_editor_base.edited_script_changed.connect(update_selected_tab)

		old_script_editor_base = script_editor_base

	if (!multiline_tab_bar.is_split()):
		multiline_tab_bar.split_btn.disabled = script_editor_base == null

	is_script_changed = true

	if (is_auto_navigate_in_fs && script_editor.get_current_script() != null):
		var file: String = script_editor.get_current_script().get_path()

		if (file.contains(BUILT_IN_SCRIPT)):
			# We navigate to the scene in case of a built-in script.
			file = file.get_slice(BUILT_IN_SCRIPT, 0)

		file_to_navigate = file
	else:
		file_to_navigate = &""

	schedule_update()

func toggle_split_view():
	var script_editor: ScriptEditor = EditorInterface.get_script_editor()
	var split_script_editor_base: ScriptEditorBase = script_editor.get_current_editor()

	if (!multiline_tab_bar.is_split()):
		if (split_script_editor_base == null):
			return

		var base_editor: Control = split_script_editor_base.get_base_editor()
		if !(base_editor is CodeEdit):
			return

		multiline_tab_bar.set_split(script_editor.get_current_script())

		var editor: CodeEdit = SplitCodeEdit.new_from(base_editor)

		var container: PanelContainer = PanelContainer.new()
		container.custom_minimum_size.x = 200
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		container.add_child(editor)
		tab_splitter.add_child(container)
	else:
		multiline_tab_bar.set_split(null)
		tab_splitter.remove_child(tab_splitter.get_child(tab_splitter.get_child_count() - 1))

		if (split_script_editor_base == null):
			multiline_tab_bar.split_btn.disabled = true

func notify_order_changed():
	multiline_tab_bar.script_order_changed()

func open_quick_search_popup():
	var pref_size: Vector2
	if (quick_open_popup == null):
		quick_open_popup = QUICK_OPEN_SCENE.instantiate()
		quick_open_popup.plugin = self
		quick_open_popup.set_unparent_when_invisible(true)
		pref_size = Vector2(500, 400) * get_editor_scale()
	else:
		pref_size = quick_open_popup.size

	quick_open_popup.popup_exclusive_on_parent(EditorInterface.get_script_editor(), get_center_editor_rect(pref_size))

func open_override_popup():
	var script: Script = get_current_script()
	if (!script):
		return

	var pref_size: Vector2
	if (override_popup == null):
		override_popup = OVERRIDE_SCENE.instantiate()
		override_popup.plugin = self
		override_popup.outline = outline
		override_popup.set_unparent_when_invisible(true)
		pref_size = Vector2(500, 400) * get_editor_scale()
	else:
		pref_size = override_popup.size

	override_popup.popup_exclusive_on_parent(EditorInterface.get_script_editor(), get_center_editor_rect(pref_size))

func hide_scripts_popup():
	if (scripts_popup != null && scripts_popup.visible):
		scripts_popup.hide.call_deferred()

func create_set_scripts_popup():
	scripts_popup = PopupPanel.new()
	scripts_popup.popup_hide.connect(restore_scripts_list)

	# Need to be inside the tree, so it can be shown as popup for the tab container.
	var script_editor: ScriptEditor = EditorInterface.get_script_editor()
	script_editor.add_child(scripts_popup)

	multiline_tab_bar.set_popup(scripts_popup)

func restore_scripts_list():
	script_filter_txt.text = &""

	update_script_list_visibility()

	scripts_item_list.get_parent().reparent(script_panel_split_container)
	script_panel_split_container.move_child(scripts_item_list.get_parent(), 0)

func navigate_on_list(event: InputEvent, list: ItemList, submit: Callable):
	if (event.is_action_pressed(&"ui_text_submit")):
		list.accept_event()

		var index: int = get_list_index(list)
		if (index == -1):
			return

		submit.call(index)
		list.accept_event()
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

func get_center_editor_rect(pref_size: Vector2) -> Rect2i:
	var script_editor: ScriptEditor = EditorInterface.get_script_editor()

	var position: Vector2 = script_editor.global_position + script_editor.size / 2 - pref_size / 2

	return Rect2i(position, pref_size)

func open_outline_popup():
	if (get_current_script() == null):
		return

	var button_flags: Array[bool] = outline.save_restore_filter()

	var old_text: String = outline_filter_txt.text
	outline_filter_txt.text = &""

	var pref_size: Vector2
	if (outline_popup == null):
		outline_popup = PopupPanel.new()
		outline_popup.set_unparent_when_invisible(true)
		pref_size = Vector2(500, 400) * get_editor_scale()
	else:
		pref_size = outline_popup.size

	var outline_initially_closed: bool = !files_panel.visible
	if (outline_initially_closed):
		files_panel.visible = true

	files_panel.reparent(outline_popup)

	outline_popup.popup_hide.connect(on_outline_popup_hidden.bind(outline_initially_closed, old_text, button_flags))

	outline_popup.popup_exclusive_on_parent(EditorInterface.get_script_editor(), get_center_editor_rect(pref_size))

	update_outline()
	outline_filter_txt.grab_focus()

func on_outline_popup_hidden(outline_initially_closed: bool, old_text: String, button_flags: Array[bool]):
	outline_popup.popup_hide.disconnect(on_outline_popup_hidden)

	if outline_initially_closed:
		files_panel.visible = false

	files_panel.reparent(script_editor_split_container)
	if (!is_outline_right):
		script_editor_split_container.move_child(files_panel, 0)

	outline_filter_txt.text = old_text

	outline.restore_filter(button_flags)

	update_outline()

func open_scripts_popup():
	multiline_tab_bar.show_popup()

func get_current_script() -> Script:
	var script_editor: ScriptEditor = EditorInterface.get_script_editor()
	return script_editor.get_current_script()

func select_script(selected_idx: int):
	hide_scripts_popup()

	scripts_item_list.item_selected.emit(selected_idx)

func scroll_outline(selected_idx: int):
	if (outline_popup != null && outline_popup.visible):
		outline_popup.hide.call_deferred()

	var script: Script = get_current_script()
	if (!script):
		return

	var text: String = outline.get_item_text(selected_idx)
	var metadata: Dictionary[StringName, StringName] = outline.get_item_metadata(selected_idx)
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
	var script_editor: ScriptEditor = EditorInterface.get_script_editor()
	script_editor.goto_line(index)

	var code_edit: CodeEdit = script_editor.get_current_editor().get_base_editor()
	code_edit.set_caret_line(index)
	code_edit.set_v_scroll(index)
	code_edit.set_caret_column(code_edit.get_line(index).length())
	code_edit.set_h_scroll(0)

	code_edit.grab_focus()

func update_script_list_visibility():
	scripts_item_list.get_parent().visible = is_script_list_visible

func sync_settings():
	if (suppress_settings_sync):
		return

	var changed_settings: PackedStringArray = get_editor_settings().get_changed_settings()
	for setting: String in changed_settings:
		if (setting == ICON_SATURATION):
			outline.reset_icons()
		elif (setting == SHOW_MEMBERS):
			show_members = get_setting(SHOW_MEMBERS, true)
			if (!show_members):
				set_setting(SHOW_MEMBERS, true)

		if (!setting.begins_with(SCRIPT_IDE)):
			continue

		match (setting):
			OUTLINE_POSITION_RIGHT:
				var new_outline_right: bool = get_setting(OUTLINE_POSITION_RIGHT, is_outline_right)
				if (new_outline_right != is_outline_right):
					is_outline_right = new_outline_right

					update_outline_position()
			OUTLINE_ORDER:
				var new_outline_order: PackedStringArray = get_outline_order()
				if (new_outline_order != outline_order):
					outline_order = new_outline_order

					update_outline_order()
			HIDE_PRIVATE_MEMBERS:
				var new_hide_private_members: bool = get_setting(HIDE_PRIVATE_MEMBERS, is_hide_private_members)
				if (new_hide_private_members != is_hide_private_members):
					is_hide_private_members = new_hide_private_members

					outline.update()
			SCRIPT_LIST_VISIBLE:
				var new_script_list_visible: bool = get_setting(SCRIPT_LIST_VISIBLE, is_script_list_visible)
				if (new_script_list_visible != is_script_list_visible):
					is_script_list_visible = new_script_list_visible

					update_script_list_visibility()
			SCRIPT_TABS_VISIBLE:
				var new_script_tabs_visible: bool = get_setting(SCRIPT_TABS_VISIBLE, is_script_tabs_visible)
				if (new_script_tabs_visible != is_script_tabs_visible):
					is_script_tabs_visible = new_script_tabs_visible

					update_tabs_visibility()
			SCRIPT_TABS_POSITION_TOP:
				var new_script_tabs_top: bool = get_setting(SCRIPT_TABS_POSITION_TOP, is_script_tabs_top)
				if (new_script_tabs_top != is_script_tabs_top):
					is_script_tabs_top = new_script_tabs_top

					update_tabs_position()
			SCRIPT_TABS_CLOSE_BUTTON_ALWAYS:
				var new_script_tabs_close_button_always: bool = get_setting(SCRIPT_TABS_CLOSE_BUTTON_ALWAYS, is_script_tabs_close_button_always)
				if (new_script_tabs_close_button_always != is_script_tabs_close_button_always):
					is_script_tabs_close_button_always = new_script_tabs_close_button_always

					update_tabs_close_button()
			SCRIPT_TABS_SINGLELINE:
				var new_script_tabs_singleline: bool = get_setting(SCRIPT_TABS_SINGLELINE, is_script_tabs_singleline)
				if (new_script_tabs_singleline != is_script_tabs_singleline):
					is_script_tabs_singleline = new_script_tabs_singleline

					update_singleline_tabs()
			AUTO_NAVIGATE_IN_FS:
				is_auto_navigate_in_fs = get_setting(AUTO_NAVIGATE_IN_FS, is_auto_navigate_in_fs)
			OPEN_OUTLINE_POPUP:
				open_outline_popup_shc = get_shortcut(OPEN_OUTLINE_POPUP)
			OPEN_SCRIPTS_POPUP:
				open_scripts_popup_shc = get_shortcut(OPEN_SCRIPTS_POPUP)
			OPEN_OVERRIDE_POPUP:
				open_override_popup_shc = get_shortcut(OPEN_OVERRIDE_POPUP)
			TAB_CYCLE_FORWARD:
				tab_cycle_forward_shc = get_shortcut(TAB_CYCLE_FORWARD)
			TAB_CYCLE_BACKWARD:
				tab_cycle_backward_shc = get_shortcut(TAB_CYCLE_BACKWARD)
			_:
				outline.update_filter_buttons()

func update_selected_tab():
	multiline_tab_bar.update_selected_tab()

func update_tabs_position():
	var tab_container_parent: Control = multiline_tab_bar.get_parent()
	if (is_script_tabs_top):
		tab_container_parent.move_child(multiline_tab_bar, 0)
	else:
		tab_container_parent.move_child(multiline_tab_bar, tab_container_parent.get_child_count() - 1)

func update_tabs_close_button():
	multiline_tab_bar.show_close_button_always = is_script_tabs_close_button_always

func update_tabs_visibility():
	multiline_tab_bar.visible = is_script_tabs_visible

func update_singleline_tabs():
	multiline_tab_bar.is_singleline_tabs = is_script_tabs_singleline

func update_outline():
	outline.update_outline()

func update_outline_position():
	if (is_outline_right):
		# Try to restore the previous split offset.
		var split_offset: float = script_editor_split_container.get_child(1).size.x
		script_editor_split_container.split_offset = split_offset
		script_editor_split_container.move_child(files_panel, 1)
	else:
		script_editor_split_container.move_child(files_panel, 0)

func update_outline_order():
	outline.outline_order = outline_order

func update_keywords():
	var script: Script = get_current_script()
	if (script == null):
		return

	var new_script_type: StringName = script.get_instance_base_type()
	if (old_script_type != new_script_type):
		old_script_type = new_script_type

		keywords.clear()
		keywords["_static_init"] = true
		register_virtual_methods(new_script_type)

func register_virtual_methods(clazz: String):
	for method: Dictionary in ClassDB.class_get_method_list(clazz):
		if (method[&"flags"] & METHOD_FLAG_VIRTUAL > 0):
			keywords[method[&"name"]] = true

func get_editor_scale() -> float:
	return EditorInterface.get_editor_scale()

func get_editor_settings() -> EditorSettings:
	return EditorInterface.get_editor_settings()

func get_setting(property: StringName, alt: bool) -> bool:
	var editor_settings: EditorSettings = get_editor_settings()
	if (editor_settings.has_setting(property)):
		return editor_settings.get_setting(property)
	else:
		editor_settings.set_setting(property, alt)
		return alt

func set_setting(property: StringName, value: bool):
	var editor_settings: EditorSettings = get_editor_settings()

	suppress_settings_sync = true
	editor_settings.set_setting(property, value)
	suppress_settings_sync = false

func get_shortcut(property: StringName) -> Shortcut:
	return get_editor_settings().get_setting(property)

func get_outline_order() -> PackedStringArray:
	var new_outline_order: PackedStringArray
	var editor_settings: EditorSettings = get_editor_settings()
	if (editor_settings.has_setting(OUTLINE_ORDER)):
		new_outline_order = editor_settings.get_setting(OUTLINE_ORDER)
	else:
		new_outline_order = Outline.DEFAULT_ORDER
		editor_settings.set_setting(OUTLINE_ORDER, outline_order)

	return new_outline_order

static func find_or_null(arr: Array[Node]) -> Control:
	if (arr.is_empty()):
		push_error("""Node that is needed for Script-IDE not found.
Plugin will not work correctly.
This might be due to some other plugins or changes in the Engine.
Please report this to Script-IDE, so we can figure out a fix.""")
		return null
	return arr[0] as Control
