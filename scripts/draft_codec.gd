extends RefCounted
class_name ChemSimDraftCodec

const DOCUMENT_TYPE := "chemsim_ui_draft"
const SCHEMA_VERSION := 1

static func build_payload(experiment_name: String, reaction_text: String, temperature_text: String, pressure_raw: String, volume_raw: String, component_drafts: Array[Dictionary]) -> Dictionary:
	var serialized_components: Array[Dictionary] = []
	for item in component_drafts:
		var position: Vector2 = item.get("position", Vector2(-1, -1))
		serialized_components.append({
			"id": int(item.get("id", 0)),
			"name": str(item.get("name", "")),
			"formula": str(item.get("formula", "")),
			"amount": str(item.get("amount", "")),
			"unit": str(item.get("unit", "не задано")),
			"phase": str(item.get("phase", "Фаза не указана")),
			"position": [position.x, position.y]
		})
	return {
		"document_type": DOCUMENT_TYPE,
		"schema_version": SCHEMA_VERSION,
		"experiment_name": experiment_name,
		"chemistry_status": "unvalidated_draft",
		"reaction_text": reaction_text,
		"conditions": {
			"temperature_k": temperature_text,
			"pressure_raw": pressure_raw,
			"volume_raw": volume_raw
		},
		"components": serialized_components
	}

static func decode_payload(payload: Variant) -> Dictionary:
	if not payload is Dictionary:
		return _failure("Файл не является корректным JSON-объектом.")
	for required_field in ["document_type", "schema_version", "experiment_name", "reaction_text", "chemistry_status", "conditions", "components"]:
		if not payload.has(required_field):
			return _failure("В документе отсутствует обязательное поле " + required_field + ".")
	if not _has_only_fields(payload, ["document_type", "schema_version", "experiment_name", "reaction_text", "chemistry_status", "conditions", "components"]):
		return _failure("Документ содержит неизвестные поля для схемы v1.")
	if typeof(payload.document_type) != TYPE_STRING or payload.document_type != DOCUMENT_TYPE:
		return _failure("Неизвестный тип документа.")
	if typeof(payload.schema_version) != TYPE_INT or payload.schema_version != SCHEMA_VERSION:
		return _failure("Неподдерживаемая версия черновика.")
	if typeof(payload.chemistry_status) != TYPE_STRING or payload.chemistry_status != "unvalidated_draft":
		return _failure("Недопустимый статус химической проверки черновика.")
	for field in ["experiment_name", "reaction_text"]:
		if typeof(payload[field]) != TYPE_STRING:
			return _failure("Поле " + field + " должно быть строкой.")
	var raw_components: Variant = payload.components
	if not raw_components is Array:
		return _failure("Отсутствует корректный список компонентов.")
	var raw_conditions: Variant = payload.conditions
	if not raw_conditions is Dictionary:
		return _failure("Блок условий имеет неверный формат.")
	if not _has_only_fields(raw_conditions, ["temperature_k", "pressure_raw", "volume_raw"]):
		return _failure("Блок условий содержит неизвестные поля для схемы v1.")
	for field in ["temperature_k", "pressure_raw", "volume_raw"]:
		if not raw_conditions.has(field):
			return _failure("В блоке условий отсутствует обязательное поле " + field + ".")
		if typeof(raw_conditions[field]) != TYPE_STRING:
			return _failure("Поле условий " + field + " должно быть строкой.")
	if raw_conditions.temperature_k != "298.15":
		return _failure("Черновик не соответствует фиксированной изотермической температуре 298.15 K.")

	var decoded_components: Array[Dictionary] = []
	var seen_ids: Dictionary = {}
	for raw_item in raw_components:
		if not raw_item is Dictionary:
			return _failure("Одна из записей компонента имеет неверный формат.")
		if not _has_only_fields(raw_item, ["id", "name", "formula", "amount", "unit", "phase", "position"]):
			return _failure("Запись компонента содержит неизвестные поля для схемы v1.")
		for field in ["id", "name", "formula", "amount", "unit", "phase", "position"]:
			if not raw_item.has(field):
				return _failure("В записи компонента отсутствует обязательное поле " + field + ".")
		for field in ["name", "formula", "amount", "unit", "phase"]:
			if typeof(raw_item[field]) != TYPE_STRING:
				return _failure("Поле компонента " + field + " должно быть строкой.")
		var raw_position: Variant = raw_item.position
		if not raw_position is Array or raw_position.size() != 2:
			return _failure("Координаты компонента имеют неверный формат.")
		if not _is_valid_position(raw_position):
			return _failure("Координаты должны находиться в видимой области поля (x: 0.03–0.97, y: 0.05–0.95) либо быть парой -1 для неразмещённого маркера.")
		var raw_id: Variant = raw_item.id
		if typeof(raw_id) != TYPE_INT:
			return _failure("Идентификатор компонента должен быть целым числом.")
		var component_id := int(raw_id)
		if component_id <= 0 or seen_ids.has(component_id):
			return _failure("Идентификаторы компонентов должны быть положительными и уникальными.")
		seen_ids[component_id] = true
		decoded_components.append({
			"id": component_id,
			"name": raw_item.name,
			"formula": raw_item.formula,
			"amount": raw_item.amount,
			"unit": raw_item.unit,
			"phase": raw_item.phase,
			"position": Vector2(float(raw_position[0]), float(raw_position[1]))
		})

	return {"ok": true, "data": {
		"experiment_name": payload.experiment_name,
		"reaction_text": payload.reaction_text,
		"conditions": raw_conditions.duplicate(true),
		"components": decoded_components
	}}

static func _has_only_fields(value: Dictionary, allowed_fields: Array) -> bool:
	for field in value.keys():
		if not allowed_fields.has(field):
			return false
	return true

static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT

static func _is_valid_position(position: Array) -> bool:
	if not _is_number(position[0]) or not _is_number(position[1]):
		return false
	var x := float(position[0])
	var y := float(position[1])
	if not is_finite(x) or not is_finite(y):
		return false
	var is_unplaced := x == -1.0 and y == -1.0
	var is_normalized := x >= 0.03 and x <= 0.97 and y >= 0.05 and y <= 0.95
	return is_unplaced or is_normalized

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
