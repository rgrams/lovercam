# Lovercam

A camera library for Löve. (A work in progress)

## Feature List
* Window resize handling - with four scale modes:
	* Expand View
	* Fixed Area
	* Fixed Width
	* Fixed Height
* Multiple cameras
* Zoom
* Shake
* Recoil
* Following
* Screen-to-World transforms

## To Do:
* Fixed Aspect Ratio (black bars)
* Initial View Area
* Camera Bounds
* Weighted Multi-Following
* Follow Deadzone
* Split-Screen Support ((?) use fixed aspect + an offset?)
* Camera Lead
* Zoom to Point
* Rotational Shake
* Multi-Follow Zoom (?)

## Basic Setup

### M.new(pos, rot, zoom, inactive, scale_mode)
Creates a new camera object. The module stores the latest active camera in `M.cur_cam`. The `scale_mode` must be one of the following strings: "expand view", "fixed area", "fixed width", or "fixed height".

## Update Functions

### M.window_resized(w, h)
Updates all cameras for the new window size. This may alter the zoom of your cameras, depending on their scale mode. ("expand view" mode cameras keep the same zoom.)
### M.update(dt)
Runs the update functions of all cameras. This will step forward all time-related features: following, shake, & recoil, and enforce camera bounds. For finer control you can use M.update_current() to only update the currently active camera, or directly call the update function of any camera you have a reference to (i.e. my_camera:update(dt)).
### M.update_current(dt)
Runs the update function of the currently active camera only.

## Shortcut to Current Camera
All of the following camera functions, except `update` and `activate`, can be used as module functions which, will call them on the current active camera. This way, you generally don't need to keep track of camera object references and which one is active, except if you want to switch between multiple cameras or only update certain ones, etc.

## Camera Functions

### cam:update(dt)
Updates the camera follow, shake, recoil, and bounds.

### cam:apply_transform()
Adds this camera's view transform (position, rotation, and zoom) to Löve's render transform stack.

### cam:reset_transform()
Resets to the last render transform (`love.graphics.pop()`)

### cam:activate()
Activates/switches to this camera.

### cam:screen_to_world(x, y, delta)
Transforms `x` and `y` from screen coordinates to world coordinates based on this camera's position, rotation, and zoom.

### cam:pan(dx, dy)
Moves this camera's position by `(dx, dy)`. This is just for convenience, you can also move the camera around by setting its `pos` property (`pos.x` and `pos.y`).

### cam:zoom(z)
A convenience function to zoom the camera in or out by a percentage. Just sets the camera's `zoom` property to `zoom * (1 + z)`.

### cam:shake(dist, duration, falloff)
Adds a shake to the camera. The shake will last for `duration` seconds, randomly offsetting the camera's position every frame by a maximum distance of +-`dist`. You can optionally set the shake falloff to "linear" or "quadratic" - it defaults to "linear".

### cam:recoil(vec, duration, falloff)
Adds a recoil to the camera. This is sort of like a shake, only it just offsets the camera by the vector you specify--smoothly falling off to (0, 0) over `duration`. `falloff` can optionally be set to "linear" or "quadratic" (defaults to "quadratic").

### cam:stop_shaking()
Cancels all shakes and recoils on this camera.

### cam:follow(obj, allowMultiFollow, weight)
Tells this camera to smoothly follow `obj`. This requires that `obj` has a property `pos` with `x` and `y` elements. Set the camera's `follow_lerp_speed` property to adjust the smoothing speed. If `allowMultiFollow` is true then `obj` will be added to a list of objects that the camera is following---the camera's lerp target will be the average position of all objects on the list.

### cam:unfollow(obj)
Removes `obj` from the camera's list of followed objects. If no object is given, it will unfollow anything and everything it is currently following.
