--- TODO port to the new slider system!


--- MCT Slider type
--- @class mct_slider


local mct = get_mct()
-- local vlib = get_vlib()
local log,logf,err,errf = get_vlog("[mct]")

local template_type = mct._MCT_TYPES.template

local wrapped_type = {}

--- Create a new wrapped type within an mct_option.
---@param option_obj MCT.Option The mct_option this wrapped_type is being passed.
function wrapped_type:new(option_obj)
    local self = {}

    --[[for k,v in pairs(getmetatable(tt)) do
        log("assigning ["..k.."] to checkbox_type from template_type.")
        self[k] = v
    end
]]
    setmetatable(self, wrapped_type)

    --[[for k,v in pairs(type) do
        log("assigning ["..k.."] to checkbox_type from self!")
        self[k] = v
    end]]

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
function wrapped_type:set_default()
    local values = self:get_values()

    local min = values.min
    local max = values.max

    -- get the "average" of the two numbers, (min+max)/2
    -- TODO set this with respect for the step sizes, precision, etc
    local mid = (min+max)/2
    mid = self:slider_get_precise_value(mid, false)
    self:set_default_value(mid)
end

--- Selects a value in the UI for this option.
--- Called from @{mct_option:set_selected_setting}.
function wrapped_type:ui_select_value(val)
    local option_uic = self:get_uic_with_key("option")
    if not is_uicomponent(option_uic) then
        err("ui_select_value() triggered for mct_option with key ["..self:get_key().."], but no option_uic was found internally. Aborting!")
        return false
    end

    local right_button = self:get_uic_with_key("right_button")
    local left_button = self:get_uic_with_key("left_button")
    local text_input = self:get_uic_with_key("text_input")

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
    text_input:SetInteractive(false)
end

--- Change the UI state; ie., lock if it's set to lock.
--- Called from @{mct_option:set_uic_locked}.
function wrapped_type:ui_change_state()
    local option_uic = self:get_uic_with_key("option")
    local text_uic = self:get_uic_with_key("text")

    local locked = self:get_uic_locked()
    local lock_reason = self:get_lock_reason()

    local left_button = self:get_uic_with_key("left_button")
    local right_button = self:get_uic_with_key("right_button")
    local edit_button = self:get_uic_with_key("edit_button")
    --local text_input = self:get_uic_with_key("text_input")

    local state = "active"
    local tt = self:get_tooltip_text()
    if locked then
        state = "inactive"
        tt = lock_reason .. "\n" .. tt
    end

    --_SetInteractive(text_input, not locked)
    _SetState(edit_button, state)
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
function wrapped_type:ui_create_option(dummy_parent)
    local templates = self:get_uic_template()
    --local values = option_obj:get_values()

    local left_button_template = templates[1]
    local right_button_template = templates[3]
    
    local text_input_template = templates[2]

    -- hold it all in a dummy
    local new_uic = core:get_or_create_component("mct_slider", "ui/mct/script_dummy", dummy_parent)
    new_uic:SetVisible(true)
    new_uic:Resize(dummy_parent:Width() * 0.5, dummy_parent:Height())

    -- secondary dummy for everything but the edit button
    local second_dummy = core:get_or_create_component("positioning_dummy", "ui/mct/script_dummy", new_uic)

    local left_button = core:get_or_create_component("left_button", left_button_template, second_dummy)
    local right_button = core:get_or_create_component("right_button", right_button_template, second_dummy)
    local text_input = core:get_or_create_component("text_input", text_input_template, second_dummy)

    local edit_button = core:get_or_create_component("mct_slider_edit", "ui/templates/square_medium_button", new_uic)
    edit_button:Resize(text_input:Height(), text_input:Height())
    edit_button:SetDockingPoint(4)
    edit_button:SetDockOffset(5, 0)

    local img_path = "ui/skins/defaulticon_options.png"
    edit_button:SetImagePath(img_path)
    edit_button:SetTooltipText("Edit", true)

    second_dummy:Resize(new_uic:Width() - edit_button:Width() - 5, new_uic:Height())
    second_dummy:SetDockingPoint(6)
    second_dummy:SetDockOffset(-5, 0)

    text_input:SetCanResizeWidth(true)
    text_input:Resize(text_input:Width() * 0.4, text_input:Height())
    text_input:SetCanResizeWidth(false)

    left_button:SetDockingPoint(4)
    text_input:SetDockingPoint(5)
    right_button:SetDockingPoint(6)

    left_button:SetDockOffset(0,0)
    right_button:SetDockOffset(0,0)

    self:set_uic_with_key("option", new_uic, true)
    self:set_uic_with_key("text_input", text_input, true)
    self:set_uic_with_key("left_button", left_button, true)
    self:set_uic_with_key("right_button", right_button, true)
    self:set_uic_with_key("edit_button", edit_button, true)

    return new_uic
end

--------- UNIQUE SECTION -----------
-- These functions are unique for this type only. Be careful calling these!

--- Get a precise value for this slider, minding the precision set.
---@param value number The number to change the precision for.
---@param as_string boolean Set to true if you want a string returned instead of a number.
---@param override_precision number|nil A number to change the precision. If not set, it will use the value set in @{mct_slider:slider_set_precision}.
--- @treturn number|string precise_value The new number with the precision in mind.
function wrapped_type:slider_get_precise_value(value, as_string, override_precision)
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
function wrapped_type:slider_set_step_size(step_size, step_size_precision)
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

    local option = self:get_option()

    option._values.step_size = step_size
    option._values.step_size_precision = step_size_precision
end

---- Setter for the precision on the slider's displayed value. Necessary when working with decimal numbers.
--- The number should be how many decimal places you want, ie. if you are using one decimal place, send 1 to this function; if you are using none, send 0.
---@param precision number The precision used for floats.
function wrapped_type:slider_set_precision(precision)
    --[[if not self:get_type() == "slider" then
        err("slider_set_precision() called for option ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the option is not a slider! Returning false.")
        return false
    end]]

    if not is_number(precision) then
        err("slider_set_precision() called for option ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the min value supplied ["..tostring(precision).."] is not a number! Returning false.")
        return false
    end

    local option = self:get_option()

    option._values.precision = precision
end

---- Setter for the minimum and maximum values for the slider. If the UI already exists, this method will do a quick check to make sure the current value is between the new min/max, and it will change the lock states of the left/right buttons if necessary.
---@param min number The minimum number the slider value can reach.
---@param max number The maximum number the slider value can reach.
function wrapped_type:slider_set_min_max(min, max)
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

    local option = self:get_option()

    option._values.min = min
    option._values.max = max

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
function wrapped_type:test_text(text)
    text = tonumber(text)
    if not is_number(text) then
        return "Not a valid number!"
    end

    local values = self:get_values()
    local min = values.min
    local max = values.max
    local current = self:get_selected_setting()
    local precision = values.precision

    if text == current then
        return "This is the current value!"
    elseif text > max then
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

--- Creates the edit-in-UI popup.
function wrapped_type:ui_create_popup()
    local panel = mct.ui.panel
    panel:UnLockPriority()

    local popup = core:get_or_create_component("mct_slider_rename", "ui/mct/mct_dialogue", panel)

    local both_group = UIComponent(popup:CreateComponent("both_group", "ui/mct/script_dummy"))
    local ok_group = UIComponent(popup:CreateComponent("ok_group", "ui/mct/script_dummy"))
    local DY_text = UIComponent(popup:CreateComponent("DY_text", "ui/vandy_lib/text/la_gioconda/center"))

    both_group:SetDockingPoint(8)
    both_group:SetDockOffset(0, 0)

    ok_group:SetDockingPoint(8)
    ok_group:SetDockOffset(0, 0)

    DY_text:SetVisible(true)
    DY_text:SetDockingPoint(5)
    local ow,oh = popup:Width() * 0.9, popup:Height() * 0.4
    DY_text:Resize(ow, oh)
    DY_text:SetDockOffset(1, -35)

    local cancel_img = skin_image("icon_cross.png")
    local tick_img = skin_image("icon_check.png")

    do
        local button_tick = UIComponent(both_group:CreateComponent("button_tick", "ui/templates/round_medium_button"))
        local button_cancel = UIComponent(both_group:CreateComponent("button_cancel", "ui/templates/round_medium_button"))

        button_tick:SetImagePath(tick_img)
        button_tick:SetDockingPoint(8)
        button_tick:SetDockOffset(-30, -10)
        button_tick:SetCanResizeWidth(false)
        button_tick:SetCanResizeHeight(false)

        button_cancel:SetImagePath(cancel_img)
        button_cancel:SetDockingPoint(8)
        button_cancel:SetDockOffset(30, -10)
        button_cancel:SetCanResizeWidth(false)
        button_cancel:SetCanResizeHeight(false)
    end

    do
        local button_tick = UIComponent(ok_group:CreateComponent("button_tick", "ui/templates/round_medium_button"))

        button_tick:SetImagePath(tick_img)
        button_tick:SetDockingPoint(8)
        button_tick:SetDockOffset(0, -10)
        button_tick:SetCanResizeWidth(false)
        button_tick:SetCanResizeHeight(false)
    end

    popup:PropagatePriority(1000)
    popup:LockPriority()

    -- TODO plop in a title with the mod key + option key

    local tx = UIComponent(popup:Find("DY_text"))
    local default_text = "Choose the number to supply to the option "..self:get_text()

    local function set_text(str)
        local w,h = tx:TextDimensionsForText(str)
        tx:ResizeTextResizingComponentToInitialSize(w,h)

        _SetStateText(tx, str)

        tx:Resize(ow,oh)
        w,h = tx:TextDimensionsForText(default_text)
        tx:ResizeTextResizingComponentToInitialSize(ow,oh)
    end

    set_text(default_text)

    do
        local x,y = tx:GetDockOffset()
        y = y -40
        tx:SetDockOffset(x,y)
    end

    local input = core:get_or_create_component("mct_text_input", "ui/common ui/text_box", popup)
    input:SetDockingPoint(8)
    input:SetDockOffset(0, input:Height() * -4.5)
    input:SetStateText("")
    input:SetInteractive(true)

    input:Resize(input:Width() * 0.75, input:Height())

    input:PropagatePriority(popup:Priority())

    local check_name = core:get_or_create_component("check_name", "ui/templates/square_medium_text_button_toggle", popup)
    check_name:PropagatePriority(input:Priority() + 100)
    check_name:SetDockingPoint(8)
    check_name:SetDockOffset(0, input:Height() * -3.0)

    check_name:Resize(input:Width() * 0.95, input:Height() * 1.45)
    check_name:SetTooltipText("", true)

    local txt = find_uicomponent(check_name, "dy_province")
    txt:SetStateText("Check Number")
    txt:SetDockingPoint(5)
    txt:SetDockOffset(0,0)
    txt:SetTooltipText("", true)

    find_uicomponent(popup, "both_group"):SetVisible(true)
    find_uicomponent(popup, "ok_group"):PropagateVisibility(false)

    local button_tick = find_uicomponent(popup, "both_group", "button_tick")
    button_tick:SetState("inactive")

    local current_num = ""

    core:add_listener(
        "mct_text_input_check_name",
        "ComponentLClickUp",
        function(context)
            --log("NEW POPUP CHECK NAME")
            return context.string == "check_name"
        end,
        function(context)
            local ok, msg = pcall(function()
            check_name:SetState("active")


            local current_key = input:GetStateText()
            -- TODO refactor this into a method on text_input wrapped_type
            --local test = mct.settings:test_profile_with_key(current_key)

            local test = self:test_text(current_key)

            if test == true then
                button_tick:SetState("active")

                current_num = current_key
                set_text(default_text .. "\nCurrent name: " .. current_key)
            else
                button_tick:SetState("inactive")

                current_num = ""

                local invalid_string = test

                set_text(default_text .. "\n[[col:red]]"..invalid_string.."[[/col]]")
            end
        end) if not ok then err(msg) end
        end,
        true
    )

    core:add_listener(
        "mct_text_input_panel_close",
        "ComponentLClickUp",
        function(context)
            return context.string == "button_tick" or context.string == "button_cancel"
        end,
        function(context)
            delete_component(popup)

            local panel = mct.ui.panel
            panel:LockPriority()

            if context.string == "button_tick" then
                self:set_selected_setting(tonumber(current_num))
            end

            core:remove_listener("mct_text_input_check_name")
        end,
        false
    )

end

---------- List'n'rs -------------
--

core:add_listener(
    "mct_slider_edit",
    "ComponentLClickUp",
    function(context)
        return context.string == "mct_slider_edit"
    end,
    function(context)
        local uic = UIComponent(context.component)
        local text_input = UIComponent(uic:Parent())
        local parent = UIComponent(text_input:Parent())
        local parent_id = parent:Id()

        local mod_obj = mct:get_selected_mod()
        local option_obj = mod_obj:get_option_by_key(parent_id)

        if not mct:is_mct_option(option_obj) then
            err("mct_slider_edit listener trigger, but the text-input pressed ["..parent_id.."] doesn't have a valid mct_option attached. Returning false.")
            return false
        end

        -- external function (it's literally right above) handles the popup and everything
        option_obj:get_wrapped_type():ui_create_popup()
    end,
    true
)

core:add_listener(
    "mct_slider_left_or_right_pressed",
    "ComponentLClickUp",
    function(context)
        local uic = UIComponent(context.component)
        return (uic:Id() == "left_button" or uic:Id() == "right_button") and uicomponent_descended_from(uic, "mct_slider")
    end,
    function(context)
        local ok, msg = pcall(function()
        local step = context.string
        local uic = UIComponent(context.component)

        local slider = UIComponent(uic:Parent())
        local dummy_option = UIComponent(slider:Parent())
        local slider_dummy_dummy = UIComponent(dummy_option:Parent())

        local option_key = slider_dummy_dummy:Id()
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

return wrapped_type