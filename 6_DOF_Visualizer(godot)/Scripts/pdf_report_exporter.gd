## Self-contained PDF report writer for telemetry graph images.
extends RefCounted

const TelemetrySchema = preload("res://Scripts/telemetry_schema.gd")
const PAGE_WIDTH := 792.0
const PAGE_HEIGHT := 612.0
const PAGE_MARGIN := 36.0
const GRAPH_WIDTH := 1200
const GRAPH_HEIGHT := 620
const GRAPH_PLOT := Rect2i(130, 70, 1015, 450)
const GRAPH_TICK_COUNT := 8

static func export_report(path: String, data_source: Node) -> bool:
	if data_source == null or data_source.rows.is_empty():
		return false
	var pages: Array[Dictionary] = []
	for column in range(1, TelemetrySchema.COLUMN_COUNT):
		pages.append(_render_graph_page(data_source.rows, column))
	return _write_pdf(path, pages)

static func _render_graph_page(rows: Array[PackedFloat64Array], column: int) -> Dictionary:
	var image := Image.create(GRAPH_WIDTH, GRAPH_HEIGHT, false, Image.FORMAT_RGB8)
	image.fill(Color("101b25"))
	_draw_rect(image, GRAPH_PLOT, Color("355166"))
	var low := INF
	var high := -INF
	for row in rows:
		low = minf(low, row[column])
		high = maxf(high, row[column])
	var span := maxf(high - low, 0.0001)
	for division in range(1, GRAPH_TICK_COUNT):
		var y := GRAPH_PLOT.position.y + roundi(float(GRAPH_PLOT.size.y) * float(division) / GRAPH_TICK_COUNT)
		_draw_line(image, Vector2i(GRAPH_PLOT.position.x, y), Vector2i(GRAPH_PLOT.end.x, y), Color("223848"))
		var x := GRAPH_PLOT.position.x + roundi(float(GRAPH_PLOT.size.x) * float(division) / GRAPH_TICK_COUNT)
		_draw_line(image, Vector2i(x, GRAPH_PLOT.position.y), Vector2i(x, GRAPH_PLOT.end.y), Color("223848"))
	var previous := Vector2i.ZERO
	var has_previous := false
	var stride := maxi(1, ceili(float(rows.size()) / float(GRAPH_PLOT.size.x)))
	for index in range(0, rows.size(), stride):
		var x := GRAPH_PLOT.position.x + roundi(float(GRAPH_PLOT.size.x) * float(index) / float(rows.size() - 1))
		var y := GRAPH_PLOT.end.y - roundi(float(GRAPH_PLOT.size.y) * float(rows[index][column] - low) / span)
		var point := Vector2i(x, y)
		if has_previous:
			_draw_line(image, previous, point, Color("58d6ff"))
		previous = point
		has_previous = true
	return {
		"title": TelemetrySchema.display_name_with_unit(column),
		"image": image,
		"graph": {
			"low": low,
			"high": high,
			"unit": TelemetrySchema.unit(column),
			"start_time": rows[0][TelemetrySchema.Column.TIME],
			"end_time": rows[-1][TelemetrySchema.Column.TIME]
		}
	}

static func _draw_rect(image: Image, rect: Rect2i, color: Color) -> void:
	_draw_line(image, rect.position, Vector2i(rect.end.x, rect.position.y), color)
	_draw_line(image, rect.position, Vector2i(rect.position.x, rect.end.y), color)
	_draw_line(image, Vector2i(rect.position.x, rect.end.y), rect.end, color)
	_draw_line(image, Vector2i(rect.end.x, rect.position.y), rect.end, color)

static func _draw_line(image: Image, start: Vector2i, finish: Vector2i, color: Color) -> void:
	var x: int = start.x
	var y: int = start.y
	var dx: int = absi(finish.x - start.x)
	var dy: int = -absi(finish.y - start.y)
	var step_x: int = 1 if start.x < finish.x else -1
	var step_y: int = 1 if start.y < finish.y else -1
	var error: int = dx + dy
	while true:
		if x >= 0 and x < image.get_width() and y >= 0 and y < image.get_height():
			image.set_pixel(x, y, color)
		if x == finish.x and y == finish.y:
			break
		var doubled_error: int = error * 2
		if doubled_error >= dy:
			error += dy
			x += step_x
		if doubled_error <= dx:
			error += dx
			y += step_y

static func _write_pdf(path: String, pages: Array[Dictionary]) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	var output := PackedByteArray()
	_append_text(output, "%PDF-1.4\n%\u00e2\u00e3\u00cf\u00d3\n")
	var object_count := 3 + pages.size() * 3
	var offsets := PackedInt64Array()
	offsets.resize(object_count + 1)
	_write_object(output, offsets, 1, _text_bytes("<< /Type /Catalog /Pages 2 0 R >>"))
	var page_references := ""
	for page_index in pages.size():
		page_references += "%d 0 R " % (4 + page_index * 3)
	_write_object(output, offsets, 2, _text_bytes("<< /Type /Pages /Count %d /Kids [ %s] >>" % [pages.size(), page_references]))
	_write_object(output, offsets, 3, _text_bytes("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"))
	for page_index in pages.size():
		var page_object := 4 + page_index * 3
		var content_object := page_object + 1
		var image_object := page_object + 2
		var image: Image = pages[page_index]["image"]
		var image_bytes := image.get_data()
		var content := _page_content(pages[page_index], image.get_width(), image.get_height())
		var page_body := "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %.0f %.0f] /Resources << /Font << /F1 3 0 R >> /XObject << /Im0 %d 0 R >> >> /Contents %d 0 R >>" % [PAGE_WIDTH, PAGE_HEIGHT, image_object, content_object]
		_write_object(output, offsets, page_object, _text_bytes(page_body))
		_write_stream_object(output, offsets, content_object, _text_bytes(content), "")
		_write_stream_object(output, offsets, image_object, image_bytes, "/Type /XObject /Subtype /Image /Width %d /Height %d /ColorSpace /DeviceRGB /BitsPerComponent 8" % [image.get_width(), image.get_height()])
	var xref_offset := output.size()
	_append_text(output, "xref\n0 %d\n0000000000 65535 f \n" % (object_count + 1))
	for object_id in range(1, object_count + 1):
		_append_text(output, "%010d 00000 n \n" % offsets[object_id])
	_append_text(output, "trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%EOF\n" % [object_count + 1, xref_offset])
	file.store_buffer(output)
	file.close()
	return true

static func _page_content(page: Dictionary, image_width: int, image_height: int) -> String:
	var scale := minf((PAGE_WIDTH - PAGE_MARGIN * 2.0) / image_width, (PAGE_HEIGHT - 110.0) / image_height)
	var width := float(image_width) * scale
	var height := float(image_height) * scale
	var x := (PAGE_WIDTH - width) * 0.5
	var y := 42.0
	var content := "q\n%.3f 0 0 %.3f %.3f %.3f cm\n/Im0 Do\nQ\n" % [width, height, x, y]
	content += _graph_label_content(page, x, y, scale, image_height)
	return content

static func _graph_label_content(page: Dictionary, image_x: float, image_y: float, scale: float, image_height: int) -> String:
	var graph: Dictionary = page["graph"]
	var low: float = graph["low"]
	var high: float = graph["high"]
	var value_unit: String = graph["unit"]
	var start_time: float = graph["start_time"]
	var end_time: float = graph["end_time"]
	var content := _pdf_label(str(page["title"]), _image_point(image_x, image_y, scale, image_height, Vector2(GRAPH_PLOT.position.x, 38.0)), 13.0, Color("e9f7ff"))
	for division in range(GRAPH_TICK_COUNT + 1):
		var ratio := float(division) / GRAPH_TICK_COUNT
		var value := lerpf(high, low, ratio)
		var y_position := GRAPH_PLOT.position.y + GRAPH_PLOT.size.y * ratio + 3.0
		var label := _format_value(value)
		if not value_unit.is_empty():
			label += " " + value_unit
		if division == 0:
			label = "max " + label
		elif division == GRAPH_TICK_COUNT:
			label = "min " + label
		content += _pdf_label(label, _image_point(image_x, image_y, scale, image_height, Vector2(14.0, y_position)), 6.6, Color("9eb2c1"))
		var time := lerpf(start_time, end_time, ratio)
		var time_label := "%.2f s" % time
		var x_position := GRAPH_PLOT.position.x + GRAPH_PLOT.size.x * ratio - float(time_label.length()) * 2.4
		content += _pdf_label(time_label, _image_point(image_x, image_y, scale, image_height, Vector2(x_position, GRAPH_PLOT.end.y + 32.0)), 6.6, Color("9eb2c1"))
	content += _pdf_label("time (s)", _image_point(image_x, image_y, scale, image_height, Vector2(GRAPH_PLOT.get_center().x - 17.0, GRAPH_PLOT.end.y + 56.0)), 7.5, Color("a9c7d9"))
	return content

static func _image_point(image_x: float, image_y: float, scale: float, image_height: int, image_position: Vector2) -> Vector2:
	return Vector2(image_x + image_position.x * scale, image_y + (float(image_height) - image_position.y) * scale)

static func _pdf_label(text: String, position: Vector2, font_size: float, color: Color) -> String:
	return "%.3f %.3f %.3f rg\nBT /F1 %.2f Tf %.2f %.2f Td (%s) Tj ET\n" % [color.r, color.g, color.b, font_size, position.x, position.y, _pdf_text(text)]

static func _format_value(value: float) -> String:
	var magnitude := absf(value)
	if magnitude >= 10000.0 or (magnitude > 0.0 and magnitude < 0.01):
		return "%.2e" % value
	if magnitude >= 100.0:
		return "%.1f" % value
	return "%.3f" % value

static func _write_object(output: PackedByteArray, offsets: PackedInt64Array, object_id: int, body: PackedByteArray) -> void:
	offsets[object_id] = output.size()
	_append_text(output, "%d 0 obj\n" % object_id)
	output.append_array(body)
	_append_text(output, "\nendobj\n")

static func _write_stream_object(output: PackedByteArray, offsets: PackedInt64Array, object_id: int, data: PackedByteArray, dictionary_prefix: String) -> void:
	offsets[object_id] = output.size()
	_append_text(output, "%d 0 obj\n<< %s /Length %d >>\nstream\n" % [object_id, dictionary_prefix, data.size()])
	output.append_array(data)
	_append_text(output, "\nendstream\nendobj\n")

static func _pdf_text(value: String) -> String:
	return value.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)").to_ascii_buffer().get_string_from_ascii()

static func _text_bytes(value: String) -> PackedByteArray:
	return value.to_ascii_buffer()

static func _append_text(output: PackedByteArray, value: String) -> void:
	output.append_array(value.to_utf8_buffer())
