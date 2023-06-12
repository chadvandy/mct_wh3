--- TODO multiple checkboxes - and|or operation

--- Select one of a collection of buttons!

local mct = get_mct()
local log,logf,err,errf = get_vlog("[mct]")

local Super = mct:get_mct_option_class()

---@alias MCT.Control.Multibox.Option {key: string, text: string, tooltip: string, default_value: boolean, value: boolean}

---@class MCT.Option.Multibox : MCT.Option
local defaults = {
    _template = "ui/templates/checkbox_toggle",

    ---@type MCT.Control.Multibox.Option[] #The options for this multibox.
    _options = {},
    _max_options = 6,

    ---@type "vertical"|"horizontal" #The layout of the checkboxes. Defaults to horizontal.
    _layout = "horizontal",

    _control_dock_point = 8,
    _control_dock_offset = {0, 0},

}

---@class MCT.Option.Multibox : MCT.Option
---@field __new fun():MCT.Option.Multibox
local Multibox = Super:extend("MCT.Option.Multibox", defaults)

function Multibox:new(mod_obj, option_key)
    local o = self:__new()
    Super.init(o, mod_obj, option_key)
    self.init(o)

    return o
end

function Multibox:init()
    -- self:set_default_value(false)
end


function Multibox:get_selected_setting()
    local options = self:get_options()

    local selected = {}
    for i, option in pairs(options) do
        selected[option.key] = option.value
    end

    return selected
end

--- Sets the value of the option passed to the value passed.
---@param option_key string The string of the option to set.
---@param value boolean The value to set the option to.
function Multibox:set_selected_setting(option_key, value)
    local option = self:get_option(option_key)
    option.value = value

    Super.set_selected_setting(self, self:get_selected_setting())
end

---@param settings table<string, boolean>
function Multibox:set_finalized_setting(settings)
    local options = self:get_options()

    for i, option in ipairs(options) do
        option.value = settings[option.key]
    end
end

function Multibox:get_finalized_setting()
    local options = self:get_options()

    local finalized = {}
    for i, option in pairs(options) do
        finalized[option.key] = option.value
    end

    return finalized
end

--- Checks the validity of the value passed.
---@param value any Tested value.
--- @return boolean valid Returns true if the value passed is valid, false otherwise.
--- @return string? valid_return If the value passed isn't valid, a second return is sent, for a valid value to replace the tested one with.
function Multibox:check_validity(value)
    if is_table(value) then
        return true
    end

    if not is_string(value) then
        return false, self:get_fallback_value()
    end

    -- confirm that this is a valid option
    for i, option in pairs(self._options) do
        if option.key == value then
            return true
        end
    end

    return true
end

--- Sets a default value for this mct_option. Defaults to "false" for checkboxes.
function Multibox:get_fallback_value()
    return self:get_option(1).key
end

function Multibox:get_options()
    return self._options
end

function Multibox:get_option_count()
    return #self._options
end

--- Get the option at the index passed, or the option with the key passed.
---@param i_or_key number|string The index or key of the option to get.
---@return MCT.Control.Multibox.Option|nil option The option at the index passed, or the option with the key passed.
function Multibox:get_option(i_or_key)
    if is_number(i_or_key) then
        return self._options[i_or_key]
    end

    local key = i_or_key
    for i, option in pairs(self._options) do
        if option.key == key then
            return option
        end
    end

    return nil
end

--- Set the options that can be linked to the radio buttons; minimum of one button, maximum of four.
--- Text and tooltip are required for each.
--- TODO create all options
---@param option_table table<number, MCT.Control.Multibox.Option> #A table of options, with the key being the value to set when selected.
function Multibox:set_options(option_table)
    --- error check the options table before adding them
    assert(is_table(option_table), "set_options() called for option with key ["..self:get_key().."], but the option_table supplied ["..tostring(option_table).."] is not a table!")

    local option_count = 0

    for i, option in ipairs(option_table) do
        -- triggering an assert if we're over the max options
        assert(option_count < self._max_options, "set_options() called for option with key ["..self:get_key().."], but we're already at maximum options of "..self._max_options .. "!")
        assert(is_table(option), "set_options() called for option with key ["..self:get_key().."], but the option supplied ["..tostring(option).."] is not a table!")
        assert(is_string(option.key), "set_options() called for option with key ["..self:get_key().."], but the key supplied ["..tostring(option.key).."] is not a string!")
        assert(is_string(option.text), "set_options() called for option with key ["..self:get_key().."], but the option text supplied ["..tostring(option.text).."] is not a string!")

        if not is_nil(option.tooltip) then
            assert(is_string(option.tooltip), "set_options() called for option with key ["..self:get_key().."], but the option tooltip supplied ["..tostring(option.tooltip).."] is not a string!")
        end
            
        option_count = option_count + 1
    end

    assert(option_count > 0, "set_options() called for option with key ["..self:get_key().."], but no options were supplied!")

    self._options = option_table
end

--- Create a single option and add it to the existing ones.
---@param key string #The key of the option to create.
---@param text string #The text to display on the button.
---@param tooltip string #The tooltip to display on the button.
---@param is_default boolean? #Whether or not this option should be the default.
function Multibox:create_option(key, text, tooltip, is_default)
    assert(self._max_options > self:get_option_count(), "create_option() called for option with key ["..self:get_key().."], but we're already at maximum options of "..self._max_options .. "!")
    assert(is_string(key), "create_option() called for option with key ["..self:get_key().."], but the key supplied ["..tostring(key).."] is not a string!")
    assert(is_string(text), "create_option() called for option with key ["..self:get_key().."], but the text supplied ["..tostring(text).."] is not a string!")
    assert(is_string(tooltip), "create_option() called for option with key ["..self:get_key().."], but the tooltip supplied ["..tostring(tooltip).."] is not a string!")

    if not is_boolean(is_default) then is_default = false end

    self._options[#self._options+1] = {
        key = key,
        text = text,
        tooltip = tooltip,
        is_default = is_default,
    }
end

--- TODO vertical or horizontal
function Multibox:set_layout(layout)
    assert(is_string(layout), "set_layout() called for option with key ["..self:get_key().."], but the layout supplied ["..tostring(layout).."] is not a string!")
    assert(layout == "vertical" or layout == "horizontal", "set_layout() called for option with key ["..self:get_key().."], but the layout supplied ["..tostring(layout).."] is not a valid layout!")

    self._layout = layout
end

function Multibox:get_layout()
    return self._layout
end

---@param selected_options table<string, boolean> #The options that are selected.
function Multibox:ui_select_value(selected_options)
    -- logf("Multibox:ui_select_value(%s)", selected_options)

    for i, option in ipairs(self:get_options()) do
        local option_uic = self:get_uic_with_key("option_"..option.key)
        if selected_options[option.key] == true then
            option_uic:SetState("selected")
        else
            option_uic:SetState("active")
        end
    end



    -- for i, option in ipairs(self:get_options()) do
    --     logf("Checking option w/ key %s", option.key)
    --     local option_uic = self:get_uic_with_key("option_"..option.key)
    --     if option.key == new_option_key then
    --         logf("Setting option w/ key %s to selected", option.key)
    --         option_uic:SetState("selected")
    --     else
    --         logf("Setting option w/ key %s to active", option.key)
    --         option_uic:SetState("active")
    --     end
    -- end

    -- Super.ui_select_value(self, new_option_key)
end

--- Creates the mct_option in the UI. Do not call externally.
---@param dummy_parent UIC #The parent to create the mct_option in.
function Multibox:ui_create_option(dummy_parent)
    -- create a layout based on the layout selected
    local mod_key = self:get_mod():get_key()
    local control_key = self:get_key()

    local layout = self:get_layout()

    dummy_parent:SetCanResizeHeight(true)
    dummy_parent:Resize(dummy_parent:Width(), dummy_parent:Height() * 2)
    dummy_parent:SetCanResizeHeight(false)

    local new_uic = core:get_or_create_component(self:get_key().."_holder", "ui/groovy/layouts/hlist", dummy_parent)

    self:set_uic_with_key("option", new_uic, true)

    -- these are handled elsewhere.
    -- new_uic:SetDockingPoint(8 + 9) -- bottom center external
    -- new_uic:SetDockOffset(0, 0)
    -- new_uic:Resize(dummy_parent:Width() * 0.95, dummy_parent:Height() * 0.9)

    local ow, oh = (dummy_parent:Width() * 0.95) / self._max_options, dummy_parent:Height() * 0.45

    local options = self:get_options()
    for i, option in ipairs(options) do
        local option_holder = core:get_or_create_component(option.key.."_holder", "ui/campaign ui/script_dummy", new_uic)
        option_holder:Resize(ow, oh)

        local option_uic = core:get_or_create_component(option.key, "ui/templates/checkbox_toggle", option_holder)
        option_uic:SetDockingPoint(5)
        option_uic:SetDockOffset(0, option_uic:Height() / 2) -- push the radio button down slightly.
        -- sets its state based on default / otherwise?

        self:set_uic_with_key("option_"..option.key, option_uic, true)
        option_uic:SetProperty("mct_mod", mod_key)
        option_uic:SetProperty("mct_control", control_key)
        option_uic:SetProperty("mct_control_type", "multibox")
        option_uic:SetProperty("mct_option", option.key)

        local label = core:get_or_create_component("label", "ui/groovy/text/fe_default", option_holder)
        label:SetDockingPoint(5)
        label:Resize(option_holder:Width() * 0.9, option_holder:Height() - option_uic:Height() - 5)
        label:SetDockOffset(0, - (label:Height() * 0.6))
        label:SetStateText(option.text)
        label:SetTextHAlign("centre")
        label:SetTextVAlign("centre")
        label:SetTextXOffset(0, 0)
        label:SetTextYOffset(0, 0)
    end

    return new_uic
end



core:add_listener(
    "MctRadioButtonClicked",
    "ComponentLClickUp",
    function(context)
        local uic = UIComponent(context.component)

        local p = uic:GetProperty("mct_control_type")
        return is_string(p) and p == "multibox"
    end,
    function(context)
        local uic = UIComponent(context.component)
        local mod_key = uic:GetProperty("mct_mod")
        local control_key = uic:GetProperty("mct_control")
        local option_key = uic:GetProperty("mct_option")

        logf("Pressed radio button [%s] in control [%s] in mod [%s]", option_key, control_key, mod_key)

        local mod = mct:get_mod_by_key(mod_key)
        local control = mod:get_option_by_key(control_key)
        ---@cast control MCT.Option.Multibox

        local option = control:get_option(option_key)

        control:set_selected_setting(option_key, not option.value)
    end,
    true
)

return Multibox