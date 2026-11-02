class_name ReactionBalancer
extends RefCounted

# Rational arithmetic is exact while every intermediate integer remains within
# this conservative bound. We fail closed instead of falling back to floats.
const MAX_SAFE_INTEGER := 1000000000
const MAX_COEFFICIENT := 1000000000

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
	var element_names: Array[String] = []
	for element in elements:
		element_names.append(str(element))
	element_names.sort()
	for element in element_names:
		rows.append(element)
	rows.append("__charge__")

	var matrix: Array[Array] = []
	for row_name in rows:
		var row: Array[Dictionary] = []
		for column in range(terms.size()):
			var value := int(terms[column].net_charge) if row_name == "__charge__" else int(terms[column].element_counts.get(row_name, 0))
			if column >= reaction.reactants.size():
				value = -value
			row.append(_rat(value, 1))
		matrix.append(row)

	var reduced := _rref(matrix)
	if not reduced.ok:
		return _arithmetic_limit()
	var pivots: Array[int] = reduced.pivots
	var free_columns: Array[int] = []
	for column in range(terms.size()):
		if not pivots.has(column):
			free_columns.append(column)
	if free_columns.is_empty():
		return BalanceResult.failure("no_solution", "BALANCE_NO_NONZERO_SOLUTION", "Ненулевое стехиометрическое решение не найдено.")
	if free_columns.size() > 1:
		return BalanceResult.failure("ambiguous", "BALANCE_AMBIGUOUS", "Найдено несколько независимых степеней свободы; автоматический выбор коэффициентов небезопасен.")

	var vector: Array[Dictionary] = []
	for _i in range(terms.size()):
		vector.append(_rat(0, 1))
	vector[free_columns[0]] = _rat(1, 1)
	for pivot_row in range(pivots.size() - 1, -1, -1):
		var pivot_column: int = pivots[pivot_row]
		var value := _rat(0, 1)
		for column in range(pivot_column + 1, terms.size()):
			var product := _multiply(reduced.matrix[pivot_row][column], vector[column])
			if not product.ok:
				return _arithmetic_limit()
			var added := _add(value, product.value)
			if not added.ok:
				return _arithmetic_limit()
			value = added.value
		vector[pivot_column] = _negate(value)

	return _to_positive_integers(vector, matrix)

func _rref(source: Array[Array]) -> Dictionary:
	var matrix: Array[Array] = []
	for source_row in source:
		var row: Array[Dictionary] = []
		for value in source_row:
			row.append(_rat(value.n, value.d))
		matrix.append(row)
	var pivots: Array[int] = []
	var pivot_row := 0
	var row_count := matrix.size()
	var column_count := matrix[0].size()
	for column in range(column_count):
		var best := -1
		for candidate in range(pivot_row, row_count):
			if matrix[candidate][column].n != 0:
				best = candidate
				break
		if best < 0:
			continue
		var swap: Array = matrix[pivot_row]
		matrix[pivot_row] = matrix[best]
		matrix[best] = swap
		var pivot: Dictionary = matrix[pivot_row][column]
		for j in range(column_count):
			var divided := _divide(matrix[pivot_row][j], pivot)
			if not divided.ok:
				return {"ok": false}
			matrix[pivot_row][j] = divided.value
		for i in range(row_count):
			if i == pivot_row:
				continue
			var factor: Dictionary = matrix[i][column]
			if factor.n == 0:
				continue
			for j in range(column_count):
				var product := _multiply(factor, matrix[pivot_row][j])
				if not product.ok:
					return {"ok": false}
				var difference := _subtract(matrix[i][j], product.value)
				if not difference.ok:
					return {"ok": false}
				matrix[i][j] = difference.value
		pivots.append(column)
		pivot_row += 1
		if pivot_row >= row_count:
			break
	return {"ok": true, "matrix": matrix, "pivots": pivots}

func _to_positive_integers(vector: Array[Dictionary], original_matrix: Array[Array]) -> BalanceResult:
	var lcm := 1
	for value in vector:
		if value.n <= 0:
			return BalanceResult.failure("no_positive_solution", "BALANCE_NO_POSITIVE_SOLUTION", "Для реакции не найдено решения, в котором все коэффициенты положительны.")
		var divisor := _gcd(lcm, value.d)
		# These quotients are exact by construction; cast explicitly because
		# GDScript's / operator produces a floating-point value for integer inputs.
		var factor: int = int(value.d / divisor)
		if not _within_safe(lcm, factor):
			return _arithmetic_limit()
		lcm *= factor
	var coefficients: Array[int] = []
	for value in vector:
		var factor: int = int(lcm / value.d)
		if not _within_safe(value.n, factor):
			return _arithmetic_limit()
		var coefficient: int = value.n * factor
		if coefficient <= 0 or coefficient > MAX_COEFFICIENT:
			return BalanceResult.failure("numeric_limit", "BALANCE_COEFFICIENT_LIMIT", "Точные коэффициенты превышают поддерживаемый предел.")
		coefficients.append(coefficient)
	var divisor := coefficients[0]
	for coefficient in coefficients:
		divisor = _gcd(divisor, coefficient)
	for i in range(coefficients.size()):
		coefficients[i] = int(coefficients[i] / divisor)
	if not _verify_integer_balance(coefficients, original_matrix):
		return BalanceResult.failure("internal_error", "BALANCE_INTERNAL_VERIFICATION_FAILED", "Внутренняя проверка точного баланса не пройдена.")
	return BalanceResult.success(coefficients)

func _verify_integer_balance(coefficients: Array[int], matrix: Array[Array]) -> bool:
	for row in matrix:
		var total := 0
		for column in range(coefficients.size()):
			if not _within_safe(int(row[column].n), coefficients[column]):
				return false
			var term := int(row[column].n) * coefficients[column]
			if abs(total) > MAX_SAFE_INTEGER - abs(term):
				return false
			total += term
		if total != 0:
			return false
	return true

func _rat(numerator: int, denominator: int) -> Dictionary:
	if denominator < 0:
		numerator = -numerator
		denominator = -denominator
	if denominator == 0:
		return {"n": 0, "d": 1}
	var divisor := _gcd(numerator, denominator)
	return {"n": int(numerator / divisor), "d": int(denominator / divisor)}

func _add(a: Dictionary, b: Dictionary) -> Dictionary:
	var left := _safe_product(a.n, b.d)
	var right := _safe_product(b.n, a.d)
	var denominator := _safe_product(a.d, b.d)
	if not left.ok or not right.ok or not denominator.ok:
		return {"ok": false}
	var numerator := int(left.value) + int(right.value)
	if abs(numerator) > MAX_SAFE_INTEGER:
		return {"ok": false}
	return {"ok": true, "value": _rat(numerator, denominator.value)}

func _subtract(a: Dictionary, b: Dictionary) -> Dictionary:
	return _add(a, _negate(b))

func _multiply(a: Dictionary, b: Dictionary) -> Dictionary:
	var numerator := _safe_product(a.n, b.n)
	var denominator := _safe_product(a.d, b.d)
	if not numerator.ok or not denominator.ok:
		return {"ok": false}
	return {"ok": true, "value": _rat(numerator.value, denominator.value)}

func _divide(a: Dictionary, b: Dictionary) -> Dictionary:
	if b.n == 0:
		return {"ok": false}
	var numerator := _safe_product(a.n, b.d)
	var denominator := _safe_product(a.d, b.n)
	if not numerator.ok or not denominator.ok:
		return {"ok": false}
	return {"ok": true, "value": _rat(numerator.value, denominator.value)}

func _safe_product(a: int, b: int) -> Dictionary:
	if a == 0 or b == 0:
		return {"ok": true, "value": 0}
	if abs(a) > int(MAX_SAFE_INTEGER / abs(b)):
		return {"ok": false}
	return {"ok": true, "value": a * b}

func _within_safe(a: int, b: int) -> bool:
	return a == 0 or b == 0 or abs(a) <= int(MAX_SAFE_INTEGER / abs(b))

func _negate(value: Dictionary) -> Dictionary:
	return _rat(-value.n, value.d)

func _gcd(a: int, b: int) -> int:
	var left := abs(a)
	var right := abs(b)
	while right != 0:
		var remainder := left % right
		left = right
		right = remainder
	return maxi(left, 1)

func _arithmetic_limit() -> BalanceResult:
	return BalanceResult.failure("numeric_limit", "BALANCE_EXACT_ARITHMETIC_LIMIT", "Точная рациональная балансировка превысила безопасный диапазон целых промежуточных значений; коэффициенты не были угаданы.")
