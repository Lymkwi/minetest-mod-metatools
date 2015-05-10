Minetest mod metatools
######################

A mod inspired by mgl512's itemframe issue
Version : 1.0

# Authors
 - LeMagnesium / Mg / ElectronLibre : Source code writer
 - Ataron : Texture creater

# Purpose
This mod's aim is to provide a way for admins to navigate through any (ok, not
ignores) nodes on the map, and see values of its metadatas at any of their
stratum.

# Media
"metatools_stick.png" by Ataron (CC-BY-NC-SA)

# Todo
 - Add a table handler for meta::set
 - Create a better ASCII-art graph at the end of this file...

# Special thanks
 - mgl512 (Le_Docteur) for its locked itemframe which gave me the idea of a tool
allowing to see/edit metadatas
 - Ataron who created the stick's texture
 - palige who agreed to test the mod for its first release

# Command tutorial

 - help										=> Get help
 - version									=> Get version
 - open (x,y,z)								=> Open the node to manipulate at pos (x,y,z)
 - show 									=> Show fields/path list at actual position
 - enter _path_								=> Enter next stratum through _path_
 - quit										=> Quit actual field and go back to previous stratum
 - set _name_ _value_						=> Set metadata _name_ to _value_ (create it if it doesn't exist)
 - itemstack								=> Manipulate itemstacks in Node/inventory/*/
	- read _name_							=> Read itemstack at field name (itemstring and count)
	- erase _name_							=> Erase itemstack at field name
	- write _name_ _itemstring_ [_count_]	=> Set itemstack in field _name_ with item _itemstring_ and count _count_. Default count is one, 0 not handled.
 - close									=> Close node

 Node metadatas look like this :

			0	1		2		3		...
			Node/
				|
				+- 		fields
				|		|
				|		+-		foo
				|		+-		bar
				|		+-		...
				+-		inventory
						|
						+-		main
						|		|
						|		+-		1
						|		+-		2
						|		+-		3
						|		+-		...
						+-		craft
						|		|
						|		+-		1
						|		+-		2
						|		+-		3
						|		+-		...
						+-		...
