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
	var rejected := DraftCodec.decode_payload(unsupported)
	assert(not rejected.ok, "Unknown schema versions must be rejected")

	var duplicate_ids := payload.duplicate(true)
	duplicate_ids.components.append(duplicate_ids.components[0].duplicate(true))
	var duplicate_result := DraftCodec.decode_payload(duplicate_ids)
	assert(not duplicate_result.ok, "Duplicate component IDs must be rejected")

	var invalid_position := payload.duplicate(true)
	invalid_position.components[0].position = [0.5]
	var invalid_position_result := DraftCodec.decode_payload(invalid_position)
	assert(not invalid_position_result.ok, "Malformed marker coordinates must be rejected")

	var invalid_component := payload.duplicate(true)
	invalid_component.components[0] = "not-a-dictionary"
	var invalid_component_result := DraftCodec.decode_payload(invalid_component)
	assert(not invalid_component_result.ok, "Malformed component records must be rejected")

	var invalid_conditions := payload.duplicate(true)
	invalid_conditions.conditions = []
	var invalid_conditions_result := DraftCodec.decode_payload(invalid_conditions)
	assert(not invalid_conditions_result.ok, "Malformed condition blocks must be rejected")

	var missing_document_type := payload.duplicate(true)
	missing_document_type.erase("document_type")
	var missing_type_result := DraftCodec.decode_payload(missing_document_type)
	assert(not missing_type_result.ok, "Documents without a type marker must be rejected")

	print("Draft codec tests passed")
	quit(0)
