--- TODO port to the new slider system!


--- MCT Slider type
local mct = get_mct()
local log,logf,err,errf = get_vlog("[mct]")
local Super = mct:get_mct_option_class()

---@type MCT.Option.Slider
local defaults = {
    _template = {"ui/templates/cycle_button_arrow_previous", "ui/common ui/text_box", "ui/templates/cycle_button_arrow_next"},

    _values = {
        min = 0,
        max = 100,
        step_size = 1,
        step_size_precision = 0,
        precision = 0,
    },

    ---@type "arrows"|"bar" How the slider is drawn. Set with `slider_set_style`.
    _style = "arrows",
}

---@class MCT.Option.Slider : MCT.Option A Slider Object.
local Slider = Super:extend("MCT.Option.Slider", defaults)

--- The bar sliders on screen, keyed by mod, option, and end. One shared timer reads their handles, since the game's slider doesn't tell
--- script when it's dragged.
---@type table<string, {option: MCT.Option.Slider, bar: UIC, handle: UIC, index: number?, last_value: number, moving: boolean}>
local active_bars = {}

--- The id of the shared timer that reads the bar handles.
local BAR_POLL_KEY = "mct_slider_bar_poll"

--- Whether the shared bar timer is running.
local bar_poll_running = false

--- The range end each bar id belongs to. A plain slider's bar has none.
local BAR_INDEXES = {low_bar = 1, high_bar = 2}

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
--- @return number valid_return If the value passed isn't valid, a second return is sent, for a valid value to replace the tested one with.
function Slider:check_validity(value)
    if not is_number(value) then
        return false, self:get_default_value()
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
        ---@cast test number
        -- not precise!
        return false, test
    end

    return true, value
end

--- Sets the default value for this mct_option.
--- Returns the exact median value for this slider, with precision in mind.
function Slider:get_fallback_value()
    local values = self:get_values()

    local min = values.min
    local max = values.max

    -- get the "average" of the two numbers, (min+max)/2
    -- TODO set this with respect for the step sizes, precision, etc
    local mid = (min+max)/2
    mid = self:slider_get_precise_value(mid, false)
    return mid
end

---- Internal function that calls the operation to change an option's selected value. Exposed here so it can be called through presets and the like. Use `set_selected_setting` instead, please!
--- Selects a value in UI for this mct_option.
---@param val any Set the selected setting as the passed value, tested with check_validity()
function Slider:ui_select_value(val)
    local text_input = self:get_uic_with_key("option")
    if not is_uicomponent(text_input) then
        err("ui_select_value() triggered for mct_option with key ["..self:get_key().."], but no option_uic was found internally. Aborting!")
        return false
    end

    local ok, new_val = self:check_validity(val)
    if not ok then
        err("ui_select_value() triggered for mct_option with key ["..self:get_key().."], but the value passed ["..tostring(val).."] was invalid. Using new val!")
        val = new_val
    end

    if self._style == "bar" then
        text_input:SetStateText(tostring(self:slider_get_precise_value(val, true)))
        self:bar_set_value(self:get_uic_with_key("bar"), val)
        return Super.ui_select_value(self, val)
    end

    local right_button = self:get_uic_with_key("right_button")
    local left_button = self:get_uic_with_key("left_button")

    local values = self:get_values()
    local max = values.max
    local min = values.min
    local step_size = values.step_size
    local step_size_precision = values.step_size_precision

    -- enable both buttons & push new value
    right_button:SetState("active")
    left_button:SetState("active")


    if val >= max then
        right_button:SetState("inactive")
        left_button:SetState("active")

        val = max
    elseif val <= min then
        right_button:SetState("active")
        left_button:SetState("inactive")

        val = min
    end

    -- TODO move step size edits out of this one?
    local step_size_str = self:slider_get_precise_value(step_size, true, step_size_precision)

    right_button:SetTooltipText("+"..step_size_str, true)
    left_button:SetTooltipText("-"..step_size_str, true)

    --local current = self:get_precise_value(self:get_selected_setting(), false)
    local current_str = self:slider_get_precise_value(self:get_selected_setting(), true)

    text_input:SetStateText(tostring(current_str))
    -- text_input:SetInteractive(false)

    Super.ui_select_value(self, val)
end

--- Change the UI state; ie., lock if it's set to lock.
--- Called from @{mct_option:set_uic_locked}.
function Slider:ui_change_state()
    local text_uic = self:get_uic_with_key("option")

    local locked = self:is_locked()
    local lock_reason = self:get_lock_reason()

    local left_button = self:get_uic_with_key("left_button")
    local right_button = self:get_uic_with_key("right_button")

    if self._style == "bar" then
        text_uic:SetInteractive(not locked)
        text_uic:SetTooltipText(self:get_tooltip_text(), true)
        self:bar_set_interactive(self:get_uic_with_key("bar"), not locked)
        return
    end

    local state = "active"
    local tt = self:get_tooltip_text()
    if locked then
        state = "inactive"
        -- tt = lock_reason .. "\n" .. tt

        text_uic:SetInteractive(false)
    end

    --_SetInteractive(text_input, not locked)
    right_button:SetState(state)
    left_button:SetState(state)
    text_uic:SetTooltipText(tt, true)
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

    --- This is solely for the sake of positioning everything!
    local slider_parent = core:get_or_create_component("slider_parent", "ui/campaign ui/script_dummy", dummy_parent)
    slider_parent:SetDockingPoint(6)
    slider_parent:SetDockOffset(0, 0)
    slider_parent:Resize(dummy_parent:Width() * 0.5, dummy_parent:Height())

    local text_input = core:get_or_create_component("mct_slider_text_input", text_input_template, slider_parent)

    if self._style == "bar" then
        local bar = self:ui_create_bar_beside_input(slider_parent, text_input, "bar")

        self:set_uic_with_key("dummy_parent", slider_parent, true)
        self:set_uic_with_key("option", text_input, true)
        self:set_uic_with_key("bar", bar, true)
        self:bar_register(bar, nil, self:get_selected_setting())

        return slider_parent
    end

    local left_button = core:get_or_create_component("left_button", left_button_template, slider_parent)
    local right_button = core:get_or_create_component("right_button", right_button_template, slider_parent)

    text_input:SetCanResizeWidth(true)
    text_input:Resize(slider_parent:Width() - right_button:Width() * 2, text_input:Height())
    text_input:SetCanResizeWidth(false)
    text_input:SetInteractive(true)

    -- as tall as the arrow buttons, so the row lines up with what's drawn. Docking below places the parts against this height.
    slider_parent:Resize(slider_parent:Width(), math.max(right_button:Height(), text_input:Height()), false)

    right_button:SetDockingPoint(6)
    text_input:SetDockingPoint(5)
    left_button:SetDockingPoint(4)

    right_button:SetDockOffset(-2, 0)
    text_input:SetDockOffset(0, 0)
    left_button:SetDockOffset(2, 0)
    -- text_input:SetDockOffset(-right_button:Width() * 1.1, 0)
    -- left_button:SetDockOffset(-right_button:Width() * 1.1 - text_input:Width() * 1.1, 0)

    self:set_uic_with_key("dummy_parent", slider_parent, true)
    self:set_uic_with_key("option", text_input, true)
    self:set_uic_with_key("left_button", left_button, true)
    self:set_uic_with_key("right_button", right_button, true)

    return slider_parent
end

--------- UNIQUE SECTION -----------
-- These functions are unique for this type only. Be careful calling these!

--- Get a precise value for this slider, minding the precision set.
---@param value number The number to change the precision for.
---@param as_string boolean Set to true if you want a string returned instead of a number.
---@param override_precision number|nil A number to change the precision. If not set, it will use the value set in @{mct_slider:slider_set_precision}.
--- @return number|string precise_value The new number with the precision in mind.
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

    return self
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

    return self
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

    return self
end


--- Set how this slider is drawn. "arrows", the default, is arrow buttons around a number box. "bar" is the game's draggable slider bar
--- beside a number box.
---@param style "arrows"|"bar"
---@return MCT.Option.Slider|false
function Slider:slider_set_style(style)
    if style ~= "arrows" and style ~= "bar" then
        err("slider_set_style() called for option ["..self:get_key().."], but the style ["..tostring(style).."] is not \"arrows\" or \"bar\"! Returning false.")
        return false
    end

    self._style = style
    return self
end

--- Get how this slider is drawn.
---@return "arrows"|"bar"
function Slider:slider_get_style()
    return self._style
end

--- Create a draggable slider bar, left-docked in its parent. Its -/+ buttons sit outside the bar itself, so it leaves room for them.
--- The layout is the game's slider without its -/+ button callbacks, which step by the game's own value. The -/+ buttons are handled below.
---@param parent UIC The component to create the bar in.
---@param id string The bar's id.
---@param width number The width for the bar and its buttons.
---@return UIC #The bar.
function Slider:ui_create_bar(parent, id, width)
    local button_room = 32

    local bar = core:get_or_create_component(id, "ui/groovy/layouts/slider_bar", parent)
    bar:SetCanResizeWidth(true)
    bar:Resize(width - button_room * 2 - 8, bar:Height(), false)
    bar:SetCanResizeWidth(false)
    bar:SetDockingPoint(4)
    bar:SetDockOffset(button_room, 0)

    return bar
end

--- Turn a number box into the bar style: a fixed-width box docked right, and a draggable bar filling the space to its left. The parent is
--- resized to the handle's height, since the handle sticks out of the bar, so the row lines up with what's drawn.
---@param parent UIC The holder for the box and bar.
---@param input UIC The number box, already created in `parent`.
---@param bar_id string The bar's id.
---@return UIC #The bar.
function Slider:ui_create_bar_beside_input(parent, input, bar_id)
    input:SetCanResizeWidth(true)
    input:Resize(70, input:Height())
    input:SetCanResizeWidth(false)
    input:SetInteractive(true)

    local bar = self:ui_create_bar(parent, bar_id, parent:Width() - input:Width())

    -- dock after the resize, so both parts dock against the final height
    parent:Resize(parent:Width(), find_uicomponent(bar, "handle"):Height(), false)
    input:SetDockingPoint(6)
    input:SetDockOffset(-2, 0)
    bar:SetDockingPoint(4)

    return bar
end

--- Read a bar's handle as a value, rounded to the step size and precision.
---@param bar UIC
---@param handle UIC The bar's handle.
---@return number
function Slider:bar_get_value(bar, handle)
    local bar_x = bar:Position()
    local handle_x = handle:Position()
    local travel = bar:Width() - handle:Width()
    local fraction = travel > 0 and math.clamp((handle_x - bar_x) / travel, 0, 1) or 0

    local values = self:get_values()
    local steps = math.floor(fraction * (values.max - values.min) / values.step_size + 0.5)
    local value = math.clamp(values.min + steps * values.step_size, values.min, values.max)

    return self:slider_get_precise_value(value, false)
end

--- The key for one bar in `active_bars`.
---@param option MCT.Option.Slider
---@param index number? The range end, or nil for a plain slider.
---@return string
local function bar_key(option, index)
    return option:get_mod_key() .. "." .. option:get_key() .. "." .. tostring(index or 1)
end

--- Move a bar's handle to show a value.
---@param bar UIC
---@param value number
---@param index number? The range end, or nil for a plain slider.
function Slider:bar_set_value(bar, value, index)
    if not is_uicomponent(bar) then return end

    local handle = find_uicomponent(bar, "handle")
    local values = self:get_values()
    local range = values.max - values.min
    local fraction = range > 0 and (value - values.min) / range or 0

    local bar_x = bar:Position()
    local _, handle_y = handle:Position()
    handle:MoveTo(bar_x + fraction * (bar:Width() - handle:Width()), handle_y)

    -- remember the shown value, so the timer doesn't mistake this move for a drag
    local entry = active_bars[bar_key(self, index)]
    if entry then entry.last_value = value end
end

--- Turn dragging and the +/- buttons on or off for a bar.
---@param bar UIC
---@param interactive boolean
function Slider:bar_set_interactive(bar, interactive)
    if not is_uicomponent(bar) then return end

    for _, child_id in ipairs({"handle", "left", "right"}) do
        local child = find_uicomponent(bar, child_id)
        if child then child:SetInteractive(interactive) end
    end
end

--- Called by the timer when a bar's handle moves. While it's held, only the number box follows. Once it's let go, the value is set.
---@param index number? The range end, or nil for a plain slider.
---@param value number The value under the handle.
---@param settled boolean True once the handle is let go.
function Slider:bar_on_moved(index, value, settled)
    if not settled then
        self:get_uic_with_key("option"):SetStateText(tostring(self:slider_get_precise_value(value, true)))
    elseif value ~= self:get_selected_setting() then
        self:set_selected_setting(value)
    else
        -- snap the handle onto the step it was dropped near
        self:ui_select_value(value)
    end
end

--- Check every bar on screen. Each read is rounded to a step, so scrolling the page doesn't count as a move. The handle shows its
--- "down_off" state while the mouse holds it, so the value is only set once it's let go.
local function poll_bars()
    for key, entry in pairs(active_bars) do
        if not is_uicomponent(entry.bar) then
            active_bars[key] = nil
        elseif not entry.option:is_locked() then
            local value = entry.option:bar_get_value(entry.bar, entry.handle)
            local held = entry.handle:CurrentState() == "down_off"

            if value ~= entry.last_value then
                entry.last_value = value
                entry.moving = true
                entry.option:bar_on_moved(entry.index, value, false)
            end

            if entry.moving and not held then
                entry.moving = false
                entry.option:bar_on_moved(entry.index, value, true)
            end
        end
    end

    if next(active_bars) == nil then
        Slider.bar_clear_all()
    end
end

--- Start watching a bar's handle, and start the shared timer if it isn't running.
---@param bar UIC
---@param index number? The range end, or nil for a plain slider.
---@param value number The value the bar starts at.
function Slider:bar_register(bar, index, value)
    local handle = find_uicomponent(bar, "handle")
    active_bars[bar_key(self, index)] = {option = self, bar = bar, handle = handle, index = index, last_value = value, moving = false}

    if not bar_poll_running then
        bar_poll_running = true
        core:get_tm():repeat_real_callback(poll_bars, 200, BAR_POLL_KEY)
    end
end

--- Stop watching every bar, and stop the shared timer. Called before the panel closes or a page is redrawn.
function Slider.bar_clear_all()
    for key in pairs(active_bars) do active_bars[key] = nil end

    core:get_tm():remove_real_callback(BAR_POLL_KEY)
    bar_poll_running = false
end

--- Read typed text as a number between two bounds, in this slider's precision.
---@param text any The typed text.
---@param lowest number The lowest allowed number.
---@param highest number The highest allowed number.
---@return number|string #The number, or the error message to show.
function Slider:read_typed_number(text, lowest, highest)
    local num = tonumber(text)
    if not is_number(num) then
        return "Not a valid number!"
    end

    if num > highest then
        return "This value is over the maximum of ["..tostring(highest).."]."
    elseif num < lowest then
        return "This value is under the minimum of ["..tostring(lowest).."]."
    elseif num ~= self:slider_get_precise_value(num, false) then
        return "This value isn't in valid precision! It expects ["..tostring(self:get_values().precision).."] decimal points."
    end

    return num
end

--- Test typed text. Checks it's a number within min/max and precision, then runs the tests added with `add_validity_test`.
---@param text any The typed text.
---@return true|string #True if valid, or the error message to show.
function Slider:test_text(text)
    local values = self:get_values()
    local num = self:read_typed_number(text, values.min, values.max)
    if is_string(num) then return num end

    return self:run_validity_tests(num)
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

        if option_obj:is_locked() then return end

        --- set the left/right buttons inactive until clicked out
        local left_button = option_obj:get_uic_with_key("left_button")
        local right_button = option_obj:get_uic_with_key("right_button")

        -- the bar style has no arrow buttons
        if left_button and right_button then
            left_button:SetState("inactive")
            right_button:SetState("inactive")
        end

        option_obj:ui_watch_text_input(
            text_input,
            function(text) return option_obj:test_text(text) end,
            function(text)
                local value = tonumber(text)
                if value ~= option_obj:get_selected_setting() then
                    option_obj:set_selected_setting(value)
                else
                    -- the same value still needs redrawing, to turn the arrow buttons back on
                    option_obj:ui_select_value(value)
                end
            end
        )
    end,
    true
)

core:add_listener(
    "mct_slider_left_or_right_pressed",
    "ComponentLClickUp",
    function(context)
        local uic = UIComponent(context.component)
        return (uic:Id() == "left_button" or uic:Id() == "right_button") and uicomponent_descended_from(uic, "slider_parent")
    end,
    function(context)
        local ok, msg = pcall(function()
            logf("Left or Right slider button pressed!")
        local step = context.string
        local uic = UIComponent(context.component)
        local option_key = uic:GetProperty("mct_option")

        logf("Slider option key %s", option_key)
        local mod_obj = mct:get_selected_mod()

        log("getting mod "..mod_obj:get_key())
        log("finding option with key "..option_key)

        local option_obj = mod_obj:get_option_by_key(option_key)

        if option_obj:is_locked() then return end

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

--- The bar's -/+ buttons. The bar layout has no value callbacks, so each click moves its end one step here.
core:add_listener(
    "mct_slider_bar_button_pressed",
    "ComponentLClickUp",
    function(context)
        if context.string ~= "left" and context.string ~= "right" then return false end

        local uic = UIComponent(context.component)
        return uicomponent_descended_from(uic, "slider_parent") or uicomponent_descended_from(uic, "range_parent")
    end,
    function(context)
        local bar = UIComponent(UIComponent(context.component):Parent())
        local option_obj = mct:get_selected_mod():get_option_by_key(bar:GetProperty("mct_option"))
        if not mct:is_mct_option(option_obj) or option_obj:is_locked() then return end

        local index = BAR_INDEXES[bar:Id()]
        local current = option_obj:get_selected_setting()
        if index then current = current[index] end

        local step = option_obj:get_values().step_size * (context.string == "left" and -1 or 1)
        option_obj:bar_on_moved(index, option_obj:slider_get_precise_value(current + step, false), true)
    end,
    true
)

return Slider