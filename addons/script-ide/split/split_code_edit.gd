## The CodeEdit that is used when the editor is split, to show the split script.
@tool
extends CodeEdit

var last_v_scroll: float
var pause_text_changed = false

func _ready() -> void:
	editable = true
	caret_draw_when_editable_disabled = true
	set_v_scroll.call_deferred(last_v_scroll)	

static func new_from(from_code_edit: CodeEdit) -> CodeEdit:
	var new_code_edit: CodeEdit = new()

	if not from_code_edit.tree_exiting.is_connected(new_code_edit.exit_tree.bind(new_code_edit)):
		from_code_edit.tree_exiting.connect(new_code_edit.exit_tree.bind(new_code_edit))

	new_code_edit.text = from_code_edit.text
	new_code_edit.set_caret_line(from_code_edit.get_caret_line())
	if not new_code_edit.text_changed.is_connected(new_code_edit.to_changed.bind(from_code_edit,new_code_edit)):
		new_code_edit.text_changed.connect(new_code_edit.to_changed.bind(from_code_edit,new_code_edit))
	if not from_code_edit.text_changed.is_connected(new_code_edit.from_changed.bind(from_code_edit,new_code_edit)):
		from_code_edit.text_changed.connect(new_code_edit.from_changed.bind(from_code_edit,new_code_edit))

	new_code_edit.syntax_highlighter = from_code_edit.syntax_highlighter
	new_code_edit.highlight_all_occurrences = from_code_edit.highlight_all_occurrences
	new_code_edit.highlight_current_line = from_code_edit.highlight_current_line

	new_code_edit.use_default_word_separators = from_code_edit.use_default_word_separators
	new_code_edit.use_custom_word_separators = from_code_edit.use_custom_word_separators
	new_code_edit.custom_word_separators = from_code_edit.custom_word_separators

	new_code_edit.line_folding = from_code_edit.line_folding
	new_code_edit.line_length_guidelines = from_code_edit.line_length_guidelines

	new_code_edit.gutters_draw_line_numbers = from_code_edit.gutters_draw_line_numbers
	new_code_edit.gutters_draw_fold_gutter = from_code_edit.gutters_draw_fold_gutter

	new_code_edit.minimap_draw = from_code_edit.minimap_draw
	new_code_edit.minimap_width = from_code_edit.minimap_width

	new_code_edit.delimiter_strings = from_code_edit.delimiter_strings
	new_code_edit.delimiter_comments = from_code_edit.delimiter_comments

	new_code_edit.indent_automatic = from_code_edit.indent_automatic
	new_code_edit.indent_size = from_code_edit.indent_size
	new_code_edit.indent_use_spaces = from_code_edit.indent_use_spaces
	new_code_edit.indent_automatic_prefixes = from_code_edit.indent_automatic_prefixes

	new_code_edit.draw_control_chars = from_code_edit.draw_control_chars
	new_code_edit.draw_tabs = from_code_edit.draw_tabs
	new_code_edit.draw_spaces = from_code_edit.draw_spaces

	new_code_edit.last_v_scroll = from_code_edit.scroll_vertical

	return new_code_edit

func from_changed(from:CodeEdit,to:CodeEdit) -> void:
	if not pause_text_changed:
		pause_text_changed = true
		var pos = to.get_caret_line()
		var scroll = to.scroll_vertical
		to.text = from.text
		to.set_caret_line(pos)
		to.scroll_vertical = scroll
		pause_text_changed = false

func to_changed(from:CodeEdit,to:CodeEdit) -> void:
	if not pause_text_changed:
		pause_text_changed = true
		var pos = from.get_caret_line()
		var scroll = from.scroll_vertical
		from.text = to.text
		from.set_caret_line(pos)
		from.scroll_vertical = scroll
		pause_text_changed = false

func exit_tree(to:CodeEdit) -> void:
	if to:
		to.get_parent().remove_child(to)
		to.queue_free()
