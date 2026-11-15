-- CRYSTAL RUSH shared tuning: palette, arena size, level table.
local Config = {}

Config.TITLE = "CRYSTAL RUSH"
Config.LIVES = 3
Config.COMBO_WINDOW = 2.5
Config.INVULN = 1.2
Config.POINTS = 10
Config.MULT_MAX = 3

Config.ARENA_W = 640
Config.ARENA_H = 480
Config.PLAYER_SIZE = 36
Config.PLAYER_SPEED = 320
Config.CRYSTAL_SIZE = 22
Config.DRIFTER_SIZE = 30
Config.CHASER_SIZE = 34
Config.HUD_H = 44
Config.TIMER_BAR_H = 6

Config.Colors = {
	BG = Color3.fromRGB(14, 27, 46),
	ARENA = Color3.fromRGB(22, 40, 63),
	ARENA_BORDER = Color3.fromRGB(42, 74, 107),
	CRYSTAL = Color3.fromRGB(255, 176, 32),
	HAZARD = Color3.fromRGB(255, 59, 48),
	CHASER = Color3.fromRGB(200, 30, 30),
	PLAYER = Color3.fromRGB(255, 224, 138),
	TEXT = Color3.fromRGB(255, 255, 255),
	SUBTEXT = Color3.fromRGB(159, 179, 200),
}

Config.LEVELS = {
	{ crystals = 6, drifters = 4, chasers = 0, time = 45, driftSpeed = 60 },
	{ crystals = 8, drifters = 6, chasers = 0, time = 40, driftSpeed = 90 },
	{ crystals = 10, drifters = 6, chasers = 2, time = 35, driftSpeed = 110, chaserSpeed = 95 },
}

function Config.getLevel(n)
	return Config.LEVELS[math.clamp(n, 1, #Config.LEVELS)]
end

function Config.levelCount()
	return #Config.LEVELS
end

return Config
