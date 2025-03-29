extends EditorContextMenuPlugin
const SCENE : PackedScene = preload("res://addons/script-ide/popup/virtuals_popup.tscn")

var ICON : Texture = null:
	get:
		if ICON == null:
			var image : Image = ResourceLoader.load("res://addons/script-ide/popup/icon/func_virtual.svg")
			if image:
				ICON = ImageTexture.create_from_image(image)
		return ICON

func callback(input : Object) -> void:
	var input_script : Script = null

	if input is Script:
		input_script = input
	elif input is CodeEdit:
		var script_editor: ScriptEditor = EditorInterface.get_script_editor()
		var scripts_editors : Array[ScriptEditorBase] = script_editor.get_open_script_editors()
		var scripts : Array[Script] = script_editor.get_open_scripts()
		var iscript : int = -1

		for x : int in range(scripts_editors.size()):
			if scripts_editors[x].get_base_editor() == input:
				iscript = x
				pass
		if iscript > -1 and iscript < scripts.size():
			input_script = scripts[iscript]

	if null == input_script:
		push_error("[PLUGIN] Error, can`t get current script - not valid!")
		return

	var root : Node = Engine.get_main_loop().root
	var virtual_popup : Popup = root.get_node_or_null("_VPOPUP_")
	if virtual_popup == null:
		virtual_popup = SCENE.instantiate()
		virtual_popup.set(&"name", &"_VPOPUP_")
		root.add_child(virtual_popup)
	virtual_popup.make_tree(input_script)
	virtual_popup.popup_centered()

func _popup_menu(paths : PackedStringArray) -> void:
	add_context_menu_item("File Custom options", callback, ICON)
