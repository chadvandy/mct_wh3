---- Template file for the "types" objects. Used for any functions shared by all types, and to catch any type-specific functions being called on the wrong type, ie. calling `slider_set_min_max` on a dropdown.
--- @class template_type

local mct = get_mct()
-- local vlib = get_vlib()
local log,logf,err,errf = get_vlog("[mct]")

---@type template_type
local template_type = {}

function template_type:new(option_obj)
    local tt = {}
    setmetatable(tt, template_type)

    tt.option_obj = option_obj
    tt.key = option_obj:get_key()
    tt.type = option_obj:get_type()

    return tt
end

function template_type:__index(key)
    --mct:log("checking template_type:__index")
    local field = rawget(getmetatable(self), key)
    local retval = nil

    if type(field) == "function" then
        retval = function(obj, ...)
            return field(self, ...)
        end
    else
        retval = field
    end
    
    return retval
end

function template_type:get_key()
    return self.key
end

function template_type:get_type()
    return self.type
end

function template_type:get_option()
    return self.option_obj
end

function template_type:override_error(function_name)
    err(function_name .. "() called on mct_option ["..self:get_key().."] with type ["..self:get_type().."], but the function wasn't overriden! Investigate!")
    return false
end

function template_type:check_validity(value)
    return self:override_error("check_validity")
end

function template_type:set_default()
    return self:override_error("set_default")
end

function template_type:ui_select_value(val)
    return self:override_error("ui_select_value")
end

function template_type:ui_change_state()
    return self:override_error("ui_change_state")
end

function template_type:ui_create_option(dummy_parent)
    return self:override_error("ui_create_option")
end

---- Unique Calls ----
-- These only exist for specific types; put defaults here to check if they're called on the wrong type
function template_type:type_error(function_name, type_expected)
    err(function_name .. "() called on mct_option ["..self:get_key().."] with type ["..self:get_type().."], but this function expects the type ["..type_expected.."]. Abortin'.")

    return false
end

---- Slider Only ----
function template_type:slider_get_precise_value()
    return self:type_error("slider_get_precise_value", "slider")
end

function template_type:slider_set_step_size()
    return self:type_error("slider_set_step_size", "slider")
end

function template_type:slider_set_precision()
    return self:type_error("slider_set_precision", "slider")
end

function template_type:slider_set_min_max()
    return self:type_error("slider_set_min_max", "slider")
end

---- Dropdown Only ----
function template_type:add_dropdown_values()
    return self:type_error("add_dropdown_values", "dropdown")
end

function template_type:add_dropdown_value()
    return self:type_error("add_dropdown_value", "dropdown")
end

function template_type:refresh_dropdown_box()
    return self:type_error("refresh_dropdown_box", "dropdown")
end

---- Text Input ----
function template_type:add_validity_test()
    return self:type_error("add_validity_test", "text_input")
end

return template_type