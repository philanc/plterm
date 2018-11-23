-- Copyright (c) 2018  Phil Leblanc  -- see LICENSE file

------------------------------------------------------------------------
--[[  

test plterm - Pure Lua ANSI Terminal functions - unix only


]]

-- some local definitions

local strf = string.format
local byte, char, rep = string.byte, string.char, string.rep
local app, concat = table.insert, table.concat
local yield = coroutine.yield

local repr = function(x) return strf("%q", tostring(x)) end


------------------------------------------------------------------------
local term = require "plterm"

local out, outf = term.out, term.outf
local golc = term.golc
local color = term.color
local colors = term.colors

------------------------------------------------------------------------

local function test_ansi()
	local l, c, mode

	mode = term.savemode()
	term.setrawmode() -- required to enable getcurpos()
	
	term.clear()
	term.golc(1,1)
	outf("[1,1]")
	
	-- colors
	term.golc(2,1); 
	color(colors.red, colors.bgyellow)
	outf "red on yellow"
	term.golc(3,1); 
	color(colors.green, colors.bgblack)
	outf "green on black"
	term.golc(4,1); 
	color(0); color(colors.red, colors.bgcyan, colors.reverse)
	outf "red on cyan, reverse"
	color(0)
	
	-- save, restore
	golc(5, 10)
	term.save()
	golc(1, 15); outf"[1,15]"
	term.restore()
	outf"[5,10]restored"
	
	-- getcurpos
	golc(12, 30)
	l, c = term.getcurpos()
	golc(11,30); outf"next line should be [12,30]"
	golc(12,30); outf(strf("[%d,%d]" , l, c))
	
	-- golc beyond limits
	golc(999,999) -- ok with vte
	l, c = term.getcurpos()
	golc(13, 30)
	outf(strf("bottom right is [%d,%d]", l, c))
	
	term.down(999)
	outf"down to last line"
	term.up(); term.left(17)
	outf"up 1 and left 17"
	
	-- done
	term.golc(18,1)
	outf "test_ansi() OK.   "
--~ 	term.setsanemode()
	term.restoremode(mode)

end --test_ansi


test_ansi()
