@tool
extends PanelContainer

signal synced()
signal pre_popup_pressed()

const CustomTabBar := preload("custom_tab_bar.gd")

var custom_tab_bar: CustomTabBar = CustomTabBar.new()
var popup_button: Button = Button.new()
var popup_panel: PopupPanel

var scripts_tab_container: TabContainer
var scripts_item_list: ItemList
var active_script_editor: ScriptEditorBase

func _ready() -> void:
	add_theme_stylebox_override(&"panel",  EditorInterface.get_editor_theme().get_stylebox(&"tabbar_background", &"TabContainer"))

	var hsplit := HSplitContainer.new()
	hsplit.add_theme_constant_override(&"separation", 0)
	hsplit.dragger_visibility = SplitContainer.DRAGGER_HIDDEN_COLLAPSED
	add_child(hsplit)

	custom_tab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hsplit.add_child(custom_tab_bar)

	var texture_rect: TextureRect = TextureRect.new()
	texture_rect.texture =  EditorInterface.get_editor_theme().get_icon(&"menu", &"TabContainer")
	texture_rect.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	popup_button.add_child(texture_rect)

	popup_button.focus_mode = Control.FOCUS_NONE
	popup_button.custom_minimum_size = Vector2(16, 24) * EditorInterface.get_editor_scale()
	popup_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	popup_button.pressed.connect(_on_popup_button_pressed)
	hsplit.add_child(popup_button)

	scripts_tab_container.tab_changed.connect(_on_script_tab_changed)
	scripts_tab_container.child_order_changed.connect(_on_script_tab_rearranged, CONNECT_DEFERRED | CONNECT_ONE_SHOT)
	scripts_tab_container.child_entered_tree.connect(_queue_sync.unbind(1))
	scripts_tab_container.child_exiting_tree.connect(_queue_sync.unbind(1))
	custom_tab_bar.tab_changed.connect(_on_tab_changed)
	custom_tab_bar.tab_close_pressed.connect(_on_tab_close_pressed)
	custom_tab_bar.tab_rearranged.connect(_on_tab_rearranged)

	EditorInterface.get_resource_filesystem().filesystem_changed.connect(sync_tab_names)
	EditorInterface.get_script_editor().editor_script_changed.connect(_on_editor_script_changed)
	if active_script_editor:
		active_script_editor.edited_script_changed.connect(_on_edited_script_changed)

	sync_tabs()


func sync_tab_names() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	for i in scripts_tab_container.get_tab_count():
		custom_tab_bar.set_tab_title(i, scripts_tab_container.get_tab_title(i))


func _on_editor_script_changed(script: Script) -> void:
	if active_script_editor:
		active_script_editor.edited_script_changed.disconnect(_on_edited_script_changed)
	active_script_editor = EditorInterface.get_script_editor().get_current_editor()
	if active_script_editor:
		active_script_editor.edited_script_changed.connect(_on_edited_script_changed)


func _on_edited_script_changed() -> void:
	var idx := scripts_tab_container.current_tab
	custom_tab_bar.set_tab_title(idx, scripts_tab_container.get_tab_title(idx))


var is_syncing: bool = false
func _queue_sync() -> void:
	if is_syncing:
		return
	is_syncing = true
	sync_tabs.call_deferred()


func sync_tabs() -> void:
	custom_tab_bar.clear_tabs()

	for i in scripts_item_list.item_count:
		var tab := custom_tab_bar.add_tab(scripts_item_list.get_item_text(i), scripts_item_list.get_item_icon(i))
		tab.icon_color = scripts_item_list.get_item_icon_modulate(i)
		tab.tooltip_text = scripts_item_list.get_item_tooltip(i)
		custom_tab_bar.tabs[tab.get_tab_path()] = tab

	custom_tab_bar.current_tab = scripts_tab_container.current_tab

	is_syncing = false

	synced.emit()


func sync_current_tab(idx: int, custom: bool) -> void:
	if  custom:
		scripts_tab_container.current_tab = idx
	custom_tab_bar.current_tab = idx


func set_popup(popup: PopupPanel) -> void:
	popup_panel = popup

func _on_script_tab_changed(idx: int) -> void:
	sync_current_tab(idx, false)


func _on_script_tab_rearranged() -> void:
	custom_tab_bar.move_tab(custom_tab_bar.current_tab, scripts_tab_container.current_tab, false)
	sync_current_tab(scripts_tab_container.current_tab, true)
	scripts_tab_container.child_order_changed.connect(_on_script_tab_rearranged, CONNECT_DEFERRED | CONNECT_ONE_SHOT)


func _on_tab_changed(idx: int) -> void:
	sync_current_tab(idx, true)


func _on_tab_close_pressed(idx: int) -> void:
	scripts_tab_container.remove_child(scripts_tab_container.get_child(idx))


func _on_tab_rearranged(from: int, to: int) -> void:
	scripts_tab_container.move_child(scripts_tab_container.get_child(from), to)
	sync_current_tab(to, true)


func _on_popup_button_pressed() -> void:
	pre_popup_pressed.emit()
	popup_panel.position = popup_button.get_screen_position() - Vector2(popup_panel.size.x, 0)
	popup_panel.popup()
