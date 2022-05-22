--- TODO prettify

local mct = get_mct()
local Super = mct._MCT_OPTION

-- local vlib = get_vlib()
local log,logf,err,errf = get_vlog("[mct]")

---@type MCT.Option.Dropdown
local defaults = {
    _template = {"ui/vandy_lib/dropdown_button", "ui/vandy_lib/dropdown_option"},
}

---@class MCT.Option.Dropdown : MCT.Option A Dropdown object.
---@field __new fun():MCT.Option.Dropdown
local Dropdown = Super:extend("MCT.Option.Dropdown", defaults)

function Dropdown:new(mod_obj, option_key)
    local o = self:__new()
    Super.init(o, mod_obj, option_key)
    self.init(o)

    return o
end

function Dropdown:init()
    --- anything?
end

--- Checks the validity of the value passed.
---@param val any Tested value.
--- @return boolean valid Returns true if the value passed is valid, false otherwise.
--- @return boolean valid_return If the value passed isn't valid, a second return is sent, for a valid value to replace the tested one with.
function Dropdown:check_validity(val)
    if not is_string(val) then
        return false
    end

    local values = self:get_values()
    
    -- check if this key exists as a dropdown option
    for i = 1, #values do
        local test = values[i].key

        if val == test then
            return true
        end
    end

    -- TODO catch if values is empty?
    -- return the first dropdown key if it's not valid.
    return false, values[1].key
end

--- Sets the default value for this dropdown, if none is selected by the modder.
--- Defaults to the first dropdown value added.
function Dropdown:set_default()

    local values = self:get_values()
    -- set the default value as the first added dropdown option
    self:set_default_value(values[1])
end

--- Select a value within the UI; ie., change from the first dropdown value to the second.
function Dropdown:ui_select_value(val, is_new_version)
    local valid,new = self:check_validity(val)
    if not valid then
        if val ~= nil then
            VLib.Warn("ui_select_value() called for option with key ["..self:get_key().."], but the val supplied ["..tostring(val).."] is not valid for the type. Replacing with ["..tostring(new).."].")
            val = new
        else
            err("ui_select_value() called for option with key ["..self:get_key().."], but the val supplied ["..tostring(val).."] is not valid for the type!")
            return false
        end
    end

    local dropdown_box_uic = self:get_uic_with_key("option")
    if not is_uicomponent(dropdown_box_uic) then
        err("ui_select_value() triggered for mct_option with key ["..self:get_key().."], but no dropdown_box_uic was found internally. Aborting!")
        return false
    end

    -- ditto
    local popup_menu = UIComponent(dropdown_box_uic:Find("popup_menu"))
    local popup_list = UIComponent(popup_menu:Find("popup_list"))
    local new_selected_uic = find_uicomponent(popup_list, val)

    local currently_selected_uic = nil

    for i = 0, popup_list:ChildCount() - 1 do
        local child = UIComponent(popup_list:Find(i))
        if child:CurrentState() == "selected" then
            currently_selected_uic = child
        end
    end

    -- unselected the currently-selected dropdown option
    if is_uicomponent(currently_selected_uic) then
        currently_selected_uic:SetState("unselected")
    else
        err("ui_select_value() triggered for mct_option with key ["..self:get_key().."], but no currently_selected_uic with key was found internally. Investigate!")
        --return false
    end

    -- set the new option as "selected", so it's highlighted in the list; also lock it as the selected setting in the option_obj
    new_selected_uic:SetState("selected")
    --self:set_selected_setting(val)

    -- set the state text of the dropdown box to be the state text of the row
    local t = find_uicomponent(new_selected_uic, "row_tx"):GetStateText()
    local tt = find_uicomponent(new_selected_uic, "row_tx"):GetTooltipText()
    local tx = find_uicomponent(dropdown_box_uic, "dy_selected_txt")

    tx:SetStateText(t)
    dropdown_box_uic:SetTooltipText(tt, true)

    -- set the menu invisible and unclick the box
    if dropdown_box_uic:CurrentState() == "selected" then
        dropdown_box_uic:SetState("active")
    end

    popup_menu:SetVisible(false)
    popup_menu:RemoveTopMost()

    Super.ui_select_value(self, val, is_new_version)
end

--- Change the state of the mct_option in UI; ie., lock the option from being used.
function Dropdown:ui_change_state()
    local option_uic = self:get_uic_with_key("option")
    local text_uic = self:get_uic_with_key("text")

    local locked = self:get_uic_locked()
    local lock_reason = self:get_lock_reason()

    -- disable the dropdown box
    local state = "active"
    local tt = self:get_tooltip_text()

    if locked then
        state = "inactive"
        tt = lock_reason .. "\n" .. tt
    end

    option_uic:SetState(state)
    text_uic:SetTooltipText(tt, true)
end

--- Create the dropdown option in UI.
function Dropdown:ui_create_option(dummy_parent)
    --local templates = option_obj:get_uic_template()
    local box = "ui/vandy_lib/dropdown_button"
    --local dropdown_option = templates[2]

    local new_uic = core:get_or_create_component("mct_dropdown_box", box, dummy_parent)
    new_uic:SetVisible(true)

    local popup_menu = find_uicomponent(new_uic, "popup_menu")
    popup_menu:PropagatePriority(1000) -- higher z-value than other shits
    popup_menu:SetVisible(false)
    --popup_menu:SetInteractive(true)

    local popup_list = find_uicomponent(popup_menu, "popup_list")
    popup_list:PropagatePriority(popup_menu:Priority()+1)
    --popup_list:SetInteractive(true)

    self:set_uic_with_key("option", new_uic, true)

    self:refresh_dropdown_box()

    return new_uic
end

--------- UNIQUE SECTION -----------
-- These functions are unique for this type only. Be careful calling these!

---- Method to set the `dropdown_values`. This function takes a table of tables, where the inner tables have the fields ["key"], ["text"], ["tt"], and ["is_default"]. The latter three are optional.
--- ex:
---      mct_option:add_dropdown_values({
---          {key = "example1", text = "Example Dropdown Value", tt = "My dropdown value does this!", is_default = true},
---          {key = "example2", text = "Lame Dropdown Value", tt = "This dropdown value does another thing!", is_default = false},
---      })
---
---@param dropdown_table {key:string,text:string?,tt:string?,is_default:boolean?}[]
---@return boolean
function Dropdown:add_dropdown_values(dropdown_table)
    --[[if not self:get_type() == "dropdown" then
        err("add_dropdown_values() called for option ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the option is not a dropdown! Returning false.")
        return false
    end]]

    if not is_table(dropdown_table) then
        err("add_dropdown_values() called for option ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the dropdown_table supplied is not a table! Returning false.")
        return false
    end

    if is_nil(dropdown_table[1]) then
        err("add_dropdown_values() called for option ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the dropdown_table supplied is an empty table! Returning false.")
        return false
    end

    for i = 1, #dropdown_table do
        local dropdown_option = dropdown_table[i]
        local key = dropdown_option.key
        local text = dropdown_option.text or ""
        local tt = dropdown_option.tt or ""
        local is_default = dropdown_option.default or false

        self:add_dropdown_value(key, text, tt, is_default)
    end
end

---- Used to create a single dropdown_value; also called within @{mct_option:add_dropdown_values}
---@param key string The unique identifier for this dropdown value.
---@param text string The localised text for this dropdown value.
---@param tt string The localised tooltip for this dropdown value.
---@param is_default boolean Whether or not to set this dropdown_value as the default one, when the dropdown box is created.
function Dropdown:add_dropdown_value(key, text, tt, is_default)
    --[[if not self:get_type() == "dropdown" then
        err("add_dropdown_value() called for option ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the option is not a dropdown! Returning false.")
        return false
    end]]

    if not is_string(key) then
        err("add_dropdown_value() called for option ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the key supplied is not a string! Returning false.")
        return false
    end

    text = text or ""
    tt = tt or ""

    local val = {
        key = key,
        text = text,
        tt = tt
    }

    -- local option = self:get_option()

    self._values[#self._values+1] = val

    -- check if it's the first value being assigned to the dropdown, to give at least one default value
    if #self._values == 1 then
        self:set_default_value(key)
    end

    if is_default then
        self:set_default_value(key)
    end

    -- if the UI already exists, refresh the dropdown box!
    if is_uicomponent(self:get_uic_with_key("option")) then
        self:refresh_dropdown_box()
    end
end


--- Only called on creation & add_dropdown_value, if the latter is called after the UI is created
--- Allows for dynamic dropdowns!
function Dropdown:refresh_dropdown_box()
    local uic = self:get_uic_with_key("option")

    local popup_menu = UIComponent(uic:Find("popup_menu"))
    local popup_list = UIComponent(popup_menu:Find("popup_list"))

    -- clear out any extant chil'uns
    popup_list:DestroyChildren()

    local selected_tx = UIComponent(uic:Find("dy_selected_txt"))
    
    local selected_value = self:get_selected_setting()

    local dropdown_values = self:get_values()

    local dropdown_option_template = "ui/vandy_lib/dropdown_option"

    for i = 1, #dropdown_values do
        local dropdown_value = dropdown_values[i]

        local key = dropdown_value.key
        local text = dropdown_value.text
        local tt = dropdown_value.tt

        local new_entry = core:get_or_create_component(key, dropdown_option_template, popup_list)
        
        -- if they're localised text strings, localise them!
        do
            local test_tt = common.get_localised_string(tt)
            if test_tt ~= "" then
                tt = test_tt
            end

            local test_text = common.get_localised_string(text)
            if test_text ~= "" then
                text = test_text
            end
        end

        new_entry:SetTooltipText(tt, true)

        local off_y = 5 + (new_entry:Height() * (i-1))

        new_entry:SetDockingPoint(2)
        new_entry:SetDockOffset(0, off_y)

        w,h = new_entry:Dimensions()

        local txt = find_uicomponent(new_entry, "row_tx")

        txt:SetStateText(text)

        -- check if this is the default value
        if selected_value == key then
            new_entry:SetState("selected")

            -- add the value's tt to the actual dropdown box
            selected_tx:SetStateText(text)
            uic:SetTooltipText(tt, true)
        end

        new_entry:SetCanResizeHeight(false)
        new_entry:SetCanResizeWidth(false)
    end


    local border_top = find_uicomponent(popup_menu, "border_top")
    local border_bottom = find_uicomponent(popup_menu, "border_bottom")
    
    border_top:SetCanResizeHeight(true)
    border_top:SetCanResizeWidth(true)
    border_bottom:SetCanResizeHeight(true)
    border_bottom:SetCanResizeWidth(true)

    popup_list:SetCanResizeHeight(true)
    popup_list:SetCanResizeWidth(true)
    popup_list:Resize(w * 1.1, h * (#dropdown_values) + 10)
    --popup_list:MoveTo(popup_menu:Position())
    popup_list:SetDockingPoint(2)
    --popup_list:SetDocKOffset()

    popup_menu:SetCanResizeHeight(true)
    popup_menu:SetCanResizeWidth(true)
    popup_list:SetCanResizeHeight(false)
    popup_list:SetCanResizeWidth(false)
    
    local w, h = popup_list:Bounds()
    popup_menu:Resize(w,h)
end


---- Specific listeners for the UI ----
core:add_listener(
    "mct_dropdown_box",
    "ComponentLClickUp",
    function(context)
        return context.string == "mct_dropdown_box"
    end,
    function(context)
        local box = UIComponent(context.component)
        local menu = find_uicomponent(box, "popup_menu")
        if is_uicomponent(menu) then
            if menu:Visible() then
                menu:SetVisible(false)
            else
                menu:SetVisible(true)
                menu:RegisterTopMost()
                -- next time you click something, close the menu!
                core:add_listener(
                    "mct_dropdown_box_close",
                    "ComponentLClickUp",
                    true,
                    function(context)
                        if box:CurrentState() == "selected" then
                            box:SetState("active")
                        end

                        menu:SetVisible(false)
                        menu:RemoveTopMost()
                    end,
                    false
                )
            end
        end
    end,
    true
)

-- Set Selected listeners
core:add_listener(
    "mct_dropdown_box_option_selected",
    "ComponentLClickUp",
    function(context)
        local uic = UIComponent(context.component)
        
        return UIComponent(uic:Parent()):Id() == "popup_list" and UIComponent(UIComponent(UIComponent(uic:Parent()):Parent()):Parent()):Id() == "mct_dropdown_box"
    end,
    function(context)
        log("mct_dropdown_box_option_selected")
        core:remove_listener("mct_dropdown_box_close")

        local uic = UIComponent(context.component)
        local popup_list = UIComponent(uic:Parent())
        local popup_menu = UIComponent(popup_list:Parent())
        local dropdown_box = UIComponent(popup_menu:Parent())


        -- will tell us the name of the option
        local parent_id = UIComponent(dropdown_box:Parent()):Id()
        local mod_obj = mct:get_selected_mod()
        local option_obj = mod_obj:get_option_by_key(parent_id)

        -- this operation is set externally (so we can perform the same operation outside of here)
        local ok, msg = pcall(function()
        option_obj:set_selected_setting(uic:Id())
        end) if not ok then err(msg) end
    end,
    true
)

return Dropdown