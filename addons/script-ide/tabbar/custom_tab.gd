@tool
extends Button

signal tab_pinned(idx: int, pinned: bool)
signal tab_close_pressed(idx: int)

var container: HBoxContainer = HBoxContainer.new()
var texture_rect: TextureRect = TextureRect.new()
var label: Label = Label.new()
var pin_button: Button = Button.new()
var close_button: Button = Button.new()

var pinned: bool = false:
	set(value):
		pinned = value
		_update_buttons()

var title: String:
	set(value):
		label.text = value
	get():
		return label.text

var tab_icon: Texture2D:
	set(value):
		texture_rect.texture = value
	get():
		return texture_rect.texture

var pin_icon: Texture2D:
	set(value):
		pin_icon = value
		if pinned: pin_button.icon = value

var unpin_icon: Texture2D:
	set(value):
		unpin_icon = value
		if not pinned: pin_button.icon = value

var close_icon: Texture2D:
	set(value):
		close_button.icon = value

var font_unselected_color: Color
var font_hovered_color: Color
var font_selected_color: Color
var icon_color: Color:
	set(value):
		texture_rect.self_modulate = value
	get():
		return texture_rect.self_modulate

func _ready() -> void:
	toggle_mode = true
	action_mode = ACTION_MODE_BUTTON_PRESS
	toggled.connect(_update_buttons.unbind(1))
	mouse_entered.connect(_update_buttons, CONNECT_DEFERRED)
	mouse_exited.connect(_update_buttons, CONNECT_DEFERRED)

	var separator := Control.new()
	separator.custom_minimum_size.x = 12 * EditorInterface.get_editor_scale()
	separator.mouse_filter = Control.MOUSE_FILTER_PASS
	container.add_child(separator)

	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	container.add_child(texture_rect)

	label.add_theme_color_override(&"font_color", Color.WHITE)
	container.add_child(label)

	pin_button.flat = true
	pin_button.focus_mode = Control.FOCUS_NONE
	pin_button.mouse_filter = Control.MOUSE_FILTER_PASS
	pin_button.add_theme_color_override(&"icon_disabled_color", Color.TRANSPARENT)
	pin_button.pressed.connect(_on_pinned_pressed)
	container.add_child(pin_button)

	close_button.flat = true
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.mouse_filter = Control.MOUSE_FILTER_PASS
	close_button.add_theme_color_override(&"icon_disabled_color", Color.TRANSPARENT)
	close_button.pressed.connect(_on_close_pressed)
	container.add_child(close_button)

	container.add_theme_constant_override(&"separation", 0)
	container.minimum_size_changed.connect(_on_container_item_rect_changed, CONNECT_DEFERRED)
	add_child(container)

	_update_buttons()


func get_tab_path() -> String:
	return tooltip_text.trim_suffix(" Class Reference")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			_on_close_pressed()


func _on_pinned_pressed() -> void:
	pinned = not pinned
	_update_buttons()
	tab_pinned.emit(get_index(), pinned)


func _on_close_pressed() -> void:
	tab_close_pressed.emit(get_index())


func _update_buttons() -> void:
	pin_button.disabled = not (is_hovered() or button_pressed or pinned)
	close_button.disabled = not (is_hovered() or button_pressed)
	pin_button.icon = pin_icon if pinned else unpin_icon
	label.self_modulate = font_selected_color if button_pressed else (font_hovered_color if is_hovered() else font_unselected_color)
	z_index = 0
	draw_drop_mark = false


func _on_container_item_rect_changed() -> void:
	custom_minimum_size = container.size


#region Drag'n'Drop

var drop_mark_color: Color = EditorInterface.get_editor_theme().get_color(&"drop_mark_color", &"TabBar")

var drop_mark_width: float = 6.0 * EditorInterface.get_editor_scale()
var drop_mark_offset: float = drop_mark_width / 2.0

var draw_drop_mark: bool = false
var is_drop_mark_left: bool = false

func _draw() -> void:
	if draw_drop_mark:
		draw_rect(Rect2(-drop_mark_offset + (0 if is_drop_mark_left else size.x), 0, drop_mark_width, size.y), drop_mark_color)


func _get_drag_data(at_position: Vector2) -> Variant:
	var hbox := HBoxContainer.new()
	hbox.z_index = 2
	var icon := TextureRect.new()
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = tab_icon
	icon.self_modulate = icon_color
	hbox.add_child(icon)

	var label := Label.new()
	label.text = title
	hbox.add_child(label)

	set_drag_preview(hbox)
	set_meta("__tab", true)
	return self


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	var can_drop: bool = data.get_meta("__tab", false)
	if can_drop:
		is_drop_mark_left = at_position.x <= size.x / 2
		z_index = 1
		draw_drop_mark = true
		queue_redraw()
	return can_drop


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if data == self:
		return
	var is_left := at_position.x <= size.x / 2
	var from: int = data.get_index()
	var to: int
	if from > get_index():
		to = get_index() + (0 if is_left else 1)
	else:
		to = get_index() - (1 if is_left else 0)
	if from != to:
		get_parent().move_tab(from, to)

#endregion
