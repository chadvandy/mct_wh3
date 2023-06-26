--- TODO get rid of this, and just use mct_option?

--- MCT dummy type. Does nothing on its own; it's just for UI spacing, or text.

local mct = get_mct()
local Super = mct:get_mct_option_class()
local log,logf,err,errf = get_vlog("[mct]")

local defaults = {}

---@class MCT.Option.Dummy : MCT.Option A Dummy type, that takes up a spot in the Settings list view but doesn't actually have any settings associated.
---@field __new fun():MCT.Option.Dummy
local Dummy = Super:extend("MCT.Option.Dummy", defaults)

function Dummy:new(mod_obj, option_key)
    local o = self:__new()
    Super.init(o, mod_obj, option_key)
    self.init(o)

    return o
end

function Dummy:init()

end


--- Check validity of the value.
--- Only `nil` is valid!
---@param val any
---@return boolean
function Dummy:check_validity(val)
    return is_nil(val)
end

--- Set the default value. `nil`.
function Dummy:get_fallback_value()
    return nil
end

--- Does nothing.
function Dummy:ui_select_value(val)
    -- do nothing
end

--- Does nothing.
function Dummy:ui_change_state()
    -- do nothing
end

--- Create the option in UI - just the text!
function Dummy:ui_create_option(dummy_parent)
    --- TODO why do I do this?
    local new_uic = core:get_or_create_component("dummy", "ui/campaign ui/script_dummy", dummy_parent)
    new_uic:Resize(1, 1)
    new_uic:SetVisible(false)

    self:set_uic_with_key("option", new_uic, true)
    return new_uic
end

return Dummy