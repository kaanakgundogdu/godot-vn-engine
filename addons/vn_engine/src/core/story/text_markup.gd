class_name VNEngineTextMarkup
extends RefCounted

static var _bbcode_tag: RegEx = null


static func interpolate(text: String, vars: Dictionary) -> String:
	if not text.contains("{"):
		return text
	var out: String = ""
	var i: int = 0
	var n: int = text.length()
	while i < n:
		var c: String = text[i]
		if c == "{" and i + 1 < n:
			if text[i + 1] == "{":
				out += "{{"
				i += 2
				continue
			if text[i + 1] == "$":
				var close: int = text.find("}", i + 2)
				if close != -1:
					out += _format_value(_lookup(text.substr(i + 2, close - i - 2).strip_edges(), vars)).replace("{", "{{")
					i = close + 1
					continue
		out += c
		i += 1
	return out


static func parse(text: String) -> Dictionary:
	return _scan(text, [])


static func strip(text: String) -> String:
	return String(parse(text)["text"])


static func validate(text: String) -> PackedStringArray:
	var errors: Array = []
	_scan(text, errors)
	return PackedStringArray(errors)


static func collect_vars(text: String) -> PackedStringArray:
	var names := PackedStringArray()
	var i: int = 0
	var n: int = text.length()
	while i < n:
		if text[i] == "{" and i + 1 < n:
			if text[i + 1] == "{":
				i += 2
				continue
			if text[i + 1] == "$":
				var close: int = text.find("}", i + 2)
				if close != -1:
					var name: String = text.substr(i + 2, close - i - 2).strip_edges()
					if name != "" and not names.has(name):
						names.append(name)
					i = close + 1
					continue
		i += 1
	return names


static func _lookup(name: String, vars: Dictionary) -> Variant:
	if vars.has(name):
		return vars[name]
	return vars.get(name.to_lower(), "")


static func _format_value(value: Variant) -> String:
	match typeof(value):
		TYPE_BOOL:
			return "true" if value else "false"
		TYPE_INT:
			return str(value)
		TYPE_FLOAT:
			if is_equal_approx(value, roundf(value)) and absf(value) < 1.0e15:
				return str(int(roundf(value)))
			return str(value)
	return str(value)


static func _is_bbcode_tag(content: String) -> bool:
	if _bbcode_tag == null:
		_bbcode_tag = RegEx.create_from_string(r"^/?[a-zA-Z_][a-zA-Z0-9_]*([= ][^\[\]]*)?$")
	return _bbcode_tag.search(content) != null


static func _scan(text: String, errors: Array) -> Dictionary:
	var out: String = ""
	var events: Array = []
	var visible: int = 0
	var no_wait: bool = false
	var nw_misplaced: bool = false
	var speed_open: bool = false
	var i: int = 0
	var n: int = text.length()

	while i < n:
		var c: String = text[i]

		if c == "[":
			var close: int = text.find("]", i + 1)
			if close != -1:
				var content: String = text.substr(i + 1, close - i - 1)
				if _is_bbcode_tag(content):
					out += text.substr(i, close - i + 1)
					if content == "lb" or content == "rb":
						visible += 1
						if no_wait:
							nw_misplaced = true
					i = close + 1
					continue

		if c == "{":
			if i + 1 < n and text[i + 1] == "{":
				out += "{"
				visible += 1
				if no_wait:
					nw_misplaced = true
				i += 2
				continue
			var end: int = text.find("}", i + 1)
			if end == -1:
				errors.append("Unclosed '{'")
				out += c
				visible += 1
				i += 1
				continue
			var body: String = text.substr(i + 1, end - i - 1).strip_edges()
			i = end + 1
			if body.begins_with("$"):
				continue
			var name: String = body
			var value: String = ""
			var has_value: bool = false
			var eq: int = body.find("=")
			if eq != -1:
				name = body.substr(0, eq).strip_edges()
				value = body.substr(eq + 1).strip_edges()
				has_value = true
			match name:
				"w":
					if not has_value:
						events.append({"at": visible, "type": "click", "value": 0.0})
					elif not value.is_valid_float() or value.to_float() < 0.0:
						errors.append("Tag '{%s}' needs a number of seconds" % body)
					else:
						events.append({"at": visible, "type": "wait", "value": value.to_float()})
				"p":
					if has_value:
						errors.append("Tag '{p}' takes no value")
					events.append({"at": visible, "type": "click", "value": 0.0})
					out += "\n"
					visible += 1
					if no_wait:
						nw_misplaced = true
				"speed":
					if not value.is_valid_float() or value.to_float() <= 0.0:
						errors.append("Tag '{%s}' needs a number above 0" % body)
					elif speed_open:
						errors.append("'{speed}' cannot be nested")
					else:
						speed_open = true
						events.append({"at": visible, "type": "speed", "value": value.to_float()})
				"/speed":
					if has_value:
						errors.append("Tag '{/speed}' takes no value")
					if not speed_open:
						errors.append("'{/speed}' has no matching '{speed}'")
					else:
						speed_open = false
						events.append({"at": visible, "type": "speed", "value": 1.0})
				"nw":
					if has_value:
						errors.append("Tag '{nw}' takes no value")
					no_wait = true
				_:
					errors.append("Unknown tag '{%s}'" % body)
			continue

		out += c
		visible += 1
		if no_wait and c.strip_edges() != "":
			nw_misplaced = true
		i += 1

	if speed_open:
		errors.append("'{speed}' is not closed")
	if nw_misplaced:
		errors.append("'{nw}' must be at the end of the line")

	return {"text": out, "events": events, "no_wait": no_wait}
