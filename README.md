# plterm

### Pure Lua ANSI Terminal functions

The module includes all the basic functionnalities to display strings in various colors, move the cursor, erase lines and read keys.

It does not use ncurses, terminfo or termcap. It uses only very common ANSI sequences that are supported by (at least) the Linux console, xterm, rxvt and vte-based terminals.

The input function reads and parses the escape sequences sent by function keys (arrows, F1-F12, insert, delete, etc.). See the definitions in `term.keys`.

UTF8 support has been added to this version. The input function also parses UTF8 sequences and returns Unicode character codes.  *To deactivate UTF8 support and restore the same behavior as the previous version: Just set the `UTF8` variable to `false`  at the beginning of `plterm.lua`.*

This module was initially developed for  [PLE](https://github.com/philanc/ple), my "Pure Lua text Editor". It is embedded at the beginning og PLE, so that the editor can be delivered as a single Lua file.  

### Dependencies

The module is written for and tested with Lua 5.3. It uses the Lua utf8 standard library.

The module does not use any other external library.  The only dependency is the Unix command `stty` which is used to set the terminal in raw mode (so that keys can be read one at a time when they are pressed).

### Functions

```
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

```

### Example

A small (and crude!) fileviewer is proposed as an example. See `example/viewfile.lua`.

Usage: 	`lua viewfile.lua filename`

### License

This code is published under a MIT license. Feel free to fork!

