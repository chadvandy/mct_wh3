--- TODO port to the new slider system!


--- MCT Slider type
local mct = get_mct()
local log,logf,err,errf = get_vlog("[mct]")
local Super = mct._MCT_OPTION

---@type MCT.Option.Slider
local defaults = {
    _template = {"ui/templates/cycle_button_arrow_previous", "ui/common ui/text_box", "ui/templates/cycle_button_arrow_next"},

    _values = {
        min = 0,
        max = 100,
        step_size = 1,
        step_size_precision = 0,
        precision = 0,
    }
}

---@class MCT.Option.Slider : MCT.Option A Slider Object.
local Slider = Super:extend("MCT.Option.Slider", defaults)

function Slider:new(mod_obj, option_key)
    local o = self:__new()
    Super.init(o, mod_obj, option_key)
    self.init(o)

    return o
end

function Slider:init()

end

--- Checks the validity of the value passed.
---@param value any Tested value.
--- @return boolean valid Returns true if the value passed is valid, false otherwise.
--- @return boolean valid_return If the value passed isn't valid, a second return is sent, for a valid value to replace the tested one with.
function Slider:check_validity(value)
    if not is_number(value) then
        return false
    end

    local values = self:get_values()

    local min = values.min
    local max = values.max
    local precision = values.precision

    if value > max then
        return false, max
    elseif value < min then
        return false, min
    end

    local test = self:slider_get_precise_value(value, false)
    
    if test ~= value then
        -- not precise!
        return false, test
    end

    return true, value
end

--- Sets the default value for this mct_option.
--- Returns the exact median value for this slider, with precision in mind.
function Slider:set_default()
    local values = self:get_values()

    local min = values.min
    local max = values.max

    -- get the "average" of the two numbers, (min+max)/2
    -- TODO set this with respect for the step sizes, precision, etc
    local mid = (min+max)/2
    mid = self:slider_get_precise_value(mid, false)
    self:set_default_value(mid)
end

---- Internal function that calls the operation to change an option's selected value. Exposed here so it can be called through presets and the like. Use `set_selected_setting` instead, please!
--- Selects a value in UI for this mct_option.
---@param val any Set the selected setting as the passed value, tested with check_validity()
---@param is_new_version true? Set this to true to skip calling mct_option:set_selected_setting from within. This is done to keep the mod backwards compatible with the last patch, where the Order of Operations went ui_select_value -> set_selected_setting; the new Order of Operations is the inverse.
function Slider:ui_select_value(val, is_new_version)
    local text_input = self:get_uic_with_key("option")
    if not is_uicomponent(text_input) then
        err("ui_select_value() triggered for mct_option with key ["..self:get_key().."], but no option_uic was found internally. Aborting!")
        return false
    end

    local right_button = self:get_uic_with_key("right_button")
    local left_button = self:get_uic_with_key("left_button")

    local values = self:get_values()
    local max = values.max
    local min = values.min
    local step_size = values.step_size
    local step_size_precision = values.step_size_precision

    -- enable both buttons & push new value
    _SetState(right_button, "active")
    _SetState(left_button, "active")


    if val >= max then
        _SetState(right_button, "inactive")
        _SetState(left_button, "active")

        val = max
    elseif val <= min then
        _SetState(left_button, "inactive")
        _SetState(right_button, "active")

        val = min
    end

    -- TODO move step size edits out of this one?
    local step_size_str = self:slider_get_precise_value(step_size, true, step_size_precision)

    _SetTooltipText(left_button, "-"..step_size_str, true)
    _SetTooltipText(right_button, "+"..step_size_str, true)

    --local current = self:get_precise_value(self:get_selected_setting(), false)
    local current_str = self:slider_get_precise_value(self:get_selected_setting(), true)

    text_input:SetStateText(tostring(current_str))
    -- text_input:SetInteractive(false)

    Super.ui_select_value(self, val, is_new_version)
end

--- Change the UI state; ie., lock if it's set to lock.
--- Called from @{mct_option:set_uic_locked}.
function Slider:ui_change_state()
    local option_uic = self:get_uic_with_key("option")
    local text_uic = self:get_uic_with_key("text")

    local locked = self:get_uic_locked()
    local lock_reason = self:get_lock_reason()

    local left_button = self:get_uic_with_key("left_button")
    local right_button = self:get_uic_with_key("right_button")

    local state = "active"
    local tt = self:get_tooltip_text()
    if locked then
        state = "inactive"
        tt = lock_reason .. "\n" .. tt
    end

    --_SetInteractive(text_input, not locked)
    _SetState(left_button, state)
    _SetState(right_button, state)
    _SetTooltipText(text_uic, tt, true)
end

-- UIC Properties:
-- Value
-- minValue
-- maxValue
-- Notify (unused?)
-- update_frequency (doesn't change anything?)

--- Create the slider in UI.
function Slider:ui_create_option(dummy_parent)
    local templates = self:get_uic_template()
    --local values = option_obj:get_values()

    local left_button_template = templates[1]
    local right_button_template = templates[3]
    
    local text_input_template = templates[2]

    local text_input = core:get_or_create_component("mct_slider_text_input", text_input_template, dummy_parent)
    local left_button = core:get_or_create_component("left_button", left_button_template, text_input)
    local right_button = core:get_or_create_component("right_button", right_button_template, text_input)

    local error_popup = core:get_or_create_component("error_popup", "ui/common ui/tooltip_text_only", dummy_parent)
    error_popup:SetDockingPoint(1)
    error_popup:SetCanResizeHeight(true)
    error_popup:Resize(error_popup:Width(), error_popup:Height() * 2)
    error_popup:SetCanResizeHeight(false
)
    error_popup:SetDockOffset(-15, -error_popup:Height())
    error_popup:RemoveTopMost()

    local t = find_uicomponent(error_popup, "text")
    t:SetStateText("")
    t:SetTextHAlign("centre")
    t:SetTextVAlign("top")
    t:SetDockingPoint(2)
    t:SetDockOffset(0, 12)
    t:SetTextXOffset(0, 0)
    t:SetTextYOffset(0, 0)
    t:Resize(error_popup:Width(), error_popup:Height() * 0.6)

    core:get_tm():real_callback(function()
        error_popup:SetVisible(false)
    end, 1, nil)

    text_input:SetCanResizeWidth(true)
    text_input:Resize(text_input:Width() * 0.4, text_input:Height())
    text_input:SetCanResizeWidth(false)
    text_input:SetInteractive(true)

    text_input:SetDockingPoint(6)
    left_button:SetDockingPoint(4)
    right_button:SetDockingPoint(6)

    left_button:SetDockOffset(-left_button:Width(),0)
    right_button:SetDockOffset(right_button:Width(),0)

    self:set_uic_with_key("option", text_input, true)
    self:set_uic_with_key("left_button", left_button, true)
    self:set_uic_with_key("right_button", right_button, true)
    self:set_uic_with_key("error_popup", error_popup, true)

    return text_input
end

--------- UNIQUE SECTION -----------
-- These functions are unique for this type only. Be careful calling these!

--- Get a precise value for this slider, minding the precision set.
---@param value number The number to change the precision for.
---@param as_string boolean Set to true if you want a string returned instead of a number.
---@param override_precision number|nil A number to change the precision. If not set, it will use the value set in @{mct_slider:slider_set_precision}.
--- @treturn number|string precise_value The new number with the precision in mind.
function Slider:slider_get_precise_value(value, as_string, override_precision)
    if not is_number(value) then
        err("slider_get_precise_value() called on mct_option ["..self:get_key().."], but the value provided is not a number!")
        return false
    end

    if is_nil(as_string) then
        as_string = false
    end

    if not is_boolean(as_string) then
        err("slider_get_precise_value() called on mct_option ["..self:get_key().."], but the as_string argument provided is not a boolean or nil!")
        return false
    end


    local function round_num(num, numDecimalPlaces)
        local mult = 10^(numDecimalPlaces or 0)
        if num >= 0 then
            return math.floor(num * mult + 0.5) / mult
        else
            return math.ceil(num * mult - 0.5) / mult
        end
    end

    local function round(num, places, is_string)
        if not is_string then
            return round_num(num, places)
        end

        return string.format("%."..(places or 0) .. "f", num)
    end

    local values = self:get_values()
    local precision = values.precision

    if is_number(override_precision) then
        precision = override_precision
    end

    return round(value, precision, as_string)
end

---- Set function to set the step size for moving left/right through the slider.
--- Works with floats and other numbers. Use the optional second argument if using floats/decimals
---@param step_size number The number to jump when using the left/right button.
---@param step_size_precision number The precision for the step size, to prevent weird number changing. If the step size is 0.2, for instance, the precision would be 1, for one-decimal-place.
function Slider:slider_set_step_size(step_size, step_size_precision)
    --[[if not self:get_type() == "slider" then
        err("slider_set_step_size() called for option ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the option is not a slider! Returning false.")
        return false
    end]]

    if not is_number(step_size) then
        err("slider_set_step_size() called for option ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the step size value supplied ["..tostring(step_size).."] is not a number! Returning false.")
        return false
    end

    if is_nil(step_size_precision) then
        step_size_precision = 0
    end

    if not is_number(step_size_precision) then
        err("slider_set_step_size() called for option ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the step size precision value supplied ["..tostring(step_size_precision).."] is not a number! Returning false.")
        return false
    end

    self._values.step_size = step_size
    self._values.step_size_precision = step_size_precision
end

---- Setter for the precision on the slider's displayed value. Necessary when working with decimal numbers.
--- The number should be how many decimal places you want, ie. if you are using one decimal place, send 1 to this function; if you are using none, send 0.
---@param precision number The precision used for floats.
function Slider:slider_set_precision(precision)
    --[[if not self:get_type() == "slider" then
        err("slider_set_precision() called for option ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the option is not a slider! Returning false.")
        return false
    end]]

    if not is_number(precision) then
        err("slider_set_precision() called for option ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the min value supplied ["..tostring(precision).."] is not a number! Returning false.")
        return false
    end

    self._values.precision = precision
end

---- Setter for the minimum and maximum values for the slider. If the UI already exists, this method will do a quick check to make sure the current value is between the new min/max, and it will change the lock states of the left/right buttons if necessary.
---@param min number The minimum number the slider value can reach.
---@param max number The maximum number the slider value can reach.
function Slider:slider_set_min_max(min, max)
    --[[if not self:get_type() == "slider" then
        err("slider_set_min_max() called for option ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the option is not a slider! Returning false.")
        return false
    end]]

    if not is_number(min) then
        err("slider_set_min_max() called for option ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the min value supplied ["..tostring(min).."] is not a number! Returning false.")
        return false
    end

    if not is_number(max) then
        err("slider_set_min_max() called for option ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the max value supplied ["..tostring(max).."] is not a number! Returning false.")
        return false
    end

    --[[if not is_number(current) then
        err("slider_set_values() called for option ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the current value supplied ["..tostring(current).."] is not a number! Returning false.")
        return false
    end]]

    self._values.min = min
    self._values.max = max

    -- if the UI exists, change the buttons and set the value if it's above the max/below the min
    local uic = self:get_uic_with_key("option")
    if is_uicomponent(uic) then
        local current_val = self:get_selected_setting()

        if current_val > max then
            self:set_selected_setting(max)
        elseif current_val < min then
            self:set_selected_setting(min)
        else
            self:set_selected_setting(current_val)
        end
    end
end


--- this is the tester function for supplied text into the string.
--- checks if it's a number; if it's valid within precision; if it's valid within min/max
function Slider:test_text(text)
    text = tonumber(text)
    if not is_number(text) then
        return "Not a valid number!"
    end

    local values = self:get_values()
    local min = values.min
    local max = values.max
    local current = self:get_selected_setting()
    local precision = values.precision

    if text > max then
        return "This value is over the maximum of ["..tostring(max).."]."
    elseif text < min then
        return "This value is under the minimum of ["..tostring(min).."]."
    else
        -- check for the precision
        local tester = self:slider_get_precise_value(text, false)
        if text ~= tester then
            return "This value isn't in valid precision! It expects ["..tostring(precision).."] decimal points."
        end
    end

    -- nothing returned a string - return true for valid!
    return true
end

---------- List'n'rs -------------
--

core:add_listener(
    "mct_slider_text_input",
    "ComponentLClickUp",
    function(context)
        return context.string == "mct_slider_text_input"
    end,
    function(context)
        --- text input
        local text_input = UIComponent(context.component)

        local mod_obj = mct:get_selected_mod()
        local option_key = text_input:GetProperty("mct_option")

        ---@type MCT.Option.Slider
        local option_obj = mod_obj:get_option_by_key(option_key)

        if not mct:is_mct_option(option_obj) then
            err("mct_slider_text_input listener trigger, but the text-input pressed ["..option_key.."] doesn't have a valid mct_option attached. Returning false.")
            return false
        end

        --- set the left/right buttons inactive until clicked out
        local left_button = option_obj:get_uic_with_key("left_button")
        local right_button = option_obj:get_uic_with_key("right_button")

        left_button:SetState("inactive")
        right_button:SetState("inactive")

        --- while clicked in this text input, check its contents - if it's ever wrong, flash an error!
        core:get_tm():repeat_real_callback(function()
            --- if no text input (changed tab etc.) remove this callback
            if not is_uicomponent(text_input) then
                core:get_tm():remove_real_callback("mct_slider_text_input_" .. option_key)
                return
            end

            local t = text_input:GetStateText()

            local valid = option_obj:test_text(t)

            local popup = option_obj:get_uic_with_key("error_popup")
            if valid ~= true then
                --- print out an error on the screen!
                popup:SetVisible(true)
                find_uicomponent(popup, "text"):SetStateText("[[col:red]]" .. valid .. "[[/col]]")
                popup:RegisterTopMost()
            else
                
                popup:RemoveTopMost()
                popup:SetVisible(false)
            end
        end, 50, "mct_slider_text_input_" .. option_key)

        --- TODO does this trigger on "enter"? <- NO.
        core:add_listener(
            "mct_slider_text_input_released",
            "ComponentLClickUp",
            function(context)
                return UIComponent(context.component) ~= text_input
            end,
            function(context)
                core:get_tm():remove_real_callback("mct_slider_text_input_" .. option_key)

                local t = text_input:GetStateText()
                local valid = option_obj:test_text(t)
                if valid == true then
                    t = tonumber(t)
                    if t ~= option_obj:get_selected_setting() then
                        option_obj:set_selected_setting(t)
                    else
                        --- TODO this is so the left/right buttons are reactivated, but I don't really like that.
                        option_obj:ui_select_value(option_obj:get_selected_setting(), true)
                    end
                else
                    --- TODO if the current text is invalid, revert it to the value it was before it all
                    --- decide whether to leave the error up or just remove it entirely.
                    option_obj:set_selected_setting(option_obj:get_finalized_setting())

                    local uic = option_obj:get_uic_with_key("error_popup")
                    uic:SetVisible(false)
                end
                

            end,
            false
        )
    end,
    true
)

core:add_listener(
    "mct_slider_left_or_right_pressed",
    "ComponentLClickUp",
    function(context)
        local uic = UIComponent(context.component)
        return (uic:Id() == "left_button" or uic:Id() == "right_button") and uicomponent_descended_from(uic, "mct_slider_text_input")
    end,
    function(context)
        local ok, msg = pcall(function()
            logf("Left or Right slider button pressed!")
        local step = context.string
        local uic = UIComponent(context.component)

        local slider = UIComponent(uic:Parent())
        local option_key = slider:GetProperty("mct_option")

        logf("Slider option key %s", option_key)
        local mod_obj = mct:get_selected_mod()

        log("getting mod "..mod_obj:get_key())
        log("finding option with key "..option_key)

        local option_obj = mod_obj:get_option_by_key(option_key)

        local values = option_obj:get_values()
        local step_size = values.step_size

        if step == "right_button" then
            log("changing val from "..option_obj:get_selected_setting().. " to "..option_obj:get_selected_setting() + step_size)
            option_obj:set_selected_setting(option_obj:get_selected_setting() + step_size)
        elseif step == "left_button" then
            option_obj:set_selected_setting(option_obj:get_selected_setting() - step_size)
        end
    end) if not ok then err(msg) end
    end,
    true
)

return Slider