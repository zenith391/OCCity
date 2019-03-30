-- Using braille, the resolution of the (monochrome) game on a 160x50 display + gpu is: 
-- 320x200, meaning it's even lower resolution than the original SimCity for DOS xD
-- Sub-pixel manipulator (using braille)
local pm = {}
local unicode = require("unicode")
local bit = require("bit32")
local component = require("component")
local gpu = component.getPrimary("gpu")

function pm.brailleCharRaw(a, b, c, d, e, f, g, h)
	return 10240 + 128 * h + 64 * g + 32 * f + 16 * d + 8 * b + 4 * e + 2 * c + a
end
function pm.brailleChar(a, b, c, d, e, f, g, h) -- from MineOS text.brailleChar
	return unicode.char(pm.brailleCharRaw(a, b, c, d, e, f, g, h))
end

function pm.fromBrailleChar(ch)
	local tab = {}
	local c = ch - 10240
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

function pm.draw(x, y, on)
	-- x, y = position
	-- If on is true then put white, else put black
	local gx = x / 2 -- gpu x position
	local gy = y / 4 -- gpu y position
	local braille = pm.fromBrailleChar(gpu.get(gx, gy))
	local bx = x % 2
	local by = y % 4
end

local function printBraille(tab)
	print(tostring(tab[1]) .. tostring(tab[2]))
	print(tostring(tab[3]) .. tostring(tab[4]))
	print(tostring(tab[5]) .. tostring(tab[6]))
	print(tostring(tab[7]) .. tostring(tab[8]))
end

printBraille(pm.fromBrailleChar(pm.brailleCharRaw(1, 0, 0, 1, 1, 0, 0, 1)))