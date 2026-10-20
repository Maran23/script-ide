## The split view of Script-IDE, which shows two scripts next to each other.
##
## The editor of a script is moved out of its script editor instead of being copied, so that
## everything (code completion, saving, errors, breakpoints, ...) works exactly like in the
## script editor of the Engine, since it is the very same editor.
@tool
extends HSplitContainer

const MultilineTabBar := preload("uid://l1rdargfn67o")

# Existing Engine components, set from the plugin.
var tab_bar: MultilineTabBar
var scripts_tab_container: TabContainer
var scripts_item_list: ItemList

## Shows the main script.
var main_pane: EditorPane
## Shows the split script.
var split_pane: EditorPane

## Whether the script of the main view was closed, so that another script needs to be shown there.
var is_main_closed: bool

func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

func is_open() -> bool:
	return split_pane != null

func toggle() -> void:
	if (is_open()):
		close()
		return

	open()

	# The split tab was pressed, but nothing could be split.
	if (!is_open()):
		tab_bar.set_split(false)

func open() -> void:
	if (!can_open()):
		return

	var script_editor: ScriptEditor = EditorInterface.get_script_editor()
	var editor_base: ScriptEditorBase = script_editor.get_current_editor()

	main_pane = create_pane()
	split_pane = create_pane()
	# The main view takes 60%, the split view 40% (initially).
	split_pane.size_flags_stretch_ratio = 0.4 / 0.6

	if (!split_pane.take(editor_base)):
		free_panes()
		return

	script_editor.script_close.connect(on_script_closed)

	tab_bar.set_split(true)

	select_script(get_next_to_split_index())

	# Starts at the default position from the stretch ratios, instead of the one from the last split.
	split_offset = 0

## Moves every editor back into its script editor.
func close() -> void:
	if (!is_open()):
		return

	EditorInterface.get_script_editor().script_close.disconnect(on_script_closed)

	main_pane.release()
	split_pane.release()
	free_panes()

	tab_bar.set_split(false)
	update_split_disabled()

func create_pane() -> EditorPane:
	var pane: EditorPane = EditorPane.new()
	pane.focused.connect(make_pane_current.bind(pane))
	pane.editor_exiting.connect(close_pane.bind(pane))

	add_child(pane)
	return pane

func free_panes() -> void:
	main_pane.queue_free()
	main_pane = null

	split_pane.queue_free()
	split_pane = null

	update_main_visibility()

## Decides which script is shown next to the split view.
## The Engine only shows the current script, but the split script has to stay in the split view.
func update_main_view() -> void:
	var current: ScriptEditorBase = EditorInterface.get_script_editor().get_current_editor()

	if (current == split_pane.editor_base):
		# A closed script is replaced later, as the Engine selects the next script after this.
		if (main_pane.is_empty() && !is_main_closed && !main_pane.is_closed()):
			close()

		return

	if (current == main_pane.editor_base):
		return

	main_pane.release()

	if (current != null):
		main_pane.take(current)

	update_main_visibility()

func update_main_visibility() -> void:
	scripts_tab_container.visible = main_pane == null || main_pane.is_empty()

## Makes the script of the pane that was clicked into the current one, so that everything
## the Engine does with the current script (menu actions, search, save, ...) applies to it.
func make_pane_current(pane: EditorPane) -> void:
	select_script(pane.editor_base.get_index())

## The script that is shown next to the split script, when there is no other choice.
func get_next_to_split_index() -> int:
	var index: int = split_pane.editor_base.get_index() - 1
	if (index < 0):
		index = 1

	return index

## Selects the script the same way the script list does it.
func select_script(index: int) -> void:
	# The script list is updated after the Engine focuses the current editor, so it can not be used here.
	if (scripts_tab_container.current_tab == index):
		return

	# The indices of the script list only match the Engine when nothing is filtered.
	tab_bar.update_script_text_filter()

	scripts_item_list.select(index)
	scripts_item_list.item_selected.emit(index)

## The script editor that is shown in the split view (if any).
func get_split_editor_base() -> ScriptEditorBase:
	if (!is_open()):
		return null

	return split_pane.editor_base

## Called when the current script changed.
func on_tab_changed() -> void:
	if (is_open()):
		update_main_view()
	else:
		update_split_disabled()

## Called when scripts were opened, closed or moved.
func script_order_changed() -> void:
	if (!is_open()):
		update_split_disabled()

## Splitting needs a script editor to move and another script to show next to it.
func can_open() -> bool:
	return EditorInterface.get_script_editor().get_current_editor() != null && scripts_tab_container.get_tab_count() > 1

func update_split_disabled() -> void:
	tab_bar.set_split_disabled(!can_open())

## Called before the Engine frees the script editor, so its editor can still be moved back.
func on_script_closed(closed_script: Script) -> void:
	if (split_pane.edited_script == closed_script):
		close_pane(split_pane)
	elif (main_pane.edited_script == closed_script):
		close_pane(main_pane)

func close_pane(pane: EditorPane) -> void:
	pane.release()
	update_main_visibility()

	if (split_pane.is_empty()):
		close()
		return

	if (pane == main_pane):
		is_main_closed = true
		replace_main_script.call_deferred()

## The Engine selects the previous script after closing one, which can be the split script.
## The split view stays then and shows the script next to it.
func replace_main_script() -> void:
	is_main_closed = false

	if (!is_open() || !main_pane.is_empty()):
		return

	# Another kind of editor (e.g. a help page) is shown instead.
	if (EditorInterface.get_script_editor().get_current_editor() != split_pane.editor_base):
		return

	# Without a script next to it, there is nothing to split anymore.
	if (scripts_tab_container.get_tab_count() < 2):
		close()
		return

	select_script(get_next_to_split_index())

## Shows the editor (code, warnings and errors) of one script inside the split view.
class EditorPane extends PanelContainer:
	## Emitted when the user clicked into the editor of this pane.
	signal focused
	## Emitted when the Engine freed the script editor while its editor is still shown here.
	signal editor_exiting

	## Also null when the Engine freed it, while its editor is still shown here.
	var editor_base: ScriptEditorBase
	var edited_script: Script
	var editor_box: Control

	# Where the editor and its script editor were, to restore both properly.
	var box_index: int
	var editor_base_position: Vector2

	func _init() -> void:
		custom_minimum_size.x = 100 * EditorInterface.get_editor_scale()
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		visible = false

		set_process_input(false)

	## The Engine places popups (context menu, inline color picker) relative to the script editor,
	## but with coordinates of the code editor, so both need to be at the same place.
	func _input(event: InputEvent) -> void:
		if (event.is_pressed() && editor_base != null):
			editor_base.global_position = editor_base.get_base_editor().global_position

	func is_empty() -> bool:
		return editor_base == null

	## Whether the Engine freed the script editor while its editor is still shown here.
	func is_closed() -> bool:
		return editor_box != null && editor_base == null

	func take(new_editor_base: ScriptEditorBase) -> bool:
		var base_editor: Control = new_editor_base.get_base_editor()
		if !(base_editor is CodeEdit):
			return false

		# The exact structure is an implementation detail of the Engine,
		# so we search from the code editor upwards instead of relying on it.
		var box: Node = base_editor
		while (box != null && box.get_parent() != new_editor_base):
			box = box.get_parent()

		if (box == null):
			return false

		editor_base = new_editor_base
		# We always take the editor of the current script.
		edited_script = EditorInterface.get_script_editor().get_current_script()
		editor_box = box
		box_index = box.get_index()
		editor_base_position = editor_base.position

		editor_base.remove_child(editor_box)
		add_child(editor_box)

		base_editor.focus_entered.connect(on_focus_entered)
		# The Engine does not tell us when it frees the editor of a file that is not a script.
		editor_base.tree_exiting.connect(on_editor_exiting, CONNECT_DEFERRED)

		visible = true
		set_process_input(true)

		return true

	## Moves the editor back to where it was, or frees it when its script editor is already gone.
	func release() -> void:
		if (editor_box == null):
			return

		if (editor_base != null):
			editor_base.get_base_editor().focus_entered.disconnect(on_focus_entered)
			editor_base.tree_exiting.disconnect(on_editor_exiting)

			remove_child(editor_box)
			editor_base.add_child(editor_box)
			editor_base.move_child(editor_box, box_index)
			editor_base.position = editor_base_position
		else:
			editor_box.queue_free()

		editor_base = null
		edited_script = null
		editor_box = null
		visible = false

		set_process_input(false)

	func on_focus_entered() -> void:
		focused.emit()

	## Also called when the script editor was just moved, e.g. when the script editor is made floating.
	func on_editor_exiting() -> void:
		if (is_closed()):
			editor_exiting.emit()
