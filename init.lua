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
local version = 1.2

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

function metatools.get_metalist(pname)
	if not pname or not playerdata[pname] then return end

	local metabase = minetest.get_meta(playerdata[pname].position):to_table()[playerdata[pname].mode]
	for strat = 1, playerdata[pname].stratum-1 do
		if metabase[playerdata[pname].path[strat]] then
			metabase = metabase[playerdata[pname].path[strat]]
		else
			playerdata[pname.stratum] = strat
			return true, "- meta::get_metalist - Warning! Gateway '" .. playerdata[pname].path[strat] .. "' doesn't exist any more, saying at Stratum " .. strat
		end
	end
	return metabase
end

function metatools.open_node(pname, pos, mode)
	if not pname then
		return false, "- meta::open - No player name provided"
	end

	-- If no mode, open fields
	if not mode then
		mode = "fields"
	-- Or else, check for the mode to be correct
	elseif type(mode) ~= "string" or (mode ~= "fields" and mode ~= "inventory") then
		return false, ("- meta::open - Invalid opening mode : %s ; it must be either 'fields' or 'inventory'"):format(mode)
	end

	-- Is the position correct?
	if not pos.x or not pos.y or not pos.z then
		return false, "Invalid position table " .. (dump(pos):gsub('\n', ""))
	end

	minetest.forceload_block(pos)
	playerdata[pname] = {
		position = pos,
		mode = mode,
		path = {},
		stratum = 1,
	}
	return true, "- meta::open - Node " .. minetest.get_node(pos).name .. " at " .. minetest.pos_to_string(pos) .. " opened (mode: " .. mode .. ")"

end

function metatools.close_node(pname)
	if not pname then
		return false, "- meta::close - No player name provided"
	end

	-- Do they have an open node?
	if not playerdata[pname] then
		return true, "- meta::close - No open node found, no data to discard"
	end

	-- Discard everything
	minetest.forceload_free_block(playerdata[pname].position)
	playerdata[pname] = nil
	return true, "- meta::close - Node closed and data discarded"
end

function metatools.show(pname)
	if not pname or not playerdata[pname] then return false end

	-- List fields
	local fieldlist = {}
	for name, value in pairs(metatools.get_metalist(pname)) do
		if type(value) == "table" then
			table.insert(fieldlist, 1, name .. " : (size " .. #value .. ") -> Stratum " .. playerdata[pname].stratum + 1)
		elseif value.get_count and value.get_name then -- It's an ItemStack
			table.insert(fieldlist, 1, name .. " = " .. ("ItemStack({name=%s, count=%d, metadata=%s})"):format(dump(value:get_name()), value:get_count(), dump(value:get_metadata())))
		else
			table.insert(fieldlist, 1, name .. " = " .. dump(value):gsub('\n', ""))
		end
	end
	return true, fieldlist
end

function metatools.enter(pname, field)
	if not pname or not playerdata[pname] then return false end
	
	local metalist = metatools.get_metalist(pname)
	if not metalist[field] then
		return false, "- meta::enter - No such field '" .. field .. "'"
	else
		playerdata[pname].path[playerdata[pname].stratum] = field
		playerdata[pname].stratum = playerdata[pname].stratum + 1
		return true, "- meta::enter - Entered stratum " .. playerdata[pname].stratum .. " through gateway '" .. field .. "'"
	end
end

function metatools.leave(pname)
	if not pname or not playerdata[pname] then return false end

	local metalist = metatools.get_metalist(pname)
	if playerdata[pname].stratum == 1 then
		return false, "- meta::leave - You cannot leave the top stratum, use '/meta close' if you wish to leave the node"
	end

	playerdata[pname].stratum = playerdata[pname].stratum - 1
	playerdata[pname].path[playerdata[pname].stratum] = nil
	return true, "- meta::leave - Back at stratum " .. playerdata[pname].stratum
end

function metatools.set(pname, varname, varval)
	if not pname or not playerdata[pname] then return false end

	if playerdata[pname].mode ~= "fields" then
		return false, "- meta::set - Your mode is '" .. playerdata[pname].mode .. "', but you need to open the node in 'fields' mode to set meta variables"
	end

	if not varname then
		return false, "- meta::set - No variable name provided"
	end

	if not varval then
		return false, "- meta::set - No variable value provided"
	end

	local meta = minetest.get_meta(playerdata[pname].position)
	if tonumber(varval) then
		({
			[false] = meta.set_float,
			[true] = meta.set_int,
		})[(tonumber(varval) % 1 == 0)](meta, varname, tonumber(varval))
	else
		meta:set_string(varname, varval)
	end

	return true, "- meta::set - Value of variable '" .. varname .. "' set to " .. dump(varval):gsub('\n', "")
end

function metatools.unset(pname, varname)
	if not pname or not playerdata[pname] then return false end

	if playerdata[pname].mode ~= "fields" then
		return false, "- meta::unset - Your mode is '" .. playerdata[pname].mode .. "', but you need to open the node in 'fields' mode to unset meta variables"
	end

	if not varname then
		return false, "- meta::unset - No variable name provided"
	end

	local meta = minetest.get_meta(playerdata[pname].position)
	meta:set_string(varname, nil)

	return true, "- meta::unset - Variable '" .. varname .. "' unset"
end

function metatools.purge(pname)
	if not pname or not playerdata[pname] then return false end

	if playerdata[pname].mode ~= "fields" then
		return false, "- meta::purge - Your mode is '" .. playerdata[pname].mode .. "', but you need to open the node in 'fields' mode to purge all metadata"
	end

	minetest.get_meta(playerdata[pname].position):from_table(nil)
	playerdata[pname].path = {}
	playerdata[pname].stratum = 1

	return true, "- meta::purge - Metadata purged, back at stratum 1"
end

function metatools.list_init(pname, listname, size)
	if not pname or not playerdata[pname] then return false end

	if playerdata[pname].mode ~= "inventory" then
		return false, "- meta::list::init - Your mode is '" .. playerdata[pname].mode .. "', but you need to open the node in 'inventory' mode to initialize a list"
	end

	if not listname or listname == "" then
		return false, "- meta::list::init - You must provide a name for the list to initialize"
	end

	if not size then
		return false, "- meta::list::init - You must provide a size for the new list"
	end

	if not tonumber(size) or tonumber(size) % 1 ~= 0 then
		return false, "- meta::list::init - Invalid size : '" .. size .. "'"
	end

	local inv = minetest.get_meta(playerdata[pname].position):get_inventory()
	inv:set_list(listname, {})
	inv:set_size(listname, tonumber(size))

	return true, "- meta::list::init - List '" .. listname .. "' of size " .. size .. " created"
end

function metatools.list_delete(pname, listname)
	if not pname or not playerdata[pname] then return false end

	if playerdata[pname].mode ~= "inventory" then
		return false, "- meta::list::delete - Your mode is '" .. playerdata[pname].mode .. "', but you need to open the node in 'inventory' mode to delete a list"
	end

	if not listname or listname == "" then
		return false, "- meta::list::delete - You must provide a name for the list to delete"
	end

	local inv = minetest.get_meta(playerdata[pname].position):get_inventory()
	inv:set_list(listname, nil)
	inv:set_size(listname, 0)

	return true, "- meta::list::delete - List '" .. listname .. "' deleted"
end

function metatools.itemstack_erase(pname, index)
	if not pname or not playerdata[pname] then return false end

	if playerdata[pname].mode ~= "inventory" then
		return false, "- meta::itemstack::erase - Your mode is '" .. playerdata[pname].mode .. "', but you need to open the node in 'inventory' mode to erase itemstacks"
	end

	if not index then
		return false, "- meta::itemstack::erase - You must provide an index for the itemstack to erase"
	end

	if not tonumber(index) or tonumber(index) % 1 ~= 0 then
		return false, "- meta::itemstack::erase - Invalid index : '" .. index .. "'"
	end

	if playerdata[pname].stratum < 2 then
		return false, "- meta::itemstack::erase - You can only erase an itemstack inside and inventory"
	end

	local inv = minetest.get_meta(playerdata[pname].position):get_inventory()
	inv:set_stack(playerdata[pname].path[#playerdata[pname].path], tonumber(index), nil)
	return true, "- meta::itemstack::erase - Itemstack erased"
end

function metatools.itemstack_write(pname, index, data)
	if not pname or not playerdata[pname] then return false end

	if playerdata[pname].mode ~= "inventory" then
		return false, "- meta::itemstack::write - Your mode is '" .. playerdata[pname].mode .. "', but you need to open the node in 'inventory' mode to write itemstacks"
	end

	if not index then
		return false, "- meta::itemstack::write - You must provide an index for the itemstack to erase"
	end

	if not tonumber(index) or tonumber(index) % 1 ~= 0 then
		return false, "- meta::itemstack::write - Invalid index : '" .. index .. "'"
	end

	if not data then
		return false, "- meta::itemstack::write - You must provide a string representing the itemstack"
	end

	if playerdata[pname].stratum < 2 then
		return false, "- meta::itemstack::write - You can only write itemstacks inside an inventory (you are at stratum " .. playerata[pname].stratum .. ")"
	end

	local stack = ItemStack({name = data:split(" ")[1], count = tonumber(data:split(" ")[2]) or 1})
	if not stack then
		return false, "- meta::itemstack::write - Invalid metadata representation : '" .. data "'"
	end

	
	minetest.get_meta(playerdata[pname].position):get_inventory():set_stack(playerdata[pname].path[#playerdata[pname].path], tonumber(index), stack)
	return true, "- meta::itemstack::write - Itemstack " .. data .. " written at index " .. index .. " of list " .. playerdata[pname].path[#playerdata[pname].path]
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
				"- meta::help - /meta open (x,y,z) [mode] : Open not at (x,y,z) with mode 'mode' (either 'fields' or 'inventory'; default is 'fields')\n" ..
				"- meta::help - /meta close : Close the node you're operating on\n" ..
				"- meta::help - /meta show : Show you the variables and gateways at your depth level/stratum\n" ..
				"- meta::help - /meta enter <field> : Enter deeper through the gateway <field>\n" ..
				"- meta::help - /meta leave : If the stratum is higher than 1, go up a level (read: go back)\n" ..
				"- meta::help - /meta set <name> <value> : Set variable 'name' to 'value', overriding any existing data and predicting the data type (str, float or int)\n" ..
				"- meta::help - /meta unset <name> : Set variable 'name' to nil, ignoring whether it exists or not\n" ..
				"- meta::help - /meta purge : Purge all metadata variables\n" ..
				"- meta::help - /meta list : List manipulation :\n" ..
				"- meta::help - /meta list init <name> <size> : Initialize list 'name' of size 'size', overriding any existing data\n" ..
				"- meta::help - /meta list delete <name> : Delete list 'name', ignoring whether it exists or not\n" ..
				"- meta::help - /meta itemstack : ItemStack manipulation :\n" ..
				"- meta::help - /meta itemstack write <index> <data> : Write an itemstack represented by 'data' at index 'index' of the list you are in\n" ..
				"- meta::help - /meta itemstack erase <index> : Remove itemstack at index 'index' in the current inventory, regardless of whether it exists or not\n" ..
				"- meta::help - End of Help"

		
		-- meta open (x,y,z) [fields|inventory]
		elseif params[1] == "open" then
			-- Check for an already opened node
			if playerdata[name] then
				return false, "- meta::open - You already have a node open at " .. minetest.pos_to_string(playerdata[name].position) .. ", please close it (/meta close) before opening another one"
			end

			-- Is there a position?
			if not params[2] then
				return false, "- meta::open - You need to provide the position of the node you wish to open in the following format : (x,y,z)"
			end

			-- Is it correct?
			local npos = minetest.string_to_pos(params[2])
			if not npos then
				return false, "- meta::open - Invalid position parameter : " .. params[2]
			end


			-- Call the API function
			return metatools.open_node(name, npos, params[3])

		-- meta close
		elseif params[1] == "close" then
			-- Call the API function
			return metatools.close_node(name)

		-- meta show
		elseif params[1] == "show" then
			-- Check for an opened node
			if not playerdata[name] then
				return false, "- meta::show - No node open, please use '/meta open' first"
			end

			local status, fieldlist = metatools.show(name)
			if not status then
				return status, fieldlist
			else
				core.chat_send_player(name, "- meta::show - Output :")
				for i, str in pairs(fieldlist) do
					core.chat_send_player(name, "- meta::show -     " .. str)
				end
				return true, "- meta::show - End of output"
			end

		-- meta enter <field>
		elseif params[1] == "enter" then
			-- Check for an opened node
			if not playerdata[name] then
				return false, "- meta::enter - No node open, please use '/meta open' first"
			end

			if not params[2] then
				return false, "- meta::enter - No field name provided for the gateway, please use a gateway field shown in '/meta show'"
			end

			return metatools.enter(name, params[2])

		-- meta leave
		elseif params[1] == "leave" then
			if not playerdata[name] then
				return false, "- meta::leave - No node open, please use '/meta open' first"
			end

			return metatools.leave(name)

		-- meta set <varname> <value>
		elseif params[1] == "set" then
			if not playerdata[name] then
				return false, "- meta::set - No node open, please use '/meta open' first"
			end

			return metatools.set(name, params[2], params[3])

		-- meta unset <varname>
		elseif params[1] == "unset" then
			if not playerdata[name] then
				return false, "- meta::unset - No open node, please use '/meta open' first"
			end

			return metatools.unset(name, params[2])

		-- meta purge
		elseif params[1] == "purge" then
			if not playerdata[name] then
				return false, "- meta::purge - No open node, please use '/meta open' first"
			end

			return metatools.purge(name)

		-- meta list...
		elseif params[1] == "list" then
			if not params[2] then
				return false, "- meta::list - Subcommand needed, consult '/meta help' for help"
			end

			-- meta list init <name> <size>
			if params[2] == "init" then
				if not playerdata[name] then
					return false, "- meta::list::init - No node open, please use '/meta open' first"
				end

				return metatools.list_init(name, params[3], params[4])

			-- meta list delete <name>
			elseif params[2] == "delete" then
				if not playerdata[name] then
					return false, "- meta::list::delete - No open node, please use '/meta open' first"
				end

				return metatools.list_delete(name, params[3])

			else
				return false, "- meta::list - Unknown subcommand '" .. params[2] .. "', please consult '/meta help' for help"
			end

		-- meta itemstack...
		elseif params[1] == "itemstack" then
			if not params[2] then
				return false, "- meta::itemstack - Subcommand needde, consult '/meta help' for help"
			end

			if not playerdata[name] then
				return false, "- meta::itemstack - No open node, please use '/meta open' first"
			end

			-- meta itemstack erase <index>
			if params[2] == "erase" then

				return metatools.itemstack_erase(name, params[3])

			-- meta itemstack write <index> <itemstack>
			elseif params[2] == "write" then
				return metatools.itemstack_write(name, params[3], metatools.build_param_str(params, 4, ' '))
			end

		else
			return false, "- meta - Unknown command " .. params[1]
		end
	end,
})
