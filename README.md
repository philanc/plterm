# plterm

### Pure Lua ANSI Terminal functions

The module includes all the basic functionnalities to display strings in various colors, move the cursor, erase lines and read keys.

Like [linenoise](https://github.com/antirez/linenoise), it does not use ncurses, terminfo or termcap. It uses only very common ANSI sequences that are supported by (at least) the Linux console, xterm, rxvt and vte-based terminals.

The origin of the term module is some code [contributed](http://lua-users.org/lists/lua-l/2009-12/msg00937.html) by Luiz Henrique de Figueiredo on the Lua mailing list some time ago.

I added some functions for input, getting the cursor position or the screen dimension, and stty-based mode handling .

The input function reads and parses the escape sequences sent by function keys (arrows, F1-F12, insert, delete, etc.). See the definitions in `term.keys`.

This module was initially developed for  [PLE](https://github.com/philanc/ple), my "Pure Lua text Editor". It is embedded at the beginning og PLE, so that the editor can be delivered as a single Lua file.  

### Dependencies

The module is written for and tested with Lua 5.3. It should work with Lua 5.2 but not with older versions (it uses a 'goto' in the input function).

The module does not use any other external library.  The only dependency is the Unix command `stty` which is used to set the terminal in raw mode (so that keys can be read one at a time when they are pressed).

### Functions

```
out(...)    -- io.write
outf(...)   -- io.write, then flush
clear()     -- clear screen
cleareol()  -- clear to end of line
golc(l, c)  -- move the cursor to line l, column c
up(n)
down(n)
right(n)
left(n)     -- move the cursor by n positions (default to 1)
color(f, b, m)
            -- change the color used to write characters
			   (foreground color, background color, modifier)
			   see term.colors
hide()
show()      -- hide or show the cursor
save()
restore()   -- save and restore the position of the cursor
reset()     -- reset the terminal (colors, cursor position)

input()     -- input iterator (coroutine-based)
		       return a "next key" function that can be iteratively called 
			   to read a key (escape sequences returned by function keys 
			   are parsed)
			   when keys.mouse is returned, mouse data is returned as additional vals btn, x, y, motion, modifier bits
rawinput()  -- same, but escape sequences are not parsed.
getcurpos() -- return the current position of the cursor
getscrlc()  -- return the dimensions of the screen 
               (number of lines and columns)
keyname()   -- return a printable name for any key
               - key names in term.keys for function keys,
			   - control characters are represented as "^A"
			   - the character itself for other keys

tty mode management functions

setrawmode()       -- set the terminal in raw mode
setsanemode()      -- set the terminal in a default "sane mode"
savemode()         -- get the current mode as a string
restoremode(mode)  -- restore a mode saved by savemode()
setmousemode(mode) -- set terminal mouse support mode to one of mousemode.(off|click|clickanddrag|all)

```

### Example

A small (and crude!) fileviewer is proposed as an example. See `example/viewfile.lua`.

Usage: 	`lua viewfile.lua filename`

#### Mouse Support

```lua
term = require 'plterm'

local getkey = term.input()
local oldmode = term.savemode()
term.setrawmode()
term.setmousemode(term.mousemode.click)

local key, btn, x, y, motion, mods = getkey()

-- term.savemode() can't save mouse mode due to stty limitations
term.setmousemode(term.mousemode.off)
term.restoremode(oldmode)

if key == term.keys.mouse then
	print("button clicked: " .. tostring(btn))
	print("x: " .. tostring(x) .. " y: " .. tostring(y))
	print("was moving: " .. tostring(motion))
	print("modifier mask: " .. tostring(mods))
else
	print("not a mouse event.")
	print("key: " .. term.keyname(key))
end
```

### License

This code is published under a MIT license. Feel free to fork!

