@tool
extends PopupPanel

const FUNC_META: StringName = &"func"

@onready var class_func_tree: Tree = %ClassFuncTree
@onready var ok_btn: Button = %OkBtn
@onready var cancel_btn: Button = %CancelBtn

var plugin: EditorPlugin

var selections: int = 0

func _ready() -> void:
	class_func_tree.multi_selected.connect(func(item, col, selected): count_selection(selected))
	class_func_tree.item_activated.connect(generate_functions)

	cancel_btn.pressed.connect(hide)
	ok_btn.pressed.connect(generate_functions)

	about_to_popup.connect(on_show)

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

	var script: Script = EditorInterface.get_script_editor().get_current_script()
	var base_script: Script = script.get_base_script()
	if (base_script == null):
		return

	var class_to_functions: Dictionary = collect_all_base_functions(base_script) # [StringName, PackedStringArray]
	if (class_to_functions.is_empty()):
		return

	var root: TreeItem = class_func_tree.create_item()
	for class_name_str: StringName in class_to_functions.keys():
		var class_item: TreeItem = root.create_child(0)
		class_item.set_selectable(0, false)
		class_item.set_text(0, class_name_str)

		for function: String in class_to_functions.get(class_name_str):
			var func_item: TreeItem = class_item.create_child()
			func_item.set_text(0, function)
			if (plugin.keywords.has(function.get_slice("(", 0))):
				func_item.set_icon(0, plugin.engine_func_icon)
			else:
				func_item.set_icon(0, plugin.func_icon)
			func_item.set_meta(FUNC_META, function)

	class_func_tree.grab_focus()

func collect_all_base_functions(script: Script)-> Dictionary: # [StringName, Array[Function]]
	var super_classes: Array[Script] = []

	var base_script: Script = script
	while (base_script != null):
		super_classes.insert(0, base_script)

		base_script = base_script.get_base_script()

	var existing_funcs: Dictionary = {} # [String, int] # Used as Set.
	for func_str: String in plugin.outline_cache.engine_funcs:
		existing_funcs[func_str] = 0
	for func_str: String in plugin.outline_cache.funcs:
		existing_funcs[func_str] = 0

	var class_to_functions: Dictionary = {} # [StringName, PackedStringArray]
	for super_class: Script in super_classes:
		var functions: PackedStringArray = collect_base_functions(super_class, existing_funcs)
		class_to_functions[super_class.get_global_name()] = functions

	return class_to_functions

func collect_base_functions(super_class: Script, existing_funcs: Dictionary) -> PackedStringArray:
	var functions: PackedStringArray = []

	for dict: Dictionary in super_class.get_script_method_list():
		var func_name: String = dict[&"name"]
		if (existing_funcs.has(func_name)):
			continue

		existing_funcs[func_name] = 0

		func_name += "("

		var arg_str: String = ""
		for arg: Dictionary in dict[&"args"]:
			if (arg_str != ""):
				arg_str += ", "

			arg_str += arg[&"name"]
			var type: String = get_type(arg)
			if (type != ""):
				arg_str += ": " + type

		func_name += arg_str + ")"

		var return_str: String = get_type(dict[&"return"])
		if (return_str != ""):
			func_name += " -> " + return_str

		functions.append(func_name)

	return functions

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
	if (type != ""):
		return type

	var type_hint: int = dict[&"type"]
	if (type_hint == 0):
		return ""

	type = type_string(type_hint)
	if (type_hint == 27):
		# Dictionary
		var generic: String = dict[&"hint_string"]
		if (generic != &""):
			var generic_parts: PackedStringArray = generic.split(";")
			if (generic_parts.size() == 2):
				return type + "[" + generic_parts[0] + ", " + generic_parts[1] + "]"

	if (type_hint == 28):
		# Array
		var generic: String = dict[&"hint_string"]
		if (generic != &""):
			return type + "[" + generic + "]"

	return type
