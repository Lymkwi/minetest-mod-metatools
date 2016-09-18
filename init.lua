--[[
	--	Metadata Tools
--
--	A mod providing write and read access to a nodes' metadata using commands
--	ßÿ Lymkwi/LeMagnesium/Mg ; 2015-2016
--	License: WTFPL
--	Contributors :
--		- Lymkwi/LeMagnesium
--		- Paly2
--
--	Version: 1.2
--
]]--

metatools = {} -- Public namespace
local playerdata = {} -- Will hold the positions of all players currently using metatools
local contexts = {}
local version = 1.3
local nodelock = {}

minetest.register_craftitem("metatools:stick",{
	description = "Meta stick",
	inventory_image = "metatools_stick.png",
	on_use = function(itemstack, user, pointed_thing)
		local username = user:get_player_name()
		local nodepos  = pointed_thing.under
		if not nodepos or not minetest.get_node(nodepos) then return end
		local nodename = minetest.get_node(nodepos).name
		local node	   = minetest.registered_nodes[nodename]
		local meta	   = minetest.get_meta(nodepos)
		local metalist = meta:to_table()

		minetest.chat_send_player(username, "- meta::stick - Node located at "..minetest.pos_to_string(nodepos))
		minetest.chat_send_player(username, "- meta::stick - Metadata fields dump : " .. dump(meta:to_table()["fields"]):gsub('\n', ""))
		minetest.log("action","[metatools] Player "..username.." saw metadatas of node at "..minetest.pos_to_string(nodepos))

	end,
})

-- Functions
function metatools.get_version() return version end

function metatools.build_param_str(table, index, separator)
	local str = table[index]
	for newindex = 1, #table-index do
		str = str .. (separator or ' ') .. table[newindex+index]
	end
	return str
end

function assign_context(pos, mode, owner)
	local i = 1
	while contexts[i] do i = i + 1 end

	contexts[i] = {
		owner = owner or "",
		position = pos,
		list = "",
		mode = mode
	}

	nodelock[minetest.pos_to_string(pos)] = owner or ""

	return i
end

function free_context(contextid)
	nodelock[minetest.pos_to_string(contexts[contextid].position)] = nil
	contexts[contextid] = nil
	return true
end

function assert_contextid(ctid)
	return contexts[ctid] ~= nil
end

function assert_ownership(ctid, name)
	return contexts[ctid].owner == "" or (name and contexts[ctid].owner == name)
end

function assert_pos(pos)
	return pos and pos.x and pos.y and pos.z and minetest.pos_to_string(pos)
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

function dump_normalize(dmp)
	return dump(dmp):gsub('\n', ''):gsub('\t', ' ')
end

function meta_exec(scope, func, ...)
	local ret, msg = func(...)
	if ret then
		return true, ("- %s - Success : %s"):format(scope, msg)
	else
		return false, ("- %s - Failure : %s"):format(scope, msg)
	end
end

function metatools.contexts_summary()
	local ctxs = {}
	for ctxid, ctx in pairs(contexts) do
		table.insert(ctxs, 1, {id=ctxid, pos=ctx.position, owner=ctx.owner})
	end
	return true, ctxs
end

function metatools.open_node(pos, mode, owner)
	if not assert_pos(pos) then
		return false, "invalid pos " .. dump_normalize(pos)
	end

	if not assert_mode(mode) then
		return false, "invalid mode " .. dump_normalize(mode)
	end

	if not assert_poslock(pos) then
		if nodelock[minetest.pos_to_string(pos)] ~= "" then
			return false, "node already opened by " .. nodelock[minetest.pos_to_string(pos)]
		else
			return false, "node already opened"
		end
	end

	return true, "opened node " .. minetest.get_node(pos).name .. " at " .. minetest.pos_to_string(pos) .. " in context ID " .. assign_context(pos, mode, owner)
end

function metatools.close_node(contextid)--, closer)
	if not assert_contextid(contextid) then
		return false, "invalid contextid " .. dump_normalize(contextid)
	end

--	if closer and not assert_ownership(contextid, closer) then
--		return false, "you do not have permission to close that node"
--	end

	free_context(contextid)
	return true, "node closed"
end

function metatools.show(contextid)
	if not assert_contextid(contextid) then
		return false, "invalid contextid " .. dump_normalize(contextid)
	end

	local ctx = contexts[contextid]
	local metabase = minetest.get_meta(ctx.position):to_table()[ctx.mode]
	if assert_specific_mode(contextid, "inventory") and ctx.list ~= "" then
		metabase = metabase[ctx.list]
	end

	return true, metabase
end

function metatools.list_enter(contextid, listname)
	if not assert_contextid(contextid) then
		return false, "invalid contexid " .. dump_normalize(contextid)
	end

	if not assert_specific_mode(contextid, "inventory") then
		return false, "invalid mode, inventory mode required"
	end

	if not listname then
		return false, "no list name provided"
	end

	local ctx = contexts[contextid]
	if ctx.list ~= "" then
		return false, "unable to reach another list until leaving the current one"
	end

	local _, metabase = metatools.show(contextid)
	if not metabase[listname] or type(metabase[listname]) ~= "table" then
		return false, "inexistent or invalid list called " .. dump_normalize(listname)
	end

	contexts[contextid].list = listname
	return true, "entered list " .. listname
end

function metatools.list_leave(contextid)
	if not assert_contextid(contextid) then
		return false, "invalid contextid " .. dump_normalize(contextid)
	end

	if not assert_specific_mode(contextid, "inventory") then
		return false, "invalid mode, inventory mode required"
	end

	local ctx = contexts[contextid]
	if ctx.list == "" then
		return false, "cannot leave, not in a list"
	end

	ctx.list = ""
	return true, "left list"
end

function metatools.set(contextid, ftype, varname, varval)
	if not assert_contextid(contextid) then
		return false, "invalid contextid " .. dump_normalize(contextid)
	end

	if not assert_specific_mode(contextid, "fields") then
		return false, "invalid mode, fields mode required"
	end

	if not assert_field_type(ftype) then
		return false, "invalid field type " .. dump_normalize(ftype)
	end

	if not varname or varname == "" then
		return false, "invalid or empty variable name"
	end

	if not varval then
		return false, "missing value, use unset to set variable to nil"
	end

	local ctx = contexts[contextid]
	local meta = minetest.get_meta(ctx.position)

	if ftype == "string" then
		meta:set_string(varname, ("%s"):format(varval))
	elseif ftype == "int" then
		if not tonumber(varval) then
			return false, "invalid integer value " .. dump_normalize(varval)
		end
		meta:set_int(varname, tonumber(varval))
	else
		if not tonumber(varval) then
			return false, "invalid float value " .. dump_normalize(varval)
		end
		meta:set_float(varname, tonumber(varval))
	end
	return true, "value of field " .. varname .. " set to " .. varval
end

function metatools.unset(contextid, varname)
	if not assert_contextid(contextid) then
		return false, "invalid contextid " .. dump_normalize(contextid)
	end

	if not assert_specific_mode(contextid, "fields") then
		return false, "invalid mode, fields mode required"
	end

	if not varname or varname == "" then
		return false, "invalid or empty variable name"
	end

	minetest.get_meta(contexts[contextid].position):set_string(varname, nil)
	return true, "field " .. varname .. " unset"
end

function metatools.purge(contextid)
	if not assert_contextid(contextid) then
		return false, "invalid context id " .. dump_normalize(contextid)
	end

	local ctx = contexts[contextid]
	local meta = minetest.get_meta(ctx.position)
	if ctx.mode == "inventory" then
		local inv = meta:get_inventory()
		inv:set_lists(nil)
		return true, "inventory purged"
	
	else
		meta:from_table(nil)
		return true, "fields purged"
	end
end

function metatools.list_init(contextid, listname, size)
	if not assert_contextid(contextid) then
		return false, "invalid context id " .. dump_normalize(contextid)
	end

	if not assert_specific_mode(contextid, "inventory") then
		return false, "invalid mode, inventory mode is required"
	end

	if not listname or listname == "" then
		return false, "missing or empty list name"
	end

	if not size or not assert_integer(size) or tonumber(size) < 0 then
		return false, "invalid size " .. dump_normalize(contextid)
	end

	local inv = minetest.get_meta(contexts[contextid].position):get_inventory()
	inv:set_list(listname, {})
	inv:set_size(listname, tonumber(size))

	return true, "list " .. listname .. " of size " .. size .. " created"
end

function metatools.list_delete(contextid, listname)
	if not assert_contextid(contextid) then
		return false, "invalid context id " .. dump_normalize(contextid)
	end

	if not assert_specific_mode(contextid, "inventory") then
		return false, "invalid mode, inventory mode is required"
	end

	if not listname or listname == "" then
		return false, "missing or empty list name"
	end

	local ctx = contexts[contextid]
	if ctx.list == listname then
		ctx.list = ""
	end

	local inv = minetest.get_meta(ctx.position):get_inventory()
	inv:set_list(listname, {})
	inv:set_size(listname, 0)

	return true, "list " .. listname .. " deleted"
end

function metatools.itemstack_erase(contextid, index)
	if not assert_contextid(contextid) then
		return false, "invalid context id " .. dump_normalize(contextid)
	end

	if not assert_specific_mode(contextid, "inventory") then
		return false, "invalid mode, inventory mode required"
	end

	if not assert_integer(index) or tonumber(index) < 0 then
		return false, "invalid index"
	end

	local ctx = contexts[contextid]
	if ctx.list == "" then
		return false, "your presence is required in a list"
	end

	local inv = minetest.get_meta(ctx.position):get_inventory()
	if tonumber(index) > inv:get_size(ctx.list) then
		return false, "index value higher than list size"
	end
	inv:set_stack(ctx.list, tonumber(index), nil)
	return true, "itemstack at index " .. index .. " erased"
end

function metatools.itemstack_write(contextid, index, data)
	if not assert_contextid(contextid) then
		return false, "invalid context id " .. dump_normalize(contextid)
	end

	if not assert_specific_mode(contextid, "inventory") then
		return false, "invalid mode, inventory mode required"
	end

	if not assert_integer(index) or tonumber(index) < 0 then
		return false, "invalid index"
	end

	local stack = ItemStack(data)
	if not stack then
		return false, "invalid itemstack representation " .. dump_normalize(data)
	end

	local ctx = contexts[contextid]
	if ctx.list == "" then
		return false, "your presence is required in a list"
	end

	local inv = minetest.get_meta(ctx.position):get_inventory()
	if tonumber(index) > inv:get_size(ctx.list) then
		return false, "index value higher than list size"
	end
	inv:set_stack(ctx.list, tonumber(index), stack)
	return true, "itemstack at index " .. index .. " written"
end

function metatools.itemstack_add(contextid, data)
	if not assert_contextid(contextid) then
		return false, "invalid context id " .. dump_normalize(contextid)
	end

	if not assert_specific_mode(contextid, "inventory") then
		return false, "invalid mode, inventory mode required"
	end

	local stack = ItemStack(data)
	if not stack then
		return false, "invalid itemstack representation " .. dump_normalize(data)
	end

	local ctx = contexts[contextid]
	if ctx.list == "" then
		return false, "your presence is required in a list"
	end

	local inv = minetest.get_meta(ctx.position):get_inventory()
	inv:add_item(ctx.list, stack)
	return true, "added " .. data .. " in list " .. ctx.list
end

-- Main chat command
minetest.register_chatcommand("meta", {
	privs = {server=true},
	params = "help | version | open (x,y,z) {mode} | show | enter <name> | leave | set <name> <value> | unset <name> | purge | list <init/delete> <name> <size>| itemstack <write/erase> <index> <data> | close",
	description = "Metadata manipulation command",
	func = function(name, paramstr)
		-- name : Ingame name of the manipulating player
		-- paramstr : string with all parameters

		if paramstr == "" then
			return true, "- meta - Consult '/meta help' for a better understanding of the meta command"
		end

		local params = paramstr:split(' ')
		--[[
		--	Param map
		--		[1] = Action
		--		[2] = Position (meta open), Gateway (meta open), Variable Name (meta unset, meta set), ItemStack Action (meta itemstack)
		--		[3] = Open mode (meta open), Value (meta set), Inventory Index (meta itemstack <read/write/erase>)
		--
		]]--

		-- meta version
		if params[1] == "version" then
			return true, "- meta::version - Metatools version " .. metatools.get_version()

		-- meta help
		elseif params[1] == "help" then
			return true, "- meta::help - Help : \n" ..
				"- meta::help - /meta version : Prints out the version\n" ..
				"- meta::help - /meta help : This very command\n" ..
				"- meta::help - /meta open <(x,y,z) [mode] : Open not at (x,y,z) with mode 'mode' (either 'fields' or 'inventory'; default is 'fields')\n" ..
				"- meta::help - /meta close <ctxindex> : Close the node which context id is 'contextid'\n" ..
				"- meta::help - /meta show <ctxindex> : Show you the fields/lists available\n" ..
				"- meta::help - /meta set <ctxindex> <ftype> <name> <value> : Set variable 'name' to 'value', overriding any existing data using data type 'ftype'\n" ..
				"- meta::help - /meta unset <ctxindex> <name> : Set variable 'name' to nil, ignoring whether it exists or not\n" ..
				"- meta::help - /meta purge <ctxindex> : Purge all metadata variables\n" ..
				"- meta::help - /meta list : List manipulation :\n" ..
				"- meta::help - /meta list enter <ctxindex> <name> : Enter in list <name>\n" ..
				"- meta::help - /meta list leave <ctxindex> : Go back to the top level of inventory data\n" ..
				"- meta::help - /meta list init <ctxindex> <name> <size> : Initialize list 'name' of size 'size', overriding any existing data\n" ..
				"- meta::help - /meta list delete <ctxindex> <name> : Delete list 'name', ignoring whether it exists or not\n" ..
				"- meta::help - /meta itemstack : ItemStack manipulation :\n" ..
				"- meta::help - /meta itemstack write <ctxindex> <index> <data> : Write an itemstack represented by 'data' at index 'index' of the list you are in\n" ..
				"- meta::help - /meta itemstack add <ctxindex> <data> : Add items of an itemstack represented by 'data' in the list you are in\n" ..
				"- meta::help - /meta itemstack erase <ctxindex> <index> : Remove itemstack at index 'index' in the current inventory, regardless of whether it exists or not\n" ..
				"- meta::help - End of Help"

		-- meta context
		elseif params[1] == "contexts" then
			local _, ctxs = metatools.contexts_summary()
			local retstr = ""
			for _, summ in pairs(ctxs) do
				retstr = retstr .. ("- meta::contexts : %d: Node at %s owner by %s\n"):
					format(summ.id, minetest.pos_to_string(summ.pos), summ.owner)
			end
			return true, retstr .. ("- meta::contexts - %d contexts"):format(#ctxs)
		
		-- meta open (x,y,z) [fields|inventory]
		elseif params[1] == "open" then

			-- Call the API function
			return meta_exec("meta::open", metatools.open_node, minetest.string_to_pos(params[2]), params[3] or "fields", name)

		-- meta close
		elseif params[1] == "close" then
			-- Call the API function
			return meta_exec("meta::close", metatools.close_node, tonumber(params[2]) or "invalid or missing id", name)

		-- meta show
		elseif params[1] == "show" then
			local status, fieldlist = metatools.show(tonumber(params[2]) or "invalid or missing id")
			if not status then
				return status, fieldlist
			else
				local retstr = "- meta::show - Output :\n"
				for name, field in pairs(fieldlist) do
					local rpr
					if type(field) == "table" then
						rpr = ("-> {...} (size %s)"):format(#field)
					elseif type(field) == "string" then
						rpr = ("= %s"):format(dump_normalize(field))
					elseif type(field) == "userdata" then
						if field.get_name and field.get_count then
							rpr = ("= ItemStack({name='%s', count=%d, metadata='%s'})"):
								format(field:get_name(), field:get_count(), field:get_metadata())
						else
							rpr = ("= %s"):format(dump_normalize(field))
						end
					else
						rpr = ("= %s"):format(field)
					end
					retstr = retstr .. ("- meta::show -     %s %s\n"):format(name, rpr)
				end
				return true, retstr .. "- meta::show - End of output"
			end

		-- meta set <type> <varname> <value>
		elseif params[1] == "set" then
			return meta_exec("meta::set", metatools.set, tonumber(params[2]) or "invalid or missing contextid", params[3], params[4], metatools.build_param_str(params, 5, ' '))

		-- meta unset <varname>
		elseif params[1] == "unset" then
			return meta_exec("meta::unset", metatools.unset, tonumber(params[2]) or "invalid or missing contextid", params[3])

		-- meta purge
		elseif params[1] == "purge" then
			return meta_exec("meta::purge", metatools.purge, tonumber(params[2]) or "missing or invalid id")

		-- meta list...
		elseif params[1] == "list" then
			if not params[2] then
				return false, "- meta::list - Subcommand needed, consult '/meta help' for help"
			end

			-- meta list enter <listname>
			if params[2] == "enter" then
				return meta_exec("meta::list::enter", metatools.list_enter, tonumber(params[3]) or "invalid or missing contextid", params[4])

			-- meta list leave
			elseif params[2] == "leave" then
				return meta_exec("meta::list::leave", metatools.list_leave, tonumber(params[3]) or "invalid or missing contextid")

			-- meta list init <name> <size>
			elseif params[2] == "init" then
				return meta_exec("meta::list::init", metatools.list_init, tonumber(params[3]) or "invalid or missing contextid", params[4], params[5])

			-- meta list delete <name>
			elseif params[2] == "delete" then
				return meta_exec("meta::list::delete", metatools.list_delete, tonumber(params[3]) or "invalid or missing contextid", params[4])

			else
				return false, "- meta::list - Unknown subcommand '" .. params[2] .. "', please consult '/meta help' for help"
			end

		-- meta itemstack...
		elseif params[1] == "itemstack" then
			if not params[2] then
				return false, "- meta::itemstack - Subcommand needde, consult '/meta help' for help"
			end

			-- meta itemstack erase <index>
			if params[2] == "erase" then
				return meta_exec("meta::itemstack::erase", metatools.itemstack_erase, tonumber(params[3]) or "invalid or missing contextid", params[4])

			-- meta itemstack write <index> <itemstack>
			elseif params[2] == "write" then
				return meta_exec("meta::itemstack::write", metatools.itemstack_write, tonumber(params[3]) or "invalid or missing contextid", params[4], metatools.build_param_str(params, 5, ' '))
			
			-- meta itemstack add <itemstack>
			elseif params[2] == "add" then
				return meta_exec("meta::itemstack::add", metatools.itemstack_add, tonumber(params[3]) or "invalid or missing contextid", metatools.build_param_str(params, 4, ' '))

			else
				return false, "- meta::itemstack - Unknown subcommand " .. params[2]
			end

		else
			return false, "- meta - Unknown command " .. params[1]
		end
	end,
})
