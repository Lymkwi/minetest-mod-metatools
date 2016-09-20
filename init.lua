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
--	Version: 1.2.2
--
]]--

metatools = {} -- Public namespace
metatools.contexts = {}
metatools.playerlocks = {} -- Selection locks of the players
local version = "1.2.2"
local nodelock = {}

local modpath = minetest.get_modpath("metatools")
dofile(modpath .. "/assertions.lua")

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

-- Useful callbacks
minetest.register_on_dignode(function(pos, node, digger)
	local spos = minetest.pos_to_string(pos)
	local ctxid = metatools.get_context_from_pos(pos)
	if ctxid then
		if not metatools.get_context_owner(ctxid) then
			metatools.alert_users("Node at " .. spos .. " dug by " .. (digger:get_player_name() or " a drone ") .. " : context " .. ctxid .. " closed")
			metatools.close_node(ctxid)
		else
			local owner = metatools.get_context_owner(ctxid)
			if owner == digger:get_player_name() then
				metatools.alert_users(owner .. " dug themselves out of node at " .. spos .. " : context " .. ctxid .. "closed")
				metatools.close_node(ctxid)
			else
				minetest.chat_send_player(digger:get_player_name() or "", "- meta - You are not allowed to dig the present node at " .. spos .. " : someone is operating on it")
				minetest.chat_send_player(metatools.get_context_owner(ctxid), "- meta - " .. digger:get_player_name() .. " tried to dig the node you are operating on")
				return true
			end
		end
	end
end)

-- Functions
function metatools.get_version() return version end

function metatools.get_context_from_pos(pos)
	for id, ctx in pairs(metatools.contexts) do
		if minetest.pos_to_string(ctx.position) == minetest.pos_to_string(pos) then
			return id
		end
	end
end

function metatools.alert_users(msg)
	for name, _ in pairs(metatools.playerlocks) do
		minetest.chat_send_player(name, ("- meta::alert - ALERT: %s"):format(msg))
	end
end

function metatools.build_param_str(table, index, separator)
	local str = table[index]
	for newindex = 1, #table-index do
		str = str .. (separator or ' ') .. table[newindex+index]
	end
	return str
end

function metatools.get_player_selection(name)
	return metatools.playerlocks[name]
end

function metatools.player_select(name, ctxid)
	metatools.playerlocks[name] = ctxid
	return true, ("context %d selected"):format(ctxid)
end

function metatools.player_unselect(name)
	metatools.playerlocks[name] = nil
	return true, "context unselected"
end

function metatools.switch(contextid)
	local ctx = metatools.contexts[contextid]
	if ctx.mode == "inventory" then
		ctx.mode = "fields"
	else
		ctx.mode = "inventory"
	end
	ctx.list = ""
	return true, "switched to mode " .. ctx.mode
end

function metatools.get_context_owner(ctxid)
	for name, id in pairs(metatools.playerlocks) do
		if id == ctxid then
			return name
		end
	end
end

function assign_context(pos, mode, owner)
	local i = 1
	while metatools.contexts[i] do i = i + 1 end

	metatools.contexts[i] = {
		owner = owner or "",
		position = pos,
		list = "",
		mode = mode
	}

	nodelock[minetest.pos_to_string(pos)] = owner or ""

	return i
end

function free_context(contextid)
	nodelock[minetest.pos_to_string(metatools.contexts[contextid].position)] = nil
	metatools.contexts[contextid] = nil
	return true
end

function dump_normalize(dmp)
	return dump(dmp):gsub('\n', ''):gsub('\t', ' ')
end

--function meta_assertion(assert_type, params)

function meta_exec(struct)
	if not struct.scope then
		struct.scope = "meta"
	end

	if not struct.func then
		return
	end

	if struct.required then
		-- will call meta_assertion from here
		for category, req in pairs(struct.required) do
			if category == "position" and not assert_pos(req) then
				return false, ("- %s - Failure : Invalid position : %s"):format(struct.scope, dump_normalize(req))
			
			elseif category == "contextid" and not assert_contextid(req) then
				return false, ("- %s - Failutre : Invalid contextid : %s"):format(struct.scope, dump_normalize(req))

			elseif category == "no_nodelock" then
				if not assert_pos(req) then
					return false, ("- %s - Failure : Invalid pos : %s"):format(struct.scope, dump_normalize(req))
				end
				local npos = req
				if type(npos) == "table" then
					npos = minetest.pos_to_string(npos)
				end
				if nodelock[npos] then
					return false, ("- %s - Failure : Nodelock on %s"):format(struct.scope, dump_normalize(req))
				end

			elseif category == "open_mode" and not assert_mode(req) then
				return false, ("- %s - Failure : Invalid mode %s"):format(struct.scope, dump_normalize(req))

			elseif category == "ownership" then
				if type(req) ~= "table" or not req.name then
					return false, ("- %s - Failure : Requirement of ownership invalid or missing a 'name' field"):format(struct.scope)
				end

				if req.contextid then
					if not assert_contextid(req.contextid) then
						return false, ("- %s - Failure : Invalid context id %s"):format(struct.scope, req.contextid)
					end
					if not assert_ownership(req.contextid, req.name) then
						return false, ("- %s - Failure : Context %d is not owner by %s"):format(struct.scope, req.contextid, req.name)
					end
				else
					return false, ("- %s - Failure : No context selected"):format(struct.scope)
				end

			elseif category == "no_ownership" then
				if not assert_contextid(req) then
					return false, ("- %s - Failure : Invalid context id %s"):format(struct.scope, dump_normalize(req))
				elseif metatools.get_context_owner(req) then
					return false, ("- %s - Failure : Node already owned"):format(struct.scope)
				end

			elseif category == "some_ownership" and (not req or not metatools.playerlocks[req]) then
				return false, ("- %s - Failure : No context owned at the moment"):format(struct.scope)

			elseif category == "specific_open_mode" then
				if not req or not req.mode or not req.contextid then
					return false, ("- %s - Failure : Invalid specific open mode requirement"):format(struct.scope)
				end

				if not assert_contextid(req.contextid) then
					return false, ("- %s - Failure : Invalid context id : %s"):format(struct.scope, dump_normalize(req.contextid))
				end
				
				if not metatools.contexts[req.contextid].mode == req.mode then
					return false, ("- %s - Failure : Invalid mode, %s is required"):format(struct.scope, dump_normalize(req.mode))
				end
			end
		end
	end

	local ret, msg = struct.func(unpack(struct.params))
	if ret then
		if struct.success then
			struct.success(struct.params, {ret, msg})
		end
		return true, ("- %s - Success : %s"):format(struct.scope, msg)
	else
		return false, ("- %s - Failure : %s"):format(struct.scope, msg)
	end
end

function metatools.contexts_summary()
	local ctxs = {}
	for ctxid, ctx in pairs(metatools.contexts) do
		table.insert(ctxs, 1, {
			id = ctxid,
			pos = ctx.position,
			owner = metatools.get_context_owner(ctxid) or "nobody",
			mode = ctx.mode,
		})
	end
	return true, ctxs
end

function metatools.open_node(pos, mode, owner)
	local id = assign_context(pos, mode)
	if owner then
		metatools.playerlocks[owner] = id
	end
	return true, "opened node " .. minetest.get_node(pos).name .. " at " .. minetest.pos_to_string(pos) .. " in context ID " .. id
end

function metatools.close_node(contextid)--, closer)
	free_context(contextid)
	return true, "node closed"
end

function metatools.show(contextid)
	if not assert_contextid(contextid) then
		return false, "invalid or missing context id"
	end
	local ctx = metatools.contexts[contextid]
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

	local ctx = metatools.contexts[contextid]
	if ctx.list ~= "" then
		return false, "unable to reach another list until leaving the current one"
	end

	local _, metabase = metatools.show(contextid)
	if not metabase[listname] or type(metabase[listname]) ~= "table" then
		return false, "inexistent or invalid list called " .. dump_normalize(listname)
	end

	metatools.contexts[contextid].list = listname
	return true, "entered list " .. listname
end

function metatools.list_leave(contextid)
	if not assert_contextid(contextid) then
		return false, "invalid contextid " .. dump_normalize(contextid)
	end

	if not assert_specific_mode(contextid, "inventory") then
		return false, "invalid mode, inventory mode required"
	end

	local ctx = metatools.contexts[contextid]
	if ctx.list == "" then
		return false, "cannot leave, not in a list"
	end

	ctx.list = ""
	return true, "left list"
end

function metatools.set(contextid, varname, varval)
	if not varname or varname == "" then
		return false, "invalid or empty variable name"
	end

	if not varval then
		return false, "missing value, use unset to set variable to nil"
	end

	local ctx = metatools.contexts[contextid]
	local meta = minetest.get_meta(ctx.position)

	meta:set_string(varname, ("%s"):format(varval))
	return true, "value of field " .. varname .. " set to " .. varval
end

function metatools.unset(contextid, varname)
	if not varname or varname == "" then
		return false, "invalid or empty variable name"
	end

	minetest.get_meta(metatools.contexts[contextid].position):set_string(varname, nil)
	return true, "field " .. varname .. " unset"
end

function metatools.purge(contextid)
	local ctx = metatools.contexts[contextid]
	local meta = minetest.get_meta(ctx.position)
	if ctx.mode == "inventory" then
		local inv = meta:get_inventory()
		inv:set_lists({})
		return true, "inventory purged"
	
	else
		meta:from_table(nil)
		return true, "fields purged"
	end
end

function metatools.prune()
	for id, ctx in pairs(metatools.contexts) do
		if not metatools.get_context_owner(id) then
			metatools.close_node(id)
		end
	end
	return true, "contexts pruned"
end

function metatools.list_init(contextid, listname, size)
	if not listname or listname == "" then
		return false, "missing or empty list name"
	end

	if not size or not assert_integer(size) or tonumber(size) < 0 then
		return false, "invalid size " .. dump_normalize(size)
	end

	local inv = minetest.get_meta(metatools.contexts[contextid].position):get_inventory()
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

	local ctx = metatools.contexts[contextid]
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

	local ctx = metatools.contexts[contextid]
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

	local ctx = metatools.contexts[contextid]
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

	local ctx = metatools.contexts[contextid]
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

		-- meta version
		if params[1] == "version" then
			return true, "- meta::version - Metatools version " .. metatools.get_version()

		-- meta help
		elseif params[1] == "help" then
			return true, "- meta::help - Help : \n" ..
				"- meta::help - /meta version : Prints out the version\n" ..
				"- meta::help - /meta help : This very command\n" ..
				"- meta::help - /meta open <(x,y,z) [mode] : Open not at (x,y,z) with mode 'mode' (either 'fields' or 'inventory'; default is 'fields')\n" ..
				"- meta::help - /meta select <contextid> : Select the node with context <contextid> for operations\n" ..
				"- meta::help - /meta unselect : Unselect the context you are currently in\n" ..
				"- meta::help - /meta contexts : Show all open contexts with id, operator, position and open mode\n" ..
				"- meta::help - /meta switch : Switch open mode in the current context\n" ..
				"- meta::help - /meta close : Close the currently selected node\n" ..
				"- meta::help - /meta prune : Close all currently unoperated nodes\n" ..
				"- meta::help - /meta show : Show you the fields/lists available\n" ..
				"- meta::help - /meta set <name> <value> : Set variable 'name' to 'value', overriding any existing data\n" ..
				"- meta::help - /meta unset <name> : Set variable 'name' to nil, ignoring whether it exists or not\n" ..
				"- meta::help - /meta purge : Purge all metadata variables or inventory lists (depending on the open mode)\n" ..
				"- meta::help - /meta list : List manipulation :\n" ..
				"- meta::help - /meta list enter <name> : Enter in list <name>\n" ..
				"- meta::help - /meta list leave : Go back to the top level of inventory data\n" ..
				"- meta::help - /meta list init <name> <size> : Initialize list 'name' of size 'size', overriding any existing data\n" ..
				"- meta::help - /meta list delete <name> : Delete list 'name', ignoring whether it exists or not\n" ..
				"- meta::help - /meta itemstack : ItemStack manipulation :\n" ..
				"- meta::help - /meta itemstack write <index> <data> : Write an itemstack represented by 'data' at index 'index' of the list you are in\n" ..
				"- meta::help - /meta itemstack add <data> : Add items of an itemstack represented by 'data' in the list you are in\n" ..
				"- meta::help - /meta itemstack erase <index> : Remove itemstack at index 'index' in the current inventory, regardless of whether it exists or not\n" ..
				"- meta::help - End of Help"

		-- meta context
		elseif params[1] == "contexts" then
			local _, ctxs = metatools.contexts_summary()
			local retstr = ""
			for _, summ in pairs(ctxs) do
				retstr = retstr .. ("- meta::contexts : %d: [%s] Node at %s owner by %s\n"):
					format(summ.id, summ.mode, minetest.pos_to_string(summ.pos), summ.owner)
			end
			return true, retstr .. ("- meta::contexts - %d contexts"):format(#ctxs)
		
		-- meta open (x,y,z) [fields|inventory]
		elseif params[1] == "open" then

			-- Call the API function
			if not params[3] then
				params[3] = "fields"
			end
			return meta_exec({
				scope = "meta::open",
				func = metatools.open_node,
				params = {minetest.string_to_pos(params[2]), params[3], name},
				required = {
					mode = params[3],
					no_nodelock = params[2],
				},
				success = function(fparams)
					metatools.alert_users(name .. " opened node at " .. minetest.pos_to_string(fparams[1]))
				end
			})

		-- meta close
		elseif params[1] == "close" then
			-- Call the API function
			return meta_exec({
				scope = "meta::close",
				func = metatools.close_node,
				params = {metatools.get_player_selection(name)},
				required = {
					ownership = {
						contextid = metatools.get_player_selection(name),
						name = name
					}
				},
				success = function(fparams)
					metatools.alert_users(name .. " closed node of id " .. fparams[1])
				end
			})

		-- meta select <contextid>
		elseif params[1] == "select" then
			return meta_exec({
				scope = "meta::select",
				func = metatools.player_select,
				params = {name, tonumber(params[2])},
				required = {
					no_ownership = tonumber(params[2]),
				},
				success = function(fparams)
					metatools.alert_users(name .. " selected context of id " .. fparams[1])
				end
			})

		-- meta unselect
		elseif params[1] == "unselect" then
			return meta_exec({
				scope = "meta::unselect",
				func = metatools.player_unselect,
				params = {name},
				required = {
					some_ownership = name,
				},
				success = function(fparams)
					metatools.alert_users(name .. " unselected their context")
				end
			})

		-- meta prune
		elseif params[1] == "prune" then
			return meta_exec({
				scope = "meta::prune",
				func = metatools.prune,
				params = {},
				success = function()
					metatools.alert_users(name .. " is pruning contexts!")
				end
			})

		-- meta switch
		elseif params[1] == "switch" then
			return meta_exec({
				scope = "meta::switch",
				func = metatools.switch,
				params = {metatools.get_player_selection(name)},
				required = {
					some_ownership = name,
				},
				success = function(fparams)
					metatools.alert_users(name .. " switched context (ID=" .. fparams[1] .. ")'s open mode")
				end
			})

		-- meta show
		elseif params[1] == "show" then
			return meta_exec({
				scope = "meta::show",
				func = function()
					local status, fieldlist = metatools.show(metatools.get_player_selection(name))
					if not status then
						return status, fieldlist
					else
						local retstr = "Output :\n"
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
				end,
				params = {},
				required = {
					some_ownership = name
				}
			})

		-- meta set <varname> <value>
		elseif params[1] == "set" then
			return meta_exec({
				scope = "meta::set",
				func = metatools.set,
				params = {metatools.get_player_selection(name), params[2], metatools.build_param_str(params, 3, ' ')},
				required = {
					some_ownership = name,
					specific_open_mode = {
						mode = "fields",
						contextid = metatools.get_player_selection(name)
					}
				}
			})


		-- meta unset <varname>
		elseif params[1] == "unset" then
			return meta_exec({
				scope = "meta::unset",
				func = metatools.unset,
				params = {metatools.get_player_selection(name), params[2]},
				required = {
					some_ownership = name,
					specific_open_mode = {
						mode = "fields",
						contextid = metatools.get_player_selection(name)
					}
				}
			})
			
		-- meta purge
		elseif params[1] == "purge" then
			return meta_exec({
				scope = "meta::purge",
				func = metatools.purge,
				params = {metatools.get_player_selection(name)},
				required = {
					some_ownership = name,
				},
				success = function(fparams)
					metatools.alert_users(name .. " purged context " .. fparams[1])
				end
			})

		-- meta list...
		elseif params[1] == "list" then
			if not params[2] then
				return false, "- meta::list - Subcommand needed, consult '/meta help' for help"
			end

			-- meta list enter <listname>
			if params[2] == "enter" then
				return meta_exec({
					scope = "meta::list::enter",
					func = metatools.list_enter,
					params = {metatools.get_player_selection(name), params[3]},
					required = {
						some_ownership = name,
						specific_open_mode = {
							contextid = metatools.get_player_selection(name),
							mode = "inventory",
						},
					}
				})

			-- meta list leave
			elseif params[2] == "leave" then
				return meta_exec({
					scope = "meta::list::leave",
					func = metatools.list_leave,
					params = {metatools.get_player_selection(name)},
					required = {
						some_ownership = name,
						specific_open_mode = {
							contextid = metatools.get_player_selection(name),
							mode = "inventory",
						}
					}
				})

			-- meta list init <name> <size>
			elseif params[2] == "init" then
				return meta_exec({
					scope = "meta::list::init",
					func = metatools.list_init,
					params = {metatools.get_player_selection(name), params[3], params[4]},
					required = {
						some_ownership = name,
						specific_open_mode = {
							contextid = metatools.get_player_selection(name),
							mode = "inventory",
						}
					}
				})

			-- meta list delete <name>
			elseif params[2] == "delete" then
				return meta_exec({
					scope = "meta::list::delete",
					func = metatools.list_delete,
					params = {metatools.get_player_selection(name), params[3]},
					required = {
						some_ownership = name,
						specific_open_mode = {
							contextid = metatools.get_player_selection(name),
							mode = "inventory",
						}
					}
				})
			
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
				return meta_exec({
					scope = "meta::itemstack::erase",
					func = metatools.itemstack_erase,
					params = {metatools.get_player_selection(name), params[3]},
					required = {
						some_ownership = name,
						specific_open_mode = {
							contextid = metatools.get_player_selection(name),
							mode = "inventory",
						}
					}
				})

			-- meta itemstack write <index> <itemstack>
			elseif params[2] == "write" then
				return meta_exec({
					scope = "meta::itemstack::write",
					func = metatools.itemstack_write,
					params = {metatools.get_player_selection(name), params[3], metatools.build_param_str(params, 4, ' ')},
					required = {
						some_ownership = name,
						specific_open_mode = {
							contextid = metatools.get_player_selection(name),
							mode = "inventory",
						}
					}
				})
			
			-- meta itemstack add <itemstack>
			elseif params[2] == "add" then
				return meta_exec({
					scope = "meta::itemstack::write",
					func = metatools.itemstack_add,
					params = {metatools.get_player_selection(name), metatools.build_param_str(params, 3, ' ')},
					required = {
						some_ownership = name,
						specific_open_mode = {
							contextid = metatools.get_player_selection(name),
							mode = "inventory",
						}
					}
				})

			else
				return false, "- meta::itemstack - Unknown subcommand " .. params[2]
			end

		else
			return false, "- meta - Unknown command " .. params[1]
		end
	end,
})
