## Tab bar that can show tabs in multiple lines (wrap), when there is not enough horizontal space.
@tool
extends PanelContainer

const CustomTab := preload("uid://bppomxp4mri2o")
const SplitView := preload("uid://dixntmagth35c")

@onready var multiline_tab_bar: HFlowContainer = %MultilineTabBar
@onready var split_btn: CustomTab = %SplitBtn
@onready var popup_btn: Button = %PopupBtn

#region Theme
var tab_hovered: StyleBoxFlat
var tab_focus: StyleBoxFlat
var tab_selected: StyleBoxFlat
var tab_unselected: StyleBoxFlat

var font_selected_color: Color
var font_unselected_color: Color
var font_hovered_color: Color
#endregion

var show_close_button_always: bool = false : set = set_show_close_button_always
var is_singleline_tabs: bool = false : set = set_singleline_tabs

var tab_group: ButtonGroup = ButtonGroup.new()

# Existing Engine components, set from the plugin.
var split_view: SplitView
var script_filter_txt: LineEdit
var scripts_item_list: ItemList
var scripts_tab_container: TabContainer

var tab_cycle_forward_shc: Shortcut
var tab_cycle_backward_shc: Shortcut

var popup: PopupPanel

var suppress_theme_changed: bool

var split_icon: Texture2D

var last_drag_over_tab: CustomTab
var drag_marker: ColorRect
var current_tab: CustomTab

#region Plugin and related tab handling processing
func _init() -> void:
	tab_group.pressed.connect(on_new_tab_selected)

func _ready() -> void:
	popup_btn.pressed.connect(show_popup)

	split_btn.reorderable = false
	split_btn.right_clicked.connect(close_split_script)
	split_btn.close_pressed.connect(move_split_to_main)
	split_icon = split_btn.icon

	set_process(false)

	if (scripts_item_list == null):
		return

	split_btn.toggled.connect(split_view.toggle.unbind(1))

	schedule_update()

func _notification(what: int) -> void:
	if (what == NOTIFICATION_DRAG_END || what == NOTIFICATION_MOUSE_EXIT):
		clear_drag_mark()
		return

	if (what == NOTIFICATION_THEME_CHANGED):
		if (suppress_theme_changed):
			return

		suppress_theme_changed = true
		add_theme_stylebox_override(&"panel", EditorInterface.get_editor_theme().get_stylebox(&"tabbar_background", &"TabContainer"))
		suppress_theme_changed = false

		tab_hovered = EditorInterface.get_editor_theme().get_stylebox(&"tab_hovered", &"TabContainer")
		tab_focus = EditorInterface.get_editor_theme().get_stylebox(&"tab_focus", &"TabContainer")
		tab_selected = EditorInterface.get_editor_theme().get_stylebox(&"tab_selected", &"TabContainer")
		tab_unselected = EditorInterface.get_editor_theme().get_stylebox(&"tab_unselected", &"TabContainer")

		font_hovered_color = EditorInterface.get_editor_theme().get_color(&"font_hovered_color", &"TabContainer")
		font_selected_color = EditorInterface.get_editor_theme().get_color(&"font_selected_color", &"TabContainer")
		font_unselected_color = EditorInterface.get_editor_theme().get_color(&"font_unselected_color", &"TabContainer")

		# If this is called too early.
		if (multiline_tab_bar == null):
			return

		update_tab_style(split_btn)

		for tab: CustomTab in get_tabs():
			update_tab_style(tab)

func _process(delta: float) -> void:
	sync_tabs_with_item_list()

	if (is_singleline_tabs):
		shift_singleline_tabs()

	set_process(false)

func _shortcut_input(event: InputEvent) -> void:
	if (!event.is_pressed() || event.is_echo()):
		return

	if (!is_visible_in_tree()):
		return

	if (current_tab == null):
		return

	if (tab_cycle_forward_shc.matches_event(event)):
		get_viewport().set_input_as_handled()
		cycle_tab(1)
	elif (tab_cycle_backward_shc.matches_event(event)):
		get_viewport().set_input_as_handled()
		cycle_tab(-1)

## Selects the next tab in the given direction, skipping the split script since it has no visible tab.
func cycle_tab(direction: int) -> void:
	var tab_count: int = get_tab_count()
	var split_index: int = get_split_index()
	var index: int = current_tab.get_index()

	for i: int in tab_count - 1:
		index = posmod(index + direction, tab_count)
		if (index != split_index):
			get_tab(index).button_pressed = true
			return

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if !(data is Dictionary):
		return false

	var can_drop: bool = data.has("index") && data["index"] != get_tab_count() - 1

	if (can_drop):
		on_drag_over(get_tab(get_tab_count() - 1))

	return can_drop

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if (!_can_drop_data(at_position, data)):
		return

	on_drag_drop(data["index"], get_tab_count() - 1)
#endregion

func schedule_update() -> void:
	set_process(true)

func set_split(split: bool) -> void:
	split_btn.set_pressed_no_signal(split)

	if (split):
		split_btn.show_close_button()
		update_split()
	else:
		split_btn.hide_close_button()

		split_btn.icon = split_icon
		split_btn.set_tab_text("")
		split_btn.tooltip_text = ""
		update_icon_color(split_btn, Color.WHITE)

	# Will remove the split tab from the tab bar.
	schedule_update()

## Syncs the split tab with the script of the split view,
## so that changes (like the unsaved marker '(*)') are visible there as well.
func update_split() -> void:
	var index: int = get_split_index()
	if (index == -1):
		return

	split_btn.set_tab_text(scripts_item_list.get_item_text(index))
	split_btn.icon = scripts_item_list.get_item_icon(index)
	split_btn.tooltip_text = scripts_item_list.get_item_tooltip(index)

	update_icon_color(split_btn, scripts_item_list.get_item_icon_modulate(index))

## The index of the split script, which is the same for the tabs, the script list and the Engine.
func get_split_index() -> int:
	var editor_base: ScriptEditorBase = split_view.get_split_editor_base()
	if (editor_base == null):
		return -1

	var index: int = editor_base.get_index()
	# The script list is filtered.
	if (index >= scripts_item_list.item_count):
		return -1

	return index

func set_split_disabled(value: bool) -> void:
	split_btn.disabled = value

## Closes the script of the split view, which closes the split view along with it.
func close_split_script() -> void:
	var index: int = get_split_index()
	if (index != -1):
		close_script(index)

## Closes the split view and shows its script in the main view again.
## The script is still open, so its tab can simply be selected.
func move_split_to_main() -> void:
	var index: int = get_split_index()

	split_view.close()

	var tab: CustomTab = get_tab(index)
	if (tab != null):
		tab.button_pressed = true

func on_drag_drop(source_index: int, target_index: int) -> void:
	var child: Node = scripts_tab_container.get_child(source_index)
	scripts_tab_container.move_child(child, target_index);

	update_script_list()

	var tab: CustomTab = get_tab(target_index)
	tab.grab_focus()

func on_drag_over(tab: CustomTab) -> void:
	if (last_drag_over_tab == tab):
		return

	if (drag_marker == null):
		drag_marker = ColorRect.new()
		drag_marker.set_anchors_and_offsets_preset(PRESET_LEFT_WIDE)
		drag_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		drag_marker.custom_minimum_size.x = 4 * EditorInterface.get_editor_scale()
	drag_marker.color = EditorInterface.get_editor_theme().get_color(&"drop_mark_color", &"TabContainer")

	# The drag marker should always be orphan when here.
	tab.add_child(drag_marker)

	last_drag_over_tab = tab

func clear_drag_mark() -> void:
	if (last_drag_over_tab == null):
		return

	last_drag_over_tab = null
	if (drag_marker != null && drag_marker.get_parent() != null):
		drag_marker.get_parent().remove_child(drag_marker)

func update_tabs() -> void:
	on_scripts_changed()
	update_split()

	for tab: CustomTab in get_tabs():
		update_tab(tab)

	# Every tab was made visible again.
	if (is_singleline_tabs):
		shift_singleline_tabs()

func get_tabs() -> Array[Node]:
	return multiline_tab_bar.get_children()

## Updates the text (unsaved marker '(*)') of the tab of the current script.
func update_current_tab_text() -> void:
	var index: int = scripts_tab_container.current_tab

	# The split script is not the selected one, but can still be the current one.
	var tab: CustomTab = split_btn
	if (index != get_split_index()):
		tab = get_tab(index)

	if (tab == null):
		return

	var text: String = scripts_item_list.get_item_text(index)
	tab.set_tab_text(text)

func update_tab(tab: CustomTab) -> void:
	if (tab == null):
		return

	var index: int = tab.get_index()

	tab.set_tab_text(scripts_item_list.get_item_text(index))
	tab.icon = scripts_item_list.get_item_icon(index)
	tab.tooltip_text = scripts_item_list.get_item_tooltip(index)

	update_icon_color(tab, scripts_item_list.get_item_icon_modulate(index))

	# The split script is shown in the split view, so it has no tab in the main view.
	var is_split_tab: bool = index == get_split_index()
	tab.visible = !is_split_tab

	if (!is_split_tab && scripts_item_list.is_selected(index)):
		tab.button_pressed = true

func get_tab(index: int) -> CustomTab:
	if (index < 0 || index >= get_tab_count()):
		return null

	return multiline_tab_bar.get_child(index)

func get_tab_count() -> int:
	return multiline_tab_bar.get_child_count()

func add_tab() -> CustomTab:
	var tab: CustomTab = CustomTab.new()
	tab.button_group = tab_group

	if (show_close_button_always):
		tab.show_close_button()

	update_tab_style(tab)

	tab.close_pressed.connect(on_tab_close_pressed.bind(tab))
	tab.right_clicked.connect(on_tab_right_click.bind(tab))
	tab.mouse_exited.connect(clear_drag_mark)
	tab.dragged_over.connect(on_drag_over.bind(tab))
	tab.dropped.connect(on_drag_drop)

	multiline_tab_bar.add_child(tab)
	return tab

func update_tab_style(tab: CustomTab) -> void:
	tab.add_theme_stylebox_override(&"normal", tab_unselected)
	tab.add_theme_stylebox_override(&"hover", tab_hovered)
	tab.add_theme_stylebox_override(&"hover_pressed", tab_hovered)
	tab.add_theme_stylebox_override(&"focus", tab_focus)
	tab.add_theme_stylebox_override(&"pressed", tab_selected)
	tab.add_theme_stylebox_override(&"disabled", tab_unselected)

	tab.add_theme_color_override(&"font_color", font_unselected_color)
	tab.add_theme_color_override(&"font_hover_color", font_hovered_color)
	tab.add_theme_color_override(&"font_pressed_color", font_selected_color)

func update_icon_color(tab: CustomTab, color: Color) -> void:
	tab.add_theme_color_override(&"icon_normal_color", color)
	tab.add_theme_color_override(&"icon_hover_color", color)
	tab.add_theme_color_override(&"icon_hover_pressed_color", color)
	tab.add_theme_color_override(&"icon_pressed_color", color)
	tab.add_theme_color_override(&"icon_focus_color", color)

func on_tab_right_click(tab: CustomTab) -> void:
	tab.button_pressed = true
	var index: int = tab.get_index()
	scripts_item_list.item_clicked.emit(index, scripts_item_list.get_local_mouse_position(), MOUSE_BUTTON_RIGHT)

func on_new_tab_selected(tab: CustomTab) -> void:
	# Hide and show close button.
	if (!show_close_button_always):
		if (current_tab != null):
			current_tab.hide_close_button()

		if (tab != null):
			tab.show_close_button()

	update_script_text_filter()

	var index: int = tab.get_index()
	if (scripts_item_list != null && !scripts_item_list.is_selected(index)):
		scripts_item_list.select(index)
		scripts_item_list.item_selected.emit(index)
		scripts_item_list.ensure_current_is_visible()

	current_tab = tab

## Removes the script filter text and emits the signal so that the tabs stay
## and we do not break anything there.
func update_script_text_filter() -> void:
	if (script_filter_txt.text != &""):
		script_filter_txt.text = &""
		update_script_list()

## The Engine only rebuilds its script list on its own changes, or when the filter text changed.
func update_script_list() -> void:
	script_filter_txt.text_changed.emit(script_filter_txt.text)

func on_tab_close_pressed(tab: CustomTab) -> void:
	close_script(tab.get_index())

## Closes the script the same way the Engine does it, which also asks to save it when needed.
func close_script(index: int) -> void:
	# The indices of the script list only match the tabs when nothing is filtered.
	update_script_text_filter()

	scripts_item_list.item_clicked.emit(index, scripts_item_list.get_local_mouse_position(), MOUSE_BUTTON_MIDDLE)

func sync_tabs_with_item_list() -> void:
	if (get_tab_count() > scripts_item_list.item_count):
		for index: int in range(get_tab_count() - 1, scripts_item_list.item_count - 1, -1):
			var tab: CustomTab = get_tab(index)

			if (tab == current_tab):
				current_tab = null

			multiline_tab_bar.remove_child(tab)
			free_tab(tab)

	for index: int in scripts_item_list.item_count:
		var tab: CustomTab = get_tab(index)
		if (tab == null):
			tab = add_tab()

		update_tab(tab)

func tab_changed() -> void:
	on_scripts_changed()
	update_script_text_filter()

	# When the tab change was not triggered by our component, we need to sync the selection.
	update_tab(get_tab(scripts_tab_container.current_tab))

func on_scripts_changed() -> void:
	update_script_text_filter()

	popup_btn.text = "(" + str(scripts_item_list.item_count) + ")"

func script_order_changed() -> void:
	schedule_update()

func set_popup(new_popup: PopupPanel) -> void:
	popup = new_popup

func show_popup() -> void:
	if (popup == null):
		return

	scripts_item_list.get_parent().reparent(popup)
	scripts_item_list.get_parent().visible = true

	popup.size = Vector2(250 * get_editor_scale(), get_parent().size.y - size.y)
	popup.position = popup_btn.get_screen_position() - Vector2(popup.size.x, 0)
	popup.popup()

	script_filter_txt.grab_focus()

func get_editor_scale() -> float:
	return EditorInterface.get_editor_scale()

func set_show_close_button_always(new_value: bool) -> void:
	if (show_close_button_always == new_value):
		return

	show_close_button_always = new_value

	if (multiline_tab_bar == null):
		return

	for tab: CustomTab in get_tabs():
		# The selected tab always shows its close button.
		if (tab.button_pressed):
			continue

		if (show_close_button_always):
			tab.show_close_button()
		else:
			tab.hide_close_button()

func free_tabs() -> void:
	if (drag_marker != null):
		drag_marker.free()

	if (split_btn.close_button != null):
		split_btn.close_button.free()

	for tab: CustomTab in get_tabs():
		free_tab(tab)

func free_tab(tab: CustomTab) -> void:
	if (tab.close_button != null):
		tab.close_button.free()
	tab.free()

#region Singeline handling
func set_singleline_tabs(new_value: bool) -> void:
	if (is_singleline_tabs == new_value):
		return

	is_singleline_tabs = new_value

	if (is_singleline_tabs):
		multiline_tab_bar.item_rect_changed.connect(shift_singleline_tabs)
		tab_group.pressed.connect(shift_singleline_tabs.unbind(1))

		shift_singleline_tabs()
	else:
		multiline_tab_bar.item_rect_changed.disconnect(shift_singleline_tabs)
		tab_group.pressed.disconnect(shift_singleline_tabs)

		for tab: CustomTab in get_tabs():
			tab.visible = true

func shift_singleline_tabs() -> void:
	if (current_tab == null):
		return

	var tabs: Array[Node] = get_tabs()
	var tab_count: int = tabs.size()
	if (tab_count == 0):
		return

	var tab_bar_width: float = multiline_tab_bar.size.x
	var current_index: int = current_tab.get_index()
	var first: int = current_index
	var last: int = current_index
	var used_width: float = current_tab.size.x

	# Pass 1: Expand through already-visible tabs first
	while (first > 0):
		var prev_tab: Node = tabs[first - 1]
		if (!prev_tab.visible || used_width + prev_tab.size.x > tab_bar_width):
			break
		first -= 1
		used_width += prev_tab.size.x

	while (last < tab_count - 1):
		var next_tab: Node = tabs[last + 1]
		if (!next_tab.visible || used_width + next_tab.size.x > tab_bar_width):
			break
		last += 1
		used_width += next_tab.size.x

	# Pass 2: Fill remaining space with any tabs
	while (first > 0):
		var prev_tab: Node = tabs[first - 1]
		if (used_width + prev_tab.size.x > tab_bar_width):
			break
		first -= 1
		used_width += prev_tab.size.x

	while (last < tab_count - 1):
		var next_tab: Node = tabs[last + 1]
		if (used_width + next_tab.size.x > tab_bar_width):
			break
		last += 1
		used_width += next_tab.size.x

	var split_index: int = get_split_index()
	for index: int in tab_count:
		var tab: Node = tabs.get(index)
		tab.visible = index >= first && index <= last && index != split_index
#endregion
