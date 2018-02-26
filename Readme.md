# Lovercam

A camera library for Löve. (A work in progress)

## Feature List
* Window resize handling - with four scale modes:
	* Expand View
	* Fixed Area
	* Fixed Width
	* Fixed Height
* Initial View Area
* Multiple cameras
* Zoom
* Shake
* Recoil
* Smoothed Following
* Weighted Multi-Following
* Screen-to-World transform
* World-to-Screen transform

## To Do:
* Fixed Aspect Ratio (black bars)
* Camera Bounds
* Follow Deadzone
* Split-Screen Support ((?) use fixed aspect + an offset?)
* Camera Lead
* Zoom to Point
* Rotational Shake
* Multi-Follow Zoom (?)

## Constructor & Basic Usage

### M.new(pos, rot, zoom_or_area, inactive, scale_mode)
Creates a new camera object. The module stores the latest active camera in `M.cur_cam`. The `scale_mode` must be one of the following strings: "expand view", "fixed area", "fixed width", or "fixed height". `zoom_or_area` can either be a zoom value (a number) or a table or vector with the dimensions of the desired view area. If it's not a number, Lovercam will look for "x" and "y" or "w" and "h", or [1] and [2] fields.

Use `apply_transform()` and `reset_transform()` to push and pop a camera's view transform from Löve's rendering transform stack. Call `M.window_resized()` in `love.resize()` so your cameras zoom correctly when the window changes. Make sure to call `M.update()` in `love.update()` (or update cameras one-by-one if you want) if you are doing any shake, recoil, or following.

## Update Functions

### M.window_resized(w, h)
Updates all cameras for the new window size. This may alter the zoom of your cameras, depending on their scale mode. ("expand view" mode cameras keep the same zoom.)

### M.update(dt)
Runs the update functions of all cameras. This will step forward all time-related features: following, shake, & recoil, and enforce camera bounds. For finer control you can use M.update_current() to only update the currently active camera, or directly call the update function of any camera you have a reference to (i.e. my_camera:update(dt)).

### M.update_current(dt)
Runs the update function of the currently active camera only.

## Shortcut to Current Camera
All of the following camera functions, except `update` and `activate`, can be used as module functions, which will call them on the current active camera. This way, you generally don't need to keep track of camera object references and which one is active, except if you want to switch between multiple cameras or only update certain ones, etc.

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

### cam:world_to_screen(x, y, delta)
Transform `x` and `x` from world coordinates to screen coordinates based on this camera's position, rotation, and zoom.

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
Tells this camera to smoothly follow `obj`. This requires that `obj` has a property `pos` with `x` and `y` elements. Set the camera's `follow_lerp_speed` property to adjust the smoothing speed. If `allowMultiFollow` is true then `obj` will be added to a list of objects that the camera is following---the camera's lerp target will be the average position of all objects on the list. The optional `weight` parameter (default=1) allows you to control how much each followed object influences the camera position. You might set it to, say, 1 for your character, and 0.5 for the mouse cursor for a top-down shooter. This only has an effect if the camera is following multiple objects. Call `cam:follow()` again with the same object to update the weight.

### cam:unfollow(obj)
Removes `obj` from the camera's list of followed objects. If no object is given, it will unfollow anything and everything it is currently following.

## Camera Properties
Properties of the camera object that you may want to get or set.

#### pos <kbd>vector2</kbd>
The camera's position. Set `pos.x` and `pos.y` to move the camera around.

#### rot <kbd>number</kbd>
The camera's rotation, in radians.

#### zoom <kbd>number</kbd>
The camera's zoom. Set it higher to zoom in, or lower to zoom out.

#### scale_mode <kbd>string / enum</kbd>
How the camera adapts when the window size is changed.
* __"expand view"__ - How Löve works normally---zoom doesn't change---if the window is made larger a larger area is rendered, and vice versa.
* __"fixed area"__ - Lovercam's default (because it's the best). The camera zooms in or out to show the same _area_ of game world, regardless of window size and proportion.
* __"fixed width"__ - The camera zooms to show the same horizontal amount of world. Vertical view space will be cropped or expanded depending on the window proportion.
* __"fixed height"__ - The camera zooms to show the same vertical amount of space. The sides will be cropped or expanded depending on the window proportion.

#### follow_lerp_speed <kbd>number</kbd>
The camera's interpolation speed, used when following objects.
