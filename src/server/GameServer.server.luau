-- CRYSTAL RUSH server: owns phase, level, score, lives, timer; validates collect/hit.
-- Honest note: single-player. The server validates what it can (a crystal exists and
-- is not taken yet, the hit cooldown, phase and timer). Hazard motion is computed on
-- the client from the shared layout + clock, so it stays deterministic on both sides.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(shared:WaitForChild("Config"))
local Layout = require(shared:WaitForChild("Layout"))

local stateEvent = ReplicatedStorage:WaitForChild("StateEvent")
local actionEvent = ReplicatedStorage:WaitForChild("ActionEvent")

local state = {
	phase = "Lobby",
	level = 1,
	score = 0,
	lives = Config.LIVES,
	crystalsLeft = 0,
	combo = 1,
	comboCount = 0,
	lastCollect = -10,
	lastHit = -10,
	deadline = 0,
	seed = 1,
	layout = nil,
	taken = {},
	endReason = "",
}

function startLevel(level)
	local cfg = Config.getLevel(level)
	state.level = level
	state.seed = (os.time() % 100000) + level * 7919
	state.layout = Layout.buildLayout(level, state.seed)
	state.taken = {}
	state.crystalsLeft = cfg.crystals
	state.combo = 1
	state.comboCount = 0
	state.phase = "Playing"
	state.deadline = os.clock() + cfg.time
	state.endReason = ""
	sendState()
end

function sendState()
	local cfg = Config.getLevel(state.level)
	stateEvent:FireAllClients({
		phase = state.phase,
		level = state.level,
		score = state.score,
		lives = state.lives,
		crystalsLeft = state.crystalsLeft,
		totalCrystals = cfg.crystals,
		combo = state.combo,
		timeLeft = math.max(0, state.deadline - os.clock()),
		timeMax = cfg.time,
		seed = state.seed,
		endReason = state.endReason,
	})
end

function endGame(won, reason)
	if state.phase ~= "Playing" and state.phase ~= "LevelClear" then
		return
	end
	state.phase = won and "Won" or "Lost"
	state.endReason = reason
	sendState()
end

function onAction(player, kind, data)
	if kind == "start" or kind == "restart" then
		if state.phase == "Lobby" or state.phase == "Won" or state.phase == "Lost" then
			state.score = 0
			state.lives = Config.LIVES
			startLevel(1)
		end
		return
	end
	if state.phase ~= "Playing" then
		return
	end
	if kind == "collect" then
		local index = tonumber(data)
		if not index or index < 1 or index > #state.layout.crystals or state.taken[index] then
			return
		end
		state.taken[index] = true
		local now = os.clock()
		if now - state.lastCollect <= Config.COMBO_WINDOW then
			state.comboCount += 1
		else
			state.comboCount = 1
		end
		state.lastCollect = now
		state.combo = math.min(state.comboCount, Config.MULT_MAX)
		state.score += Config.POINTS * state.combo
		state.crystalsLeft -= 1
		if state.crystalsLeft <= 0 then
			if state.level >= Config.levelCount() then
				endGame(true, "clear")
			else
				state.phase = "LevelClear"
				sendState()
				task.delay(2, function()
					if state.phase == "LevelClear" then
						startLevel(state.level + 1)
					end
				end)
			end
		else
			sendState()
		end
	elseif kind == "hit" then
		local now = os.clock()
		if now - state.lastHit < Config.INVULN then
			return
		end
		state.lastHit = now
		state.combo = 1
		state.comboCount = 0
		state.lives -= 1
		if state.lives <= 0 then
			endGame(false, "lives")
		else
			sendState()
		end
	end
end

function watchTimer()
	while true do
		task.wait(0.2)
		if state.phase == "Playing" and os.clock() >= state.deadline then
			endGame(false, "time")
		end
	end
end

actionEvent.OnServerEvent:Connect(onAction)

Players.PlayerAdded:Connect(function(_player)
	sendState()
end)

task.spawn(watchTimer)
sendState()
