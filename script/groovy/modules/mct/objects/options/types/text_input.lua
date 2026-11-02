local mct = get_mct()
local log,logf,err,errf = get_vlog("[mct]")
local Super = mct:get_mct_option_class()

---@class MCT.Option.TextInput
local defaults = {
    _template = "ui/common ui/text_box",
}

---@class MCT.Option.TextInput : MCT.Option
---@field __new fun():MCT.Option.TextInput
local TextInput = Super:extend("MCT.Option.TextInput", defaults)

function TextInput:new(mod_obj, option_key)
    local o = self:__new()
    Super.init(o, mod_obj, option_key)
    self.init(o)

    return o
end

function TextInput:init()

end

--------- OVERRIDEN SECTION -------------
-- These functions exist for every type, and have to be overriden from the version defined in template_types.

-- TODO this

--- Checks the validity of the value passed.
function TextInput:check_validity(value)
    if not is_string(value) then
        return false, ""
    end

    return true
end

--- Set a default value for this type, if none is set by the modder.
--- Defaults to `""`
function TextInput:get_fallback_value()
    -- TODO do this better mebs?
    return ""
end

--- Selects a passed value in UI.
function TextInput:ui_select_value(val)
    local option_uic = self:get_uic_with_key("option")
    if not is_uicomponent(option_uic) then
        err("ui_select_value() triggered for mct_option with key ["..self:get_key().."], but no option_uic was found internally. Aborting!")
        return false
    end
    
    -- auto-type the text
    option_uic:SetStateText(val)

    Super.ui_select_value(self, val)
end

--- Changes the state of the option in UI.
--- Locks the edit button, changes the tooltip, etc.
function TextInput:ui_change_state()
    local option_uic = self:get_uic_with_key("option")
    local text_uic = self:get_uic_with_key("text")
    -- local edit_button = self:get_uic_with_key("edit_button")

    local locked = self:is_locked()
    local lock_reason = self:get_lock_reason()

    local tt = self:get_tooltip_text()

    local state = "active"

    if locked then
        state = "inactive"
        -- tt = lock_reason .. "\n" .. tt
    end

    option_uic:SetInteractive(not locked)
    -- _SetState(edit_button, state)
    -- text_uic:SetTooltipText(tt, true)
end

--- Creates the option in UI.
function TextInput:ui_create_option(dummy_parent)
    local text_input_template = "ui/common ui/text_box"

    local text_input = core:get_or_create_component("mct_text_input", text_input_template, dummy_parent)
    text_input:SetVisible(true)
    text_input:SetCanResizeWidth(true) text_input:SetCanResizeHeight(true)
    text_input:Resize(dummy_parent:Width() * 0.4, text_input:Height())
    text_input:SetDockingPoint(6)
    text_input:SetDockOffset(-5, 0)

    text_input:SetInteractive(true)

    self:set_uic_with_key("option", text_input, true)

    return text_input
end

--------- UNIQUE SECTION -----------
-- These functions are unique for this type only. Be careful calling these!

--- Test typed text against the validity tests added with `add_validity_test`.
---@param text any The typed text.
---@return true|string #True if valid, or the error message to show.
function TextInput:test_text(text)
    if not is_string(text) then
        return "Not a valid string"
    end

    return self:run_validity_tests(text)
end

---------- List'n'rs -------------
--

core:add_listener(
    "mct_text_input",
    "ComponentLClickUp",
    function(context)
        return context.string == "mct_text_input"
    end,
    function(context)
        local text_input = UIComponent(context.component)
        local mod_obj = mct:get_selected_mod()
        local option_key = text_input:GetProperty("mct_option")

        ---@type MCT.Option.TextInput
        local option_obj = mod_obj:get_option_by_key(option_key)

        if not mct:is_mct_option(option_obj) then
            err("mct_text_input listener trigger, but the text-input pressed ["..option_key.."] doesn't have a valid mct_option attached. Returning false.")
            return false
        end

        option_obj:ui_watch_text_input(
            text_input,
            function(text) return option_obj:test_text(text) end,
            function(text)
                if text ~= option_obj:get_selected_setting() then
                    option_obj:set_selected_setting(text)
                end
            end
        )
    end,
    true
)

return TextInput