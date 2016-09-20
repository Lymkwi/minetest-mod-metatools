Minetest mod metatools
######################

A mod inspired by mgl512's itemframe issue
Version : 1.2.2

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
 - Soon to come, please refer to /meta help until then

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
