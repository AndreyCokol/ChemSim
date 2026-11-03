extends RefCounted
class_name ChemSourceSpan

## A2-local, lossless offsets-only bridge between Godot String character
## ranges and UTF-8 byte ranges over the *same original, unchanged source*.
##
## This does not construct a shared ErrorEnvelope, decide whether a shared
## consumer accepts zero-length insertion spans, or normalize source text.

static func to_utf8_byte_span(source: String, character_span: Dictionary) -> Dictionary:
	var start_value: Variant = character_span.get("start_offset")
	var end_value: Variant = character_span.get("end_offset")
	if typeof(start_value) != TYPE_INT or typeof(end_value) != TYPE_INT:
		return _invalid_span()
	var start_offset: int = start_value
	var end_offset: int = end_value
	if start_offset < 0 or end_offset < start_offset or end_offset > source.length():
		return _invalid_span()
	return {
		"ok": true,
		"source_span": {
			"utf8_byte_start": source.substr(0, start_offset).to_utf8_buffer().size(),
			"utf8_byte_end": source.substr(0, end_offset).to_utf8_buffer().size()
		}
	}


static func to_character_span(source: String, byte_span: Dictionary) -> Dictionary:
	var start_value: Variant = byte_span.get("utf8_byte_start")
	var end_value: Variant = byte_span.get("utf8_byte_end")
	if typeof(start_value) != TYPE_INT or typeof(end_value) != TYPE_INT:
		return _invalid_span()
	var start_byte: int = start_value
	var end_byte: int = end_value
	if start_byte < 0 or end_byte < start_byte:
		return _invalid_span()
	if end_byte > source.to_utf8_buffer().size():
		return _invalid_span()

	# A UTF-8 source byte span may only start and end on complete Godot
	# character boundaries. Reject the middle of any multibyte scalar.
	var start_offset := -1
	var end_offset := -1
	var byte_offset := 0
	for offset in range(source.length() + 1):
		if byte_offset == start_byte:
			start_offset = offset
		if byte_offset == end_byte:
			end_offset = offset
		if offset < source.length():
			byte_offset += source.substr(offset, 1).to_utf8_buffer().size()
	if start_offset < 0 or end_offset < 0:
		return _invalid_span()

	return {
		"ok": true,
		"source_span": {
			"start_offset": start_offset,
			"end_offset": end_offset
		}
	}


static func _invalid_span() -> Dictionary:
	return {"ok": false, "code": "A2_INVALID_SOURCE_SPAN"}
