-- viewfile.lua

-- Usage: lua viewfile.lua filename
------------------------------------------------------------------------

local term = require "plterm"

-- some local definitions

local strf = string.format
local byte, char, rep = string.byte, string.char, string.rep
local app, concat = table.insert, table.concat

local repr = function(x) return strf("%q", tostring(x)) end
local max = function(x, y) if x < y then return y else return x end end 
local min = function(x, y) if x < y then return x else return y end end 

local out, outf, outdbg = term.out, term.outf, term.outdbg
local go, cleareol, color = term.golc, term.cleareol, term.color
local col, keys = term.colors, term.keys

------------------------------------------------------------------------

local style = {
	[1] = function() color(col.normal) end, 
	[2] = function() color(col.red, col.bold) end, 
	[3] = function() color(col.green) end, 
	[5] = function() color(col.red, col.bgblack) end, 
}

local put = function(l, c, y, s) -- y is style number
	go(l, c); style[y](); outf(s)
end

local puteol = function(l, c, y, s) -- y is style number
	go(l, c); cleareol(); style[y](); outf(s)
end

local scrl, scrc -- screen lines, columns
local tabln = 8

local function brep3(b, li)
	-- return the screen representation of ascii b at line index li and
	-- the new line index
	-- (use hex representation for non latin1-printable chars)
	local s
	local pre = char(215) -- latin1 mult sign
	if b == 9 then s = rep(' ', tabln - li%tabln)
	elseif (b >= 127 and b <160) or (b < 32) then s = strf('%s%02x', pre, b) 
	else s = char(b)
	end
	return s, li + #s
end --brep3

local function brep2(b, li)
	-- return the screen representation of ascii b at line index li and
	-- the new line index
	-- (use middledot for non latin1-printable chars)
	local s
	local ndc = char(183) -- latin1 centered dot
	if b == 9 then s = rep(' ', tabln - li%tabln)
	elseif b >= 127 and b <160 then s = ndc
	elseif b < 32 then s = ndc
	else s = char(b)
	end
	return s, li + #s
end --brep2

local brep -- select the preferred representation below
--
brep = brep2 -- use middledot for non latin1-printable chars
-- brep = brep3 -- use hex representation for non latin1-printable chars
--

local function reflow(txt, col)
	-- read all chars in txt, place them in display lines
	-- (max length = col). return the list of display lines
	local txtl = {} -- the list of display lines
	local dll = {} -- a display line as a list of chars or small strings
	local dl -- display line as a string (#dl <= col)
	local b, c, s
	local i, li = 1, 0
	for i = 1, #txt do
		b = byte(txt, i)
		if b == 10 then --newline
			dl = concat(dll)
			app(txtl, dl)
			dll = {}
			li = 1		
		else
			s, li = brep(b, li)
			if li > col then
				dl = concat(dll)
				app(txtl, dl)
				dll = {}
				li = #s
			end
			app(dll, s)
		end -- if newline
	end
	dl = concat(dll) --finalize the last line
	app(txtl, dl)
	return txtl
end --reflow

function displines(txtl, li, maxl)
	-- display lines at index li in txtl
	-- display at most maxl lines
	topl = 2 -- display starting at screenline 2
	for i = topl, topl + maxl - 1 do
		local sl = txtl[li]
		if sl then puteol(i, 1, 1, sl)
		else puteol(i, 1, 1, '~')
		end
		li = li + 1
	end
end

local function pad(s, col)
	if #s >= col then return s:sub(1,col) end
	return s .. rep(' ', col-#s)
end

function disptitle(title, l, w) puteol(l, 1, 3, pad(title, w)) end	
function dispmsg(msg, l, w) puteol(l, 1, 3, pad(msg, w)) end	

function display(txt)
	local prevmode, e, m = term.savemode()
	if not prevmode then print(prevmode, e, m); os.exit() end
	term.setrawmode()
	nextk = term.input()
	while true do
		term.reset()
		term.hide()
		scrl, scrc = term.getscrlc()
		local title = strf("viewfile: %d %d", scrl, scrc)
		disptitle(title, 1, scrc)
		local help = "Quit: ^Q, Redisplay: ^L,  "
		.. "Navigation: PgUp, PgDown, Home, End"
		dispmsg(help, scrl, scrc)
		local txtl = reflow(txt, scrc)
		local li = 1
		displines(txtl, li, scrl-2)
		while true do
			k = nextk()
			if k == byte'Q'-64 then break
			elseif k == byte'L'-64 then goto continue
			elseif k == keys.kpgup and li > 1 then
				li = max(li - (scrl - 3), 1)
				displines(txtl, li, scrl-2)
			elseif k == keys.kpgdn and li < #txtl then
				li = min(li + (scrl - 3), #txtl)
				displines(txtl, li, scrl-2)
			elseif k == keys.khome then
				li = 1
				displines(txtl, li, scrl-2)
			elseif k == keys.kend then
				li = max(#txtl - (scrl-3), 1)
				displines(txtl, li, scrl-2)
			else
--~ 				puteol(scrl, 1, 2, term.keyname(k))
			end
		end
		break
		::continue::
	end
	term.show() -- show cursor
	puteol(scrl, 1, 1, "")
	term.restoremode(prevmode)
end --display

function main()
	local filename = arg[1]
	if not filename then
		print("Usage: lua viewfile.lua filename")
		os.exit(1)
	end
	local f, msg = io.open(filename, 'rb')
	if not f then 
		print(msg); os.exit(1)
	end
	local txt = f:read("a") 
	f:close()	
	display(txt)
end

main()

