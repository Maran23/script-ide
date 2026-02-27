## The outline container shows a filter box and
## all script members with different color coding, depending of the type.
@tool
extends VBoxContainer

const GETTER: StringName = &"get"
const SETTER: StringName = &"set"
const UNDERSCORE: StringName = &"_"
const INLINE: StringName = &"@"
const BUILT_IN_SCRIPT: StringName = &"::GDScript"

#region Outline type name
const TYPE: StringName = &"type"

const ENGINE_FUNCS: StringName = &"Engine Callbacks"
const FUNCS: StringName = &"Functions"
const SIGNALS: StringName = &"Signals"
const EXPORTED: StringName = &"Exported Properties"
const PROPERTIES: StringName = &"Properties"
const CLASSES: StringName = &"Classes"
const CONSTANTS: StringName = &"Constants"

const DEFAULT_ORDER: PackedStringArray = [ENGINE_FUNCS, FUNCS, SIGNALS, EXPORTED, PROPERTIES, CONSTANTS, CLASSES]
#endregion

const Plugin := preload("uid://bc0b5v66xdidn")

@onready var filter_box: HBoxContainer = %FilterBox
@onready var outline: ItemList = %Outline

var plugin: Plugin

#region Existing Engine controls we modify
var outline_filter_txt: LineEdit
#endregion

#region Outline icons and buttons
var engine_func_icon: Texture2D
var func_icon: Texture2D
var func_get_icon: Texture2D
var func_set_icon: Texture2D
var property_icon: Texture2D
var export_icon: Texture2D
var signal_icon: Texture2D
var constant_icon: Texture2D
var class_icon: Texture2D

var class_btn: Button
var constant_btn: Button
var signal_btn: Button
var property_btn: Button
var export_btn: Button
var func_btn: Button
var engine_func_btn: Button
#endregion

var is_hide_private_members: bool = false : set = set_hide_private_members
var outline_order: PackedStringArray : set = set_outline_order

var outline_type_order: Array[OutlineType] = []
var outline_cache: OutlineCache

func _ready() -> void:
	init_icons()
	init_outline_order()

	engine_func_btn = create_filter_btn(engine_func_icon, ENGINE_FUNCS)
	func_btn = create_filter_btn(func_icon, FUNCS)
	signal_btn = create_filter_btn(signal_icon, SIGNALS)
	export_btn = create_filter_btn(export_icon, EXPORTED)
	property_btn = create_filter_btn(property_icon, PROPERTIES)
	class_btn = create_filter_btn(class_icon, CLASSES)
	constant_btn = create_filter_btn(constant_icon, CONSTANTS)

	update_outline_button_order()

	outline.item_selected.connect(find_in_outline_and_goto)

func update():
	update_outline_cache()
	update_outline()

func tab_changed():
	var is_script: bool = get_current_script() != null
	visible = is_script

	update()

func find_in_outline_and_goto(selected_idx: int):
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
			plugin.goto_line(index)
			return

		# We have an modifier, e.g. 'static'
		if (modifier != &"" && line.begins_with(modifier)):
			if (line.begins_with(modifier + " " + type_with_text)):
				plugin.goto_line(index)
				return
			# Special case: An 'enum' is treated different.
			elif (modifier == &"enum" && line.contains("enum " + text)):
				plugin.goto_line(index)
				return

		# Hard case, probably something like '@onready var abc'
		if (type == &"var" && line.contains(type_with_text)):
			plugin.goto_line(index)
			return

		index += 1

	push_error(type_with_text + " or " + modifier + " not found in source code")

## Initializes all plugin icons, while respecting the editor settings.
func init_icons():
	engine_func_icon = create_editor_texture(load_rel("icon/engine_func.svg"))
	func_icon = create_editor_texture(load_rel("icon/func.svg"))
	func_get_icon = create_editor_texture(load_rel("icon/func_get.svg"))
	func_set_icon = create_editor_texture(load_rel("icon/func_set.svg"))
	property_icon = create_editor_texture(load_rel("icon/property.svg"))
	export_icon = create_editor_texture(load_rel("icon/export.svg"))
	signal_icon = create_editor_texture(load_rel("icon/signal.svg"))
	constant_icon = create_editor_texture(load_rel("icon/constant.svg"))
	class_icon = create_editor_texture(load_rel("icon/class.svg"))

func create_filter_btn(icon: Texture2D, type: StringName) -> Button:
	var btn: Button = Button.new()
	btn.toggle_mode = true
	btn.icon = icon
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.tooltip_text = type

	var property: StringName = plugin.SCRIPT_IDE + type.to_lower().replace(" ", "_")
	btn.set_meta(&"property", property)
	btn.set_meta(&"type", type)
	btn.button_pressed = plugin.get_setting(property, true)

	btn.toggled.connect(on_filter_button_pressed.bind(btn))
	btn.gui_input.connect(on_right_click.bind(btn))

	btn.add_theme_color_override(&"icon_pressed_color", Color.WHITE)
	btn.add_theme_color_override(&"icon_hover_color", Color.WHITE)
	btn.add_theme_color_override(&"icon_hover_pressed_color", Color.WHITE)
	btn.add_theme_color_override(&"icon_focus_color", Color.WHITE)

	var style_box_empty: StyleBoxEmpty = StyleBoxEmpty.new()
	btn.add_theme_stylebox_override(&"normal", style_box_empty)

	var style_box: StyleBoxFlat = StyleBoxFlat.new()
	style_box.draw_center = false
	style_box.border_color = get_editor_accent_color()
	style_box.set_border_width_all(1 * get_editor_scale())
	style_box.set_corner_radius_all(get_editor_corner_radius() * get_editor_scale())
	btn.add_theme_stylebox_override(&"focus", style_box)

	return btn

func on_right_click(event: InputEvent, btn: Button):
	if !(event is InputEventMouseButton):
		return

	var mouse_event: InputEventMouseButton = event

	if (!mouse_event.is_pressed() || mouse_event.button_index != MOUSE_BUTTON_RIGHT):
		return

	btn.button_pressed = true

	var pressed_state: bool = false
	for child: Node in filter_box.get_children():
		var other_btn: Button = child

		if (btn != other_btn):
			pressed_state = pressed_state || other_btn.button_pressed

	for child: Node in filter_box.get_children():
		var other_btn: Button = child

		if (btn != other_btn):
			other_btn.button_pressed = !pressed_state

	outline_filter_txt.grab_focus()

func on_filter_button_pressed(pressed: bool, btn: Button):
	plugin.set_setting(btn.get_meta(&"property"), pressed)

	update_outline()
	outline_filter_txt.grab_focus()

## Initializes the outline type structure and sorts it based off the outline order.
func init_outline_order():
	var outline_type: OutlineType = OutlineType.new()
	outline_type.type_name = ENGINE_FUNCS
	outline_type.add_to_outline = func(): add_to_outline_if_selected(engine_func_btn,
		func(): add_to_outline(outline_cache.engine_funcs, engine_func_icon, &"func"))
	outline_type_order.append(outline_type)

	outline_type = OutlineType.new()
	outline_type.type_name = FUNCS
	outline_type.add_to_outline = func(): add_to_outline_if_selected(func_btn,
		func(): add_to_outline_ext(outline_cache.funcs, get_func_icon, &"func", &"static"))
	outline_type_order.append(outline_type)

	outline_type = OutlineType.new()
	outline_type.type_name = SIGNALS
	outline_type.add_to_outline = func(): add_to_outline_if_selected(signal_btn,
		func(): add_to_outline(outline_cache.signals, signal_icon, &"signal"))
	outline_type_order.append(outline_type)

	outline_type = OutlineType.new()
	outline_type.type_name = EXPORTED
	outline_type.add_to_outline = func(): add_to_outline_if_selected(export_btn,
		func(): add_to_outline(outline_cache.exports, export_icon, &"var", &"@export"))
	outline_type_order.append(outline_type)

	outline_type = OutlineType.new()
	outline_type.type_name = PROPERTIES
	outline_type.add_to_outline = func(): add_to_outline_if_selected(property_btn,
		func(): add_to_outline(outline_cache.properties, property_icon, &"var"))
	outline_type_order.append(outline_type)

	outline_type = OutlineType.new()
	outline_type.type_name = CLASSES
	outline_type.add_to_outline = func(): add_to_outline_if_selected(class_btn,
		func(): add_to_outline(outline_cache.classes, class_icon, &"class"))
	outline_type_order.append(outline_type)

	outline_type = OutlineType.new()
	outline_type.type_name = CONSTANTS
	outline_type.add_to_outline = func(): add_to_outline_if_selected(constant_btn,
		func(): add_to_outline(outline_cache.constants, constant_icon, &"const", &"enum"))
	outline_type_order.append(outline_type)

func add_to_outline_if_selected(btn: Button, action: Callable):
	if (btn.button_pressed):
		action.call()

func update_outline_button_order():
	var all_buttons: Array[Button] = [engine_func_btn, func_btn, signal_btn, export_btn, property_btn, class_btn, constant_btn]
	all_buttons.sort_custom(sort_buttons_by_outline_order)

	for btn: Button in all_buttons:
		if (btn.get_parent() != null):
			filter_box.remove_child(btn)

	for btn: Button in all_buttons:
		filter_box.add_child(btn)

func sort_buttons_by_outline_order(btn1: Button, btn2: Button) -> bool:
	return sort_by_outline_order(btn1.get_meta(TYPE), btn2.get_meta(TYPE))

func sort_types_by_outline_order(type1: OutlineType, type2: OutlineType) -> bool:
	return sort_by_outline_order(type1.type_name, type2.type_name)

func sort_by_outline_order(outline_type1: StringName, outline_type2: StringName) -> bool:
	return outline_order.find(outline_type1) < outline_order.find(outline_type2)

func get_current_script() -> Script:
	var script_editor: ScriptEditor = EditorInterface.get_script_editor()
	return script_editor.get_current_script()

func update_outline_cache():
	outline_cache = null

	var script: Script = get_current_script()
	if (!script):
		return

	# Check if built-in script. In this case we need to duplicate it for whatever reason.
	if (script.get_path().contains(BUILT_IN_SCRIPT)):
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

		if (plugin.keywords.has(func_name)):
			consumer.call(outline_cache.engine_funcs, func_name)
		else:
			if (is_hide_private_members && func_name.begins_with(UNDERSCORE)):
				continue

			# Inline getter/setter will normally be shown as '@...getter', '@...setter'.
			# Since we already show the variable itself, we will skip those.
			if (func_name.begins_with(INLINE)):
				continue

			consumer.call(outline_cache.funcs, func_name)

	# Properties / Exported variables
	for dict: Dictionary in script.get_script_property_list():
		var property: String = dict[&"name"]
		if (is_hide_private_members && property.begins_with(UNDERSCORE)):
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
		if (is_hide_private_members && property.begins_with(UNDERSCORE)):
			continue

		var usage: int = dict[&"usage"]

		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			consumer.call(outline_cache.properties, property)

	# Signals
	for dict: Dictionary in script.get_script_signal_list():
		var signal_name: String = dict[&"name"]

		consumer.call(outline_cache.signals, signal_name)

	# Constants / Classes
	for name_key: String in script.get_script_constant_map():
		if (is_hide_private_members && name_key.begins_with(UNDERSCORE)):
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

	for outline_type: OutlineType in outline_type_order:
		outline_type.add_to_outline.call()

func add_to_outline(items: Array[String], icon: Texture2D, type: StringName, modifier: StringName = &""):
	add_to_outline_ext(items, func(str: String): return icon, type, modifier)

func add_to_outline_ext(items: Array[String], icon_callable: Callable, type: StringName, modifier: StringName = &""):
	var text: String = outline_filter_txt.get_text()

	if (is_sorted()):
		items = items.duplicate()
		items.sort_custom(func(str1: String, str2: String): return str1.naturalnocasecmp_to(str2) < 0)

	for item: String in items:
		if (text.is_empty() || text.is_subsequence_ofn(item)):
			var icon: Texture2D = icon_callable.call(item)
			outline.add_item(item, icon, true)

			var dict: Dictionary[StringName, StringName] = {
				&"type": type,
				&"modifier": modifier
			}
			outline.set_item_metadata(outline.item_count - 1, dict)

func get_func_icon(func_name: String) -> Texture2D:
	var icon: Texture2D = func_icon
	if (func_name.begins_with(GETTER)):
		icon = func_get_icon
	elif (func_name.begins_with(SETTER)):
		icon = func_set_icon

	return icon

func save_restore_filter() -> Array[bool]:
	var button_flags: Array[bool] = []
	for child: Node in filter_box.get_children():
		var btn: Button = child
		button_flags.append(btn.button_pressed)

		btn.set_pressed_no_signal(true)

	return button_flags

func restore_filter(button_flags: Array[bool]):
	var index: int = 0
	for flag: bool in button_flags:
		var btn: Button = filter_box.get_child(index)
		btn.set_pressed_no_signal(flag)
		index += 1

func set_outline_order(new_outline_order: PackedStringArray):
	outline_order = new_outline_order

	outline_type_order.sort_custom(sort_types_by_outline_order)

	update_outline_button_order()
	update_outline()

func set_hide_private_members(new_value: bool):
	is_hide_private_members = new_value

	update_outline()

func update_filter_buttons():
	# Update filter buttons.
	for btn_node: Node in filter_box.get_children():
		var btn: Button = btn_node
		var property: StringName = btn.get_meta(&"property")

		btn.button_pressed = plugin.get_setting(property, btn.button_pressed)

func reset_icons():
	init_icons()
	engine_func_btn.icon = engine_func_icon
	func_btn.icon = func_icon
	signal_btn.icon = signal_icon
	export_btn.icon = export_icon
	property_btn.icon = property_icon
	class_btn.icon = class_icon
	constant_btn.icon = constant_icon
	update_outline()

func create_editor_texture(texture: Texture2D) -> Texture2D:
	var image: Image = texture.get_image().duplicate()
	image.adjust_bcs(1.0, 1.0, get_editor_icon_saturation())

	return ImageTexture.create_from_image(image)

func load_rel(path: String) -> Variant:
	var script_path: String = get_script().get_path().get_base_dir()
	return load(script_path.path_join(path))

func is_sorted() -> bool:
	return EditorInterface.get_editor_settings().get_setting("text_editor/script_list/sort_members_outline_alphabetically")

func get_editor_scale() -> float:
	return EditorInterface.get_editor_scale()

func get_editor_corner_radius() -> int:
	return EditorInterface.get_editor_settings().get_setting("interface/theme/corner_radius")

func get_editor_accent_color() -> Color:
	return EditorInterface.get_editor_settings().get_setting("interface/theme/accent_color")

func get_editor_icon_saturation() -> float:
	return EditorInterface.get_editor_settings().get_setting("interface/theme/icon_saturation")

## Cache for everything inside we collected to show in the Outline.
class OutlineCache:
	var classes: Array[String] = []
	var constants: Array[String] = []
	var signals: Array[String] = []
	var exports: Array[String] = []
	var properties: Array[String] = []
	var funcs: Array[String] = []
	var engine_funcs: Array[String] = []

## Outline type for a concrete button with their items in the Outline.
class OutlineType:
	var type_name: StringName
	var add_to_outline: Callable
