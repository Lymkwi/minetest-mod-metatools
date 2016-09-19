-- Assertion tools for Metatools

function assert_contextid(ctid)
	return contexts[ctid] ~= nil
end

function assert_ownership(ctid, name)
	return playerlocks[name] == ctid
end

function assert_pos(pos)
	if type(pos) ~= "string" then
		return pos and pos.x and pos.y and pos.z and minetest.pos_to_string(pos)
	else
		return minetest.string_to_pos(pos) ~= nil
	end
end

function assert_mode(mode)
	return mode and (mode == "fields" or mode == "inventory")
end

function assert_poslock(pos)
	return nodelock[minetest.pos_to_string(pos)] == nil
end

function assert_specific_mode(contextid, mode)
	return assert_contextid(contextid) and contexts[contextid].mode == mode
end

function assert_field_type(ftype)
	return ftype and type(ftype) == "string" and (ftype == "int" or ftype == "float" or ftype == "string")
end

function assert_integer(int)
	return int and tonumber(int) and tonumber(int) % 1 == 0
end

