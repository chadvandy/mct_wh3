---- MCT Checkbox Wrapped Type.
--- @class mct_checkbox

local mct = get_mct()
local log,logf,err,errf = get_vlog("[mct]")

local template_type = mct._MCT_TYPES.template

local wrapped_type = {}

--- Create a new wrapped type within an mct_option.
---@param option_obj MCT.Option The mct_option this wrapped_type is being passed.
function wrapped_type:new(option_obj)
    local self = {}


    setmetatable(self, wrapped_type)

    self.option = option_obj

    local tt = template_type:new(option_obj)

    self.template_type = tt

    return self
end

function wrapped_type:__index(attempt)
    --log("start check in type:__index")
    --log("calling: "..attempt)
    --log("key: "..self:get_key())
    --log("calling "..attempt.." on mct option "..self:get_key())
    local field = rawget(getmetatable(self), attempt)
    local retval = nil

    if type(field) == "nil" then
        --log("not found, check mct_option")
        -- not found in mct_option, check template_type!
        local wrapped_boi = rawget(self, "option")

        field = wrapped_boi and wrapped_boi[attempt]

        if type(field) == "nil" then
            --log("not found in wrapped_type or mct_option, check in template_type!")
            -- not found in mct_option or wrapped_type, check in template_type
            local wrapped_boi_boi = rawget(self, "template_type")
            
            field = wrapped_boi_boi and wrapped_boi_boi[attempt]
            if type(field) == "function" then
                retval = function(obj, ...)
                    return field(wrapped_boi_boi, ...)
                end
            else
                retval = field
            end
        else
            if type(field) == "function" then
                retval = function(obj, ...)
                    return field(wrapped_boi, ...)
                end
            else
                retval = field
            end
        end
    else
        --log("found in wrapped_type")
        if type(field) == "function" then
            retval = function(obj, ...)
                return field(self, ...)
            end
        else
            retval = field
        end
    end
    
    return retval
end


--------- OVERRIDEN SECTION -------------
-- These functions exist for every type, and have to be overriden from the version defined in template_types.

--- Checks the validity of the value passed.
---@param value any Tested value.
--- @treturn boolean valid Returns true if the value passed is valid, false otherwise.
--- @treturn boolean valid_return If the value passed isn't valid, a second return is sent, for a valid value to replace the tested one with.
function wrapped_type:check_validity(value)
    if not is_boolean(value) then
        return false, false
    end

    return true
end

--- Sets a default value for this mct_option. Defaults to "false" for checkboxes.
function wrapped_type:set_default()

    -- if there's no default, set it to false.
    self:set_default_value(false)
end

--- Selects a value in UI for this mct_option.
function wrapped_type:ui_select_value(val)

    local option_uic = self:get_uic_with_key("option")
    if not is_uicomponent(option_uic) then
        err("ui_select_value() triggered for mct_option with key ["..self:get_key().."], but no option_uic was found internally. Aborting!")
        return false
    end

    -- grab the checkbox UI

    local state = "selected"

    if val == false then
        state = "active"
    end

    option_uic:SetState(state)
end

--- Changes the state for the mct_option in UI, ie. locked/unlocked.
function wrapped_type:ui_change_state(val)
    local option_uic = self:get_uic_with_key("option")
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
        else
            state = "active"
        end
    end

    option_uic:SetState(state)
    text_uic:SetTooltipText(tt, true)
end

--- Creates the mct_option in the UI. Do not call externally.
function wrapped_type:ui_create_option(dummy_parent)
    local template = self:get_uic_template()

    local new_uic = core:get_or_create_component("mct_checkbox_toggle", template, dummy_parent)
    new_uic:SetVisible(true)

    self:set_uic_with_key("option", new_uic, true)

    return new_uic
end

--------- UNIQUE SECTION -----------
-- These functions are unique for this type only. Be careful calling these!



--------- List'n'rs ----------
-- Unique listeners for just this type.
core:add_listener(
    "mct_checkbox_toggle_option_selected",
    "ComponentLClickUp",
    function(context)
        return context.string == "mct_checkbox_toggle"
    end,
    function(context)
        local uic = UIComponent(context.component)

        -- will tell us the name of the option
        local parent_id = UIComponent(uic:Parent()):Id()
        --log("Checkbox Pressed - parent id ["..parent_id.."]")
        local mod_obj = mct:get_selected_mod()
        local option_obj = mod_obj:get_option_by_key(parent_id)

        if not mct:is_mct_option(option_obj) then
            err("mct_checkbox_toggle_option_selected listener trigger, but the checkbox pressed ["..parent_id.."] doesn't have a valid mct_option attached. Returning false.")
            return false
        end

        option_obj:set_selected_setting(not option_obj:get_selected_setting())
    end,
    true
)

return wrapped_type