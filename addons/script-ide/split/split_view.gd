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

func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

func script_order_changed() -> void:
	sync_editor_rects()

func is_open() -> bool:
	return split_pane != null

func toggle():
	if (is_open()):
		close()

		tab_bar.set_split(false)

		if (EditorInterface.get_script_editor().get_current_editor() == null):
			tab_bar.set_split_disabled(true)

		return

	open()

	# Nothing could be shown, so the tab has to go back to its unsplit state.
	if (!is_open()):
		tab_bar.set_split(false)

func open():
	var script_editor: ScriptEditor = EditorInterface.get_script_editor()
	var editor_base: ScriptEditorBase = script_editor.get_current_editor()
	# The split view needs a second script that can be shown next to the split one.
	if (editor_base == null || scripts_item_list.item_count < 2):
		return

	main_pane = EditorPane.new()
	split_pane = EditorPane.new()

	main_pane.focused.connect(make_pane_current.bind(main_pane))
	split_pane.focused.connect(make_pane_current.bind(split_pane))

	# A SplitContainer uses the first two visible children, so the tab container
	# of the Engine is only visible while we do not show a script ourselves.
	add_child(main_pane)
	add_child(split_pane)

	if (!split_pane.take(editor_base)):
		free_panes()
		return

	# The editors must be moved back before the scripts themselves are closed.
	script_editor.script_close.connect(on_script_closed)
	# In case the script editor is freed without the signal above.
	editor_base.tree_exiting.connect(request_close, CONNECT_DEFERRED)

	tab_bar.set_split(true)

	# The split script is shown in the split view now, so we show another one next to it.
	show_other_script(editor_base.get_index())

## Moves every editor back into its script editor, e.g. when the plugin is disabled.
func close():
	if (!is_open()):
		return

	disconnect_split_script()

	main_pane.release()
	split_pane.release()
	free_panes()

## Closes the split view by untoggling its tab, e.g. when its script was closed.
func request_close():
	# Everything is already gone when the plugin was disabled in the meantime.
	if (!is_open()):
		return

	# Untoggling the tab triggers 'toggle', which closes the split view.
	tab_bar.close_split()

func free_panes():
	remove_child(main_pane)
	main_pane.queue_free()
	main_pane = null

	remove_child(split_pane)
	split_pane.queue_free()
	split_pane = null

	update_main_visibility()

## Decides which script is shown next to the split view.
## The Engine only shows the current script, but the split script has to stay in the split view.
## Therefore we show the current script ourselves, as long as it is not the split one.
func update_main_view():
	var current: ScriptEditorBase = EditorInterface.get_script_editor().get_current_editor()

	# The split script stays in the split view, also when it is the current one.
	if (current == split_pane.editor_base):
		# Nothing is left to show next to it, so the split view is of no use anymore.
		if (main_pane.is_empty()):
			request_close()

		return

	if (current == main_pane.editor_base):
		return

	main_pane.release()

	# Nothing we could show (e.g. the class reference), which the Engine shows on its own.
	if (current != null):
		main_pane.take(current)

	update_main_visibility()

## The tab container of the Engine is only needed while we do not show a script ourselves.
func update_main_visibility():
	scripts_tab_container.visible = main_pane == null || main_pane.is_empty()

func sync_editor_rects():
	if (!is_open()):
		return

	main_pane.sync_editor_rect()
	split_pane.sync_editor_rect()

## Makes the script of the pane that was clicked into the current one, so that everything
## the Engine does with the current script (menu actions, search, save, ...) applies to it.
func make_pane_current(pane: EditorPane):
	var index: int = pane.editor_base.get_index()
	if (index >= scripts_item_list.item_count || scripts_item_list.is_selected(index)):
		return

	# The same way the Engine selects a script, so that everything is updated properly.
	scripts_item_list.select(index)
	scripts_item_list.item_selected.emit(index)

## Shows the script next to the one that just moved into the split view.
func show_other_script(split_index: int):
	var tab: Button = tab_bar.get_tab(split_index - 1)
	if (tab == null):
		tab = tab_bar.get_tab(split_index + 1)

	if (tab != null):
		tab.button_pressed = true

## The script editor that is shown in the split view (if any).
func get_split_editor_base() -> ScriptEditorBase:
	if (!is_open()):
		return null

	return split_pane.editor_base

## Called when the current script changed.
func on_tab_changed(script_editor_base: ScriptEditorBase):
	if (is_open()):
		update_main_view()
	else:
		tab_bar.set_split_disabled(script_editor_base == null)

func on_script_closed(closed_script: Script):
	if (split_pane.edited_script == closed_script):
		request_close()
	elif (main_pane.edited_script == closed_script):
		main_pane.release()
		update_main_visibility()

func disconnect_split_script():
	EditorInterface.get_script_editor().script_close.disconnect(on_script_closed)

	if (split_pane.editor_base != null):
		split_pane.editor_base.tree_exiting.disconnect(request_close)

## Shows the editor (code, warnings and errors) of one script inside the split view.
class EditorPane extends PanelContainer:
	## Meta of the moved editor, to remember where it belongs inside its script editor.
	const BOX_INDEX: StringName = &"script_ide_editor_box_index"

	## Emitted when the user clicked into the editor of this pane.
	signal focused

	var editor_base: ScriptEditorBase
	var base_editor: CodeEdit
	var edited_script: Script
	var editor_box: Control

	func _init() -> void:
		custom_minimum_size.x = 100
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		visible = false

		item_rect_changed.connect(sync_editor_rect)

	func is_empty() -> bool:
		return editor_box == null

	func take(new_editor_base: ScriptEditorBase) -> bool:
		var new_base_editor: Control = new_editor_base.get_base_editor()
		if !(new_base_editor is CodeEdit):
			return false

		# The exact structure is an implementation detail of the Engine,
		# so we search from the code editor upwards instead of relying on it.
		var box: Node = new_base_editor
		while (box != null && box.get_parent() != new_editor_base):
			box = box.get_parent()

		if (box == null):
			return false

		# Remember the place inside the script editor, so it can be restored properly.
		box.set_meta(BOX_INDEX, box.get_index())
		new_editor_base.remove_child(box)
		add_child(box)

		editor_base = new_editor_base
		base_editor = new_base_editor
		# We always take the editor of the current script.
		edited_script = EditorInterface.get_script_editor().get_current_script()
		editor_box = box
		visible = true

		base_editor.focus_entered.connect(on_focus_entered)
		sync_editor_rect()

		return true

	## Moves the editor back to where it was, or frees it when its script editor is already gone.
	func release() -> void:
		if (editor_box == null):
			return

		base_editor.focus_entered.disconnect(on_focus_entered)

		if (editor_base != null):
			remove_child(editor_box)
			editor_base.add_child(editor_box)
			editor_base.move_child(editor_box, editor_box.get_meta(BOX_INDEX, 0))

			# Since we placed this one ourselves, we have to put it back on its anchors.
			editor_base.set_anchor(SIDE_LEFT, editor_base.anchor_left, true)
		else:
			# The script editor is gone, so its editor is of no use anymore.
			editor_box.queue_free()

		editor_base = null
		base_editor = null
		edited_script = null
		editor_box = null
		visible = false

	## The Engine places the popups of a script editor (context menu, inline color picker) relative to it,
	## but with coordinates of the code editor.
	## Both only match when the script editor sits where we actually show its editor.
	func sync_editor_rect() -> void:
		if (editor_base == null):
			return

		editor_base.global_position = global_position
		editor_base.size = size

	func on_focus_entered() -> void:
		focused.emit()
