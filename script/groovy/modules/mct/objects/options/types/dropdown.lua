--- TODO use an auto-fill similar to the new command button dropdowns.

--- TODO prettify

local mct = get_mct()
local Super = mct:get_mct_option_class()
local log,logf,err,errf = get_vlog("[mct]")

---@type MCT.Option.Dropdown
local defaults = {
    -- _template = {"ui/vandy_lib/dropdown_button", "ui/vandy_lib/dropdown_option"},
}

---@class MCT.Option.Dropdown : MCT.Option A Dropdown object.
---@field __new fun():MCT.Option.Dropdown
local Dropdown = Super:extend("MCT.Option.Dropdown", defaults)

function Dropdown:new(mod_obj, option_key)
    local o = self:__new()
    o:init(mod_obj, option_key)

    return o
end

function Dropdown:init(mod_obj, option_key)
    --- anything?
    Super.init(self, mod_obj, option_key)
end

--- Checks the validity of the value passed.
---@param val any Tested value.
--- @return boolean valid Returns true if the value passed is valid, false otherwise.
--- @return boolean? valid_return If the value passed isn't valid, a second return is sent, for a valid value to replace the tested one with.
function Dropdown:check_validity(val)
    local values = self:get_values()
  
    if is_string(val) then
        -- check if this key exists as a dropdown option
        for i = 1, #values do
            local test = values[i].key
    
            if val == test then
                return true
            end
        end
    end

    -- TODO catch if values is empty?
    -- return the first dropdown key if it's not valid.
    return false, values[1].key
end

--- Gets a fallback value, if no default value is set by the modder.
function Dropdown:get_fallback_value()
    -- set the default value as the first added dropdown option
    local values = self:get_values()
    return values[1]
end

function Dropdown:get_option(key)
    local values = self:get_values()
    for i = 1, #values do
        local test = values[i].key

        if key == test then
            return values[i]
        end
    end

    return nil
end

--- TODO use a Cco call instead somehow?
--- Select a value within the UI; ie., change from the first dropdown value to the second.
function Dropdown:ui_select_value(val)
    local valid,new = self:check_validity(val)
    if not valid then
        if val ~= nil then
            GLib.Warn("ui_select_value() called for option with key ["..self:get_key().."], but the val supplied ["..tostring(val).."] is not valid for the type. Replacing with ["..tostring(new).."].")
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
    local popup_list = find_uicomponent(popup_menu, "listview", "list_clip", "list_box")

    local new_selected_uic = nil
    -- local currently_selected_uic = nil

    local new_selected_node = nil

    GLib.Log("Trying to set the UI value of dropdown %s to %s", self:get_key(), val)

    for i = 0, popup_list:ChildCount() - 1 do
        local child = UIComponent(popup_list:Find(i))
        local table_node = child:GetContextObject("CcoScriptTableNode")

        if table_node then
            GLib.Log("Found CcoScriptTableNode for " .. child:Id())
            local key = table_node:Call("Key")
            GLib.Log("Table node key is " .. key)

            if key == val then
                new_selected_node = table_node
                new_selected_uic = child

                child:SetState("selected")
            end
        end
    end

    -- set the new option as "selected", so it's highlighted in the list; also lock it as the selected setting in the option_obj
    new_selected_uic:SetState("selected")
    -- self:set_selected_setting(val)

    -- set the state text of the dropdown box to be the state text of the row
    local t = new_selected_node:Call("ValueForKey('text')")
    local tt = new_selected_node:Call("ValueForKey('tooltip')")
    local current_display = find_uicomponent(dropdown_box_uic, "selected_context_display")

    current_display:SetContextObject(new_selected_node)
    current_display:SetStateText(t)
    dropdown_box_uic:SetTooltipText(tt, true)

    if dropdown_box_uic:CurrentState() == "selected" then
        dropdown_box_uic:SetState("active")
    end

    Super.ui_select_value(self, val)
end

--- Change the state of the mct_option in UI; ie., lock the option from being used.
function Dropdown:ui_change_state()
    local option_uic = self:get_uic_with_key("option")
    local text_uic = self:get_uic_with_key("text")

    local locked = self:is_locked()
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

    local box_template = "ui/mct/options/dropdown"

    --- TODO do this elsewhere?
    --- TODO build a CcoScriptObject for this dropdown, and truly all options
    --- 
    local dd = {
        mod_key = self:get_mod_key(),
        option_key = self:get_key(),
        values = {}
    }

    for i, value in ipairs(self._values) do
        dd.values[value.key] = {
            text = value.text,
            tooltip = value.tt,
            sort_order = i,
        }

        local text = common.get_localised_string(value.text)
        local tt = common.get_localised_string(value.tt)

        if text ~= "" then
            dd.values[value.key].text = text
        end

        if tt ~= "" then
            dd.values[value.key].tooltip = tt
        end
    end

    local context_key = self:get_mod_key().."_"..self:get_key().."_dropdown"
    common.set_context_value(context_key, dd)

    local new_uic = core:get_or_create_component("mct_dropdown_box", box_template, dummy_parent)
    new_uic:SetProperty("mct_option", self:get_key())
    new_uic:SetProperty("mct_mod", self:get_mod_key())

    new_uic:SetVisible(true)
    new_uic:Resize(dummy_parent:Width() * 0.4, new_uic:Height())
    
    new_uic:SetContextObject(cco("CcoScriptObject", context_key))

    self:set_uic_with_key("option", new_uic, true)

    -- TODO this is done to force a refresh of the dropdown menu; I don't like it and want it to immediately be removed.
    -- new_uic:SimulateLClick()
    -- find_uicomponent(new_uic, "popup_menu"):SetVisible(false)



    --- TODO grab selected value and click it UP


    -- self:refresh_dropdown_box()

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
---@return boolean? #Isn't valid if false
function Dropdown:add_dropdown_values(dropdown_table)
    --[[
    if not self:get_type() == "dropdown" then
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
        local is_default = dropdown_option.is_default or false

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
        -- self:refresh_dropdown_box()
        self:get_uic_with_key("option"):Layout()
    end
end

---- Specific listeners for the UI ----

--- TODO listen for ContextTriggerEvent for `mct_dropdown_item_selected|%MOD_KEY%|%OPTION_KEY%|%VALUE_KEY`
core:add_listener(
    "mct_dropdown_box_option_selected",
    "ContextTriggerEvent",
    function(context)
        return context.string:starts_with("mct_dropdown_item_selected|")
    end,
    function(context)

        --- TODO handle command stripping entirely through command_manager.
        ---@type string
        local command = context.string

        -- remove the header, leave just the args.
        local args = command:gsub("mct_dropdown_item_selected|", "")

        local mod_key = args:match("([^|]-)|")
        local option_key = args:match("|([^|]-)|")
        local setting_key = args:match("|([^|]-)$")

        local mod_obj = mct:get_mod_by_key(mod_key)
        if mod_obj then
            local option_obj = mod_obj:get_option_by_key(option_key)
            if option_obj then
                option_obj:set_selected_setting(setting_key)
            end
        end
    end,
    true
)

return Dropdown