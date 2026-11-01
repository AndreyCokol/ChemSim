class_name ReactionBalancer
extends RefCounted

const PIVOT_EPSILON := 1.0e-10
const VERIFY_EPSILON := 1.0e-7
const MAX_INTEGER_COEFFICIENT := 10000

func balance(reaction: ReactionParseResult) -> BalanceResult:
	if reaction == null or not reaction.ok:
		return BalanceResult.failure("invalid_input", "BALANCE_INVALID_REACTION", "Для балансировки требуется корректно разобранное уравнение.")
	var terms: Array[Dictionary] = []
	terms.append_array(reaction.reactants)
	terms.append_array(reaction.products)
	if terms.size() < 2:
		return BalanceResult.failure("invalid_input", "BALANCE_TOO_FEW_TERMS", "Для реакции требуется не менее двух членов.")

	var elements: Dictionary = {}
	for term in terms:
		for element in term.element_counts:
			elements[element] = true
	var rows: Array[String] = []
	for element in elements:
		rows.append(element)
	rows.append("__charge__")

	var matrix: Array[Array] = []
	for row_name in rows:
		var row: Array[float] = []
		for column in range(terms.size()):
			var value := float(terms[column].net_charge) if row_name == "__charge__" else float(terms[column].element_counts.get(row_name, 0))
			if column >= reaction.reactants.size():
				value = -value
			row.append(value)
		matrix.append(row)

	var reduced := _rref(matrix)
	var pivots: Array[int] = reduced.pivots
	var free_columns: Array[int] = []
	for column in range(terms.size()):
		if not pivots.has(column):
			free_columns.append(column)
	if free_columns.is_empty():
		return BalanceResult.failure("no_solution", "BALANCE_NO_NONZERO_SOLUTION", "Ненулевое стехиометрическое решение не найдено.")
	if free_columns.size() > 1:
		return BalanceResult.failure("ambiguous", "BALANCE_AMBIGUOUS", "Найдено несколько независимых степеней свободы; автоматический выбор коэффициентов небезопасен.")

	var vector: Array[float] = []
	vector.resize(terms.size())
	for i in range(vector.size()):
		vector[i] = 0.0
	vector[free_columns[0]] = 1.0
	for pivot_row in range(pivots.size() - 1, -1, -1):
		var pivot_column: int = pivots[pivot_row]
		var value := 0.0
		for column in range(pivot_column + 1, terms.size()):
			value += float(reduced.matrix[pivot_row][column]) * vector[column]
		vector[pivot_column] = -value

	return _integerize_and_verify(vector, matrix)

func _rref(source: Array[Array]) -> Dictionary:
	var matrix: Array[Array] = []
	for row in source:
		matrix.append(row.duplicate())
	var pivot_columns: Array[int] = []
	var pivot_row := 0
	var row_count := matrix.size()
	var column_count := matrix[0].size()
	for column in range(column_count):
		var best_row := -1
		var best_value := PIVOT_EPSILON
		for candidate in range(pivot_row, row_count):
			var candidate_value := abs(float(matrix[candidate][column]))
			if candidate_value > best_value:
				best_value = candidate_value
				best_row = candidate
		if best_row < 0:
			continue
		var swap: Array = matrix[pivot_row]
		matrix[pivot_row] = matrix[best_row]
		matrix[best_row] = swap
		var pivot := float(matrix[pivot_row][column])
		for j in range(column_count):
			matrix[pivot_row][j] = float(matrix[pivot_row][j]) / pivot
		for i in range(row_count):
			if i == pivot_row:
				continue
			var factor := float(matrix[i][column])
			if abs(factor) <= PIVOT_EPSILON:
				continue
			for j in range(column_count):
				matrix[i][j] = float(matrix[i][j]) - factor * float(matrix[pivot_row][j])
		pivot_columns.append(column)
		pivot_row += 1
		if pivot_row >= row_count:
			break
	return {"matrix": matrix, "pivots": pivot_columns}

func _integerize_and_verify(vector: Array[float], original_matrix: Array[Array]) -> BalanceResult:
	var first_nonzero := -1
	for i in range(vector.size()):
		if abs(vector[i]) > PIVOT_EPSILON:
			first_nonzero = i
			break
	if first_nonzero < 0:
		return BalanceResult.failure("no_solution", "BALANCE_ZERO_VECTOR", "Получено нулевое решение.")

	var sign := 1.0 if vector[first_nonzero] > 0.0 else -1.0
	var normalized: Array[float] = []
	for value in vector:
		normalized.append(value * sign)
	for value in normalized:
		if value <= PIVOT_EPSILON:
			return BalanceResult.failure("no_positive_solution", "BALANCE_NO_POSITIVE_SOLUTION", "Для реакции не найдено решения, в котором все коэффициенты положительны.")

	for multiplier in range(1, MAX_INTEGER_COEFFICIENT + 1):
		var candidate: Array[int] = []
		var valid := true
		for value in normalized:
			var scaled := value * float(multiplier)
			var rounded := int(round(scaled))
			if rounded <= 0 or abs(scaled - float(rounded)) > VERIFY_EPSILON:
				valid = false
				break
			candidate.append(rounded)
		if not valid:
			continue
		if _is_exact_integer_balance(candidate, original_matrix):
			return BalanceResult.success(_normalize_gcd(candidate))
	return BalanceResult.failure("numeric_limit", "BALANCE_INTEGERIZATION_LIMIT", "Не удалось подтвердить целочисленные коэффициенты в установленном диапазоне. Требуется точная рациональная процедура или ручная проверка.")

func _is_exact_integer_balance(coefficients: Array[int], matrix: Array[Array]) -> bool:
	for row in matrix:
		var total := 0.0
		for column in range(coefficients.size()):
			total += float(row[column]) * float(coefficients[column])
		if abs(total) > VERIFY_EPSILON:
			return false
	return true

func _normalize_gcd(values: Array[int]) -> Array[int]:
	var divisor := values[0]
	for value in values:
		divisor = _gcd(divisor, value)
	var result: Array[int] = []
	for value in values:
		result.append(value / divisor)
	return result

func _gcd(a: int, b: int) -> int:
	var left := abs(a)
	var right := abs(b)
	while right != 0:
		var remainder := left % right
		left = right
		right = remainder
	return maxi(left, 1)
