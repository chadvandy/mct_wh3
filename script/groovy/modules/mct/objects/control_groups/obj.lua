local mct = get_mct()

---@class MCT.ControlGroup : Class
local defaults = {
    ---@type string #The key of this ControlGroup.
    _key = nil,

    ---@type MCT.Mod #The Mod this ControlGroup belongs to.
    _mod = nil,

    _controls = {},
}

---@class MCT.ControlGroup : Class #The ControlGroup class is used to group Controls together.
---@field __new fun(): MCT.ControlGroup
local ControlGroup = GLib.NewClass("MCT.ControlGroup", defaults)

function ControlGroup:new()
    local o = self:__new()
    self.init(o)

    return o
end

function ControlGroup:init()

end

---@param parent UIC
function ControlGroup:display(parent)
    -- create the holder UIC, all labels and controls will be placed inside this.
end

function ControlGroup:set_key(k)
    self._key = k
end

function ControlGroup:get_key()
    return self._key
end

function ControlGroup:set_mod(m)
    self._mod = m
end

function ControlGroup:get_mod()
    return self._mod
end

--- TODO universal functionality, labels and controls and positioning.
--- TODO move some of the existing functionality of MCT.Options into here, like how labels and info holders are currently created, and decouple "options" and "controls".


return ControlGroup