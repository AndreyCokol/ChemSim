extends SceneTree

const DraftCodec = preload("res://scripts/draft_codec.gd")

func _initialize() -> void:
	var components: Array[Dictionary] = [{
		"id": 1,
		"name": "Вода",
		"formula": "H2O",
		"amount": "1",
		"unit": "моль",
		"phase": "Водный раствор",
		"position": Vector2(0.25, 0.75)
	}]
	var payload := DraftCodec.build_payload(
		"Тестовый черновик",
		"H2 + O2 -> H2O",
		"298.15",
		"1",
		"2",
		components
	)
	var decoded := DraftCodec.decode_payload(payload)
	assert(decoded.ok, "A valid UI draft must decode")
	assert(decoded.data.components.size() == 1, "The component must round-trip")
	assert(decoded.data.components[0].position == Vector2(0.25, 0.75), "Visual position must round-trip")

	var unsupported := payload.duplicate(true)
	unsupported.schema_version = 99
	assert(not DraftCodec.decode_payload(unsupported).ok, "Unknown schema versions must be rejected")
	var fractional_schema := payload.duplicate(true)
	fractional_schema.schema_version = 1.5
	assert(not DraftCodec.decode_payload(fractional_schema).ok, "Fractional schema versions must not be coerced to the supported integer version")
	var string_schema := payload.duplicate(true)
	string_schema.schema_version = "1"
	assert(not DraftCodec.decode_payload(string_schema).ok, "String schema versions must be rejected")

	var duplicate_ids := payload.duplicate(true)
	duplicate_ids.components.append(duplicate_ids.components[0].duplicate(true))
	assert(not DraftCodec.decode_payload(duplicate_ids).ok, "Duplicate component IDs must be rejected")
	var fractional_id := payload.duplicate(true)
	fractional_id.components[0].id = 1.5
	assert(not DraftCodec.decode_payload(fractional_id).ok, "Fractional component IDs must not be truncated")
	var string_id := payload.duplicate(true)
	string_id.components[0].id = "1"
	assert(not DraftCodec.decode_payload(string_id).ok, "String component IDs must be rejected")

	var invalid_position := payload.duplicate(true)
	invalid_position.components[0].position = [0.5]
	assert(not DraftCodec.decode_payload(invalid_position).ok, "Malformed marker coordinates must be rejected")
	var out_of_range_position := payload.duplicate(true)
	out_of_range_position.components[0].position = [1.01, 0.5]
	assert(not DraftCodec.decode_payload(out_of_range_position).ok, "Marker coordinates outside the normalized range must be rejected")
	var partial_unplaced_position := payload.duplicate(true)
	partial_unplaced_position.components[0].position = [-1.0, 0.5]
	assert(not DraftCodec.decode_payload(partial_unplaced_position).ok, "Unplaced markers must use the complete [-1, -1] sentinel")

	var invalid_component := payload.duplicate(true)
	invalid_component.components[0] = "not-a-dictionary"
	assert(not DraftCodec.decode_payload(invalid_component).ok, "Malformed component records must be rejected")
	var invalid_component_field := payload.duplicate(true)
	invalid_component_field.components[0].name = 123
	assert(not DraftCodec.decode_payload(invalid_component_field).ok, "Component text fields must not be silently coerced")
	var invalid_conditions := payload.duplicate(true)
	invalid_conditions.conditions = []
	assert(not DraftCodec.decode_payload(invalid_conditions).ok, "Malformed condition blocks must be rejected")
	var invalid_condition_field := payload.duplicate(true)
	invalid_condition_field.conditions.pressure_raw = 1
	assert(not DraftCodec.decode_payload(invalid_condition_field).ok, "Raw condition fields must remain strings")

	var missing_document_type := payload.duplicate(true)
	missing_document_type.erase("document_type")
	assert(not DraftCodec.decode_payload(missing_document_type).ok, "Documents without a type marker must be rejected")

	print("Draft codec tests passed")
	quit(0)
