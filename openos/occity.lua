-- Using braille, the resolution of the (monochrome) game on a 160x50 display + gpu is: 
-- 320x200, meaning it's like VGA hi-color mode.. but without the colors xD
-- Sub-pixel manipulator (using braille)
-- Made by zenith391
local pm = {}
local unicode = require("unicode")
local bit = require("bit32")
local component = require("component")
local event = require("event")
local thread = require("thread")
local gpu = component.getPrimary("gpu")

-- All tiles in game
-- TODO: make a tileset
local tiles = {
	{
		{true, true, true, true, true, true, true},
		{true, true, true, true, true, true, true},
		{true, true, true, true, true, true, true},
		{true, true, true, true, true, true, true},
		{true, true, true, true, true, true, true},
		{true, true, true, true, true, true, true},
		{true, true, true, true, true, true, true}
	},
	{
		{false, false, false, false, false, false, true},
		{false, false, false, false, false, true, true},
		{false, false, false, false, true, true, true},
		{false, false, false, true, true, true, true},
		{false, false, true, true, true, true, true},
		{false, true, true, true, true, true, true},
		{true, true, true, true, true, true, true}
	},
	{
		{true, true, true, true, true, true, true},
		{false, true, true, true, true, true, true},
		{false, false, true, true, true, true, true},
		{false, false, false, true, true, true, true},
		{false, false, false, false, true, true, true},
		{false, false, false, false, false, true, true},
		{false, false, false, false, false, false, true}
	},
	{
		{true, true, true, true, true, true, true},
		{true, true, true, true, true, true, false},
		{true, true, true, true, true, false, false},
		{true, true, true, true, false, false, false},
		{true, true, true, false, false, false, false},
		{true, true, false, false, false, false, false},
		{true, false, false, false, false, false, false}
	},
	{
		{false, false, false, false, false, false, false},
		{false, false, false, false, false, false, false},
		{false, false, false, false, false, false, false},
		{false, false, false, false, false, false, false},
		{false, false, false, false, false, false, false},
		{false, false, false, false, false, false, false},
		{false, false, false, false, false, false, false}
	}
}

local terrain = nil
local w, h = gpu.maxResolution()

if w < 160 or h < 50 then
	io.stderr:write("Sorry, the game is designed to work on 160x50!\n")
	return
end

gpu.setResolution(160, 50)

config = {
	optimize = true
}

function utf8byte(utf)
	local res, seq, val = {}, 0, nil
	for i = 1, #utf do
		local c = string.byte(utf, i)
		if seq == 0 then
			table.insert(res, val)
			seq = c < 0x80 and 1 or c < 0xE0 and 2 or c < 0xF0 and 3 or
			      c < 0xF8 and 4 or --c < 0xFC and 5 or c < 0xFE and 6 or
				  error("invalid UTF-8 character sequence")
			val = bit.band(c, 2^(8-seq) - 1)
		else
			val = bit.bor(bit.lshift(val, 6), bit.band(c, 0x3F))
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

pm.cc = pm.brailleChar(0, 0, 0, 0, 0, 0, 0, 0) -- cached char
pm.cx = -1 -- cached char x
pm.cy = -1 -- cached char y

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
	if gx ~= pm.cx or gy ~= pm.cy or (not config.optimize) then
		if config.rainbow then
			gpu.setBackground(math.random() * 0xFFFFFF)
			gpu.setForeground(math.random() * 0xFFFFFF)
		end
		gpu.set(pm.cx, pm.cy, pm.cc)
		pm.cc = gpu.get(gx, gy)
		pm.cx = gx
		pm.cy = gy
	end
	local b = pm.fromBrailleChar(utf8byte(pm.cc)[1])
	local bx = x % 2
	local by = y % 4
	if on == true then
		b[bx + by*2 + 1] = 1
	else
		b[bx + by*2 + 1] = 0
	end
	local bc = pm.brailleChar(b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8])
	pm.cc = bc
end

function pm.fill(x, y, width, height, on)
	local i = x
	local j = y
	if width > 1 and height > 3 and config.optimize then
		local rw = math.floor(width/2+1)
		local rh = math.floor(height/4+1)
		local rx = math.floor(x/2+1)
		local ry = math.floor(y/4+1)
		if on then
			gpu.setBackground(0xFFFFFF)
		else
			gpu.setBackground(0x000000)
		end
		gpu.fill(rx, ry, rw, rh, " ")
		pm.cx = -1
		pm.cy = -1
		gpu.setBackground(0x000000)
		i = math.floor(x%2+width/2*2+x/2*2)
		j = math.floor(y%4+height/4*4+y/4*4)
	end
	while i < x + width do
		j = y
		while j < y + height do
			pm.draw(i, j, on)
			j = j + 1
		end
		i = i + 1
	end
end

-- OCCity game
local running = true
print("WARNING! ONLY USE CTRL+C TO CLOSE THE GAME!")
os.sleep(1)

local function interruptListener()
	running = false
end

local money = 50000
local gameThread = thread.create(function()
	local oldmoney = 0
	local dirty = true
	while running do
		if money ~= oldmoney then
			oldmoney = money
			dirty = true
		end
		if dirty then
			gpu.set(22, 1, "Funds: $" .. tostring(money))
		end
		os.sleep(0.1)
	end
end)

local function loadTerrain()
	local file = io.open("default.ter", "r")
	local width = file:read("*n")
	local height = file:read("*n")
	print(width .. "x" .. height)
	terrain = {}
	for y=1, height do
		terrain[y] = {}
		for x=1, width do
			terrain[y][x] = file:read("*n")
		end
	end
	file:close()
end

local function drawResidentialHouse(x, y) -- width: 17, height: 17
	pm.fill(x, y, 16, 1, true)
	pm.fill(x, y+16, 16, 1, true)
	pm.fill(x, y, 1, 16, true)
	pm.fill(x+16, y, 1, 17, true)
	
	-- R
	pm.fill(x + 4, y + 4, 1, 10, true)
	pm.fill(x + 4, y + 4, 7, 1, true)
	pm.fill(x + 11, y + 4, 1, 4, true)
	pm.fill(x + 4, y + 8, 7, 1, true)
	pm.fill(x + 11, y + 9, 1, 5, true)
end

local function drawBuildPanel()
	pm.fill(0, 0, 40, 200, true)
	pm.fill(9, 13, 19, 19, false)
	drawResidentialHouse(10, 14)
	gpu.setBackground(0xFFFFFF)
	gpu.setForeground(0x000000)
	gpu.set(6, 2, "Buildings")
	gpu.setForeground(0xFFFFFF)
	gpu.setBackground(0x000000)
end

local oldX = -1
local oldY = -1
local function mousePress(_, screen, x, y, button)
	if oldX ~= -1 then
		pm.fill(oldX * 2, oldY * 4, 17, 17, false)
		if oldX < 22 then
			drawBuildPanel()
		end
		oldX = x
		oldY = y
	else
		oldX = x
		oldY = y
	end
	drawResidentialHouse(150, 92)
	drawResidentialHouse(x*2, y*4)
end

local function drawTile(ox, oy, tile)
	local img = tiles[tile]
	for y=1, 7 do
		for x=1, 7 do
			local pix = img[y][x]
			pm.draw(ox + x, oy + y, pix)
		end
	end
end

print("Loading terrain..")
loadTerrain()

require("term").clear()

drawResidentialHouse(150, 92)
drawBuildPanel()

for iy=1, 5 do
	for ix=1, 40 do
		local dx, dy = 40 + ix*7, 0 + iy*7
		if dx < 303 and dy < 193 then
			drawTile(dx, dy, terrain[iy][ix])
		end
	end
end

event.listen("interrupted", interruptListener)
event.listen("touch", mousePress)
event.listen("drag", mousePress)

while running do
	event.pull(0.1)
end

gameThread:kill()

require("term").clear()
event.ignore("interrupted", interruptListener)
event.ignore("touch", mousePress)
event.ignore("drag", mousePress)

-- Reference to Maxis, when you close SimEarth, it gives a similar message about Maxis
print("This game was brought to you by the people called Zen1th")
