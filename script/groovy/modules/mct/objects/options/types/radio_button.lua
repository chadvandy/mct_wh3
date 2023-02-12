--- TODO
--- Select one of a collection of buttons!

local mct = get_mct()
local log,logf,err,errf = get_vlog("[mct]")

local Super = mct:get_mct_option_class()

---@alias MCT.Control.RadioButton.Option {key: string, text: string, tooltip: string, is_default: boolean}

---@class MCT.Option.RadioButton
local defaults = {
    _template = "ui/templates/radio_button",

    ---@type MCT.Control.RadioButton.Option[] #The options for this radio button.
    _options = {},

    ---@type "vertical"|"horizontal" #The layout of the radio buttons. Defaults to horizontal.
    _layout = "horizontal",

    _control_dock_point = 8,
    _control_dock_offset = {0, 0},
}

---@class MCT.Option.RadioButton : MCT.Option
---@field __new fun():MCT.Option.RadioButton
local RadioButton = Super:extend("MCT.Option.RadioButton", defaults)

function RadioButton:new(mod_obj, option_key)
    local o = self:__new()
    Super.init(o, mod_obj, option_key)
    self.init(o)

    return o
end

function RadioButton:init()
    -- self:set_default_value(false)
end

--- Checks the validity of the value passed.
---@param value any Tested value.
--- @return boolean valid Returns true if the value passed is valid, false otherwise.
--- @return boolean? valid_return If the value passed isn't valid, a second return is sent, for a valid value to replace the tested one with.
function RadioButton:check_validity(value)
    if not is_boolean(value) then
        return false, false
    end

    return true
end

--- Sets a default value for this mct_option. Defaults to "false" for checkboxes.
function RadioButton:get_fallback_value()
    return self:get_option(1).key
end

function RadioButton:get_options()
    return self._options
end

function RadioButton:get_option_count()
    return #self._options
end

function RadioButton:get_option(i_or_key)
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
---@param option_table table<number, MCT.Control.RadioButton.Option> #A table of options, with the key being the value to set when selected.
function RadioButton:set_options(option_table)
    --- error check the options table before adding them
    assert(is_table(option_table), "set_options() called for option with key ["..self:get_key().."], but the option_table supplied ["..tostring(option_table).."] is not a table!")

    local option_count = 0

    for i, option in pairs(option_table) do
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
function RadioButton:create_option(key, text, tooltip, is_default)
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
function RadioButton:set_layout(layout)
    assert(is_string(layout), "set_layout() called for option with key ["..self:get_key().."], but the layout supplied ["..tostring(layout).."] is not a string!")
    assert(layout == "vertical" or layout == "horizontal", "set_layout() called for option with key ["..self:get_key().."], but the layout supplied ["..tostring(layout).."] is not a valid layout!")

    self._layout = layout
end

function RadioButton:get_layout()
    return self._layout
end

function RadioButton:ui_select_value(new_option_key)
    for i, option in ipairs(self:get_options()) do
        local option_uic = self:get_uic_with_key("option_"..option.key)
        if option.key == new_option_key then
            option_uic:SetState("selected")
        else
            option_uic:SetState("active")
        end
    end

    Super.ui_select_value(self, new_option_key)
end

--- Creates the mct_option in the UI. Do not call externally.
---@param dummy_parent UIC #The parent to create the mct_option in.
function RadioButton:ui_create_option(dummy_parent)
    -- local template = self:get_uic_template()

    -- local new_uic = core:get_or_create_component("mct_checkbox_toggle", template, dummy_parent)
    -- new_uic:SetVisible(true)

    -- self:set_uic_with_key("option", new_uic, true)

    -- create a layout based on the layout selected
    local mod_key = self:get_mod():get_key()
    local control_key = self:get_key()

    local layout = self:get_layout()

    dummy_parent:SetCanResizeHeight(true)
    dummy_parent:Resize(dummy_parent:Width(), dummy_parent:Height() * 2)
    dummy_parent:SetCanResizeHeight(false)

    local new_uic = core:get_or_create_component(self:get_key().."_holder", "ui/groovy/layouts/hlist", dummy_parent)

    -- these are handled elsewhere.
    -- new_uic:SetDockingPoint(8 + 9) -- bottom center external
    -- new_uic:SetDockOffset(0, 0)
    -- new_uic:Resize(dummy_parent:Width() * 0.95, dummy_parent:Height() * 0.9)

    local ow, oh = (dummy_parent:Width() * 0.95) / 4, dummy_parent:Height() * 0.4

    local options = self:get_options()
    for i, option in ipairs(options) do
        local option_holder = core:get_or_create_component(option.key.."_holder", "ui/campaign ui/script_dummy", new_uic)
        option_holder:Resize(ow, oh)

        local option_uic = core:get_or_create_component(option.key, "ui/templates/radio_button", option_holder)
        option_uic:SetDockingPoint(5)
        option_uic:SetDockOffset(0, option_uic:Height() / 2) -- push the radio button down slightly.
        -- sets its state based on default / otherwise?

        self:set_uic_with_key("option_"..option.key, option_uic, true)
        option_uic:SetProperty("mct_mod", mod_key)
        option_uic:SetProperty("mct_control", control_key)
        option_uic:SetProperty("mct_control_type", "radio_button")
        option_uic:SetProperty("mct_option", option.key)

        local label = core:get_or_create_component("label", "ui/groovy/text/fe_default", option_holder)
        label:SetDockingPoint(5)
        label:Resize(option_holder:Width() * 0.9, option_holder:Height() * 0.2)
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
        return is_string(p) and p == "radio_button"
    end,
    function(context)
        logf("Pressed radio button!")
        local uic = UIComponent(context.component)
        local mod_key = uic:GetProperty("mct_mod")
        local control_key = uic:GetProperty("mct_control")
        local option_key = uic:GetProperty("mct_option")

        logf("Pressed radio button [%s] in control [%s] in mod [%s]", option_key, control_key, mod_key)

        local mod = mct:get_mod_by_key(mod_key)
        local control = mod:get_option_by_key(control_key)
        ---@cast control MCT.Option.RadioButton

        local option = control:get_option(option_key)

        control:set_selected_setting(option_key)
    end,
    true
)

return RadioButton