@tool
extends HFlowContainer

signal tab_changed(idx: int)
signal tab_pinned(idx: int, pinned: bool)
signal tab_close_pressed(idx: int)
signal tab_rearranged(from: int, to: int)

const Tab := preload("custom_tab.gd")
const pin_icon: Texture2D = preload("../icon/pin.svg")
const unpin_icon: Texture2D = preload("../icon/unpin.svg")

var style_tab_selected: StyleBoxFlat = EditorInterface.get_editor_theme().get_stylebox(&"tab_selected", &"TabBar").duplicate(true)
var style_tab_unselected: StyleBoxFlat = EditorInterface.get_editor_theme().get_stylebox(&"tab_unselected", &"TabBar").duplicate(true)
var style_tab_hovered: StyleBoxFlat = EditorInterface.get_editor_theme().get_stylebox(&"tab_hovered", &"TabBar").duplicate(true)

var current_tab: int = -1:
	set(value):
		current_tab = value
		if current_tab >= 0 and current_tab < get_child_count():
			get_child(current_tab).button_pressed = true

var button_group: ButtonGroup = ButtonGroup.new()

var scripts_item_list: ItemList
var scripts_tab_container: TabContainer

var tabs: Dictionary

func _ready() -> void:
	add_theme_constant_override(&"h_separation", 0)
	add_theme_constant_override(&"v_separation", 0)

	button_group.pressed.connect(_on_tab_changed)


func clear_tabs() -> void:
	tabs.clear()
	if get_child_count() == 0:
		return
	for i in range(get_child_count() - 1, -1, -1):
		var child := get_child(i)
		remove_child(child)
		child.queue_free()


func get_tab(idx: int) -> Tab:
	if idx >= 0 and idx < get_child_count():
		return get_child(idx)
	return null


func get_tab_count() -> int:
	return get_child_count()


func add_tab(title: String, icon: Texture2D = null) -> Tab:
	var tab := Tab.new()
	tab.title = title
	tab.tab_icon = icon

	tab.button_group = button_group

	tab.pin_icon = pin_icon
	tab.unpin_icon = unpin_icon
	tab.close_icon = EditorInterface.get_editor_theme().get_icon(&"Close", &"EditorIcons")

	tab.add_theme_stylebox_override(&"normal", style_tab_unselected)
	tab.add_theme_stylebox_override(&"pressed", style_tab_selected)
	tab.add_theme_stylebox_override(&"focus", style_tab_selected)
	tab.add_theme_stylebox_override(&"hover", style_tab_hovered)
	tab.font_hovered_color = EditorInterface.get_editor_theme().get_color(&"font_hovered_color", &"TabBar")
	tab.font_unselected_color = EditorInterface.get_editor_theme().get_color(&"font_unselected_color", &"TabBar")
	tab.font_selected_color = EditorInterface.get_editor_theme().get_color(&"font_selected_color", &"TabBar")

	tab.tab_pinned.connect(_on_tab_pinned)
	tab.tab_close_pressed.connect(_on_tab_close_pressed)
	add_child(tab)
	return tab


func set_tab_title(idx: int, text: String) -> void:
	var tab := get_tab(idx)
	if tab:
		tab.title = text


#func get_tab_title(idx: int) -> String:
	#var tab := get_tab(idx)
	#if tab:
		#return tab.title
	#return ""


func pin_tab(path: String) -> void:
	var tab: Tab = tabs.get(path, null)
	if tab:
		tab._on_pinned_pressed()

#func get_tab_icon(idx: int) -> Texture2D:
	#var tab := get_tab(idx)
	#if tab:
		#return tab.tab_icon
	#return null


#func get_tab_icon_color(idx: int) -> Color:
	#var tab := get_tab(idx)
	#if tab:
		#return tab.icon_color
	#return Color.WHITE


func set_tab_tooltip(idx: int, text: String) -> void:
	var tab := get_tab(idx)
	if tab:
		tab.tooltip_text = text


func _on_tab_close_pressed(idx: int) -> void:
	tab_close_pressed.emit(idx)
	var tab := get_tab(idx)
	if tab:
		remove_child(tab)
		tab.queue_free()


func _on_tab_changed(button: BaseButton) -> void:
	if not button:
		return
	var idx := button.get_index()
	if current_tab == idx:
		return
	current_tab = idx
	tab_changed.emit(idx)


func _on_tab_pinned(idx: int, pinned: bool) -> void:
	var tab: Tab = get_tab(idx)
	if pinned:
		for i in range(0, get_child_count()):
			var child: Tab = get_tab(i)
			if child == tab:
				break
			if not child.pinned:
				move_tab(idx, i)
				break
	else:
		for i in range(get_child_count() - 1, -1, -1):
			var child: Tab = get_tab(i)
			if child == tab:
				break
			if child.pinned:
				move_tab(idx, i)
				break


func move_tab(from: int, to: int, with_signal: bool = true) -> void:
	move_child(get_child(from), to)
	if with_signal:
		tab_rearranged.emit(from, to)

	var right_tab := get_tab(to + 1)
	var left_tab := get_tab(to - 1)
	if right_tab and right_tab.pinned:
		get_tab(to).pinned = true
	elif left_tab and not left_tab.pinned:
		get_tab(to).pinned = false
