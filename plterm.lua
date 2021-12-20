-- Copyright (c) 2018 Phil Leblanc  -- see LICENSE file

------------------------------------------------------------------------
--[[

plterm - Pure Lua ANSI Terminal functions - unix only

This module assumes that 
	- the terminal supports the common ANSI sequences,
	- the current tty encoding is UTF-8,
	- the unix command 'stty' is available (it is used to save 
	  and restore the tty mode and set the tty in raw mode).

Module functions:

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
	       return a "next key" function that can be iteratively
	       called to read a key (UTF8 sequences and escape 
	       sequences returned by function keys are parsed)
rawinput()  -- same, but UTF8 and escape sequences are not parsed.
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

License: BSD
https://github.com/philanc/plterm

-- just in case, a good ref on ANSI esc sequences:
https://en.wikipedia.org/wiki/ANSI_escape_code
(in the text, "CSI" is "<esc>[")

]]

-- if UTF8 below is true, the module assumes that the terminal supports
-- UTF8.  If false, it assumes that the terminal uses an 8-bit encoding 
-- where each character is encoded as one 8-bit byte (eg Latin-1 or 
-- other ISO-8859 encodings).
-- It doesn't make a difference except for the input() and keyname()
-- functions.

-- local UTF8 = false -- 8-bit encoding (eg. ISO-8859 encodings)
local UTF8 = true  -- UTF8 encoding

if UTF8 then local utf8 = require "utf8" end

-- some local definitions

local byte, char, yield = string.byte, string.char, coroutine.yield


------------------------------------------------------------------------

local out = io.write

local function outf(...)
	-- write arguments to stdout, then flush.
	io.write(...); io.flush()
end

-- following definitions (from term.clear to term.restore) are
-- based on public domain code by Luiz Henrique de Figueiredo
-- http://lua-users.org/lists/lua-l/2009-12/msg00942.html

local term={ -- the plterm module
	out = out,
	outf = outf,
	clear = function() out("\027[2J") end,
	cleareol = function() out("\027[K") end,
	golc = function(l,c) out("\027[",l,";",c,"H") end,
	up = function(n) out("\027[",n or 1,"A") end,
	down = function(n) out("\027[",n or 1,"B") end,
	right = function(n) out("\027[",n or 1,"C") end,
	left = function(n) out("\027[",n or 1,"D") end,
	color = function(f,b,m)
	    if m then out("\027[",f,";",b,";",m,"m")
	    elseif b then out("\027[",f,";",b,"m")
	    else out("\027[",f,"m") end
	end,
	-- hide / show cursor
	hide = function() out("\027[?25l") end,
	show = function() out("\027[?25h") end,
	-- save/restore cursor position
	save = function() out("\027[s") end,
	restore = function() out("\027[u") end,
	-- reset terminal (clear and reset default colors)
	reset = function() out("\027c") end,
}

term.colors = {
	default = 0,
	-- foreground colors
	black = 30, red = 31, green = 32, yellow = 33,
	blue = 34, magenta = 35, cyan = 36, white = 37,
	-- backgroud colors
	bgblack = 40, bgred = 41, bggreen = 42, bgyellow = 43,
	bgblue = 44, bgmagenta = 45, bgcyan = 46, bgwhite = 47,
	-- attributes
	reset = 0, normal= 0, bright= 1, bold = 1, reverse = 7,
}

------------------------------------------------------------------------
-- key input

term.keys = { -- key code definitions
	unknown = 0x10000,
	esc = 0x1b,
	del = 0x7f,
	kf1 = 0xffff,  -- 0xffff-0
	kf2 = 0xfffe,  -- 0xffff-1
	kf3 = 0xfffd,  -- ...
	kf4 = 0xfffc,
	kf5 = 0xfffb,
	kf6 = 0xfffa,
	kf7 = 0xfff9,
	kf8 = 0xfff8,
	kf9 = 0xfff7,
	kf10 = 0xfff6,
	kf11 = 0xfff5,
	kf12 = 0xfff4,
	kins  = 0xfff3,
	kdel  = 0xfff2,
	khome = 0xfff1,
	kend  = 0xfff0,
	kpgup = 0xffef,
	kpgdn = 0xffee,
	kup   = 0xffed,
	kdown = 0xffec,
	kleft = 0xffeb,
	kright = 0xffea,
}

local keys = term.keys

--special chars (for parsing esc sequences)
local ESC, LETO, LBR, TIL= 27, 79, 91, 126  --  esc, [, ~

local isdigitsc = function(c)
	-- return true if c is the code of a digit or ';'
	return (c >= 48 and c < 58) or c == 59
end

--ansi sequence lookup table
local seq = {
	['[A'] = keys.kup,
	['[B'] = keys.kdown,
	['[C'] = keys.kright,
	['[D'] = keys.kleft,

	['[2~'] = keys.kins,
	['[3~'] = keys.kdel,
	['[5~'] = keys.kpgup,
	['[6~'] = keys.kpgdn,
	['[7~'] = keys.khome,  --rxvt
	['[8~'] = keys.kend,   --rxvt
	['[1~'] = keys.khome,  --linux
	['[4~'] = keys.kend,   --linux
	['[11~'] = keys.kf1,
	['[12~'] = keys.kf2,
	['[13~'] = keys.kf3,
	['[14~'] = keys.kf4,
	['[15~'] = keys.kf5,
	['[17~'] = keys.kf6,
	['[18~'] = keys.kf7,
	['[19~'] = keys.kf8,
	['[20~'] = keys.kf9,
	['[21~'] = keys.kf10,
	['[23~'] = keys.kf11,
	['[24~'] = keys.kf12,

	['OP'] = keys.kf1,   --xterm
	['OQ'] = keys.kf2,   --xterm
	['OR'] = keys.kf3,   --xterm
	['OS'] = keys.kf4,   --xterm
	['[H'] = keys.khome, --xterm
	['[F'] = keys.kend,  --xterm

	['[[A'] = keys.kf1,  --linux
	['[[B'] = keys.kf2,  --linux
	['[[C'] = keys.kf3,  --linux
	['[[D'] = keys.kf4,  --linux
	['[[E'] = keys.kf5,  --linux

	['OH'] = keys.khome, --vte
	['OF'] = keys.kend,  --vte

}

local getcode = function() return byte(io.read(1)) end

term.input = function()
	-- return a "read next key" function that can be used in a loop
	-- the "next" function blocks until a key is read
	-- it returns ascii or unicode code for all regular keys, 
	-- or a key code for special keys (see term.keys)
	return coroutine.wrap(function()
	  local c, c1, c2, ci, s, u
	  while true do
		c = getcode()
		::restart::
		if UTF8 and (c & 0xc0 == 0xc0) then 
			-- utf8 sequence start
			if c & 0x20 == 0 then -- 2-byte seq
				u = c & 0x1f
				c = getcode()
				u = (u << 6) | (c & 0x3f)
				yield(u)
				goto continue
			elseif c & 0xf0 == 0xe0 then -- 3-byte seq
				u = c & 0x0f
				c = getcode()
				u = (u << 6) | (c & 0x3f)
				c = getcode()
				u = (u << 6) | (c & 0x3f)
				yield(u)
				goto continue
			else -- assume it is a 4-byte seq
				u = c & 0x07
				c = getcode()
				u = (u << 6) | (c & 0x3f)
				c = getcode()
				u = (u << 6) | (c & 0x3f)
				c = getcode()
				u = (u << 6) | (c & 0x3f)
				yield(u)
				goto continue
			end
		end -- end utf8 sequence. continue with c.
		if c ~= ESC then -- not an esc sequence, yield c
			yield(c)
			goto continue
		end
		c1 = getcode()
		if c1 == ESC then -- esc esc [ ... sequence
			yield(ESC)
			-- here c still contains ESC, read a new c1
			c1 = getcode() -- and carry on ...
		end
		if c1 ~= LBR and c1 ~= LETO then -- not a valid seq
			if UTF8 then
			-- c1 maybe the beginning of an utf8 seq...
				yield(c) ; c = c1 ; goto restart
			else
				yield(c) ; yield(c1)
				goto continue
			end
		end
		c2 = getcode()
		s = char(c1, c2)
		if c2 == LBR then -- esc[[x sequences (F1-F5 in linux console)
			s = s .. char(getcode())
		end
		if seq[s] then
			yield(seq[s])
			goto continue
		end
		if not isdigitsc(c2) then
			yield(c) ; yield(c1) ; yield(c2)
			goto continue
		end
		while true do -- read until tilde '~'
			ci = getcode()
			s = s .. char(ci)
			if ci == TIL then
				if seq[s] then
					yield(seq[s])
					goto continue
				else
					-- valid but unknown sequence
					-- ignore it
					yield(keys.unknown)
					goto continue
				end
			end
			if not isdigitsc(ci) then
				-- not a valid seq. 
				-- return all the chars
				yield(ESC)
				for i = 1, #s do yield(byte(s, i)) end
				goto continue
			end
		end--while read until tilde '~'
		::continue::
	  end--coroutine while loop
	end)--coroutine
end--input()

term.rawinput = function()
	-- return a "read next key" function that can be used in a loop
	-- the "next" function blocks until a key is read
	-- it returns ascii code for all keys
	-- (this function assume the tty is already in raw mode)
	return coroutine.wrap(function()
		local c
		while true do
			c = getcode()
			yield(c)
		end
	end)--coroutine
end--rawinput()

term.getcurpos = function()
	-- return current cursor position (line, column as integers)
	--
	outf("\027[6n") -- report cursor position. answer: esc[n;mR
	local i, c = 0
	local s = ""
	c = getcode(); if c ~= ESC then return nil end
	c = getcode(); if c ~= LBR then return nil end
	while true do
		i = i + 1
		if i > 8 then return nil end
		c = getcode()
		if c == byte'R' then break end
		s = s .. char(c)
	end
	-- here s should be n;m
	local n, m = s:match("(%d+);(%d+)")
	if not n then return nil end
	return tonumber(n), tonumber(m)
end

term.getscrlc = function()
	-- return current screen dimensions (line, coloumn as integers)
	term.save()
	term.down(999); term.right(999)
	local l, c = term.getcurpos()
	term.restore()
	return l, c
end

term.keyname = function(c)
	for k, v in pairs(keys) do
		if c == v then 
			return k 
		end
	end
	if c < 32 then return "^" .. char(c+64) end
	-- utf8
	if UTF8 then
		return utf8.char(c)
	elseif c < 256 then 
		return char(c) 
	else 
		return tostring(c)
	end
end

------------------------------------------------------------------------
-- poor man's tty mode management, based on stty
-- (better use slua linenoise extension if available)


-- use the following to define a non standard stty location
-- eg.:  stty = "/opt/busybox/bin/stty"
--
local stty = "stty" -- use the default stty

term.setrawmode = function()
	return os.execute(stty .. " raw -echo 2> /dev/null")
end

term.setsanemode = function()
	return os.execute(stty .. " sane")
end

-- the string meaning that file:read() should return all the
-- content of the file is "*a"  for Lua 5.0-5.2 and LuaJIT, 
-- and "a" for more recent Lua versions 
-- thanks to Phil Hagelberg for the heads up.
--
local READALL = (_VERSION < "Lua 5.3") and "*a" or "a" 

term.savemode = function()
	local fh = io.popen(stty .. " -g")
	local mode = fh:read(READALL)
	local succ, e, msg = fh:close()
	return succ and mode or nil, e, msg
end

term.restoremode = function(mode)
	return os.execute(stty .. " " .. mode)
end

return term
