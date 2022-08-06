local mct = get_mct()
local log,logf,err,errf = get_vlog("[mct]")
local Super = mct._MCT_OPTION

---@class MCT.Option.TextInput
local defaults = {
    _template = "ui/common ui/text_box",

    ---@type fun(text:string)[]
    _validity_callbacks = {}
}

---@class MCT.Option.TextInput : MCT.Option
---@field __new fun():MCT.Option.TextInput
local TextInput = Super:extend("MCT.Option.TextInput", defaults)

function TextInput:new(mod_obj, option_key)
    local o = self:__new()
    Super.init(o, mod_obj, option_key)
    self.init(o)

    return o
end

function TextInput:init()

end

--------- OVERRIDEN SECTION -------------
-- These functions exist for every type, and have to be overriden from the version defined in template_types.

-- TODO this

--- Checks the validity of the value passed.
function TextInput:check_validity(value)
    if not is_string(value) then
        return false, ""
    end

    return true
end

--- Set a default value for this type, if none is set by the modder.
--- Defaults to `""`
function TextInput:get_fallback_value()
    -- TODO do this better mebs?
    return ""
end

--- Selects a passed value in UI.
function TextInput:ui_select_value(val)
    local option_uic = self:get_uic_with_key("option")
    if not is_uicomponent(option_uic) then
        err("ui_select_value() triggered for mct_option with key ["..self:get_key().."], but no option_uic was found internally. Aborting!")
        return false
    end
    
    -- auto-type the text
    _SetStateText(option_uic, val)

    Super.ui_select_value(self, val)
end

--- Changes the state of the option in UI.
--- Locks the edit button, changes the tooltip, etc.
function TextInput:ui_change_state()
    local option_uic = self:get_uic_with_key("option")
    local text_uic = self:get_uic_with_key("text")
    -- local edit_button = self:get_uic_with_key("edit_button")

    local locked = self:is_locked()
    local lock_reason = self:get_lock_reason()

    local tt = self:get_tooltip_text()

    local state = "active"

    if locked then
        state = "inactive"
        tt = lock_reason .. "\n" .. tt
    end

    option_uic:SetInteractive(not locked)
    -- _SetState(edit_button, state)
    _SetTooltipText(text_uic, tt, true)
end

--- Creates the option in UI.
function TextInput:ui_create_option(dummy_parent)
    local text_input_template = "ui/common ui/text_box"

    local text_input = core:get_or_create_component("mct_text_input", text_input_template, dummy_parent)
    text_input:SetVisible(true)
    text_input:SetCanResizeWidth(true) text_input:SetCanResizeHeight(true)
    text_input:Resize(dummy_parent:Width() * 0.4, text_input:Height())
    text_input:SetDockingPoint(6)
    text_input:SetDockOffset(-5, 0)

    text_input:SetInteractive(true)

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

    core:get_tm():real_callback(function()
        error_popup:SetVisible(false)
    end, 1, nil)

    self:set_uic_with_key("option", text_input, true)
    self:set_uic_with_key("error_popup", error_popup, true)

    return text_input
end

--------- UNIQUE SECTION -----------
-- These functions are unique for this type only. Be careful calling these!

--- add a test for validity with several returns.
---@param callback fun(t:string):boolean,string? The function to pass. Takes the text as a parameter. Return "true" for valid tests, and return false for invalid, optionally passing a string for the string that will be displayed in the popup to explain to the user why that text is unallowed.
--- @usage    wrapped_type:add_validity_test(
---               function(text)
---                     if text == "bloop" then
---                         return false, "Bloop is unallowed."
---                     else
---                         return true
---                     end
---                end
---            )
function TextInput:add_validity_test(callback)
    if not is_function(callback) then
        err("add_validity_test() called on mct_option ["..self:get_key().."], but the callback provided is not a valid function!")
        return false
    end


    self._validity_callbacks[#self._validity_callbacks+1] = callback
end

--- this is the tester function for supplied text into the string.
--- loops through every validity 
function TextInput:test_text(text)
    if not is_string(text) then
        return "Not a valid string"
    end

    local callbacks = self._validity_callbacks

    for i = 1, #callbacks do
        local callback = callbacks[i]
        local valid,errmsg = callback(text)

        if valid == false then
            return errmsg
        end
    end

    -- nothing returned a string - return true for valid!
    return true
end

---------- List'n'rs -------------
--

core:add_listener(
    "mct_text_input",
    "ComponentLClickUp",
    function(context)
        return context.string == "mct_text_input"
    end,
    function(context)
        local text_input = UIComponent(context.component)
        local mod_obj = mct:get_selected_mod()
        local option_key = text_input:GetProperty("mct_option")

        ---@type MCT.Option.TextInput
        local option_obj = mod_obj:get_option_by_key(option_key)

        if not mct:is_mct_option(option_obj) then
            err("mct_text_input listener trigger, but the text-input pressed ["..option_key.."] doesn't have a valid mct_option attached. Returning false.")
            return false
        end

        --- TODO while clicked in this text input, check its contents - if it's ever wrong, flash an error!
        core:get_tm():repeat_real_callback(function()
            --- TODO if no text input (changed tab etc.) remove this callback
            if not is_uicomponent(text_input) then
                core:get_tm():remove_real_callback("mct_text_input")
                return
            end

            local t = text_input:GetStateText()

            local valid = option_obj:test_text(t)

            local popup = option_obj:get_uic_with_key("error_popup")
            if valid ~= true then
                --- TODO print out an error on the screen!
                popup:SetVisible(true)
                find_uicomponent(popup, "text"):SetStateText("[[col:red]]" .. valid .. "[[/col]]")
                popup:RegisterTopMost()
            else
                
                popup:RemoveTopMost()
                popup:SetVisible(false)
            end
        end, 50, "mct_text_input_" .. option_key)

        core:add_listener(
            "mct_text_input_released",
            "ComponentLClickUp",
            function(context)
                return UIComponent(context.component) ~= text_input
            end,
            function(context)
                core:get_tm():remove_real_callback("mct_text_input_" .. option_key)

                local t = text_input:GetStateText()
                local valid = option_obj:test_text(t)
                if valid == true then
                    if t ~= option_obj:get_selected_setting() then
                        option_obj:set_selected_setting(t)
                    end
                else
                    --- TODO if the current text is invalid, revert it to the value it was before it all
                    --- decide whether to leave the error up or just remove it entirely.
                    option_obj:set_selected_setting(option_obj:get_finalized_setting())

                    local uic = option_obj:get_uic_with_key("error_popup")
                    if uic then
                        uic:SetVisible(false)
                    end
                end
            end,
            false
        )
    end,
    true
)

return TextInput