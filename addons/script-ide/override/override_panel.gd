@tool
extends PopupPanel

const FUNC_META: StringName = &"func"

@onready var filter_txt: LineEdit = %FilterTxt
@onready var class_func_tree: Tree = %ClassFuncTree
@onready var ok_btn: Button = %OkBtn
@onready var cancel_btn: Button = %CancelBtn

var plugin: EditorPlugin

var selections: int = 0
var class_to_functions: Dictionary[StringName, PackedStringArray]

func _ready() -> void:
	filter_txt.text_changed.connect(update_tree_filter.unbind(1))

	class_func_tree.multi_selected.connect(func(item: TreeItem, col: int, selected: bool): count_selection(selected))
	class_func_tree.item_activated.connect(generate_functions)

	cancel_btn.pressed.connect(hide)
	ok_btn.pressed.connect(generate_functions)

	about_to_popup.connect(on_show)

func update_tree_filter():
	update_tree()

func count_selection(selected: bool):
	if (selected):
		selections += 1
	else:
		selections -= 1

	ok_btn.disabled = selections == 0

func on_show():
	class_func_tree.clear()
	selections = 0
	ok_btn.disabled = true
	filter_txt.text = &""

	var script: Script = EditorInterface.get_script_editor().get_current_script()
	class_to_functions = collect_all_class_functions(script) # [StringName, PackedStringArray]
	if (class_to_functions.is_empty()):
		return

	update_tree()
	filter_txt.grab_focus()

func update_tree():
	class_func_tree.clear()

	var text: String = filter_txt.text

	var root: TreeItem = class_func_tree.create_item()
	for class_name_str: StringName in class_to_functions.keys():
		var class_item: TreeItem = root.create_child(0)
		class_item.set_selectable(0, false)
		class_item.set_text(0, class_name_str)

		for function: String in class_to_functions.get(class_name_str):
			if (text.is_empty() || text.is_subsequence_ofn(function)):
				var func_item: TreeItem = class_item.create_child()
				func_item.set_text(0, function)
				if (plugin.keywords.has(function.get_slice("(", 0))):
					func_item.set_icon(0, plugin.engine_func_icon)
				else:
					func_item.set_icon(0, plugin.func_icon)
				func_item.set_meta(FUNC_META, function)

func collect_all_class_functions(script: Script) -> Dictionary[StringName, PackedStringArray]:
	var existing_funcs: Dictionary[String, int] = {} # Used as Set.
	for func_str: String in plugin.outline_cache.engine_funcs:
		existing_funcs[func_str] = 0
	for func_str: String in plugin.outline_cache.funcs:
		existing_funcs[func_str] = 0

	var class_to_functions: Dictionary[StringName, PackedStringArray] = collect_super_class_functions(script.get_base_script(), existing_funcs)
	var native_class_to_functions: Dictionary[StringName, PackedStringArray] = collect_native_class_functions(script.get_instance_base_type(), existing_funcs)

	return native_class_to_functions.merged(class_to_functions)

func collect_super_class_functions(base_script: Script, existing_funcs: Dictionary[String, int]) -> Dictionary[StringName, PackedStringArray]:
	var super_classes: Array[Script] = []
	while (base_script != null):
		super_classes.insert(0, base_script)

		base_script = base_script.get_base_script()

	var class_to_functions: Dictionary[StringName, PackedStringArray] = {}
	for super_class: Script in super_classes:
		var functions: PackedStringArray = collect_script_functions(super_class, existing_funcs)
		if (functions.is_empty()):
			continue

		class_to_functions[super_class.get_global_name()] = functions

	return class_to_functions

func collect_native_class_functions(native_class: StringName, existing_funcs: Dictionary[String, int]) -> Dictionary[StringName, PackedStringArray]:
	var super_native_classes: Array[StringName] = []
	while (native_class != &""):
		super_native_classes.insert(0, native_class)

		native_class = ClassDB.get_parent_class(native_class)

	var class_to_functions: Dictionary[StringName, PackedStringArray] = {}
	for super_native_class: StringName in super_native_classes:
		var functions: PackedStringArray = collect_class_functions(super_native_class, existing_funcs)
		if (functions.is_empty()):
			continue

		class_to_functions[super_native_class] = functions

	return class_to_functions

func collect_class_functions(native_class: StringName, existing_funcs: Dictionary[String, int]):
	var functions: PackedStringArray = []

	for method: Dictionary in ClassDB.class_get_method_list(native_class, true):
		if (method[&"flags"] & METHOD_FLAG_VIRTUAL <= 0):
			continue

		var func_name: String = method[&"name"]
		if (existing_funcs.has(func_name)):
			continue

		func_name = create_function_signature(method)
		functions.append(func_name)

	return functions

func collect_script_functions(super_class: Script, existing_funcs: Dictionary[String, int]) -> PackedStringArray:
	var functions: PackedStringArray = []

	for method: Dictionary in super_class.get_script_method_list():
		var func_name: String = method[&"name"]
		if (existing_funcs.has(func_name)):
			continue

		existing_funcs[func_name] = 0

		func_name = create_function_signature(method)
		functions.append(func_name)

	return functions

func create_function_signature(method: Dictionary) -> String:
	var func_name: String = method[&"name"]
	func_name += "("

	var arg_str: String = ""
	for arg: Dictionary in method[&"args"]:
		if (arg_str != ""):
			arg_str += ", "

		arg_str += arg[&"name"]
		var type: String = get_type(arg)
		if (type != ""):
			arg_str += ": " + type

	func_name += arg_str + ")"

	var return_str: String = get_type(method[&"return"])
	if (return_str != ""):
		func_name += " -> " + return_str

	return func_name

func generate_functions():
	var selected_item: TreeItem = class_func_tree.get_next_selected(null)
	if (selected_item == null):
		return

	var selected_functions: PackedStringArray = []

	while (selected_item != null):
		var function: String = selected_item.get_meta(FUNC_META)
		selected_functions.append(function)

		selected_item = class_func_tree.get_next_selected(selected_item)

	var generated_text: String = ""
	for function: String in selected_functions:
		generated_text += "\nfunc " + function + ":\n\tpass\n"

	var editor: CodeEdit = EditorInterface.get_script_editor().get_current_editor().get_base_editor()
	editor.text += generated_text

	plugin.goto_line(editor.get_line_count() - 1)

	hide()

func get_type(dict: Dictionary) -> String:
	var type: String = dict[&"class_name"]
	if (type != &""):
		return type

	var type_hint: int = dict[&"type"]
	if (type_hint == 0):
		return &""

	type = type_string(type_hint)
	# Dictionary
	if (type_hint == 27):
		var generic: String = dict[&"hint_string"]
		if (generic != &""):
			var generic_parts: PackedStringArray = generic.split(";")
			if (generic_parts.size() == 2):
				return type + "[" + generic_parts[0] + ", " + generic_parts[1] + "]"

	# Array
	if (type_hint == 28):
		var generic: String = dict[&"hint_string"]
		if (generic != &""):
			return type + "[" + generic + "]"

	return type
