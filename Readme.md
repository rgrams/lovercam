# Lovercam

A camera library for Löve. (A work in progress)

## Feature List
* Window resize handling - with four scale modes:
	* Expand View
	* Fixed Area
	* Fixed Width
	* Fixed Height
* Initial View Area
* Fixed Aspect Ratio (black bars)
* Multiple cameras
* Zoom
* Shake
* Recoil
* Smoothed Following
* Weighted Multi-Following
* Follow Deadzones
* Screen-to-World transform
* World-to-Screen transform
* Camera Bounds

## To Do:
* Split-Screen Support - or any custom scissor
* Camera Lead
* Zoom to Point
* Rotational Shake
* Multi-Follow Zoom (?)

## Constructor

### M.new([x], [y], [angle], [zoom_or_area], [scale_mode], [fixed_aspect_ratio], [inactive])
Creates a new camera object. If not `inactive`, the current camera (at M.cur_cam) will be set to this one.

_PARAMETERS_
* __x, y__ <kbd>number</kbd> - _optional_ - Initial x and y position of the camera. Defaults to 0, 0.
* __angle__ <kbd>number</kbd> - _optional_ - Initial rotation of the camera. Defaults to 0.
* __zoom_or_area__ <kbd>number | table | vector2</kbd> - _optional_ - Either the initial zoom or the initial view area of the camera. Pass in a number, and it will be used as a zoom value. Pass in a table or vector type (anything with `x, y`, `w, h`, or `[1], [2]` fields), and it will be used as a view area width and height, and the camera's zoom will be calculated based on this. The actual area rendered may not match this exactly, it depends on your window proportion and any fixed aspect ratio you have set. The necessary adjustments will be made based on the camera's scale mode. ("expand view" cameras will still zoom, based on a "fixed area" calculation). Defaults to 1.
* __scale_mode__ <kbd>string</kbd> - _optional_ - The camera's scale mode, which determines how it handles window resizing. Must be one of the following: (Defaults to "fixed area")
	* __"expand view"__ - How Löve works normally---zoom doesn't change---if the window is made larger a larger area is rendered, and vice versa.
	* __"fixed area"__ - Lovercam's default (because it's the best). The camera zooms in or out to show the same _area_ of game world, regardless of window size and proportion.
	* __"fixed width"__ - The camera zooms to show the same horizontal amount of world. The top and bottom will be cropped or expanded depending on the window proportion.
	* __"fixed height"__ - The camera zooms to show the same vertical amount of space. The sides will be cropped or expanded depending on the window proportion.
* __fixed_aspect_ratio__ <kbd>number</kbd> _optional_ - The aspect ratio that the viewport will be fixed to (if specified). If you pass in a value here, the camera will crop the area that it draws to as necessary maintain this aspect ratio. It will either crop the top and bottom, or left and right, depending on the aspect ratio and your window proportion. The cropping is applied and removed along with the camera's transform (with `apply_transform` and `reset_transform`). Defaults to `nil` (no aspect ratio enforced).
* __inactive__ <kbd>bool</kbd> _optional_ - If the camera should be inactive when initialized. This just means the camera won't be set as the active camera. Defaults to `false` (i.e. active).

_RETURNS_
* __t__ <kbd>table</kbd> - The camera object table.

## Basic Usage

Use `apply_transform()` and `reset_transform()` to push and pop a camera's view transform from Löve's rendering transform stack. Call `M.window_resized()` in `love.resize()` so your cameras zoom correctly when the window changes. Make sure to call `M.update()` in `love.update()` (or update cameras one-by-one if you want) if you are doing any shake, recoil, or following.

## Update Functions

### M.window_resized(w, h)
Updates all cameras for the new window size. This may alter the zoom of your cameras, depending on their scale mode. ("expand view" mode cameras keep the same zoom.)

_PARAMETERS_
* __w__ <kbd>number</kbd> - The new width of the window.
* __h__ <kbd>number</kbd> - The new height of the window.

### M.update(dt)
Runs the update functions of all cameras. This will step forward all time-related features: following, shake, & recoil, and enforce camera bounds. For finer control you can use M.update_current() to only update the currently active camera, or directly call the update function of any camera you have a reference to (i.e. my_camera:update(dt)).

_PARAMETERS_
* __dt__ <kbd>number</kbd> - Delta time for this frame

### M.update_current(dt)
Runs the update function of the currently active camera only.

_PARAMETERS_
* __dt__ <kbd>number</kbd> - Delta time for this frame


## Shortcut to Current Camera
All of the following camera functions, except `update` and `activate`, can be used as module functions, which will call them on the current active camera. This way, you generally don't need to keep track of camera object references and which one is active, except if you want to switch between multiple cameras or only update certain ones, etc. For example:

```lua
local Camera = require "lib.lovercam"

function love.draw()
	Camera.apply_transform() -- apply the transform of the current camera
	-- set an object's world position based on a stored mouse screen pos
	my_obj.pos.x, my_obj.pos.y = Camera.screen_to_world(mouse_sx, mouse_sy)
	my_obj:draw()
	Camera.reset_transform() -- reset the transform of the current camera
	-- draw GUI stuff
end
```

## Camera Functions

### cam:update(dt)
Updates the camera follow, shake, recoil, and bounds.

_PARAMETERS_
* __dt__ <kbd>number</kbd> - Delta time for this frame

### cam:apply_transform()
Adds this camera's view transform (position, rotation, and zoom) to Löve's render transform stack.

### cam:reset_transform()
Resets to the last render transform (`love.graphics.pop()`)

### cam:activate()
Activates/switches to this camera.

### cam:screen_to_world(x, y, [delta])
Transforms `x` and `y` from screen coordinates to world coordinates based on this camera's position, rotation, and zoom.

_PARAMETERS_
* __x__ <kbd>number</kbd> - The screen x coordinate to transform.
* __y__ <kbd>number</kbd> - The screen y coordinate to transform.
* __delta__ <kbd>bool</kbd> - _optional_ If the coordinates are for a _change_ in position (or size), rather than an absolute position. Defaults to `false`.

_RETURNS_
* __x__ <kbd>number</kbd> - The corresponding world x coordinate.
* __y__ <kbd>number</kbd> - The corresponding world y coordinate.

### cam:world_to_screen(x, y, [delta])
Transform `x` and `x` from world coordinates to screen coordinates based on this camera's position, rotation, and zoom.

_PARAMETERS_
* __x__ <kbd>number</kbd> - The world x coordinate to transform.
* __y__ <kbd>number</kbd> - The world y coordinate to transform.
* __delta__ <kbd>bool</kbd> - _optional_ If the coordinates are for a _change_ in position (or size), rather than an absolute position. Defaults to `false`.

_RETURNS_
* __x__ <kbd>number</kbd> - The corresponding screen x coordinate.
* __y__ <kbd>number</kbd> - The corresponding screen y coordinate.

### cam:pan(dx, dy)
Moves this camera's position by `(dx, dy)`. This is just for convenience, you can also move the camera around by setting its `pos` property (`pos.x` and `pos.y`).

_PARAMETERS_
* __x__ <kbd>number</kbd> - The change in x to apply to the camera's position.
* __y__ <kbd>number</kbd> - The change in y to apply to the camera's position.

### cam:zoom(z)
A convenience function to zoom the camera in or out by a percentage. Just sets the camera's `zoom` property to `zoom * (1 + z)`.

_PARAMETERS_
* __z__ <kbd>number</kbd> - The percent of the current zoom value to add or subtract.

### cam:shake(dist, duration, [falloff])
Adds a shake to the camera. The shake will last for `duration` seconds, randomly offsetting the camera's position every frame by a maximum distance of +/-`dist`. The shake effect will falloff to zero over its duration. By default it uses linear falloff. For each shake you can optionally specify the fallof function, as "linear" or "quadratic", or you can change the default by setting `M.default_shake_falloff`.

_PARAMETERS_
* __dist__ <kbd>number</kbd> - The "intensity" of the shake. The length of the maximum offset it may apply.
* __duration__ <kbd>number</kbd> - How long the shake will last, in seconds.
* __falloff__ <kbd>string</kbd> - _optional_ - The falloff type for the shake to use. Can be either "linear" or "quadratic". Defaults to "linear" (or `M.default_shake_falloff`).

### cam:recoil(vec, duration, [falloff])
Adds a recoil to the camera. This is sort of like a shake, only it just offsets the camera by the vector you specify--smoothly falling off to (0, 0) over `duration`. The falloff function for each recoil can optionally be set to "linear" or "quadratic" (defaults to "quadratic"), or you can change the default by setting `M.default_recoil_falloff`.

_PARAMETERS_
* __vec__ <kbd>table | vector</kbd> - The vector of the recoil. The initial offset it applies to the camera. Must have `x` and `y` fields.
* __duration__ <kbd>number</kbd> - How long the recoil will last, in seconds.
* __falloff__ <kbd>string</kbd> - _optional_ - The falloff type for the shake to use. Can be either "linear" or "quadratic". Defaults to "quadratic" (or `M.default_recoil_falloff`).

### cam:stop_shaking()
Cancels all shakes and recoils on this camera.

### cam:follow(obj, [allowMultiFollow], [weight], [deadzone])
Tells this camera to smoothly follow `obj`. This requires that `obj` has a property `pos` with `x` and `y` elements. Set the camera's `follow_lerp_speed` property to adjust the smoothing speed. If `allowMultiFollow` is true then `obj` will be added to a list of objects that the camera is following---the camera's lerp target will be the average position of all objects on the list. The optional `weight` parameter allows you to control how much each followed object influences the camera position. You might set it to, say, 1 for your character, and 0.5 for the mouse cursor for a top-down shooter. This only has an effect if the camera is following multiple objects. Call `cam:follow()` again with the same object to update the weight.

To set a deadzone on the camera follow (the camera won't move unless the object moves out of the deadzone), supply a table with `x`, `y`, `w`, and `h` fields. These fields should contain 0-to-1 screen percentage values that describe the deadzone rectangle. If you are using a fixed aspect ratio camera, the deadzone will be based on the viewport area, not the full window. Deadzones work _per-object_. If your camera is following a single object and you want to change which object that is without changing the deadzone, you can just put `true` for the `deadzone`, and the deadzone settings for the previous object will be copied and used for the new object. For this to work, `allowMultiFollow` must be `false` and the camera can't be following multiple objects.

_PARAMETERS_
* __obj__ <kbd>table</kbd> - The object to follow. This must be a table with a property `pos` that has `x` and `y` elements.
* __allowMultiFollow__ <kbd>bool</kbd> - _optional_ - Whether to add `obj` to the list of objects to follow, or to replace the list with only `obj`. Defaults to `false`.
* __weight__ <kbd>number</kbd> - _optional_ - The averaging weight for this object. This only matters if the camera is following multiple objects. Higher numbers will make the camera follow this object more closely than the other objects, and vice versa. The actual number doesn't matter, only its value relative to the weights of the other objects this camera is following. Defaults to 1.
* __deadzone__ <kbd>table | bool</kbd> - _optional_ - The deadzone rectangle, a table with `x`, `y`, `w`, and `h` fields. (x and y of the top left corner, and width and height.) These should be 0-to-1 screen percentages. If the window changes, the deadzone rectangle will adapt to the new window/viewport size according to these percentages. You can also put `true` for the `deadzone` to copy an existing deadzone to a new object (see the description above).

### cam:unfollow([obj])
Removes `obj` from the camera's list of followed objects. If no object is given, the camera will unfollow anything and everything it is currently following.

_PARAMETERS_
* __obj__ <kbd>table</kbd> - _optional_ - The object to stop following. Leave out this argument to unfollow everything.

### cam:set_bounds([lt, rt, top, bot])
Sets limits on how far the edge of the camera view can travel, in world coordinates. Call this with no arguments to remove the bounds. If the bounds are smaller than the camera view in either direction then the camera's position will be locked to the center of the bounds area in that axis.

_PARAMETERS_
* __lt__ <kbd>number</kbd> - The x position of the left edge of the bounds.
* __rt__ <kbd>number</kbd> - The x position of the right edge of the bounds.
* __top__ <kbd>number</kbd> - The y position of the top edge of the bounds.
* __bot__ <kbd>number</kbd> - The y position of the bottom edge of the bounds.

## Camera Properties
Properties of the camera object that you may want to get or set.

### pos <kbd>vector2</kbd>
The camera's position. Set `pos.x` and `pos.y` to move the camera around.

### angle <kbd>number</kbd>
The camera's rotation, in radians.

### zoom <kbd>number</kbd>
The camera's zoom. Set it higher to zoom in, or lower to zoom out.

### scale_mode <kbd>string</kbd>
How the camera adapts when the window size is changed. See the documentation for the constructor function (near the top of the page) for a list of available options.

### follow_lerp_speed <kbd>number</kbd>
The camera's interpolation speed, used when following objects.
