--- MCT range slider type. Picks a low and a high number between a min and a max, saved as one setting: `{low, high}`.

local mct = get_mct()
local log,logf,err,errf = get_vlog("[mct]")
local Option = mct:get_mct_option_class()

-- option types load in no set order, so load the slider directly. GLib caches it by path, so the type loader reuses this copy.
---@type MCT.Option.Slider
local Slider = GLib.LoadModule("slider", GLib.ThisPath(...))

--- The ends of the range, in order. Used to name each end's UICs.
local SIDES = {"low", "high"}

--- Arrow button ids, mapped to the end they move and the direction.
local ARROWS = {
    low_left = {1, -1},
    low_right = {1, 1},
    high_left = {2, -1},
    high_right = {2, 1},
}

--- Text input ids, mapped to the end they edit.
local INPUTS = {
    mct_range_low_input = 1,
    mct_range_high_input = 2,
}

--- A slider with two ends. Its setting is `{low, high}`, with min <= low <= high <= max. It keeps the slider's templates, bounds, step size,
--- and precision, set with the same `slider_set_*` functions. Copy the setting table before changing it, since it's MCT's own copy.
---@class MCT.Option.RangeSlider : MCT.Option.Slider
---@field __new fun():MCT.Option.RangeSlider
local RangeSlider = Slider:extend("MCT.Option.RangeSlider")

---@param mod_obj MCT.Mod
---@param option_key string
---@return MCT.Option.RangeSlider
function RangeSlider:new(mod_obj, option_key)
    local o = self:__new()
    Option.init(o, mod_obj, option_key)

    return o
end

--- Check the value is `{low, high}` within min/max and precision, with low <= high.
---@param value any Tested value.
---@return boolean valid True if the value is valid.
---@return number[] valid_return The value to use instead, if it wasn't valid.
function RangeSlider:check_validity(value)
    if not is_table(value) or not is_number(value[1]) or not is_number(value[2]) then
        return false, self:get_fallback_value()
    end

    local values = self:get_values()
    local low = self:slider_get_precise_value(math.clamp(value[1], values.min, values.max), false)
    local high = self:slider_get_precise_value(math.clamp(value[2], values.min, values.max), false)

    if low > high then low, high = high, low end

    if low ~= value[1] or high ~= value[2] then
        return false, {low, high}
    end

    return true, value
end

--- The default value is the full range, `{min, max}`.
---@return number[]
function RangeSlider:get_fallback_value()
    local values = self:get_values()
    return {values.min, values.max}
end

--- Show the range as "low - high".
---@param value any The setting.
---@return string
function RangeSlider:get_value_text(value)
    if not is_table(value) then return Option.get_value_text(self, value) end
    return tostring(value[1]) .. " - " .. tostring(value[2])
end

--- Set the lowest and highest numbers the ends can reach. If the UI exists, the current range is pulled inside the new bounds.
---@param min number
---@param max number
function RangeSlider:slider_set_min_max(min, max)
    if not is_number(min) or not is_number(max) or min > max then
        err("slider_set_min_max() called for option ["..self:get_key().."], but min ["..tostring(min).."] and max ["..tostring(max).."] are not numbers with min <= max! Returning false.")
        return false
    end

    self._values.min = min
    self._values.max = max

    if is_uicomponent(self:get_uic_with_key("option")) then
        -- the validity check pulls the current range inside the new bounds
        self:set_selected_setting(self:get_selected_setting())
    end

    return self
end

--- Test typed text for one end. Checks it's a number between the bounds and the other end, in precision, then runs the validity tests.
---@param i number 1 for the low end, 2 for the high end.
---@param text any The typed text.
---@return true|string #True if valid, or the error message to show.
function RangeSlider:test_end_text(i, text)
    local values = self:get_values()
    local current = self:get_selected_setting()
    local num = self:read_typed_number(text, i == 1 and values.min or current[1], i == 1 and current[2] or values.max)
    if is_string(num) then return num end

    local value = table.copy(current)
    value[i] = num
    return self:run_validity_tests(value)
end

--- Show the range in both text boxes, and turn off any arrow that would push an end past a bound or the other end.
---@param val any The setting to show.
function RangeSlider:ui_select_value(val)
    if not self:get_uic_with_key("low_input") then return end

    local ok, new_val = self:check_validity(val)
    if not ok then val = new_val end

    local values = self:get_values()
    local step_size_str = self:slider_get_precise_value(values.step_size, true, values.step_size_precision)

    for i, side in ipairs(SIDES) do
        local input = self:get_uic_with_key(side.."_input")
        local left = self:get_uic_with_key(side.."_left")
        local right = self:get_uic_with_key(side.."_right")

        local lowest = i == 1 and values.min or val[1]
        local highest = i == 1 and val[2] or values.max

        input:SetStateText(tostring(self:slider_get_precise_value(val[i], true)))

        if left then
            left:SetState(val[i] <= lowest and "inactive" or "active")
            right:SetState(val[i] >= highest and "inactive" or "active")
            left:SetTooltipText("-"..step_size_str, true)
            right:SetTooltipText("+"..step_size_str, true)
        else
            self:bar_set_value(self:get_uic_with_key(side.."_bar"), val[i], i)
        end
    end
end

--- Lock or unlock both ends.
function RangeSlider:ui_change_state()
    local locked = self:is_locked()

    for _, side in ipairs(SIDES) do
        local input = self:get_uic_with_key(side.."_input")
        if not input then return end

        input:SetInteractive(not locked)
        input:SetTooltipText(self:get_tooltip_text(), true)

        local left = self:get_uic_with_key(side.."_left")
        if not left then
            self:bar_set_interactive(self:get_uic_with_key(side.."_bar"), not locked)
        elseif locked then
            -- unlocked arrow states are set by `ui_select_value`
            left:SetState("inactive")
            self:get_uic_with_key(side.."_right"):SetState("inactive")
        end
    end
end

--- Called by the bar timer when one end's handle moves. Each end stops at the other one.
---@param i number 1 for the low end, 2 for the high end.
---@param value number The value under the handle.
---@param settled boolean True once the handle has stopped.
function RangeSlider:bar_on_moved(i, value, settled)
    local current = self:get_selected_setting()
    if i == 1 then value = math.min(value, current[2]) else value = math.max(value, current[1]) end

    if not settled then
        self:get_uic_with_key(SIDES[i].."_input"):SetStateText(tostring(self:slider_get_precise_value(value, true)))
    elseif value ~= current[i] then
        local new_value = table.copy(current)
        new_value[i] = value
        self:set_selected_setting(new_value)
    else
        -- snap the handle onto the step it was dropped near, or back off the other end
        self:ui_select_value(current)
    end
end

--- Create one end as an arrow, a text box, and an arrow, like a slider. The two ends sit side by side.
---@param range_parent UIC The holder for both ends.
---@param group UIC This end's holder.
---@param i number 1 for the low end, 2 for the high end.
---@param side string "low" or "high".
---@param templates string[] The arrow, text box, and arrow templates.
function RangeSlider:ui_create_arrows_end(range_parent, group, i, side, templates)
    group:Resize(range_parent:Width() / 2, range_parent:Height())

    local left = core:get_or_create_component(side.."_left", templates[1], group)
    local input = core:get_or_create_component("mct_range_"..side.."_input", templates[2], group)
    local right = core:get_or_create_component(side.."_right", templates[3], group)

    input:SetCanResizeWidth(true)
    input:Resize(group:Width() - right:Width() * 2 - 4, input:Height())
    input:SetCanResizeWidth(false)
    input:SetInteractive(true)

    -- as tall as the arrow buttons. Docking below places the parts against this height.
    group:Resize(group:Width(), math.max(right:Height(), input:Height()), false)

    left:SetDockingPoint(4)
    left:SetDockOffset(2, 0)
    input:SetDockingPoint(5)
    right:SetDockingPoint(6)
    right:SetDockOffset(-2, 0)

    self:set_uic_with_key(side.."_left", left, true)
    self:set_uic_with_key(side.."_input", input, true)
    self:set_uic_with_key(side.."_right", right, true)
end

--- Create one end as a draggable bar with a number box on its right. The two ends are stacked, low on top.
---@param range_parent UIC The holder for both ends.
---@param group UIC This end's holder.
---@param i number 1 for the low end, 2 for the high end.
---@param side string "low" or "high".
---@param templates string[] The arrow, text box, and arrow templates. Only the text box is used.
function RangeSlider:ui_create_bar_end(range_parent, group, i, side, templates)
    group:Resize(range_parent:Width(), range_parent:Height() / 2)

    local input = core:get_or_create_component("mct_range_"..side.."_input", templates[2], group)
    local bar = self:ui_create_bar_beside_input(group, input, side.."_bar")

    self:set_uic_with_key(side.."_input", input, true)
    self:set_uic_with_key(side.."_bar", bar, true)
    self:bar_register(bar, i, self:get_selected_setting()[i])
end

--- The label lines up with the first line of the control. For stacked bars that's the low bar, not both.
---@param control UIC The holder for both ends.
---@return number
function RangeSlider:ui_get_control_line_height(control)
    return find_uicomponent(control, "low_group"):Height()
end

--- Create both ends in the right half of the row, as arrows or bars depending on the style.
---@param dummy_parent UIC The option row.
---@return UIC #The holder for both ends.
function RangeSlider:ui_create_option(dummy_parent)
    local templates = self:get_uic_template()

    local range_parent = core:get_or_create_component("range_parent", "ui/campaign ui/script_dummy", dummy_parent)
    range_parent:Resize(dummy_parent:Width() * 0.5, dummy_parent:Height())

    for i, side in ipairs(SIDES) do
        local group = core:get_or_create_component(side.."_group", "ui/campaign ui/script_dummy", range_parent)

        if self._style == "bar" then
            self:ui_create_bar_end(range_parent, group, i, side, templates)
        else
            self:ui_create_arrows_end(range_parent, group, i, side, templates)
        end
    end

    -- fit the holder to the ends: side by side, or stacked with a gap between the bars
    local low, high = find_uicomponent(range_parent, "low_group"), find_uicomponent(range_parent, "high_group")
    local stacked = self._style == "bar"
    local height = stacked and low:Height() + mct:get_ui():get_spacing().stack_gap + high:Height() or low:Height()
    range_parent:Resize(range_parent:Width(), height, false)
    low:SetDockingPoint(stacked and 2 or 4)
    high:SetDockingPoint(stacked and 8 or 6)

    self:set_uic_with_key("option", range_parent, true)

    return range_parent
end

---------- List'n'rs -------------
--

--- Get the range slider a clicked component belongs to, or nil if it's locked or missing.
---@param uic UIC
---@return MCT.Option.RangeSlider?
local function get_unlocked_option(uic)
    local option_obj = mct:get_selected_mod():get_option_by_key(uic:GetProperty("mct_option"))
    if not mct:is_mct_option(option_obj) or option_obj:is_locked() then return end

    return option_obj
end

core:add_listener(
    "mct_range_slider_arrow_pressed",
    "ComponentLClickUp",
    function(context)
        return ARROWS[context.string] ~= nil and uicomponent_descended_from(UIComponent(context.component), "range_parent")
    end,
    function(context)
        local option_obj = get_unlocked_option(UIComponent(context.component))
        if not option_obj then return end

        -- moves the end like a dropped bar handle, which stops it at the other end instead of letting them swap
        local i, direction = ARROWS[context.string][1], ARROWS[context.string][2]
        option_obj:bar_on_moved(i, option_obj:get_selected_setting()[i] + direction * option_obj:get_values().step_size, true)
    end,
    true
)

core:add_listener(
    "mct_range_slider_text_input",
    "ComponentLClickUp",
    function(context)
        return INPUTS[context.string] ~= nil
    end,
    function(context)
        local text_input = UIComponent(context.component)
        local option_obj = get_unlocked_option(text_input)
        if not option_obj then return end

        local i = INPUTS[context.string]
        option_obj:ui_watch_text_input(
            text_input,
            function(text) return option_obj:test_end_text(i, text) end,
            function(text)
                local value = table.copy(option_obj:get_selected_setting())
                value[i] = tonumber(text)
                option_obj:set_selected_setting(value)
            end
        )
    end,
    true
)

return RangeSlider
