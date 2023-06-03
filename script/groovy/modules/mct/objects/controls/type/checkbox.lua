---@module Controls

local mct = get_mct()
local log,logf,err,errf = get_vlog("[mct_control]")

local Super = mct:get_mct_control_class()

---@ignore
---@class ControlCheckbox
local defaults = {
    _template = "ui/templates/checkbox_toggle",

    ---@type fun(value:boolean)[]
    _validity_callbacks = {},

    fallback_value = false,

    _type = "Checkbox",
}

---@class ControlCheckbox : Control
---@field __new fun():ControlCheckbox
local ControlCheckbox = Super:extend("ControlCheckbox", defaults)

--- Creates a new ControlCheckbox instance
---@return ControlCheckbox
function ControlCheckbox:new(mod_obj, control_key)
    local o = self:__new()
    Super.init(o, mod_obj, control_key)
    self.init(o)

    return o
end

function ControlCheckbox:init()
    self:set_default_value(false)
end

function ControlCheckbox:display(parent)
    local template = self._template

    local new_uic = core:get_or_create_component(self:get_key(), template, parent)
    new_uic:SetVisible(true)

    self:set_uic(new_uic)
    
    new_uic:SetProperty("mct_mod", self:get_mod():get_key())
    new_uic:SetProperty("mct_control", self:get_key())
    new_uic:SetProperty("mct_control_type", "Checkbox")
end

--- Checks the validity of the value passed.
---@param value any Tested value.
--- @return boolean valid Returns true if the value passed is valid, false otherwise.
--- @return boolean? valid_return If the value passed isn't valid, a second return is sent, for a valid value to replace the tested one with.
function ControlCheckbox:check_validity(value)
    if not is_boolean(value) then
        return false, false
    end

    return true
end

function ControlCheckbox:change_state()
    local value = self:current()
    local is_locked = self:is_locked()

    local state = ""

    if is_locked then
        if value == true then
            state = "selected_inactive"
        else
            state = "inactive"
        end
    else
        if value == true then
            state = "selected"
        else
            state = "active"
        end
    end

    self:get_uic():SetState(state)
end

return ControlCheckbox