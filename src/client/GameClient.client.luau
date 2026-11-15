-- CRYSTAL RUSH client: input, render loop, HUD, effects, collision, reports to server.
-- Keys: WASD/arrows move (read with IsKeyDown in RenderStepped), ENTER starts, R restarts.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(shared:WaitForChild("Config"))
local Layout = require(shared:WaitForChild("Layout"))

local function getEvent(name)
	local ok, ev = pcall(function()
		return ReplicatedStorage:WaitForChild(name, 5)
	end)
	if ok and ev then
		return ev
	end
	return nil
end

local stateEvent = getEvent("StateEvent")
local actionEvent = getEvent("ActionEvent")

local C = Config.Colors
local snap = { phase = "Lobby", level = 1, score = 0, lives = 3, crystalsLeft = 0, totalCrystals = 0, combo = 1, timeLeft = 0, timeMax = 45, seed = 0, endReason = "" }
local layout = nil
local lastSeed = -1
local lastLevel = -1
local px = 0
local py = 0
local timeLeft = 0
local invulnUntil = 0
local shakeUntil = 0
local flashAlpha = 0
local collected = {}
local hazards = {}
local popups = {}
local confetti = {}

local gui, arena, hudLevel, hudScore, hudHearts, hudCombo, timerFill
local startOverlay, banner, winOverlay, loseOverlay, loseTitle, winScore, loseScore
local playerFrame, flashFrame, crystalFolder, hazardFolder

local function mkFrame(parent, name, pos, size, color)
	local f = Instance.new("Frame")
	f.Name = name
	f.Position = pos
	f.Size = size
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function mkLabel(parent, text, pos, size, textSize, font, color)
	local l = Instance.new("TextLabel")
	l.Position = pos
	l.Size = size
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = color
	l.TextSize = textSize
	l.Font = font
	l.Parent = parent
	return l
end

local function mkOverlay(name)
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = C.BG
	f.BackgroundTransparency = 0.15
	f.BorderSizePixel = 0
	f.Visible = false
	f.Parent = arena
	return f
end

local function overlayTitle(parent, text, y, size, color)
	local t = mkLabel(parent, text, UDim2.new(0.5, 0, 0, y), UDim2.fromOffset(560, 64), size, Enum.Font.GothamBold, color)
	t.AnchorPoint = Vector2.new(0.5, 0)
	return t
end

local function overlayLine(parent, text, y, h, size, font, color)
	local t = mkLabel(parent, text, UDim2.new(0.5, 0, 0, y), UDim2.fromOffset(560, h), size, font, color)
	t.AnchorPoint = Vector2.new(0.5, 0)
	return t
end

local function mkToken(parent, name, x, y, size, color, round)
	local f = Instance.new("Frame")
	f.Name = name
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(size, size)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Parent = parent
	if round then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = f
	end
	return f
end

function renderState(s)
	snap = s
	timeLeft = s.timeLeft
	if s.seed ~= lastSeed or s.level ~= lastLevel then
		lastSeed = s.seed
		lastLevel = s.level
		layout = Layout.buildLayout(s.level, s.seed)
		px = layout.playerSpawn.x
		py = layout.playerSpawn.y
		buildLevel()
	end
	hudLevel.Text = "LEVEL " .. tostring(s.level)
	hudScore.Text = "SCORE " .. tostring(s.score)
	local hearts = ""
	for _i = 1, s.lives do
		hearts = hearts .. "♥"
	end
	hudHearts.Text = hearts
	if s.combo > 1 then
		hudCombo.Text = "COMBO x" .. tostring(s.combo)
	else
		hudCombo.Text = ""
	end
	startOverlay.Visible = s.phase == "Lobby"
	winOverlay.Visible = s.phase == "Won"
	loseOverlay.Visible = s.phase == "Lost"
	if s.phase == "Won" then
		winScore.Text = "SCORE " .. tostring(s.score)
		spawnConfetti()
	end
	if s.phase == "Lost" then
		if s.endReason == "time" then
			loseTitle.Text = "TIME UP"
		else
			loseTitle.Text = "GAME OVER"
		end
		loseScore.Text = "SCORE " .. tostring(s.score)
	end
	if s.phase == "LevelClear" then
		banner.Text = "LEVEL " .. tostring(s.level + 1) .. " — FASTER!"
		banner.Visible = true
	else
		banner.Visible = false
	end
end

function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "CrystalRushGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	local bg = mkFrame(gui, "Background", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), C.BG)
	arena = Instance.new("Frame")
	arena.Name = "Arena"
	arena.AnchorPoint = Vector2.new(0.5, 0.5)
	arena.Position = UDim2.fromScale(0.5, 0.5)
	arena.Size = UDim2.fromOffset(Config.ARENA_W, Config.ARENA_H)
	arena.BackgroundColor3 = C.ARENA
	arena.BorderColor3 = C.ARENA_BORDER
	arena.BorderSizePixel = 2
	arena.Parent = bg
	local hud = mkFrame(arena, "Hud", UDim2.fromScale(0, 0), UDim2.new(1, 0, 0, Config.HUD_H), C.ARENA)
	hud.BackgroundTransparency = 1
	hudLevel = mkLabel(hud, "LEVEL 1", UDim2.fromOffset(16, 6), UDim2.fromOffset(120, 32), 22, Enum.Font.GothamBold, C.TEXT)
	hudLevel.TextXAlignment = Enum.TextXAlignment.Left
	hudScore = mkLabel(hud, "SCORE 0", UDim2.fromOffset(150, 6), UDim2.fromOffset(200, 32), 22, Enum.Font.GothamBold, C.TEXT)
	hudScore.TextXAlignment = Enum.TextXAlignment.Left
	hudCombo = mkLabel(hud, "", UDim2.fromOffset(360, 6), UDim2.fromOffset(120, 32), 22, Enum.Font.GothamBold, C.CRYSTAL)
	hudCombo.TextXAlignment = Enum.TextXAlignment.Left
	hudHearts = mkLabel(hud, "♥♥♥", UDim2.new(1, -140, 0, 6), UDim2.fromOffset(124, 32), 22, Enum.Font.GothamBold, C.HAZARD)
	hudHearts.TextXAlignment = Enum.TextXAlignment.Right
	local timerBack = mkFrame(arena, "TimerBack", UDim2.fromOffset(0, Config.HUD_H), UDim2.new(1, 0, 0, Config.TIMER_BAR_H), Color3.fromRGB(10, 18, 32))
	timerFill = mkFrame(timerBack, "TimerFill", UDim2.fromScale(0, 0), UDim2.new(1, 0, 1, 0), C.CRYSTAL)
	crystalFolder = Instance.new("Folder")
	crystalFolder.Name = "Crystals"
	crystalFolder.Parent = arena
	hazardFolder = Instance.new("Folder")
	hazardFolder.Name = "Hazards"
	hazardFolder.Parent = arena
	playerFrame = mkFrame(arena, "Player", UDim2.fromOffset(0, 0), UDim2.fromOffset(Config.PLAYER_SIZE, Config.PLAYER_SIZE), C.PLAYER)
	local pCorner = Instance.new("UICorner")
	pCorner.CornerRadius = UDim.new(0.3, 0)
	pCorner.Parent = playerFrame
	flashFrame = mkFrame(arena, "Flash", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), C.HAZARD)
	flashFrame.BackgroundTransparency = 1
	banner = mkLabel(arena, "", UDim2.fromScale(0.5, 0.4), UDim2.fromOffset(480, 48), 32, Enum.Font.GothamBold, C.CRYSTAL)
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Visible = false
	startOverlay = mkOverlay("StartOverlay")
	startOverlay.Visible = true
	overlayTitle(startOverlay, Config.TITLE, 90, 48, C.CRYSTAL)
	overlayLine(startOverlay, "Collect every crystal before the timer runs out.\n3 levels — dodge the red hazards!", 170, 60, 20, Enum.Font.Gotham, C.TEXT)
	overlayLine(startOverlay, "Move: WASD or Arrow Keys\nENTER: start   •   R: restart", 250, 60, 20, Enum.Font.Gotham, C.SUBTEXT)
	overlayLine(startOverlay, "Press ENTER to start", 340, 40, 24, Enum.Font.GothamBold, C.TEXT)
	winOverlay = mkOverlay("WinOverlay")
	overlayTitle(winOverlay, "YOU WIN!", 130, 48, C.CRYSTAL)
	winScore = overlayLine(winOverlay, "SCORE 0", 210, 40, 24, Enum.Font.GothamBold, C.TEXT)
	overlayLine(winOverlay, "Press R to play again", 270, 40, 20, Enum.Font.Gotham, C.SUBTEXT)
	loseOverlay = mkOverlay("LoseOverlay")
	loseTitle = overlayTitle(loseOverlay, "GAME OVER", 130, 48, C.HAZARD)
	loseScore = overlayLine(loseOverlay, "SCORE 0", 210, 40, 24, Enum.Font.GothamBold, C.TEXT)
	overlayLine(loseOverlay, "Press R to retry", 270, 40, 20, Enum.Font.Gotham, C.SUBTEXT)
	gui.Parent = player:WaitForChild("PlayerGui")
end

function buildLevel()
	crystalFolder:ClearAllChildren()
	hazardFolder:ClearAllChildren()
	collected = {}
	hazards = {}
	if not layout then
		return
	end
	for i, spot in ipairs(layout.crystals) do
		local f = mkToken(crystalFolder, "Crystal" .. tostring(i), spot.x, spot.y, Config.CRYSTAL_SIZE, C.CRYSTAL, false)
		f.Rotation = 45
	end
	for _, d in ipairs(layout.drifters) do
		local f = mkToken(hazardFolder, "Drifter", d.x, d.y, Config.DRIFTER_SIZE, C.HAZARD, true)
		table.insert(hazards, { frame = f, x = d.x, y = d.y, dx = d.dx, dy = d.dy, speed = d.speed, size = Config.DRIFTER_SIZE, chaser = false })
	end
	for _, c in ipairs(layout.chasers) do
		local f = mkToken(hazardFolder, "Chaser", c.x, c.y, Config.CHASER_SIZE, C.CHASER, true)
		table.insert(hazards, { frame = f, x = c.x, y = c.y, dx = 0, dy = 0, speed = Config.getLevel(snap.level).chaserSpeed or 95, size = Config.CHASER_SIZE, chaser = true })
	end
end

function stepGame(dt)
	local now = os.clock()
	if snap.phase == "Playing" then
		timeLeft = math.max(0, timeLeft - dt)
		local dx = 0
		local dy = 0
		if UserInputService:IsKeyDown(Enum.KeyCode.Left) or UserInputService:IsKeyDown(Enum.KeyCode.A) then
			dx -= 1
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Right) or UserInputService:IsKeyDown(Enum.KeyCode.D) then
			dx += 1
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Up) or UserInputService:IsKeyDown(Enum.KeyCode.W) then
			dy -= 1
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Down) or UserInputService:IsKeyDown(Enum.KeyCode.S) then
			dy += 1
		end
		if dx ~= 0 or dy ~= 0 then
			local len = math.sqrt(dx * dx + dy * dy)
			px = math.clamp(px + (dx / len) * Config.PLAYER_SPEED * dt, 0, Config.ARENA_W - Config.PLAYER_SIZE)
			py = math.clamp(py + (dy / len) * Config.PLAYER_SPEED * dt, 0, Config.ARENA_H - Config.PLAYER_SIZE)
		end
		if layout then
			for i, spot in ipairs(layout.crystals) do
				if not collected[i] and px < spot.x + Config.CRYSTAL_SIZE and px + Config.PLAYER_SIZE > spot.x and py < spot.y + Config.CRYSTAL_SIZE and py + Config.PLAYER_SIZE > spot.y then
					collected[i] = true
					local frame = crystalFolder:FindFirstChild("Crystal" .. tostring(i))
					if frame then
						frame.Visible = false
					end
					showPopup("+" .. tostring(Config.POINTS * snap.combo), spot.x, spot.y)
					if actionEvent then
						actionEvent:FireServer("collect", i)
					end
				end
			end
		end
		for _, h in ipairs(hazards) do
			if h.chaser then
				local vx = (px + Config.PLAYER_SIZE / 2) - (h.x + h.size / 2)
				local vy = (py + Config.PLAYER_SIZE / 2) - (h.y + h.size / 2)
				local len = math.sqrt(vx * vx + vy * vy)
				if len > 1 then
					h.x = h.x + (vx / len) * h.speed * dt
					h.y = h.y + (vy / len) * h.speed * dt
				end
			else
				h.x = h.x + h.dx * h.speed * dt
				h.y = h.y + h.dy * h.speed * dt
				if h.x <= 0 or h.x >= Config.ARENA_W - h.size then
					h.dx = -h.dx
					h.x = math.clamp(h.x, 0, Config.ARENA_W - h.size)
				end
				if h.y <= 0 or h.y >= Config.ARENA_H - h.size then
					h.dy = -h.dy
					h.y = math.clamp(h.y, 0, Config.ARENA_H - h.size)
				end
			end
			h.frame.Position = UDim2.fromOffset(math.floor(h.x + 0.5), math.floor(h.y + 0.5))
			if now > invulnUntil and px < h.x + h.size and px + Config.PLAYER_SIZE > h.x and py < h.y + h.size and py + Config.PLAYER_SIZE > h.y then
				invulnUntil = now + Config.INVULN
				flashAlpha = 0.45
				shakeUntil = now + 0.3
				if actionEvent then
					actionEvent:FireServer("hit", 0)
				end
			end
		end
	end
	playerFrame.Position = UDim2.fromOffset(math.floor(px + 0.5), math.floor(py + 0.5))
	if now < invulnUntil then
		playerFrame.BackgroundTransparency = 0.5
	else
		playerFrame.BackgroundTransparency = 0
	end
	if flashAlpha > 0 then
		flashAlpha = math.max(0, flashAlpha - dt * 1.5)
		flashFrame.BackgroundTransparency = 1 - flashAlpha
	end
	if now < shakeUntil then
		arena.Position = UDim2.new(0.5, math.random(-6, 6), 0.5, math.random(-6, 6))
	else
		arena.Position = UDim2.fromScale(0.5, 0.5)
	end
	if snap.timeMax > 0 then
		timerFill.Size = UDim2.new(math.clamp(timeLeft / snap.timeMax, 0, 1), 0, 1, 0)
	end
	for i = #popups, 1, -1 do
		local p = popups[i]
		p.life = p.life - dt
		if p.life <= 0 then
			p.label:Destroy()
			table.remove(popups, i)
		else
			p.label.Position = UDim2.fromOffset(p.x, math.floor(p.y - (0.8 - p.life) * 40 + 0.5))
			p.label.TextTransparency = 1 - (p.life / 0.8)
		end
	end
	for i = #confetti, 1, -1 do
		local c = confetti[i]
		c.y = c.y + c.speed * dt
		if c.y > Config.ARENA_H then
			c.frame:Destroy()
			table.remove(confetti, i)
		else
			c.frame.Position = UDim2.fromOffset(math.floor(c.x + 0.5), math.floor(c.y + 0.5))
		end
	end
end

function showPopup(text, x, y)
	local label = mkLabel(arena, text, UDim2.fromOffset(x, y), UDim2.fromOffset(60, 28), 20, Enum.Font.GothamBold, C.CRYSTAL)
	table.insert(popups, { label = label, x = x, y = y, life = 0.8 })
end

function spawnConfetti()
	for _, c in ipairs(confetti) do
		c.frame:Destroy()
	end
	confetti = {}
	local colors = { C.CRYSTAL, C.TEXT, C.HAZARD, C.PLAYER }
	for i = 1, 40 do
		local f = mkFrame(arena, "Confetti", UDim2.fromOffset(0, 0), UDim2.fromOffset(10, 10), colors[((i - 1) % 4) + 1])
		f.Rotation = math.random(0, 90)
		table.insert(confetti, { frame = f, x = math.random(0, Config.ARENA_W - 10), y = math.random(-120, 0), speed = math.random(90, 200) })
	end
end

function bindKeys()
	local function onStart(_action, state, _input)
		if state == Enum.UserInputState.Begin and actionEvent then
			actionEvent:FireServer("start", 0)
		end
	end
	local function onRestart(_action, state, _input)
		if state == Enum.UserInputState.Begin and actionEvent then
			actionEvent:FireServer("restart", 0)
		end
	end
	local okStart = pcall(function()
		ContextActionService:BindAction("CrystalStart", onStart, false, Enum.KeyCode.Return)
	end)
	local okRestart = pcall(function()
		ContextActionService:BindAction("CrystalRestart", onRestart, false, Enum.KeyCode.R)
	end)
	if not okStart or not okRestart then
		warn("CRYSTAL RUSH: key bind failed")
	end
end

buildGui()
bindKeys()
if stateEvent then
	stateEvent.OnClientEvent:Connect(renderState)
end
RunService.RenderStepped:Connect(stepGame)
