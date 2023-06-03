---@module ControlGroups


--- Default control group for a single control.

local MCT = get_mct()

local Super = MCT:get_control_group_class()

---@ignore
---@class ControlGroup.Single : ControlGroup
local defaults = {}

---@class ControlGroup.Single : ControlGroup
local Single = Super:extend("ControlGroup.Single", defaults)

function Single:new()

end

function Single:init()

    Super.init(self)
end

return Single