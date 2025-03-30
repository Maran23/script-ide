@tool
extends Popup
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#	script-ide: Virtual Popups
#
#	Virtual Popups for script-ide addon.godot 4
#	author:	"Twister"
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

const CHAR_VIRTUAL_FUNCTION : String = "_"
const CHAR_PRIVATE_FUNCTION : String = "__"
const BUILT_IN_SCRIPT: StringName = &"::GDScript"

const ICON_CLASS : Image = preload("res://addons/script-ide/icon/class.svg")
const ICON_VIRTUALS : Image = preload("res://addons/script-ide/popup/icon/func_virtual.svg")
const ICON_CHECKED : Image = preload("res://addons/script-ide/popup/icon/check.svg")

var COLOR_CLASS : Color = Color.DARK_SLATE_BLUE
var COLOR_NATIVE_CLASS : Color = Color.BLACK
var COLOR_PARAMETERS : Color = Color.BLACK

var include_paremeters : bool = false

enum FILTER_TYPE{
	DEFAULT,
	REVERSE,
	DEFAUL_TREE,
	REVERSE_TREE
}

@export_tool_button("Test")
var test_button: Callable = _testing

@export var tree : Tree
@export var accept_button : Button
@export var cancel_button : Button

var _buffer_data : Dictionary = {}


func make_tree(input_script : Script, filter_type : FILTER_TYPE = FILTER_TYPE.REVERSE) -> void:
	_buffer_data = {}
	if tree == null:
		push_error("Not defined tree!")
		return

	tree.clear()

	var callback : Callable = _on_accept_button.bind(input_script)
	if accept_button:
		if accept_button.pressed.is_connected(_on_accept_button):
			accept_button.pressed.disconnect(_on_accept_button)
		accept_button.pressed.connect(callback)
	if tree.item_activated.is_connected(_on_accept_button):
		tree.item_activated.disconnect(_on_accept_button)
	tree.item_activated.connect(callback)

	# script-ide: Check if built-in script. In this case we need to duplicate it for whatever reason.
	if (input_script.get_path().contains(BUILT_IN_SCRIPT)):
		input_script = input_script.duplicate()

	var output : Array = generate_data(input_script)
	#var current : Dictionary = output[0]
	var base : Dictionary = output[0]
	var base_count : int = output[1]

	#MAKE TREE
	var start : int = 0
	var end : int = base_count + 1
	var step : int = 1
	if filter_type == FILTER_TYPE.DEFAULT or filter_type == FILTER_TYPE.DEFAUL_TREE:
		start = base_count
		end = -1
		step = -1

	tree.set_column_custom_minimum_width(0, 250)
	tree.set_column_custom_minimum_width(1, 50)
	tree.set_column_custom_minimum_width(2, 50)

	tree.set_column_title_alignment(0, HORIZONTAL_ALIGNMENT_CENTER)
	tree.set_column_title_alignment(1, HORIZONTAL_ALIGNMENT_CENTER)
	tree.set_column_title_alignment(2, HORIZONTAL_ALIGNMENT_CENTER)

	tree.set_column_title(0, "Class/Functions")
	tree.set_column_title(1, "Params")
	tree.set_column_title(2, "Return")
	tree.column_titles_visible = true

	var root : TreeItem = tree.create_item()
	root.set_text(0, "Classes")

	var texture_class: Texture = ImageTexture.create_from_image(ICON_CLASS)
	var texture_virtual : Texture = ImageTexture.create_from_image(ICON_VIRTUALS)
	var texture_check : Texture = ImageTexture.create_from_image(ICON_CHECKED)

	var created_funcs : Dictionary = _clear_funcs(input_script)

	_buffer_data = base

	if filter_type == FILTER_TYPE.DEFAUL_TREE or filter_type == FILTER_TYPE.REVERSE_TREE:
		var last : TreeItem = root
		for x : int in range(start, end, step):
			var dict : Dictionary = base[x]
			var funcs : Dictionary = dict["funcs"]

			if funcs.size() == 0:continue

			var item : TreeItem = tree.create_item(last, -1)

			item.set_text(0, dict["name"])
			item.set_icon(0, texture_class)
			last = item

			if dict["native"] == true:
				item.set_custom_bg_color(0, COLOR_NATIVE_CLASS)
				item.set_custom_bg_color(1, COLOR_NATIVE_CLASS)
				item.set_custom_bg_color(2, COLOR_NATIVE_CLASS)
				item.collapsed = true
			else:
				item.set_custom_bg_color(0, COLOR_CLASS)
				item.set_custom_bg_color(1, COLOR_CLASS)
				item.set_custom_bg_color(2, COLOR_CLASS)
			item.set_selectable(0, false)
			item.set_selectable(1, false)
			item.set_selectable(2, false)
			for key : Variant in funcs.keys():
				var sub_item : TreeItem = tree.create_item(item, -1)
				sub_item.set_text(0, funcs[key])
				if created_funcs.has(key):
					sub_item.set_icon(0, texture_check)
					sub_item.set_selectable(0, false)
				else:
					sub_item.set_icon(0, texture_virtual)
					sub_item.set_selectable(0, true)
				sub_item.set_custom_color(1, COLOR_PARAMETERS)
				sub_item.set_custom_color(2, COLOR_PARAMETERS)
				if sub_item.get_text(1) == "-":
					sub_item.set_text_alignment(1,HORIZONTAL_ALIGNMENT_CENTER)
				else:
					sub_item.set_text_alignment(1,HORIZONTAL_ALIGNMENT_LEFT)
				sub_item.set_text_alignment(2,HORIZONTAL_ALIGNMENT_CENTER)
				sub_item.set_selectable(1, false)
				sub_item.set_selectable(2, false)
	else:
		for x : int in range(start, end, step):
			var dict : Dictionary = base[x]
			var funcs : Dictionary = dict["funcs"]

			if funcs.size() == 0:continue

			var item : TreeItem = tree.create_item(null, -1)

			item.set_text(0, dict["name"])
			item.set_icon(0, texture_class)
			if dict["native"] == true:
				item.set_custom_bg_color(0, COLOR_NATIVE_CLASS)
				item.set_custom_bg_color(1, COLOR_NATIVE_CLASS)
				item.set_custom_bg_color(2, COLOR_NATIVE_CLASS)
				item.collapsed = true
			else:
				item.set_custom_bg_color(0, COLOR_CLASS)
				item.set_custom_bg_color(1, COLOR_CLASS)
				item.set_custom_bg_color(2, COLOR_CLASS)
			item.set_selectable(0, false)
			item.set_selectable(1, false)
			item.set_selectable(2, false)
			for key : Variant in funcs.keys():
				var sub_item : TreeItem = tree.create_item(item, -1)
				var func_name : PackedStringArray = (funcs[key] as String).split('||', false, 2)
				for fx : int in range(0, func_name.size(), 1):
					sub_item.set_text(fx, func_name[fx])
				if sub_item.get_text(1) == "-":
					sub_item.set_text_alignment(1,HORIZONTAL_ALIGNMENT_CENTER)
				else:
					sub_item.set_text_alignment(1,HORIZONTAL_ALIGNMENT_LEFT)
				sub_item.set_text_alignment(2,HORIZONTAL_ALIGNMENT_CENTER)
				sub_item.set_selectable(1, false)
				sub_item.set_selectable(2, false)
				sub_item.set_custom_color(1, COLOR_PARAMETERS)
				sub_item.set_custom_color(2, COLOR_PARAMETERS)
				if created_funcs.has(key):
					sub_item.set_icon(0, texture_check)
					sub_item.set_selectable(0, false)
				else:
					sub_item.set_icon(0, texture_virtual)
					sub_item.set_selectable(0, true)

	if root.get_child_count() == 0:
		root.set_text(0, "No virtual functions aviables!")
		tree.hide_root = false

## Generate tree data, @output Array(base class data, total bases inherited class])
func generate_data(script : Script) -> Array:
	var data_base : Dictionary = {}
	var base_count : int = _generate_native(script.get_instance_base_type(), data_base, _generate(script.get_base_script(), data_base))
	return [data_base, base_count]

#region init
func _ready() -> void:
	if !Engine.is_editor_hint():
		#Component created for be used in editor mode, so testing is invoke in non editor mode.
		_testing()

func _testing() -> void:
	await get_tree().process_frame

	#Also work with class_name
	var input_script : Script = ResourceLoader.load("res://addons/script-ide/popup/testing/child.gd")

	#Show popup
	call_deferred(&"show")
	make_tree(input_script)

func _init() -> void:
	if !is_node_ready():
		await ready
	assert(tree and accept_button and cancel_button)

	tree.select_mode = Tree.SELECT_MULTI
	tree.multi_selected.connect(_on_tree_multi_selected)
	cancel_button.pressed.connect(_on_cancel_button)

	COLOR_CLASS = COLOR_CLASS.darkened(0.4)
	COLOR_NATIVE_CLASS = COLOR_CLASS.darkened(0.4)
	COLOR_PARAMETERS = COLOR_CLASS.lightened(0.3)

	_update_gui()
#endregion

func _update_gui() -> void:
	if accept_button:
		accept_button.disabled = tree.get_selected() == null

func _write_lines(input_script : Script, data : String) -> bool:
	#ONLY EDITOR MODE
	if !Engine.is_editor_hint():
		print(data)
		return false

	const COMMENT : String = '\n#Override virtual function'

	var script_editor: ScriptEditor = EditorInterface.get_script_editor()
	var scripts : Array[Script] = script_editor.get_open_scripts()
	var scripts_editor : Array[ScriptEditorBase] = script_editor.get_open_script_editors()
	var edit : CodeEdit = null
	var iscript : int = -1

	for x : int in range(scripts.size()):
		if scripts[x] == input_script:
			iscript = x
			break

	if iscript == -1 or iscript >= scripts_editor.size():
		push_error("Error, can`t get editor!")
		return false

	edit = scripts_editor[iscript].get_base_editor()
	edit.text += str("\n", COMMENT,"\n", data)

	_goto_line(script_editor, edit.get_line_count() - 1)
	return true

# goto_line script-ide
func _goto_line(script_editor : ScriptEditor, index : int):
	script_editor.goto_line(index)

	var code_edit: CodeEdit = script_editor.get_current_editor().get_base_editor()
	code_edit.set_caret_line(index)
	code_edit.set_v_scroll(index)
	code_edit.set_caret_column(code_edit.get_line(index).length())
	code_edit.set_h_scroll(0)

	code_edit.grab_focus()

#region UI_CALLBACK
func _on_accept_button(input_script : Script) -> void:
	var item : TreeItem = tree.get_selected()
	var data : Array[Dictionary] = input_script.get_method_list()
	var funcs : PackedStringArray = []

	while item != null:
		var fname : String = item.get_text(0)
		funcs.append(fname)
		item = tree.get_next_selected(item)
	for _func : String in funcs:
		for meta : Dictionary in data:
			if meta.name == _func:
				if _write_lines(input_script, _get_full_header_virtual(meta)):
					print('[PLUGIN] Created virtual function "', _func , '"')
				else:
					if Engine.is_editor_hint():
						print('[PLUGIN] Error on create virtual function "', _func , '"')
	hide()

func _on_cancel_button() -> void:
	hide()

func _on_tree_multi_selected(_item: TreeItem, _column: int, _selected: bool) -> void:
	_update_gui()
#endregion

func _get_name(script : Script) -> StringName:
	var base_name : StringName = script.get_global_name()
	if base_name.is_empty():
		var path : String = script.resource_name
		if path.is_empty():
			path = script.resource_path
			if !path.is_empty():
				var _name : String = path.get_file()
				_name = _name.trim_suffix("." + _name.get_extension())
				base_name = _name
			else:
				base_name = &"CustomScript"
		else:
			base_name = path
	return base_name

func _clear_funcs(script : Script) -> Dictionary:
	var out : Dictionary = {}
	if Engine.is_editor_hint():
		var rgx : RegEx = RegEx.create_from_string("(?m)^func\\s+(\\w*)\\s*\\(")
		var source : String = script.source_code
		var script_editor: ScriptEditor = EditorInterface.get_script_editor()
		var scripts_editors : Array[ScriptEditorBase] = script_editor.get_open_script_editors()
		var scripts : Array[Script] = script_editor.get_open_scripts()
		var iscript : int = -1

		for x : int in range(scripts.size()):
			if scripts[x] == script:
				iscript = x
				break
		if iscript > -1 and scripts_editors.size() > iscript:
			source = scripts_editors[iscript].get_base_editor().text
		for rs : RegExMatch in rgx.search_all(source):
			if rs.strings.size() > 1:
				var fname : String = rs.strings[1]
				out[fname] = fname
	else:
		for methods : Dictionary in script.get_script_method_list():
			out[methods.name] = methods.name
	return out

func _generate_native(native :  StringName, data : Dictionary, index : int = 0) -> int:
	if native.is_empty() or !ClassDB.class_exists(native):
		return index
	var funcs : Dictionary = {}
	var base : Dictionary = {
		"name" : native
		,"funcs" : funcs
		,"native" : true
	}
	index += 1
	data[index] = base
	for dict: Dictionary in ClassDB.class_get_method_list(native):
		#region conditional
		if dict.flags & METHOD_FLAG_VIRTUAL > 0:
			funcs[dict.name] =_get_header_virtual(dict)
		#endregion

	for x : int in range(0, index, 1):
		var clazz : Dictionary = data[x]["funcs"]
		for k : Variant in funcs.keys():
			if clazz.has(k):
				clazz.erase(k)

	return _generate_native(ClassDB.get_parent_class(native), data, index)

func _generate(script : Script, data : Dictionary, index : int = -1) -> int:
	if script == null:
		return index
	var funcs : Dictionary = {}
	var base : Dictionary = {
		"name" : _get_name(script)
		,"funcs" : funcs
		,"native": false
	}
	index += 1
	data[index] = base
	for dict: Dictionary in script.get_script_method_list():
		var func_name: StringName = dict.name
		#region conditional
		if (func_name.begins_with(CHAR_VIRTUAL_FUNCTION) and !func_name.begins_with(CHAR_PRIVATE_FUNCTION)) or dict.flags & METHOD_FLAG_VIRTUAL > 0:
			funcs[func_name] = _get_header_virtual(dict)
		#endregion

	for x : int in range(0, index, 1):
		var clazz : Dictionary = data[x]["funcs"]
		for k : Variant in funcs.keys():
			if clazz.has(k):
				clazz.erase(k)

	return _generate(script.get_base_script(), data, index)

func _get_header_virtual(dict : Dictionary) -> String:
	var params : String = ""
	var args : Array = dict["args"]
	var separator : String = ""
	var default_args : Array = dict["default_args"]
	var _default_index : int = default_args.size()

	for y : int in range(args.size() - 1, -1, -1):
		var arg : Dictionary = args[y]
		var txt : String = arg["name"]
		if !(arg["class_name"]).is_empty():
			txt += str(" : ", arg["class_name"] as String)
		else:
			var _typeof : int = arg["type"]
			txt += str(" : ", _get_type(_typeof))
		if include_paremeters and _default_index > 0:
			_default_index -= 1
			var def : Variant = default_args[_default_index]
			var _type : int = typeof(def)
			if def == null or _type < 1:
				txt += str(' = null')
			elif _type < 5:
				if def is String:
					txt += str(' = "', def, '"')
				elif def is StringName:
					txt += str(' = &"', def, '"')
				else:
					txt += str(" = ", def)
			else:
				txt += str(" = ",_get_type(typeof(def)), def)
		params = str(txt, separator, params)
		separator = ", "

	var return_dic : Dictionary = dict["return"]
	var return_type : String = "void"
	if !return_dic["class_name"].is_empty():
		return_type = (return_dic["class_name"] as String)
	else:
		var _type : int = return_dic["type"]
		if _type < 1:
			var func_name : String = str(dict["name"]).to_lower()
			if func_name.begins_with("_get") or func_name.ends_with("_get"):
				return_type = "Variant"
			else:
				return_type = "void"
		else:
			return_type = _get_type(return_dic["type"])

	if params.is_empty():
		params = "-"
	return "{0}||{1}||{2}".format([dict["name"], params, return_type]).replace(" ", "") #Replace x more space.

func _get_full_header_virtual(dict : Dictionary) -> String:
	var params : String = ""
	var args : Array = dict["args"]
	var separator : String = ""
	var default_args : Array = dict["default_args"]
	var _default_index : int = default_args.size()

	for y : int in range(args.size() - 1, -1, -1):
		var arg : Dictionary = args[y]
		var txt : String = arg["name"]
		if !(arg["class_name"]).is_empty():
			txt += str(" : ", arg["class_name"] as String)
		else:
			var _typeof : int = arg["type"]
			txt += str(" : ", _get_type(_typeof))
		if _default_index > 0:
			_default_index -= 1
			var def : Variant = default_args[_default_index]
			var _type : int = typeof(def)
			if def == null or _type < 1:
				txt += str(' = null')
			elif _type < 5:
				if def is String:
					txt += str(' = "', def, '"')
				elif def is StringName:
					txt += str(' = &"', def, '"')
				else:
					txt += str(" = ", def)
			else:
				txt += str(" = ",_get_type(typeof(def)), def)
		params = str(txt, separator, params)
		separator = ", "

	var return_dic : Dictionary = dict["return"]
	var return_type : String = "void"
	var return_value : String = "pass"
	if !return_dic["class_name"].is_empty():
		return_type = (return_dic["class_name"] as String)
		return_value = "return null"
	else:
		var _type : int = return_dic["type"]
		if _type < 1:
			var func_name : String = str(dict["name"]).to_lower()
			if func_name.begins_with("_get") or func_name.ends_with("_get"):
				return_type = "Variant"
				return_value = "return null"
			else:
				return_type = "void"
		else:
			return_type = _get_type(return_dic["type"])
			if _type == TYPE_INT:
				return_value = "return 0"
			elif _type == TYPE_BOOL:
				return_value = "return false"
			elif _type == TYPE_FLOAT:
				return_value = "return 0.0"
			elif _type == TYPE_STRING:
				return_value = 'return ""'
			elif _type == TYPE_ARRAY:
				return_value = "return []"
			else:
				return_value = str("return ", return_type,"()")
	return "func {0}({1}) -> {2}:\n\t#TODO: code here :)\n\t{3}".format([dict["name"], params, return_type, return_value])

func _get_type(_typeof : int) -> String:
	var txt : String = ""
	match _typeof:
		TYPE_BOOL : txt = "bool"
		TYPE_INT : txt = "int"
		TYPE_FLOAT: txt = "float"
		TYPE_STRING : txt = "String"
		TYPE_VECTOR2 : txt = "Vector2"
		TYPE_VECTOR2I : txt = "Vector2i"
		TYPE_RECT2 : txt = "Rect2"
		TYPE_RECT2I : txt = "Rect2i"
		TYPE_VECTOR3 : txt = "Vector3"
		TYPE_VECTOR3I : txt = "Vector3i"
		TYPE_TRANSFORM2D : txt = "Tranform2D"
		TYPE_VECTOR4 : txt = "Vector4"
		TYPE_VECTOR4I : txt = "Vector4i"
		TYPE_PLANE : txt = "Plane"
		TYPE_QUATERNION : txt = "Quaternion"
		TYPE_AABB : txt = "AABB"
		TYPE_BASIS : txt = "Basis"
		TYPE_TRANSFORM3D : txt = "Transform3D"
		TYPE_PROJECTION : txt = "Projection"
		TYPE_COLOR : txt = "Color"
		TYPE_STRING_NAME : txt = "StringName"
		TYPE_NODE_PATH : txt = "NodePath"
		TYPE_RID : txt = "RID"
		TYPE_OBJECT : txt = "Object"
		TYPE_CALLABLE : txt = "Callable"
		TYPE_SIGNAL : txt = "Signal"
		TYPE_DICTIONARY : txt = "Dictionary"
		TYPE_ARRAY : txt = "Array"
		TYPE_PACKED_BYTE_ARRAY : txt = "PackedByteArray"
		TYPE_PACKED_INT32_ARRAY : txt = "PackedInt32Array"
		TYPE_PACKED_INT64_ARRAY : txt = "PackedInt64Array"
		TYPE_PACKED_FLOAT32_ARRAY : txt = "PackedFloat32Array"
		TYPE_PACKED_FLOAT64_ARRAY : txt = "PackedFloat64Array"
		TYPE_PACKED_STRING_ARRAY : txt = "PackedStringArray"
		TYPE_PACKED_VECTOR2_ARRAY : txt = "PackedVector2Array"
		TYPE_PACKED_VECTOR3_ARRAY : txt = "PackedVector3Array"
		TYPE_PACKED_COLOR_ARRAY : txt = "PackedColorArray"
		TYPE_PACKED_VECTOR4_ARRAY : txt = "PackedVector4Array"
		_:
			txt = "Variant"
	return txt
