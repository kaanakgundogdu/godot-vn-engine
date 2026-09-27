extends RefCounted
class_name VNEngineExpressionEvaluator


static func evaluate(expr: String, vars: Dictionary) -> bool:
	return bool(evaluate_value(expr, vars))


static func get_var(vars: Dictionary, name: String, expect_bool: bool = false) -> Variant:
	var key: String = name.to_lower()
	if vars.has(key):
		return vars[key]
	if expect_bool:
		return false
	return 0.0


static func compare(current: Variant, op: String, target: Variant) -> bool:
	match op:
		"==":
			return current == target
		"!=":
			return current != target
		">":
			return float(current) > float(target)
		"<":
			return float(current) < float(target)
		">=":
			return float(current) >= float(target)
		"<=":
			return float(current) <= float(target)
	return false


static func evaluate_value(expr: String, vars: Dictionary) -> Variant:
	var parser: _Parser = _Parser.new(expr)
	var parsed: Dictionary = parser.parse()
	var errors: PackedStringArray = parsed["errors"]
	if not errors.is_empty():
		return false
	return _eval(parsed["ast"], vars)


static func collect_identifiers(expr: String) -> PackedStringArray:
	var tok_result: Dictionary = _Parser._tokenize(expr.strip_edges())
	var tokens: Array = tok_result["tokens"]
	var seen: Dictionary = {}
	var result: PackedStringArray = []
	for token in tokens:
		var token_dict: Dictionary = token
		if token_dict["kind"] == "ident":
			var text: String = token_dict["text"]
			var lowered: String = text.to_lower()
			if not seen.has(lowered):
				seen[lowered] = true
				result.append(lowered)
	return result


static func validate(expr: String, flag_list: VNEngineFlagList = null) -> PackedStringArray:
	var parser: _Parser = _Parser.new(expr)
	var parsed: Dictionary = parser.parse()
	var errors: PackedStringArray = parsed["errors"]
	if not errors.is_empty():
		return errors
	return _validate_node(parsed["ast"], flag_list)


static func _eval(node: Variant, vars: Dictionary) -> Variant:
	if node == null:
		return false
	var node_data: Dictionary = node
	var kind: String = node_data.get("kind", "")
	match kind:
		"or":
			return bool(_eval(node_data["left"], vars)) or bool(_eval(node_data["right"], vars))
		"and":
			return bool(_eval(node_data["left"], vars)) and bool(_eval(node_data["right"], vars))
		"not":
			return not bool(_eval(node_data["operand"], vars))
		"cmp":
			return _eval_cmp(node_data, vars)
		"arith":
			return _eval_arith(node_data, vars)
		"num":
			return node_data["value"]
		"str":
			return node_data["value"]
		"bool":
			return node_data["value"]
		"ident":
			return get_var(vars, node_data["name"], false)
	return false


static func _eval_cmp(node: Dictionary, vars: Dictionary) -> bool:
	var left: Dictionary = node["left"]
	var right: Dictionary = node["right"]
	var left_is_bool_literal: bool = left.get("kind", "") == "bool"
	var right_is_bool_literal: bool = right.get("kind", "") == "bool"

	var left_val: Variant = _eval_operand(left, vars, right_is_bool_literal)
	var right_val: Variant = _eval_operand(right, vars, left_is_bool_literal)
	return compare(left_val, node["op"], right_val)


static func _eval_operand(node: Dictionary, vars: Dictionary, expect_bool_hint: bool) -> Variant:
	if node.get("kind", "") == "ident":
		var name: String = node["name"]
		return get_var(vars, name, expect_bool_hint)
	return _eval(node, vars)


static func _eval_arith(node: Dictionary, vars: Dictionary) -> float:
	if node.get("kind", "") == "arith":
		var left_value: float = _eval_arith(node["left"], vars)
		var right_value: float = _eval_arith(node["right"], vars)
		if node["op"] == "+":
			return left_value + right_value
		return left_value - right_value
	return _to_float(_eval(node, vars))


static func _validate_node(node: Variant, flag_list: VNEngineFlagList) -> PackedStringArray:
	var result: PackedStringArray = []
	if node == null:
		return result
	var node_data: Dictionary = node
	var kind: String = node_data.get("kind", "")
	match kind:
		"or":
			result.append_array(_validate_node(node_data["left"], flag_list))
			result.append_array(_validate_node(node_data["right"], flag_list))
		"and":
			result.append_array(_validate_node(node_data["left"], flag_list))
			result.append_array(_validate_node(node_data["right"], flag_list))
		"not":
			result.append_array(_validate_node(node_data["operand"], flag_list))
		"arith":
			result.append_array(_validate_node(node_data["left"], flag_list))
			result.append_array(_validate_node(node_data["right"], flag_list))
		"cmp":
			result.append_array(_validate_cmp(node_data, flag_list))
			result.append_array(_validate_node(node_data["left"], flag_list))
			result.append_array(_validate_node(node_data["right"], flag_list))
	return result


static func _validate_cmp(node: Dictionary, flag_list: VNEngineFlagList) -> PackedStringArray:
	var result: PackedStringArray = []
	var op: String = node["op"]
	var is_ordering: bool = op == "<" or op == ">" or op == "<=" or op == ">="
	if not is_ordering:
		return result

	var left: Dictionary = node["left"]
	var right: Dictionary = node["right"]
	var left_kind: String = left.get("kind", "")
	var right_kind: String = right.get("kind", "")

	if left_kind == "str" or right_kind == "str":
		result.append("ordering operators ('<', '>', '<=', '>=') cannot be used with string literals")
		return result

	if flag_list == null:
		return result

	if left_kind == "ident":
		var left_name: String = left["name"]
		var left_flag: VNEngineFlagDef = flag_list.find(left_name)
		if left_flag != null and left_flag.type == "bool":
			result.append("ordering operator ('%s') cannot be used with boolean flag '%s'" % [op, left_name.to_lower()])
	if right_kind == "ident":
		var right_name: String = right["name"]
		var right_flag: VNEngineFlagDef = flag_list.find(right_name)
		if right_flag != null and right_flag.type == "bool":
			result.append("ordering operator ('%s') cannot be used with boolean flag '%s'" % [op, right_name.to_lower()])

	return result


static func _to_float(value: Variant) -> float:
	if typeof(value) == TYPE_BOOL:
		return 1.0 if value else 0.0
	return float(value)


static func _coerce_literal(value_str: String) -> Variant:
	var text: String = value_str.strip_edges()
	if text.length() >= 2 and text.begins_with("\"") and text.ends_with("\""):
		return text.substr(1, text.length() - 2)
	if text.to_lower() == "true":
		return true
	if text.to_lower() == "false":
		return false
	if text.is_valid_float():
		return text.to_float()
	return text


class _Parser extends RefCounted:
	var _tokens: Array = []
	var _pos: int = 0
	var _errors: PackedStringArray = []

	func _init(expr: String) -> void:
		var trimmed: String = expr.strip_edges()
		if trimmed.is_empty():
			_errors.append("empty expression")
			return
		var tok_result: Dictionary = _tokenize(trimmed)
		_tokens = tok_result["tokens"]
		var tok_error: String = tok_result["error"]
		if tok_error != "":
			_errors.append(tok_error)

	func parse() -> Dictionary:
		if not _errors.is_empty():
			return {"ast": null, "errors": _errors}
		var ast: Variant = _parse_or()
		if _errors.is_empty() and _pos < _tokens.size():
			var leftover: Dictionary = _tokens[_pos]
			var leftover_text: String = leftover["text"]
			_error("unexpected token: '%s'" % leftover_text)
		if not _errors.is_empty():
			return {"ast": null, "errors": _errors}
		return {"ast": ast, "errors": _errors}

	func _peek() -> Dictionary:
		if _pos < _tokens.size():
			var token: Dictionary = _tokens[_pos]
			return token
		return {"kind": "eof", "text": ""}

	func _advance() -> Dictionary:
		var token: Dictionary = _peek()
		if _pos < _tokens.size():
			_pos += 1
		return token

	func _error(msg: String) -> void:
		if _errors.is_empty():
			_errors.append(msg)

	func _parse_or() -> Variant:
		var node: Variant = _parse_and()
		while _errors.is_empty() and _peek()["kind"] == "or":
			_advance()
			var rhs: Variant = _parse_and()
			node = {"kind": "or", "left": node, "right": rhs}
		return node

	func _parse_and() -> Variant:
		var node: Variant = _parse_not()
		while _errors.is_empty() and _peek()["kind"] == "and":
			_advance()
			var rhs: Variant = _parse_not()
			node = {"kind": "and", "left": node, "right": rhs}
		return node

	func _parse_not() -> Variant:
		if _peek()["kind"] == "not":
			_advance()
			var operand: Variant = _parse_not()
			return {"kind": "not", "operand": operand}
		return _parse_primary()

	func _parse_primary() -> Variant:
		if not _errors.is_empty():
			return null

		if _peek()["kind"] == "lparen":
			_advance()
			var inner: Variant = _parse_or()
			if not _errors.is_empty():
				return null
			if _peek()["kind"] != "rparen":
				_error("unclosed parenthesis")
				return null
			_advance()
			return inner

		var node: Variant = _parse_arith()
		if not _errors.is_empty():
			return null

		var op_kind: String = _peek()["kind"]
		var cmp_op: String = _cmp_op_text(op_kind)
		if cmp_op != "":
			_advance()
			var rhs: Variant = _parse_arith()
			if not _errors.is_empty():
				return null
			return {"kind": "cmp", "op": cmp_op, "left": node, "right": rhs}
		return node

	func _parse_arith() -> Variant:
		var node: Variant = _parse_atom()
		while _errors.is_empty() and (_peek()["kind"] == "plus" or _peek()["kind"] == "minus"):
			var op_token: Dictionary = _advance()
			var rhs: Variant = _parse_atom()
			if not _errors.is_empty():
				return null
			var op_text: String = "+" if op_token["kind"] == "plus" else "-"
			node = {"kind": "arith", "op": op_text, "left": node, "right": rhs}
		return node

	func _parse_atom() -> Variant:
		var tok: Dictionary = _peek()
		var kind: String = tok["kind"]
		match kind:
			"number":
				_advance()
				var num_value: float = tok["value"]
				return {"kind": "num", "value": num_value}
			"true":
				_advance()
				return {"kind": "bool", "value": true}
			"false":
				_advance()
				return {"kind": "bool", "value": false}
			"string":
				_advance()
				var str_value: String = tok["text"]
				return {"kind": "str", "value": str_value}
			"ident":
				_advance()
				var ident_name: String = tok["text"]
				return {"kind": "ident", "name": ident_name}
			"eof":
				_error("unexpected end of expression (missing term)")
			_:
				var tok_text: String = tok["text"]
				_error("unexpected token: '%s'" % tok_text)
		return null

	func _cmp_op_text(kind: String) -> String:
		match kind:
			"eq":
				return "=="
			"neq":
				return "!="
			"ge":
				return ">="
			"le":
				return "<="
			"gt":
				return ">"
			"lt":
				return "<"
		return ""

	static func _tokenize(expr: String) -> Dictionary:
		var tokens: Array = []
		var i: int = 0
		var length: int = expr.length()
		while i < length:
			var current_char: String = expr[i]

			if current_char == " " or current_char == "\t" or current_char == "\n" or current_char == "\r":
				i += 1
				continue

			if current_char == "(":
				tokens.append({"kind": "lparen", "text": "("})
				i += 1
				continue
			if current_char == ")":
				tokens.append({"kind": "rparen", "text": ")"})
				i += 1
				continue
			if current_char == "+":
				tokens.append({"kind": "plus", "text": "+"})
				i += 1
				continue
			if current_char == "-":
				tokens.append({"kind": "minus", "text": "-"})
				i += 1
				continue

			if current_char == "=":
				if i + 1 < length and expr[i + 1] == "=":
					tokens.append({"kind": "eq", "text": "=="})
					i += 2
					continue
				return {"tokens": tokens, "error": "unexpected character: '=' (use '==' for equality)"}

			if current_char == "!":
				if i + 1 < length and expr[i + 1] == "=":
					tokens.append({"kind": "neq", "text": "!="})
					i += 2
					continue
				return {"tokens": tokens, "error": "unexpected character: '!' (use 'not' for logical negation)"}

			if current_char == ">":
				if i + 1 < length and expr[i + 1] == "=":
					tokens.append({"kind": "ge", "text": ">="})
					i += 2
				else:
					tokens.append({"kind": "gt", "text": ">"})
					i += 1
				continue

			if current_char == "<":
				if i + 1 < length and expr[i + 1] == "=":
					tokens.append({"kind": "le", "text": "<="})
					i += 2
				else:
					tokens.append({"kind": "lt", "text": "<"})
					i += 1
				continue

			if current_char == "\"":
				var pos: int = i + 1
				var buf: String = ""
				var closed: bool = false
				while pos < length:
					var ch: String = expr[pos]
					if ch == "\\" and pos + 1 < length and (expr[pos + 1] == "\"" or expr[pos + 1] == "\\"):
						buf += expr[pos + 1]
						pos += 2
						continue
					if ch == "\"":
						closed = true
						pos += 1
						break
					buf += ch
					pos += 1
				if not closed:
					return {"tokens": tokens, "error": "unclosed string"}
				tokens.append({"kind": "string", "text": buf})
				i = pos
				continue

			if current_char >= "0" and current_char <= "9":
				var digit_start: int = i
				var dot_seen: bool = false
				var pos: int = i
				while pos < length:
					var ch: String = expr[pos]
					if ch >= "0" and ch <= "9":
						pos += 1
					elif ch == "." and not dot_seen:
						dot_seen = true
						pos += 1
					else:
						break
				var num_text: String = expr.substr(digit_start, pos - digit_start)
				tokens.append({"kind": "number", "text": num_text, "value": num_text.to_float()})
				i = pos
				continue

			if (current_char >= "a" and current_char <= "z") or (current_char >= "A" and current_char <= "Z") or current_char == "_":
				var ident_start: int = i
				var pos: int = i
				while pos < length:
					var ch: String = expr[pos]
					if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "_":
						pos += 1
					else:
						break
				var ident_text: String = expr.substr(ident_start, pos - ident_start)
				var lowered: String = ident_text.to_lower()
				match lowered:
					"and":
						tokens.append({"kind": "and", "text": ident_text})
					"or":
						tokens.append({"kind": "or", "text": ident_text})
					"not":
						tokens.append({"kind": "not", "text": ident_text})
					"true":
						tokens.append({"kind": "true", "text": ident_text})
					"false":
						tokens.append({"kind": "false", "text": ident_text})
					_:
						tokens.append({"kind": "ident", "text": ident_text})
				i = pos
				continue

			return {"tokens": tokens, "error": "unexpected character: '%s'" % current_char}

		return {"tokens": tokens, "error": ""}
