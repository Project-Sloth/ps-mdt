TODO: this whole thing might better be served integrated into ps_lib (ALWAYS KEEP CREDITS!)

# Object Gizmo Module

This module exports a `useGizmo` function that enables manipulation of entity position and rotation.

## Export

`exports.object_gizmo:useGizmo(handle)`

## Usage

Ensure the `object_gizmo` module script is running on your server.

The `useGizmo` export can be used in any Lua script on the client side as follows:

```lua
local handle = --[[Your target entity]]
local result = exports.object_gizmo:useGizmo(handle)
```

`result` will contain the entity handle, final position, and final rotation.

## Test Command

This module includes a test command `testGizmo` that demonstrates how to use the gizmo. 

The command creates an object at the player's location and then activates the gizmo for that object.

```lua
local model = `prop_mp_cone_02`
RegisterCommand('testGizmo', function()
    local offset = GetEntityCoords(cache.ped) + GetEntityForwardVector(cache.ped) * 3
    lib.requestModel(model)
    local obj = CreateObject(model, offset.x, offset.y, offset.z, false, false, false)
    local data = exports.object_gizmo:useGizmo(obj)

    lib.print.info(data)
end)
```

## Controls

While using the gizmo, the following controls apply:
- [W]: Switch to Translate Mode
- [R]: Switch to Rotate Mode
- [S]: Switch to Scale Mode (if enabled)
- [Q]: Switch between Relative and World
- [LAlt]: Snap To Ground
- [Enter]: Finish Editing

The current mode (Translate/Rotate) will be displayed on the screen.

## Note

The gizmo only works on entities that you have sufficient permissions to manipulate. Make sure you have the correct permissions to move or rotate the entity you are working with.

## Credits

- DemiAutomatic: https://github.com/DemiAutomatic
