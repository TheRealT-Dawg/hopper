## Interpolates individual telemetry frames for smooth timestamp-based playback.
extends RefCounted

const TelemetrySchema = preload("res://Scripts/telemetry_schema.gd")

static func interpolate(start: PackedFloat64Array, finish: PackedFloat64Array, weight: float) -> PackedFloat64Array:
	var t := clampf(weight, 0.0, 1.0)
	var result := PackedFloat64Array()
	result.resize(TelemetrySchema.COLUMN_COUNT)
	for column in TelemetrySchema.COLUMN_COUNT:
		result[column] = lerpf(start[column], finish[column], t)
	var start_rotation := Quaternion(
		start[TelemetrySchema.Column.Q1], start[TelemetrySchema.Column.Q2],
		start[TelemetrySchema.Column.Q3], start[TelemetrySchema.Column.Q0]
	).normalized()
	var finish_rotation := Quaternion(
		finish[TelemetrySchema.Column.Q1], finish[TelemetrySchema.Column.Q2],
		finish[TelemetrySchema.Column.Q3], finish[TelemetrySchema.Column.Q0]
	).normalized()
	var rotation := start_rotation.slerp(finish_rotation, t).normalized()
	result[TelemetrySchema.Column.Q0] = rotation.w
	result[TelemetrySchema.Column.Q1] = rotation.x
	result[TelemetrySchema.Column.Q2] = rotation.y
	result[TelemetrySchema.Column.Q3] = rotation.z
	return result
