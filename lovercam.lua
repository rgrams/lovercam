
local M = {}

-- Try to load a 'vec2' module in the current directory
local module_dir = string.gsub(..., "%.[^%.]+$", "") .. "."
local vec2_loaded, vec2 = pcall(require, module_dir .. "vec2")
if not vec2_loaded then
	-- No vec2 module found, create a minimal table with the functions we need
	local vec2_mt = {}
	vec2 = {
		new = function(x, y) return setmetatable({x=x, y=y}, vec2_mt) end,
	}
	function vec2_mt.__call(_, x, y) return vec2.new(x, y) end
	function vec2_mt.__div(x, y) if type(y) == "number" then return vec2.new(x.x/y, x.y/y) end end
	function vec2_mt.__tostring(a) return string.format("(%+0.3f,%+0.3f)", a.x, a.y) end
	setmetatable(vec2, vec2_mt)
end

M.cur_cam = nil -- set to fallback_cam at end of module
local cameras = {}
M.SCALE_MODES = { "expand view", "fixed area", "fixed width", "fixed height" }
M.default_shake_falloff = "linear"
M.default_recoil_falloff = "quadratic"

-- localize stuff
local sin = math.sin
local cos = math.cos
local sqrt = math.sqrt
local rand = love.math.random
local TWO_PI = math.pi*2

--##############################  Module Functions ##############################

local function get_zoom_for_new_window(z, scale_mode, old_x, old_y, new_x, new_y)
	if scale_mode == "expand view" then
		return z
	elseif scale_mode == "fixed area" then
		local new_a = new_x * new_y
		local old_a = old_x * old_y
		return z * sqrt(new_a / old_a) -- zoom is the scale on both axes, hence the square root
	elseif scale_mode == "fixed width" then
		return z * new_x / old_x
	elseif scale_mode == "fixed height" then
		return z * new_y / old_y
	end
end

function M.window_resized(w, h) -- call once on module and it updates all cameras
	for i, self in ipairs(cameras) do
		self.zoom = get_zoom_for_new_window(self.zoom, self.scale_mode, self.win.x, self.win.y, w, h)
		self.win.x = w;  self.win.y = h
		self.half_win.x = self.win.x / 2;  self.half_win.y = self.win.y / 2
	end
end

function M.update(dt) -- updates all cameras
	for k, cam in pairs(cameras) do cam:update(dt) end
end

function M.update_current(dt)
	M.cur_cam:update(dt)
end

-- convert these names into functions applied to the current camera
local F = {	"apply_transform", "reset_transform", "deactivate", "pan", "screen_to_world",
	"zoom_in", "shake", "recoil", "stop_shaking", "follow", "unfollow" }

for i, func in ipairs(F) do -- calling functions on the module passes the call to the current camera
	M[func] = function(...) return M.cur_cam[func](M.cur_cam, ...) end
end

--##############################  Utilities & Misc.  ##############################

local function rotate(x, y, a) -- vector rotate with x, y
	local ax, ay = cos(a), sin(a)
	return ax*x - ay*y, ay*x + ax*y
end

local falloff_funcs = {
	linear = function(x) return x end,
	quadratic = function(x) return x*x end
}

local function lerpdt(ax, ay, bx, by, s, dt) -- vector lerp with x, y over dt
	local k = 1 - 0.5^(dt*s)
	return ax + (bx - ax)*k, ay + (by - ay)*k
end

--##############################  Camera Object Functions  ##############################

local function update(self, dt)
	-- update follows
	if self.follow_count > 0 then
		-- average position of all follows
		local fx, fy = 0, 0
		for obj, data in pairs(self.follows) do
			fx = fx + obj.pos.x;  fy = fy + obj.pos.y
		end
		fx = fx / self.follow_count;  fy = fy / self.follow_count
		fx, fy = lerpdt(self.pos.x, self.pos.y, fx, fy, self.follow_lerp_speed, dt)
		self.pos.x, self.pos.y = fx, fy

		-- TODO - follow weights
		-- TODO - follow deadzone
	end

	-- TODO - enforce bounds

	-- update shakes & recoils
	self.shake_x, self.shake_y = 0, 0
	for i=#self.shakes,1,-1 do -- iterate backwards because I may remove elements
		local s = self.shakes[i]
		local k = s.falloff(s.t/s.dur) -- falloff multiplier based on percent finished
		if s.dist then -- is a shake
			local d = rand() * s.dist * k
			local angle = rand() * TWO_PI
			self.shake_x = self.shake_x + sin(angle) * d
			self.shake_y = self.shake_y + cos(angle) * d
		elseif s.vec then -- is a recoil
			self.shake_x = self.shake_x + vec.x * k
			self.shake_y = self.shake_y + vec.y * k
		end
		s.t = s.t - dt
		if s.t <= 0 then table.remove(self.shakes, i) end
	end
end

local function apply_transform(self)
	-- save previous transform
	love.graphics.push()
	-- center view on camera - offset by half window res
	love.graphics.translate(self.half_win.x, self.half_win.y)
	-- view rot and translate are negative because we're really transforming the world
	love.graphics.rotate(-self.rot)
	love.graphics.scale(self.zoom, self.zoom)
	love.graphics.translate(-self.pos.x - self.shake_x, -self.pos.y - self.shake_y)

	-- TODO - fixed aspect ratio stuff
	--if self.fixed_aspect_ratio then
	--	love.graphics.setScissor(x, y, width, height)
	--end
end

local function reset_transform(self)
	love.graphics.pop()
	if self.fixed_aspect_ratio then love.graphics.setScissor() end
end

local function screen_to_world(self, x, y, delta)
	-- screen center offset
	if not delta then x = x - self.half_win.x;  y = y - self.half_win.y end
	x, y = x/self.zoom, y/self.zoom -- scale
	x, y = rotate(x, y, self.rot) -- rotate
	-- translate
	if not delta then x = x + self.pos.x;  y = y + self.pos.y end
	return x, y
end

-- TODO - world_to_screen()

local function deactivate(self)
	self.active = false
	self.cur_cam = fallback_cam
end

local function activate(self)
	self.active = true
	if self.cur_cam then self.cur_cam:deactivate() end
	self.cur_cam = self
end

-- convenience function for moving camera
--		mostly useful to call on the module to apply to the current camera
local function pan(self, dx, dy)
	self.pos.x = self.pos.x + dx
	self.pos.y = self.pos.y + dy
end

-- zoom in or out by a percentage
--		mostly useful to call on the module to apply to the current camera
local function zoom_in(self, z)
	self.zoom = self.zoom * (1 + z)
end

local function shake(self, intensity, dur, falloff)
	falloff = falloff or M.default_shake_falloff
	table.insert(self.shakes, {dist=intensity, t=dur, dur=dur, falloff=falloff_funcs[falloff]})
end

local function recoil(self, vec, dur, falloff)
	falloff = falloff or M.default_recoil_falloff
	table.insert(self.shakes, {vec=vec, t=dur, dur=dur, falloff=falloff_funcs[falloff]})
end

local function stop_shaking(self) -- clears all shakes and recoils
	for i, v in ipairs(self.shakes) do self.shakes[i] = nil end
end

-- following requires 'obj' to have a property 'pos' with 'x' and 'y' properties
local function follow(self, obj, allowMultiFollow, weight)
	-- using object table as key
	if not self.follows[obj] then
		self.follows[obj] = { weight=weight }
		self.follow_count = self.follow_count + 1
	else -- already following, just update weight
		self.follows[obj].weight = weight
	end
	if not allowMultiFollow and self.follow_count > 1 then
		for k, v in pairs(self.follows) do
			if k ~= obj then self.follows[k] = nil end
		end
		self.follow_count = 1
	end
end

local function unfollow(self, obj)
	if obj and self.follows[obj] then -- remove specified object from list
		self.follows[obj] = nil
		self.follow_count = self.follow_count - 1
	else -- no object specified, clear follows
		for k, v in pairs(self.follows) do self.follows[k] = nil end
		self.follow_count = 0
	end
end

function M.new(pos, rot, zoom, inactive, scale_mode)
	local n = {
		-- User Settings:
		active = not inactive,
		pos = vec2(pos.x, pos.y),
		rot = rot or 0,
		zoom = zoom or 1,
		scale_mode = scale_mode or "fixed area",

		-- functions, state properties, etc.
		apply_transform = apply_transform,
		reset_transform = reset_transform,
		win = vec2(love.graphics.getDimensions()),
		win_resized = win_resized,
		screen_to_world = screen_to_world,
		activate = activate,
		deactivate = deactivate,
		pan = pan,
		zoom_in = zoom_in,
		update = update,
		shake = shake,
		shakes = {},
		recoil = recoil,
		stop_shaking = stop_shaking,
		shake_x = 0,
		shake_y = 0,
		follow = follow,
		follows = {},
		follow_count = 0,
		unfollow = unfollow,
		follow_lerp_speed = 3
	}
	n.half_win = n.win / 2
	if n.active then M.cur_cam = n end
	table.insert(cameras, n)
	return n
end

local fallback_cam = M.new(vec2(love.graphics.getDimensions())/2)
M.cur_cam = fallback_cam

return M
