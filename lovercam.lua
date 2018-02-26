
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
local min = math.min
local max = math.max
local abs = math.abs
local sin = math.sin
local cos = math.cos
local sqrt = math.sqrt
local rand = love.math.random
local TWO_PI = math.pi*2

--##############################  Private Functions  ##############################

local function sign(x)
	return x >= 0 and 1 or -1
end

local function max_abs(a, b)
	return abs(a) > abs(b) and a or b
end

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

local function is_vec(v) -- check if `v` is a vector or a table with two values
	local t = type(v)
	if t == "table" or t == "userdata" or t == "cdata" then
		if v.x and v.y then
			return v.x, v.y
		elseif v.w and v.h then
			return v.w, v.h
		elseif v[1] and v[2] then
			return v[1], v[2]
		end
	end
end

local function get_aspect_rect_in_win(aspect_ratio, win_x, win_y)
	local s = math.min(win_x/aspect_ratio, win_y)
	local w, h = s*aspect_ratio, s
	local x, y = (win_x - w)/2, (win_y - h)/2
	return x, y, w, h
end

local function get_zoom_or_area(zoom_area)
	local t = type(zoom_area)
	if t == "nil" then
		return 1 -- default value
	elseif t == "number" then
		return zoom_area -- if number
	else
		x, y = is_vec(zoom_area)
		if x and y then
			return x, y -- if vec
		end
	end
	return -- invalid value, returns nil
end

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
	else
		error("Lovercam - get_zoom_for_new_window() - invalid scale mode: " .. tostring(scale_mode))
	end
end

--##############################  Module Functions ##############################

function M.window_resized(w, h) -- call once on module and it updates all cameras
	for i, self in ipairs(cameras) do
		self.zoom = get_zoom_for_new_window(self.zoom, self.scale_mode, self.win.x, self.win.y, w, h)
		self.win.x = w;  self.win.y = h
		self.half_win.x = self.win.x / 2;  self.half_win.y = self.win.y / 2
		if self.aspect_ratio then
			self.vp.x, self.vp.y, self.vp.w, self.vp.h = get_aspect_rect_in_win(self.aspect_ratio, w, h)
		end
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
	"world_to_screen", "zoom_in", "shake", "recoil", "stop_shaking", "follow", "unfollow", "set_bounds" }

for i, func in ipairs(F) do -- calling functions on the module passes the call to the current camera
	M[func] = function(...) return M.cur_cam[func](M.cur_cam, ...) end
end

--##############################  Camera Object Functions  ##############################

local function update(self, dt)
	-- update follows
	if self.follow_count > 0 then
		-- average position of all follows
		local total_weight = 0 -- total weight
		local fx, fy = 0, 0
		for obj, data in pairs(self.follows) do
			fx = fx + obj.pos.x * data.weight;  fy = fy + obj.pos.y * data.weight
			total_weight = total_weight + data.weight
		end
		fx = fx / total_weight;  fy = fy / total_weight
		fx, fy = lerpdt(self.pos.x, self.pos.y, fx, fy, self.follow_lerp_speed, dt)
		self.pos.x, self.pos.y = fx, fy

		-- TODO - follow deadzone
	end

	self:enforce_bounds()

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

	if self.aspect_ratio then
		love.graphics.setScissor(self.vp.x, self.vp.y, self.vp.w, self.vp.h)
	end
end

local function reset_transform(self)
	love.graphics.pop()
	if self.aspect_ratio then love.graphics.setScissor() end
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

local function world_to_screen(self, x, y, delta)
	if not delta then x = x - self.pos.x;  y = y - self.pos.y end
	x, y = rotate(x, y, -self.rot)
	x, y = x*self.zoom, y*self.zoom
	if not delta then x = x + self.half_win.x;  y = y + self.half_win.y end
	return x, y
end

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
	weight = weight or 1
	-- using object table as key
	if self.follows[obj] then -- already following, just update weight
		self.follows[obj].weight = weight
	else
		self.follows[obj] = { weight=weight }
		self.follow_count = self.follow_count + 1
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

local function set_bounds(self, lt, rt, top, bot)
	if lt and rt and top and bot then
		local b = {
			lt=lt, rt=rt, top=top, bot=bot,
			width=rt-lt, height=bot-top
		}
		b.center_x = lt + b.w/2
		b.center_y = top + b.h/2
		self.bounds = b
	else
		self.bounds = nil
	end
end

local bounds_vec_table = { tl=vec2(), tr=vec2(), bl=vec2(), br=vec2() } -- save the GC some work

local function enforce_bounds(self)
	if self.bounds then
		local bounds = self.bounds
		local vp = self.vp
		local c = bounds_vec_table -- corners
		-- get viewport corner positions in world space
		c.tl.x, c.tl.y = self:screen_to_world(vp.x, vp.y) -- top left
		c.tr.x, c.tr.y = self:screen_to_world(vp.x + vp.w, vp.y) -- top right
		c.bl.x, c.bl.y = self:screen_to_world(vp.x, vp.y + vp.h) -- bottom left
		c.br.x, c.br.y = self:screen_to_world(vp.x + vp.w, vp.y + vp.h) -- bottom right

		local w_view_w = max(c.tl.x, c.tr.x, c.bl.x, c.br.x) - min(c.tl.x, c.tr.x, c.bl.x, c.br.x)
		local w_view_h = max(c.tl.y, c.tr.y, c.bl.y, c.br.y) - min(c.tl.y, c.tr.y, c.bl.y, c.br.y)
		local set_x, set_y = true, true
		if w_view_w > bounds.width then
			self.pos.x = bounds.center_x
			set_x = false
		end
		if w_view_h > bounds.height then
			self.pos.y = bounds.center_y
			set_y = false
		end

		if set_x or set_y then
			local correct = vec2() -- total correction vec
			for k, v in pairs(c) do
				-- check if it's outside bounds
				if set_x then
					local x = v.x < bounds.lt and (v.x-bounds.lt) or v.x > bounds.rt and (v.x-bounds.rt) or 0
					correct.x = sign(correct.x) == sign(x) and max_abs(correct.x, x) or correct.x + x
				end
				if set_y then
					local y = v.y > bounds.bot and (v.y-bounds.bot) or v.y < bounds.top and (v.y-bounds.top) or 0
					correct.y = sign(correct.y) == sign(y) and max_abs(correct.y, y) or correct.y + y
				end
			end
			self.pos.x = self.pos.x - correct.x
			self.pos.y = self.pos.y - correct.y
		end
	end
end

function M.new(pos, rot, zoom_or_area, scale_mode, fixed_aspect_ratio, inactive)
	local win_x, win_y = love.graphics.getDimensions()
	scale_mode = scale_mode or "fixed area"

	local n = {
		-- User Settings:
		active = not inactive,
		pos = pos and vec2(pos.x, pos.y) or vec2(0, 0),
		rot = rot or 0,
		zoom = 1,
		scale_mode = scale_mode,
		aspect_ratio = fixed_aspect_ratio,

		-- functions, state properties, etc.
		apply_transform = apply_transform,
		reset_transform = reset_transform,
		win = vec2(win_x, win_y),
		half_win = vec2(win_x/2, win_y/2),
		win_resized = win_resized,
		screen_to_world = screen_to_world,
		world_to_screen = world_to_screen,
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
		follow_lerp_speed = 3,
		set_bounds = set_bounds,
		enforce_bounds = enforce_bounds
	}
	-- Fixed aspect ratio - get viewport/scissor
	local vp = {}
	if fixed_aspect_ratio then
		vp.x, vp.y, vp.w, vp.h = get_aspect_rect_in_win(n.aspect_ratio, win_x, win_y)
	else
		vp.x, vp.y, vp.w, vp.h = 0, 0, win_x, win_y
	end
	n.vp = vp

	-- Zoom
	local vx, vy = get_zoom_or_area(zoom_or_area)
	if not vx then
		error("Lovercam - M.new() - invalid zoom or area: " .. tostring(zoom_or_area))
	elseif vx and not vy then -- user supplied a zoom value, keep this zoom no matter what
		n.zoom = vx
	else -- user supplied a view area - use this with scale_mode and viewport to find zoom
		-- Want initial zoom to respect user settings. Even if "expand view" mode is used,
		-- we want to zoom so the specified area fits the window. Use "fixed area" mode
		-- instead to get a nice fit regardless of proportion differences.
		local sm = scale_mode == "expand view" and "fixed area" or scale_mode
		n.zoom = get_zoom_for_new_window(1, sm, vx, vy, n.vp.w, n.vp.h)
	end

	if n.active then M.cur_cam = n end
	table.insert(cameras, n)
	return n
end

local fallback_cam = M.new(vec2(love.graphics.getDimensions())/2)
M.cur_cam = fallback_cam

return M
