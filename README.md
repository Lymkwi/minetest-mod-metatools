Minetest mod metatools
######################

A mod inspired by mgl512's itemframe issue
Version : 1.2

# Authors
 - LeMagnesium / Mg / ElectronLibre : Source code writer
 - Paly2 / Palige : Contributor for the source code
 - Ataron : Texture creater

# Purpose
This mod's aim is to provide a way for admins to navigate through any (ok, not
ignores) nodes on the map, and see values of its metadatas at any of their
stratum.

# Media
"metatools_stick.png" by Ataron (CC-BY-NC-SA)

# Todo
 - Rewrite the table stocking : a variable containing a copy of the global
   table returned by :to_table(), on which we would work, and a save command to
   apply it on the node

# Special thanks
 - mgl512 (Le_Docteur) for its locked itemframe which gave me the idea of a tool
allowing to see/edit metadatas
 - Ataron who created the stick's texture
 - palige who agreed to test the mod for its first release, and contributed to the last version

# Command tutorial

 - help										=> Get help
 - version									=> Get version
 - open (x,y,z)	_mode_							=> Open the node to manipulate at pos (x,y,z) with mode _mode_ (default is 'fields')
 - show 									=> Show fields/path list at actual position
 - enter _path_								=> Enter next stratum through _path_
 - leave										=> Leave current field and go back to previous stratum
 - set _name_ _value_						=> Set metadata _name_ to _value_ (create it if it doesn't exist)
 - itemstack								=> Manipulate itemstacks in Node/inventory/\*/
	- erase _name_							=> Erase itemstack at field name
	- write _name_ _itemstring_ [_count_]	=> Set itemstack in field _name_ with item _itemstring_ and count _count_. Default count is one, 0 not handled.
 - list
 	- init _name_ _size_			=> Create a list of size _size_ named _name_
	- delete _name_				=> Delete any list that could be called _name_
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
