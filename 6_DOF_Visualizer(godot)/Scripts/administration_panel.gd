## Full-screen administration scene for report export and extensible visual settings.
extends Control

signal back_requested
signal pdf_export_requested(path: String)
signal palette_requested(palette_name: String)
signal landing_ellipse_toggled(visible: bool)
signal monte_carlo_toggled(visible: bool)

var database: Node
var _save_dialog: FileDialog
var _settings_tabs: TabContainer
var _status: Label

func configure(data_source: Node) -> void:
	database = data_source

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()

func show_status(message: String) -> void:
	_status.text = message

func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("071019")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	margin.add_child(panel)
	var inner_margin := MarginContainer.new()
	inner_margin.add_theme_constant_override("margin_left", 18)
	inner_margin.add_theme_constant_override("margin_top", 18)
	inner_margin.add_theme_constant_override("margin_right", 18)
	inner_margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(inner_margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	inner_margin.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var title_label := Label.new()
	title_label.text = "MENU"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	var back_button := Button.new()
	back_button.text = "Back to visualizer"
	back_button.pressed.connect(func(): back_requested.emit())
	header.add_child(back_button)
	var description := Label.new()
	description.text = "Export the loaded telemetry graphs or open the extensible visual settings page."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(description)
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 10)
	content.add_child(actions)
	var export_button := Button.new()
	export_button.text = "Export all graphs to PDF..."
	export_button.custom_minimum_size = Vector2(280, 42)
	export_button.pressed.connect(_choose_pdf_destination)
	actions.add_child(export_button)
	var settings_button := Button.new()
	settings_button.text = "Open settings"
	settings_button.custom_minimum_size = Vector2(160, 42)
	settings_button.pressed.connect(func(): _settings_tabs.visible = true)
	actions.add_child(settings_button)
	_status = Label.new()
	_status.add_theme_color_override("font_color", Color("a9c7d9"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_status)
	_settings_tabs = TabContainer.new()
	_settings_tabs.visible = false
	_settings_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_settings_tabs)
	_add_palette_tab()
	_add_trajectory_tab()
	_save_dialog = FileDialog.new()
	_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_save_dialog.filters = PackedStringArray(["*.pdf ; Portable Document Format"])
	_save_dialog.file_selected.connect(_pdf_destination_selected)
	add_child(_save_dialog)

func _add_palette_tab() -> void:
	var page := VBoxContainer.new()
	page.name = "Overlay Palette"
	page.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = "Overlay colors"
	label.add_theme_font_size_override("font_size", 18)
	page.add_child(label)
	var help := Label.new()
	help.text = "Applies a coordinated palette to the trajectory, landing aids, uncertainty visuals, and rocket overlays. New visual categories can be added here as the project grows."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(help)
	var palette := OptionButton.new()
	palette.add_item("Default")
	palette.set_item_metadata(0, "default")
	palette.add_item("High contrast")
	palette.set_item_metadata(1, "high_contrast")
	palette.add_item("Monochrome")
	palette.set_item_metadata(2, "monochrome")
	palette.item_selected.connect(func(selected: int): palette_requested.emit(str(palette.get_item_metadata(selected))))
	page.add_child(palette)
	_settings_tabs.add_child(page)

func _add_trajectory_tab() -> void:
	var page := VBoxContainer.new()
	page.name = "Trajectory Aids"
	page.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = "Landing and uncertainty overlays"
	label.add_theme_font_size_override("font_size", 18)
	page.add_child(label)
	var ellipse := CheckButton.new()
	ellipse.text = "Show landing ellipse"
	ellipse.button_pressed = true
	ellipse.toggled.connect(func(visible: bool): landing_ellipse_toggled.emit(visible))
	page.add_child(ellipse)
	var monte_carlo := CheckButton.new()
	monte_carlo.text = "Show Monte Carlo visuals"
	monte_carlo.button_pressed = true
	monte_carlo.toggled.connect(func(visible: bool): monte_carlo_toggled.emit(visible))
	page.add_child(monte_carlo)
	_settings_tabs.add_child(page)

func _choose_pdf_destination() -> void:
	var filename := "%s_visualizer_report.pdf" % (database.source_label if database != null else "telemetry")
	_save_dialog.current_file = filename.validate_filename()
	_save_dialog.popup_centered_ratio(0.75)

func _pdf_destination_selected(path: String) -> void:
	var destination := path if path.to_lower().ends_with(".pdf") else path + ".pdf"
	pdf_export_requested.emit(destination)

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101b25")
	style.border_color = Color("355166")
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style
