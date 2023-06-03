---@module Options

-- TODO an Action Control.
-- a button that does something when clicked.
-- a couple of versions - a text button, and an image button.
-- maybe also have a few buttons in a row, but that's getting into ControlGroup territory

local mct = get_mct()
local log,logf,err,errf = get_vlog("[mct_option_action]")
local Super = mct:get_mct_option_class()

---@ignore
---@class Action : mct_option
local defaults = {
    _template = "ui/templates/square_medium_text_button",

    ---@type function
    _callback = function() end,

    _button_text = "",
}

---@class Action : mct_option
---@field __new fun():Action
local Action = Super:extend("MCT.Option.Action", defaults)

function Action:new(mod_obj, key)
    local o = self:__new()
    self.init(o, mod_obj, key)

    return o
end

function Action:init(mod_obj, key)
    Super.init(self, mod_obj, key)
end

function Action:check_validity(val) return is_nil(val) end

--- Set the default value. `nil`.
function Action:get_fallback_value()
    return nil
end

--- Does nothing.
function Action:ui_select_value(val)
    -- do nothing
end

--- Does nothing.
function Action:ui_change_state()
    -- do nothing
end

---@internal
function Action:ui_create_option(dummy_parent)
    local new_uic = core:get_or_create_component("mct_action_button", self:get_uic_template(), dummy_parent)
    new_uic:SetState("active")
    
    local text = self:get_button_text()
    if text == "" then
        text = "Do Stuff"
    end

    local button_txt = find_uicomponent(new_uic, "button_txt")
    button_txt:SetStateText(text)

    self:set_uic_with_key("option", new_uic, true)
    return new_uic
end

function Action:set_callback(f)
    if not is_function(f) then
        errf("set_callback() called with non-function argument: %s", tostring(f))
        return
    end

    self._callback = f
end

function Action:set_button_text(t)
    if not is_string(t) then
        errf("set_button_text() called with non-string argument: %s", tostring(t))
        return
    end
    
    self._button_text = t
    -- local uic = self:get_uic_with_key("option")
    -- uic:SetStateText(t)
end

function Action:get_button_text()
    return self._button_text
end

function Action:callback()
    if self._callback then
        self._callback()
    end
end

core:add_listener(
    "mct_option_action_callback",
    "ComponentLClickUp",
    function(context)
        return context.string == "mct_action_button"
    end,
    function(context)
        local uic = UIComponent(context.component)

        local mod_key = uic:GetProperty("mct_mod")
        local mod_obj = mct:get_mod_by_key(mod_key)

        local option_key = uic:GetProperty("mct_option")
        local option_obj = mod_obj:get_option_by_key(option_key)

        ---@cast option_obj Action
        option_obj:callback()
    end,
    true
)

return Action
