-- CRYSTAL RUSH deterministic layout: crystal spots, hazard spawns, drift paths.
-- Same (level, seed) always builds the same layout on server and client.
local Config = require(script.Parent.Config)

local Layout = {}

function Layout.buildLayout(level, seed)
	local cfg = Config.getLevel(level)
	math.randomseed(seed)
	local layout = {
		crystals = {},
		drifters = {},
		chasers = {},
		playerSpawn = { x = (Config.ARENA_W - Config.PLAYER_SIZE) / 2, y = Config.ARENA_H - 60 },
	}
	local spawnCx = layout.playerSpawn.x + Config.PLAYER_SIZE / 2
	local spawnCy = layout.playerSpawn.y + Config.PLAYER_SIZE / 2
	for _i = 1, cfg.crystals do
		local cx = 60
		local cy = 60
		local placed = false
		for _try = 1, 20 do
			cx = 40 + math.random() * (Config.ARENA_W - 80 - Config.CRYSTAL_SIZE)
			cy = 40 + math.random() * (Config.ARENA_H - 80 - Config.CRYSTAL_SIZE)
			placed = true
			local dx = (cx + Config.CRYSTAL_SIZE / 2) - spawnCx
			local dy = (cy + Config.CRYSTAL_SIZE / 2) - spawnCy
			if dx * dx + dy * dy < 70 * 70 then
				placed = false
			else
				for _, other in ipairs(layout.crystals) do
					local ox = (cx + Config.CRYSTAL_SIZE / 2) - (other.x + Config.CRYSTAL_SIZE / 2)
					local oy = (cy + Config.CRYSTAL_SIZE / 2) - (other.y + Config.CRYSTAL_SIZE / 2)
					if ox * ox + oy * oy < 48 * 48 then
						placed = false
						break
					end
				end
			end
			if placed then
				break
			end
		end
		table.insert(layout.crystals, { x = cx, y = cy })
	end
	for _i = 1, cfg.drifters do
		local dx = math.random() * 2 - 1
		local dy = math.random() * 2 - 1
		if math.abs(dx) < 0.2 and math.abs(dy) < 0.2 then
			dx = 1
			dy = 0
		end
		local len = math.sqrt(dx * dx + dy * dy)
		table.insert(layout.drifters, {
			x = 30 + math.random() * (Config.ARENA_W - 60 - Config.DRIFTER_SIZE),
			y = 30 + math.random() * (Config.ARENA_H - 60 - Config.DRIFTER_SIZE),
			dx = dx / len,
			dy = dy / len,
			speed = cfg.driftSpeed,
		})
	end
	local corners = {
		{ x = 60, y = 60 },
		{ x = Config.ARENA_W - 60 - Config.CHASER_SIZE, y = 60 },
		{ x = 60, y = Config.ARENA_H - 60 - Config.CHASER_SIZE },
		{ x = Config.ARENA_W - 60 - Config.CHASER_SIZE, y = Config.ARENA_H - 60 - Config.CHASER_SIZE },
	}
	-- Chasers start on opposite corners so they never share a spawn.
	local first = math.random(0, 3)
	for i = 1, cfg.chasers do
		local spot = corners[((first + (i - 1) * 2) % 4) + 1]
		table.insert(layout.chasers, { x = spot.x, y = spot.y })
	end
	return layout
end

return Layout
