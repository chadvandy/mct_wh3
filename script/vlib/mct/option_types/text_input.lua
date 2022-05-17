--- MCT Text-Input type
--- @class mct_text_input

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

    -- unique fields for this wrapped type
    self._validity_callbacks = {}

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

--------- OVERRIDEN SECTION -------------
-- These functions exist for every type, and have to be overriden from the version defined in template_types.

-- TODO this

--- Checks the validity of the value passed.
function wrapped_type:check_validity(value)
    if not is_string(value) then
        return false, ""
    end

    return true
end

--- Set a default value for this type, if none is set by the modder.
--- Defaults to `""`
function wrapped_type:set_default()

    -- TODO do this better mebs?
    self:set_default_value("")
    --self._default_setting = ""
end

--- Selects a passed value in UI.
function wrapped_type:ui_select_value(val)
    local option_uic = self:get_uic_with_key("text_input")
    if not is_uicomponent(option_uic) then
        err("ui_select_value() triggered for mct_option with key ["..self:get_key().."], but no option_uic was found internally. Aborting!")
        return false
    end
    
    -- auto-type the text
    _SetStateText(option_uic, val)
end

--- Changes the state of the option in UI.
--- Locks the edit button, changes the tooltip, etc.
function wrapped_type:ui_change_state()
    local option_uic = self:get_uic_with_key("text_input")
    local text_uic = self:get_uic_with_key("text")
    local edit_button = self:get_uic_with_key("edit_button")

    local locked = self:get_uic_locked()
    local lock_reason = self:get_lock_reason()

    local tt = self:get_tooltip_text()

    local state = "active"

    if locked then
        state = "inactive"
        tt = lock_reason .. "\n" .. tt
    end

    option_uic:SetInteractive(not locked)
    _SetState(edit_button, state)
    _SetTooltipText(text_uic, tt, true)
end

--- Creates the option in UI.
function wrapped_type:ui_create_option(dummy_parent)
    local text_input_template = "ui/common ui/text_box"

    local new_uic = core:get_or_create_component("mct_text_input_dummy", "ui/mct/script_dummy", dummy_parent)
    new_uic:SetVisible(true)
    new_uic:SetCanResizeWidth(true) new_uic:SetCanResizeHeight(true)
    new_uic:Resize(dummy_parent:Width() * 0.5, dummy_parent:Height())

    local text_input = core:get_or_create_component("mct_text_input", text_input_template, new_uic)
    text_input:SetVisible(true)
    text_input:SetCanResizeWidth(true) text_input:SetCanResizeHeight(true)
    text_input:Resize(new_uic:Width() - text_input:Height() - 10, text_input:Height())
    text_input:SetDockingPoint(6)
    text_input:SetDockOffset(-5, 0)

    text_input:SetInteractive(false)

    local edit_button = core:get_or_create_component("mct_text_input_edit", "ui/templates/square_medium_button", new_uic)
    edit_button:Resize(text_input:Height(), text_input:Height())
    edit_button:SetDockingPoint(4)
    edit_button:SetDockOffset(5, 0)
    local img_path = "ui/skins/default/icon_options.png"
    edit_button:SetImagePath(img_path)
    edit_button:SetTooltipText("Edit", true)
    --edit_button:Resize()

    self:set_uic_with_key("option", new_uic, true)
    self:set_uic_with_key("text_input", text_input, true)
    self:set_uic_with_key("edit_button", edit_button, true)
    
    return new_uic
    --return self:override_error("ui_create_option")
end

--------- UNIQUE SECTION -----------
-- These functions are unique for this type only. Be careful calling these!

--- add a test for validity with several returns.
---@param callback function The function to pass. Takes the text as a parameter. Return "true" for valid tests, and return false for invalid, optionally passing a string for the string that will be displayed in the popup to explain to the user why that text is unallowed.
--- @usage    wrapped_type:add_validity_test(
---               function(text)
---                     if text == "bloop" then
---                         return false, "Bloop is unallowed."
---                     else
---                         return true
---                     end
---                end
---            )
function wrapped_type:add_validity_test(callback)
    if not is_function(callback) then
        err("add_validity_test() called on mct_option ["..self:get_key().."], but the callback provided is not a valid function!")
        return false
    end


    self._validity_callbacks[#self._validity_callbacks+1] = callback
end

--- this is the tester function for supplied text into the string.
--- loops through every validity 
function wrapped_type:test_text(text)
    if not is_string(text) then
        return "Not a valid string"
    end

    local callbacks = self._validity_callbacks

    for i = 1, #callbacks do
        local callback = callbacks[i]
        local valid,errmsg = callback(text)
        if is_string(valid) then
            -- this is how they used to be handled; TODO remove this later
            return valid
        elseif valid == false then
            return errmsg
        end
    end

    -- nothing returned a string - return true for valid!
    return true
end

--- Create the popup in UI to edit the text.
function wrapped_type:ui_create_popup()
    local panel = mct.ui.panel
    panel:UnLockPriority()

    local popup = core:get_or_create_component("mct_text_input_rename", "ui/mct/mct_dialogue", panel)
    local both_group = UIComponent(popup:CreateComponent("both_group", "ui/mct/script_dummy"))
    local ok_group = UIComponent(popup:CreateComponent("ok_group", "ui/mct/script_dummy"))
    local DY_text = UIComponent(popup:CreateComponent("DY_text", "ui/vandy_lib/text/la_gioconda/center"))

    both_group:SetDockingPoint(8)
    both_group:SetDockOffset(0, 0)

    ok_group:SetDockingPoint(8)
    ok_group:SetDockOffset(0, 0)

    DY_text:SetDockingPoint(5)
    local ow,oh = popup:Width() * 0.9, popup:Height() * 0.8
    DY_text:Resize(ow,oh)
    DY_text:SetDockOffset(1, -35)
    DY_text:SetVisible(true)

    local cancel_img = skin_image("icon_cross")
    local tick_img = "ui/skins/default/icon_check.png"

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
    local default_text = "Choose the text to supply to the option "..self:get_text()

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
    txt:SetStateText("Check Text")
    txt:SetDockingPoint(5)
    txt:SetDockOffset(0,0)
    txt:SetTooltipText("", true)

    find_uicomponent(popup, "both_group"):SetVisible(true)
    find_uicomponent(popup, "ok_group"):SetVisible(false)

    local button_tick = find_uicomponent(popup, "both_group", "button_tick")
    button_tick:SetState("inactive")

    local current_name = ""

    core:add_listener(
        "mct_text_input_check_name",
        "ComponentLClickUp",
        function(context)
            --mct:log("NEW POPUP CHECK NAME")
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

                current_name = current_key
                set_text(default_text .. "\nCurrent name: " .. current_name)
            else
                button_tick:SetState("inactive")

                current_name = ""

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
                self:set_selected_setting(current_name)
            end

            core:remove_listener("mct_text_input_check_name")
        end,
        false
    )

end

---------- List'n'rs -------------
--

core:add_listener(
    "mct_text_input",
    "ComponentLClickUp",
    function(context)
        return context.string == "mct_text_input_edit"
    end,
    function(context)
        local uic = UIComponent(context.component)
        local text_input = UIComponent(uic:Parent())
        local parent = UIComponent(text_input:Parent())
        local parent_id = parent:Id()

        local mod_obj = mct:get_selected_mod()
        local option_obj = mod_obj:get_option_by_key(parent_id)

        if not mct:is_mct_option(option_obj) then
            err("mct_text_input listener trigger, but the text-input pressed ["..parent_id.."] doesn't have a valid mct_option attached. Returning false.")
            return false
        end

        -- external function (it's literally right above) handles the popup and everything
        option_obj:get_wrapped_type():ui_create_popup()
    end,
    true
)

return wrapped_type