--- TODO get rid of this

--- MCT dummy type. Does nothing on its own; it's just for UI spacing, or text.
--- @class mct_dummy

local mct = get_mct()
-- local vlib = get_vlib()
local log,logf,err,errf = get_vlog("[mct]")

local template_type = mct._MCT_TYPES.template

local wrapped_type = {}

function wrapped_type:new(option_obj)
    local self = {}

    --[[for k,v in pairs(getmetatable(tt)) do
        mct:log("assigning ["..k.."] to checkbox_type from template_type.")
        self[k] = v
    end
]]
    setmetatable(self, wrapped_type)

    --[[for k,v in pairs(type) do
        mct:log("assigning ["..k.."] to checkbox_type from self!")
        self[k] = v
    end]]

    self.option = option_obj

    local tt = template_type:new(option_obj)

    self.template_type = tt

    return self
end

function wrapped_type:__index(attempt)
    --mct:log("start check in type:__index")
    --mct:log("calling: "..attempt)
    --mct:log("key: "..self:get_key())
    --mct:log("calling "..attempt.." on mct option "..self:get_key())
    local field = rawget(getmetatable(self), attempt)
    local retval = nil

    if type(field) == "nil" then
        --mct:log("not found, check mct_option")
        -- not found in mct_option, check template_type!
        local wrapped_boi = rawget(self, "option")

        field = wrapped_boi and wrapped_boi[attempt]

        if type(field) == "nil" then
            --mct:log("not found in wrapped_type or mct_option, check in template_type!")
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
        --mct:log("found in wrapped_type")
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

--- Check validity of the value.
--- Only `nil` is valid!
function wrapped_type:check_validity(val)
    return is_nil(val)
end

--- Set the default value. `nil`.
function wrapped_type:set_default()
    self:set_default_value(nil)
end

--- Does nothing.
function wrapped_type:ui_select_value(val)
    -- do nothing
end

--- Does nothing.
function wrapped_type:ui_change_state()
    -- do nothing
end

--- Create the option in UI - just the text!
function wrapped_type:ui_create_option(dummy_parent)
    local new_uic = core:get_or_create_component("dummy", "ui/mct/script_dummy", dummy_parent)
    new_uic:Resize(1, 1)

    self:set_uic_with_key("option", new_uic, true)
    return new_uic
end


return wrapped_type