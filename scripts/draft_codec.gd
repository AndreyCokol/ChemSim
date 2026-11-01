extends RefCounted
class_name ChemSimDraftCodec

const DOCUMENT_TYPE := "chemsim_ui_draft"
const SCHEMA_VERSION := 1

static func build_payload(
	experiment_name: String,
	reaction_text: String,
	temperature_text: String,
	pressure_raw: String,
	volume_raw: String,
	component_drafts: Array[Dictionary]
) -> Dictionary:
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
	if str(payload.get("document_type", "")) != DOCUMENT_TYPE:
		return _failure("Неизвестный тип документа.")
	if int(payload.get("schema_version", -1)) != SCHEMA_VERSION:
		return _failure("Неподдерживаемая версия черновика.")
	var raw_components: Variant = payload.get("components", null)
	if not raw_components is Array:
		return _failure("Отсутствует корректный список компонентов.")
	var raw_conditions: Variant = payload.get("conditions", {})
	if not raw_conditions is Dictionary:
		return _failure("Блок условий имеет неверный формат.")

	var decoded_components: Array[Dictionary] = []
	var seen_ids: Dictionary = {}
	for raw_item in raw_components:
		if not raw_item is Dictionary:
			return _failure("Одна из записей компонента имеет неверный формат.")
		var raw_position: Variant = raw_item.get("position", [-1.0, -1.0])
		if not raw_position is Array or raw_position.size() != 2:
			return _failure("Координаты компонента имеют неверный формат.")
		if not _is_number(raw_position[0]) or not _is_number(raw_position[1]):
			return _failure("Координаты компонента должны быть числами.")
		var component_id := int(raw_item.get("id", 0))
		if component_id <= 0 or seen_ids.has(component_id):
			return _failure("Идентификаторы компонентов должны быть положительными и уникальными.")
		seen_ids[component_id] = true
		decoded_components.append({
			"id": component_id,
			"name": str(raw_item.get("name", "")),
			"formula": str(raw_item.get("formula", "")),
			"amount": str(raw_item.get("amount", "")),
			"unit": str(raw_item.get("unit", "не задано")),
			"phase": str(raw_item.get("phase", "Фаза не указана")),
			"position": Vector2(float(raw_position[0]), float(raw_position[1]))
		})

	return {
		"ok": true,
		"data": {
			"experiment_name": str(payload.get("experiment_name", "Черновик")),
			"reaction_text": str(payload.get("reaction_text", "")),
			"conditions": raw_conditions,
			"components": decoded_components
		}
	}

static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
