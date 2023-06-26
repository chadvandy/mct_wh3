--- Default control group for a single control.

local MCT = get_mct()

local Super = MCT:get_control_group_class()

---@class MCT.ControlGroup.Single : MCT.ControlGroup
local defaults = {}

---@class MCT.ControlGroup.Single : MCT.ControlGroup
local Single = Super:extend("MCT.ControlGroup.Single", defaults)

function Single:new()

end

function Single:init()

    Super.init(self)
end

return Single