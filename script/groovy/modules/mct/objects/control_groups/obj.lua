local mct = get_mct()

---@class MCT.ControlGroup : Class
local defaults = {
    _key = nil,
}

---@class MCT.ControlGroup : Class #The ControlGroup class is used to group Controls together.
local ControlGroup = GLib.NewClass("MCT.ControlGroup", defaults)

function ControlGroup:new()

end

function ControlGroup:init()

end

function ControlGroup:display()

end

function ControlGroup:set_key(k)
    self._key = k
end

--- TODO universal functionality, labels and controls and positioning.
--- TODO move some of the existing functionality of MCT.Options into here, like how labels and info holders are currently created, and decouple "options" and "controls".


return ControlGroup