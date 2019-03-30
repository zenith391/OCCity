-- Using braille, the resolution of the (monochrome) game on a 160x50 display + gpu is: 
-- 320x200, meaning it's even lower resolution than the original SimCity for DOS xD
-- Sub-pixel manipulator (using braille)
local pm = {}
local unicode = require("unicode")
local bit = require("bit32")
local component = require("component")
local event = require("event")
local gpu = component.getPrimary("gpu")

function utf8byte(utf8)
	local res, seq, val = {}, 0, nil
	for i = 1, #utf8 do
		local c = string.byte(utf8, i)
		if seq == 0 then
			table.insert(res, val)
			seq = c < 0x80 and 1 or c < 0xE0 and 2 or c < 0xF0 and 3 or
			      c < 0xF8 and 4 or --c < 0xFC and 5 or c < 0xFE and 6 or
				  error("invalid UTF-8 character sequence")
			val = bit32.band(c, 2^(8-seq) - 1)
		else
			val = bit32.bor(bit32.lshift(val, 6), bit32.band(c, 0x3F))
		end
		seq = seq - 1
	end
	table.insert(res, val)
	table.insert(res, 0)
	return res
end

function pm.brailleCharRaw(a, b, c, d, e, f, g, h)
	return 10240 + 128 * h + 64 * g + 32 * f + 16 * d + 8 * b + 4 * e + 2 * c + a
end
function pm.brailleChar(a, b, c, d, e, f, g, h) -- from MineOS text.brailleChar
	return unicode.char(pm.brailleCharRaw(a, b, c, d, e, f, g, h))
end

function pm.fromBrailleChar(ch)
	local tab = {}
	local c = ch - 10240
	if c < 0 then
		c = 0
	end
	tab[1] = bit.band(c, 1) -- a
	tab[3] = bit.band(c, 2) -- c
	if tab[3] == 2 then tab[3] = 1 end
	tab[5] = bit.band(c, 4) -- e
	if tab[5] == 4 then tab[5] = 1 end
	tab[2] = bit.band(c, 8) -- b
	if tab[2] == 8 then tab[2] = 1 end
	tab[4] = bit.band(c, 16) -- d
	if tab[4] == 16 then tab[4] = 1 end
	tab[6] = bit.band(c, 32) -- f
	if tab[6] == 32 then tab[6] = 1 end
	tab[7] = bit.band(c, 64) -- g
	if tab[7] == 64 then tab[7] = 1 end
	tab[8] = bit.band(c, 128) -- h
	if tab[8] == 128 then tab[8] = 1 end
	return tab
end

function pm.draw(x, y, on) -- 2 operations, could be 1 with a double-buffer, however it would cost a lot of memory
	-- x, y = position
	-- If on is true then put white, else put black
	local gx = x / 2 + 1 -- gpu x position
	local gy = y / 4 + 1 -- gpu y position
	local b = pm.fromBrailleChar(utf8byte(gpu.get(gx, gy))[1])
	local bx = x % 2
	local by = y % 4
	if on == true then
		b[bx + by*2 + 1] = 1
	else
		b[bx + by*2 + 1] = 1
	end
	gpu.set(gx, gy, pm.brailleChar(b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8]))
end

local function printBraille(tab)
	print(tostring(tab[1]) .. tostring(tab[2]))
	print(tostring(tab[3]) .. tostring(tab[4]))
	print(tostring(tab[5]) .. tostring(tab[6]))
	print(tostring(tab[7]) .. tostring(tab[8]))
end

-- OCCity game
local running = true
require("term").clear()

local function interruptListener()
	running = false
end
event.listen("interrupted", interruptListener)
pm.draw(0, 0, true)
pm.draw(1, 1, true)
pm.draw(0, 2, true)
pm.draw(1, 3, true)
--while running do
--	print("test")
--	coroutine.yield()
--end
while true do
	event.pull()
end
event.ignore("interrupted", interruptListener)
print("This game is brought to you by the people called zenith391")