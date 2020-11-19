package = "plterm"
version = "0.3-1"
source = {
   url = "git://github.com/philanc/plterm" 
}
description = {
   summary = "Pure Lua ANSI Terminal functions",
   detailed = [[
      The module includes basic functionnalities to display 
	  strings in various colors, move the cursor, erase lines, 
	  read keys (including arrows and function keys) and set 
	  the terminal in raw mode.
	  It does not use ncurses, terminfo or termcap. It uses only 
	  very common ANSI sequences that are supported by 
	  (at least) the Linux console, xterm, rxvt and vte-based
	  terminals
   ]],
   homepage = "https://github.com/philanc/plterm",
   license = "MIT",
}
supported_platforms = { 
	"unix", 
}
dependencies = {
   "lua >= 5.3"
}
build = {
   type = "builtin",
   modules = {
      plterm = "plterm.lua",
   },
   copy_directories = { "example" },
}

