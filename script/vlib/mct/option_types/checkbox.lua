---- MCT Checkbox Wrapped Type.
--- @class mct_checkbox

local mct = get_mct()
local log,logf,err,errf = get_vlog("[mct]")

local Super = mct._MCT_OPTION

---@type MCT.Option.Checkbox
local defaults = {
    _template = "ui/templates/checkbox_toggle"
}

---@class MCT.Option.Checkbox : MCT.Option
---@field __new fun():MCT.Option.Checkbox
local Checkbox = Super:extend("MCT.Option.Checkbox", defaults)

function Checkbox:new(mod_obj, option_key)
    local o = self:__new()
    Super.init(o, mod_obj, option_key)
    self.init(o)

    return o
end

function Checkbox:init()
    self:set_default_value(false)
end

--- Checks the validity of the value passed.
---@param value any Tested value.
--- @return boolean valid Returns true if the value passed is valid, false otherwise.
--- @return boolean valid_return If the value passed isn't valid, a second return is sent, for a valid value to replace the tested one with.
function Checkbox:check_validity(value)
    if not is_boolean(value) then
        return false, false
    end

    return true
end

--- Sets a default value for this mct_option. Defaults to "false" for checkboxes.
function Checkbox:set_default()

    -- if there's no default, set it to false.
    self:set_default_value(false)
end

---- Internal function that calls the operation to change an option's selected value. Exposed here so it can be called through presets and the like. Use `set_selected_setting` instead, please!
--- Selects a value in UI for this mct_option.
---@param val any Set the selected setting as the passed value, tested with check_validity()
---@param is_new_version true? Set this to true to skip calling mct_option:set_selected_setting from within. This is done to keep the mod backwards compatible with the last patch, where the Order of Operations went ui_select_value -> set_selected_setting; the new Order of Operations is the inverse.
function Checkbox:ui_select_value(val, is_new_version)
    local valid,new = self:check_validity(val)
    if not valid then
        if val ~= nil then
            VLib.Warn("ui_select_value() called for option with key ["..self:get_key().."], but the val supplied ["..tostring(val).."] is not valid for the type. Replacing with ["..tostring(new).."].")
            val = new
        else
            err("ui_select_value() called for option with key ["..self:get_key().."], but the val supplied ["..tostring(val).."] is not valid for the type!")
            return false
        end
    end

    -- grab the checkbox UI
    local option_uic = self:get_uic_with_key("option")
    if not is_uicomponent(option_uic) then
        err("ui_select_value() triggered for mct_option with key ["..self:get_key().."], but no option_uic was found internally. Aborting!")
        return false
    end

    local state = "selected"

    if val == false then
        state = "active"
    end

    option_uic:SetState(state)

    Super.ui_select_value(self, val, is_new_version)
end

--- Changes the state for the mct_option in UI, ie. locked/unlocked.
function Checkbox:ui_change_state(val)
    local option_uic = self:get_uic_with_key("option")
    if not option_uic then return end
    
    local text_uic = self:get_uic_with_key("text")

    local locked = self:get_uic_locked()
    local lock_reason = self:get_lock_reason()
    
    local value = self:get_selected_setting()

    local state = "active"
    local tt = self:get_tooltip_text()

    if locked then
        -- disable the checkbox, set it as checked if the finalized setting is true
        if value == true then
            state = "selected_inactive"
        else
            state = "inactive"
        end
        tt = lock_reason .. "\n" .. tt
    else
        if value == true then
            state = "selected"
        -- else
        --     state = "active"
        end
    end

    option_uic:SetState(state)
    text_uic:SetTooltipText(tt, true)
end

--- Creates the mct_option in the UI. Do not call externally.
function Checkbox:ui_create_option(dummy_parent)
    local template = self:get_uic_template()

    local new_uic = core:get_or_create_component("mct_checkbox_toggle", template, dummy_parent)
    new_uic:SetVisible(true)

    self:set_uic_with_key("option", new_uic, true)

    return new_uic
end

core:add_listener(
    "mct_checkbox_toggle_option_selected",
    "ComponentLClickUp",
    function(context)
        return context.string == "mct_checkbox_toggle"
    end,
    function(context)
        local uic = UIComponent(context.component)
        local mod_obj = mct:get_selected_mod()
        local option_key = uic:GetProperty("mct_option")
        local option_obj = mod_obj:get_option_by_key(option_key)

        if not mct:is_mct_option(option_obj) then
            err("mct_checkbox_toggle_option_selected listener trigger, but the checkbox pressed ["..option_key.."] doesn't have a valid mct_option attached. Returning false.")
            return false
        end

        option_obj:set_selected_setting(not option_obj:get_selected_setting())
    end,
    true
)

return Checkbox