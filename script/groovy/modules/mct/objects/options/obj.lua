--- the abstract class for all individual option types (checkbox, dropdown, etc).
--- this holds all global information that's valuable to each option type, and is then extended into the individual versions.


--- TODO enable the "backend-only" type of options.

---- MCT Option Object
---@class MCT.Option
---@field _template string

local mct = get_mct()
local Registry = mct:get_registry()

local log,logf,err,errf = get_vlog("[mct]")

---@class MCT.Option
local mct_option_defaults = {
    ---@type MCT.Mod The owning mod object.
    _mod = nil,

    -- ---@type string The key of the owning mod object.
    -- _mod_key = nil,

    ---@type string The key of this option object.
    _key = "",

    ---@type string The type of this option - ie., checkbox, text input, etcv.
    _type = nil,

    ---@type string The displayed text for this option.
    _text = "No text assigned.",

    ---@type string The tooltip for this option.
    _tooltip_text = "",


    ---@type table Used for Sliders / Dropdowns, internal values to choose betwixt.
    _values = {},

    -- default setting is the mct_mod default and the one to reset to;
    -- selected setting is the current UI state, defaults to default_setting if no finalized_setting;
    -- finalized setting is the saved setting in the file/etc;
    _default_setting = nil,
    _finalized_setting = nil,

    ---@type any #If this setting is NOT global, then we need to track its "global" value separately from its finalized value.
    _global_value = nil,

    _is_locked = false,
    _lock_reason = "",

    -- --- TODO rework these.
    -- _local_only = false,
    -- _mp_disabled = false,

    -- the UICs linked to this option (the option + the txt)
    _uics = {},

    -- UIC options for construction
    _uic_visible = true,
    _uic_locked = false,
    _uic_lock_reason = {},
    _uic_in_ui = true,

    -- border deets
    _border_visible = false,
    _border_image_path = "ui/skins/default/panel_back_border.png",

    --- TODO rework/remove this
    _pos = {
        x = 0,
        y = 0
    },

    ---@type string
    _assigned_section = nil,

    ---@type boolean Whether this option has its settings stored globally or within independent campaigns.
    _is_global = false,

    _control_dock_point = 6, -- the dock point for the control
    _control_dock_offset = {0, 0} -- the dock position for the control
}

---@class MCT.Option : Class
---@field __new fun():MCT.Option
local mct_option = GLib.NewClass("MCT.Option", mct_option_defaults)

--- Overridden by subtypes!
---@return MCT.Option
function mct_option:new(...) end

---@param mod_obj MCT.Mod
---@param option_key string
function mct_option:init(mod_obj, option_key)
    logf("MCT.Option init on %s", option_key)
    assert(mct:verify_key(self, option_key))
    
    self._mod = mod_obj
    self._text = option_key

    -- assigned section, used for UI, defaults to the last created section unless one is specified
    self._assigned_section = mod_obj:get_last_section():get_key()

    -- add the option to the mct_section
    mod_obj:get_section_by_key(self._assigned_section):assign_option(self)
end

function mct_option:get_global_value()
    if self:is_global() then
        return self:get_finalized_setting()
    end

    if is_nil(self._global_value) then
        self._global_value = self:get_default_value()
    end

    return self._global_value
end

function mct_option:set_global_value(val)
    if self:is_global() then
        self:set_finalized_setting(val)
    end

    local is_valid, new_val = self:check_validity(val)

    if not is_valid then
        errf("set_global_value() called for mct_option [%s] in mct_mod [%s], but the value passed is not valid! Value passed: [%s], new value: [%s]", self:get_key(), self:get_mod():get_key(), tostring(val), tostring(new_val))
        val = new_val
    end

    self._global_value = val
end

---- Read whether this mct_option is edited exclusively for the client, instead of passed between both PC's.
--- --@return boolean local_only Whether this option is only edited on the local PC, instead of both.
function mct_option:get_local_only()
    -- return self._local_only
end

---- Set whether this mct_option is edited for just the local PC, or sent to both PC's.
--- For instance, this is useful for settings that don't edit the model, like enabling script logging.
---@param enabled boolean True for local-only, false for passed-in-MP-and-only-editable-by-the-host.
function mct_option:set_local_only(enabled)
    -- if is_nil(enabled) then
    --     enabled = true
    -- end

    -- if not is_boolean(enabled) then
    --     err("set_local_only() called for mct_mod ["..self:get_key().."], but the enabled argument passed is not a boolean or nil!")
    --     return false
    -- end

    -- self._local_only = enabled
end

--- Set whether this Option is globally editable or on a campaign-basis.
---@param b boolean
function mct_option:set_is_global(b)
    if is_nil(b) then b = true end
    if not is_boolean(b) then return false end

    self._is_global = b
end

--- Whether this Option is globally editable or on a campaign-basis.
---@return any
function mct_option:is_global() return self._is_global end

---- Read whether this mct_option is available in multiplayer.
--- @return boolean mp_disabled Whether this mct_option is available in multiplayer or completely disabled.
function mct_option:get_mp_disabled()
    return self._mp_disabled
end

--- Set whether this MCT Option is locked (ie. can't be edited). If the option is_global, this lock will be everywhere, otherwise it will be saved within the campaign.
---@param is_locked boolean? True for locked, false for unlocked. Defaults to true.
---@param lock_reason string? The localised text explaining why it's locked.
function mct_option:set_locked(is_locked, lock_reason)
    if not is_boolean(is_locked) then is_locked = true end
    if not is_string(lock_reason) and is_locked then lock_reason = "" end
    
    self._is_locked = is_locked

    if is_locked then self._lock_reason = lock_reason end

    self:ui_refresh()
end

function mct_option:is_locked()
    return self._is_locked
end

function mct_option:get_lock_reason()
    return self._lock_reason
end

--- TODO make an option context-specific (ie. battle) so 
function mct_option:set_context_specific(context)

end

---- Set whether this mct_option exists for MP campaigns.
--- If set to true, this option is invisible for MP and completely untracked by MCT.
---@param enabled boolean True for MP-disabled, false to MP-enabled
function mct_option:set_mp_disabled(enabled)
    if is_nil(enabled) then
        enabled = true
    end

    if not is_boolean(enabled) then
        err("set_mp_disabled() called for mct_mod ["..self:get_key().."], but the enabled argument passed is not a boolean or nil!")
        return false
    end

    self._mp_disabled = enabled
end

--- Read whether this mct_option can be edited or not at the moment.
-- @return boolean read_only Whether this option is uneditable or not.
function mct_option:get_read_only()
    return self:is_locked()
end

---- Set whether this mct_option can be edited or not at the moment.
---@param b_read_only boolean True for non-editable, false for editable.
---@param reason string
function mct_option:set_read_only(b_read_only, reason)
    self:set_locked(b_read_only, reason)
end

---- Assigns the section_key that this option is a member of.
--- Calls @{mct_section:assign_option} internally.
---@param section_key string The key for the section this option is being added to.
function mct_option:set_assigned_section(section_key)
    local mod = self:get_mod()
    local section = mod:get_section_by_key(section_key)
    if not section or not mct:is_mct_section(section) then
        log("set_assigned_section() called for option ["..self:get_key().."] in mod ["..mod:get_key().."] but no section with the key ["..section_key.."] was found!")
        return false
    end

    section:assign_option(self) -- this sets the option's self._assigned_section
end

---- Reads the assigned_section for this option.
---@return string section_key The key of the section this option is assigned to.
function mct_option:get_assigned_section()
    return self._assigned_section
end

---- Get the @{mct_mod} object housing this option.
--- @return MCT.Mod @{mct_mod}
function mct_option:get_mod()
    return self._mod
end

--- Grab the key of the owning mct_mod.
---@return string
function mct_option:get_mod_key()
    return self._mod:get_key()
end

--- 
function mct_option:set_origin()

end

---- Internal use only. Clears all the UIC objects attached to this boy.
function mct_option:clear_uics(b)
    --self._selected_setting = nil
    self._uics = {}

    if b then
        self._selected_setting = nil
    end
end

---- Internal use only. Set UICs through the uic_obj
--- k/v table of key=uic
function mct_option:set_uics(uic_obj)
    -- check if it's a table of UIC's
    if is_table(uic_obj) then
        for key,uic in pairs(uic_obj) do
            if is_uicomponent(uic) and is_string(key) then
                self._uics[key] = uic
            else
                if not is_uicomponent(uic) then
                    err("set_uics() called for mct_option ["..self:get_key().."], but the UIC provided is not a valid UIComponent!")
                end
                
                if not is_string(key) then
                    err("set_uics() called for mct_option ["..self:get_key().."], but the key provided is not a valid string!")
                end
            end
        end
        return
    end
end

---- Add a UIC to this mct_option with supplied key (doesn't have to be the UIC ID)
--- Easily grab the UIC with get_uic_with_key.
---@param key string The key to save this UIC as
---@param uic UIC The UIC to save locally.
---@param force_override boolean  Whether this function will override an existing UIC with this key or skip it.
function mct_option:set_uic_with_key(key, uic, force_override)
    if not is_string(key) then
        err("set_uic_with_key() called on mct_option ["..self:get_key().."], but the key provided is not a string!")
        return false
    end

    if not is_uicomponent(uic) then
        err("set_uic_with_key() called on mct_option ["..self:get_key().."], but the UIC provided is not a UIComponent!")
        return false
    end

    if self._uics[key] and not force_override then
        err("set_uic_with_key() called on mct_option ["..self:get_key().."], but there is already a UIC saved with key ["..key.."]. Call `set_uic_with_key(key, uic, true)` to force an override.")
        return false
    end

    self._uics[key] = uic

    -- if key == "option" then
        uic:SetProperty("mct_option", self:get_key())
        uic:SetProperty("mct_mod", self:get_mod_key())
    -- end
end

---comment
---@param key string
---@return UIComponent
function mct_option:get_uic_with_key(key)
    if self._uics == {} then
        err("get_uic_with_key() called for mct_option with key ["..self:get_key().."] but no uics are found! Returning false.")
        return false
    end

    if not is_string(key) then
        err("get_uic_with_key() called for mct_option ["..self:get_key().."], but the key supplied is not a string!")
        return false
    end

    local uic_table = self._uics

    local uic = uic_table[key]

    -- TODO swap these errors for warns and 
    if not uic then
        --err("get_uic_with_key() called for mct_option ["..self:get_key().."], but there was no UIC found with key ["..key.."].")
        return false
    end

    if not is_uicomponent(uic) then
        --err("get_uic_with_key() called for mct_option ["..self:get_key().."], but the UIC found with key ["..key.."] is not a valid UIComponent! Returning false.")
        return false
    end

    return uic
end

---- Internal use only. Get all UICs.
---@return table<string, UIComponent>
function mct_option:get_uics()
    local uic_table = self._uics
    local copy = {}

    -- first, loop through the table of UICs to make sure they're all still valid; if any are, add them to a copy table
    for key, uic in pairs(uic_table) do
        if is_uicomponent(uic) then
            copy[key] = uic
        end
    end

    self._uics = copy
    return self._uics
end

---- Set a UIC as visible or invisible, dynamically. If the UIC isn't created yet, it will get the applied setting when it is created.
---@param visibility boolean True for visible, false for invisible.
---@param keep_in_ui boolean? This boolean determines whether this mct_option will exist at all in the UI. Tick this to true to make the option invisible but still have a "gap" in the UI where it would be placed. Set this to false to make that spot be taken by the next otion. ONLY AFFECTS INITIAL UI CREATION.
function mct_option:set_uic_visibility(visibility, keep_in_ui)
    -- default to true if a param isn't provided
    if is_nil(visibility) then
        visibility = true
    end

    -- ditto
    if is_nil(keep_in_ui) then
        keep_in_ui = true
    end

    if not is_boolean(visibility) then
        log("set_uic_visibility() called for option ["..self._key.."], but the visibility argument provided is not a boolean. Returning false!")
        return false
    end    
    
    if not is_boolean(keep_in_ui) then
        log("set_uic_visibility() called for option ["..self._key.."], but the keep_in_ui argument provided is not a boolean. Returning false!")
        return false
    end

    self._uic_in_ui = keep_in_ui
    self._uic_visible = visibility

    -- if the UIC exists, set it to the new visibility!
    local uic_table = self:get_uics()

    for key, uic in pairs(uic_table) do
        if is_uicomponent(uic) then
            -- the visibility of these two are determined elsewhere.
            if key ~= "error_popup" and key ~= "border" then
                uic:SetVisible(self:get_uic_visibility())
            end
        end
    end
end

---- Get the current visibility for this mct_option.
--- @return boolean visibility True for visible, false for invisible.
function mct_option:get_uic_visibility()
    return self._uic_visible
end

---- Getter for the image path for this mct_option's border.
--- @return string border_path The image path for the .png for the border.
function mct_option:get_border_image_path()
    return self._border_image_path
end

function mct_option:save_data()

end

function mct_option:load_data(data_table)
    local mod_key, option_key = self:get_mod_key(), self:get_key()
    logf("Checking saved settings for %s.%s", self:get_mod_key(), self:get_key())

    --- TODO if we don't have anything saved in the Registry, we should set defaults and the like.
    if not is_table(data_table) then
        logf("No saved data found for %s.%s", self:get_mod_key(), self:get_key())
        self._finalized_setting = self:get_default_value()
        return false
    end

    -- TODO do I want this here?
    if not is_nil(data_table.global_value) then
        self._global_value = data_table.global_value
    end

    -- if this option is global, we only have to track a single finalized setting.
    if self:is_global() then
        local f_setting = data_table.setting
        
        if is_nil(data_table.setting) then
            f_setting = self:get_default_value()
        end

        logf("%s.%s is global - setting the setting to %s", mod_key, option_key, tostring(f_setting))
        -- assign finalized settings!
        self._finalized_setting = f_setting
        self._is_locked = (is_boolean(data_table.is_locked) and data_table.is_locked) or false
        self._lock_reason = (is_string(data_table.lock_reason) and data_table.lock_reason) or ""
    else
        -- if we're not in campaign, we need to set the finalized setting to the global value.
        if mct:context() ~= "campaign" then
            local g_setting = data_table.global_value

            if is_nil(data_table.global_value) then
                g_setting = self:get_default_value()
            end

            local f_setting = g_setting

            logf("%s.%s is not global - setting the value to %s and the global value to %s", mod_key, option_key, tostring(f_setting), tostring(g_setting))

            self._finalized_setting = f_setting
            self._global_value = g_setting
            self._is_locked = (is_boolean(data_table.is_locked) and data_table.is_locked) or false
            self._lock_reason = (is_string(data_table.lock_reason) and data_table.lock_reason) or ""

        else -- we're in campaign
            -- if the option is not global, we need to track its campaign-specific "finalized" setting AND its global setting.
            if not is_nil(cm) and cm:is_new_game() then
                -- assign finalized settings!
                local f_setting = data_table.setting
                local g_setting = data_table.global_value

                if is_nil(data_table.setting) then
                    f_setting = self:get_default_value()
                end

                if is_nil(data_table.global_value) then
                    g_setting = self:get_default_value()
                end

                self._finalized_setting = f_setting
                self._global_value = g_setting
                self._is_locked = (is_boolean(data_table.is_locked) and data_table.is_locked) or false
                self._lock_reason = (is_string(data_table.lock_reason) and data_table.lock_reason) or ""
            end
        end
    end
end

---- Setter for the image path. Provide the path from the base structure - ie., "ui/skins/default/panel_back_border.png" is the default image. Make sure to include the directory path and the .png!
---@param border_path string The image path for the border.
function mct_option:set_border_image_path(border_path)
    if not is_string(border_path) then
        -- errmsg
        return false
    end

    -- TODO test if it's a valid path?

    self._border_image_path = border_path
    
    local border_uic = self:get_uic_with_key("border")
    if is_uicomponent(border_uic) then
        ---@diagnostic disable-next-line
        border_uic:SetImagePath(border_path)
    end
end

---- Setter for the visibility for this mct_option's border. Set this to false if you want to not have a border img around it!
---@param is_visible boolean True to set it visible, opposite for opposite.
function mct_option:set_border_visibility(is_visible)
    if is_nil(is_visible) then
        is_visible = true
    end

    if not is_boolean(is_visible) then
        -- errmsg
        return false
    end

    self._border_visible = is_visible

    local border_uic = self:get_uic_with_key("border")
    if is_uicomponent(border_uic) then
        ---@diagnostic disable-next-line
        border_uic:SetVisible(self._border_visible)
    end
end

---- Get the current visibility for this mct_option's border. Always true unless changed with @{mct_option:set_border_visibility}.
--- @return boolean visibility True for visible, false for the opposite of that.
function mct_option:get_border_visibility()
    return self._border_visible
end

---- Create a callback triggered whenever this option's setting changes within the MCT UI.
--- You can alternatively do this through core:add_listener(), using the "MctOptionSelectedSettingSet" event. The reason this callback is here, is for backwards compatibility.
--- The function will automatically be passed a context object (methods listed below) so you can read state of everything and go from there.
--- ex:
--- when the "enable" button is checked on or off, all other options are set visible or invisible
--- enable:add_option_set_callback(
---    function(context) 
---        local option = context:option()
---        local mct_mod = option:get_mod()
---
---        local val = context:setting()
---        local options = options_list
---
---        for i = 1, #options do
---            local i_option_key = options[i]
---            local i_option = mct_mod:get_option_by_key(i_option_key)
---            i_option:set_uic_visibility(val)
---        end
---    end
---)
---@param callback function The callback triggered whenever this option is changed. Callback will be passed one argument - the `context` object for the listener. `context:mct()`, `context:option()`, `context:setting()`, and `context:is_creation()` (for if this was triggered on the UI being created) are the valid methods on context.
---@param is_context boolean Set this to true if you want to treat this function with the new method of passing a context. If this is false or nil, it will pass the mct_option like before. For backwards compatibility - I'll probably take this out eventually.
function mct_option:add_option_set_callback(callback, is_context)
    if not is_function(callback) then
        err("Trying `add_option_set_callback()` on option ["..self._key.."], but the supplied callback is not a function. Returning false.")
        return false
    end

    core:add_listener(
        "MctOption"..self:get_key().."Set",
        "MctOptionSelectedSettingSet",
        function(context)
            return context:option():get_key() == self:get_key()
        end,
        function(context)
            if is_context == true then
                callback(context)
            else
                callback(self)
            end
        end,
        true
    )
end

--- Triggered via the UI object. Change the mct_option's selected value, and trigger the script event "MctOptionSelectedSettingSet". Can be listened through a listener, or by using @{mct_option:add_option_set_callback}.
---@param val any Set the selected setting as the passed value, tested with @{mct_option:is_val_valid_for_type}
function mct_option:set_selected_setting(val, is_from_popup)
    local valid, new_value = self:is_val_valid_for_type(val)
    if not valid then
        if new_value ~= nil then
            log("set_selected_setting() called for option with key ["..self:get_key().."], but the val provided ["..tostring(val).."] is not valid for the type. Replacing with ["..tostring(new_value).."].")
            val = new_value
        else
            err("set_selected_setting() called for option with key ["..self:get_key().."], but the val supplied ["..tostring(val).."] is not valid for the type!")
            return false
        end
    end

    -- check if the UI is currently locked for this option; if it is, don't change the selected setting
    if self:is_locked() then
        self:ui_refresh()
        return
    end
    
    -- -- make sure nothing happens if the new val is the current setting
    -- if self:get_selected_setting() == val then
    --     return
    -- end
    
    --- Only valid if the panel is open!
    if not mct:get_ui():is_open() then
        return
    end

    logf("Changing option %s of type %q to val %s", self:get_key(), self:get_type(), tostring(val))

    --- If we have a confirmation popup, abort the operation and go through that. 
    if not is_from_popup and self:test_confirmation_popup(val, self:get_selected_setting()) then
        return
    end
    
    Registry:set_changed_setting(self, val)
    
    self:ui_refresh()
    
    core:trigger_custom_event("MctOptionSelectedSettingSet", {mct = mct, option = self, setting = val} )

    -- -- save the val as the currently selected setting, used for UI and finalization
    -- self._selected_setting = val

    -- if not is_creation then
    --     mct.settings:set_changed_setting(self:get_mod():get_key(), self:get_key(), val)
    -- end

    --[[if not event_free then
        -- run the callback, passing the mct_option along as an arg
        self:process_callback()
    end]]
end

---- Manually set the x/y position for this option, within its section.
--- @warning Use with caution, this needs an overhaul in the future!
---@param x number x-coord
---@param y number y-coord
function mct_option:override_position(x,y)
    if not is_number(x) or not is_number(y) then
        err("override_position() called for option ["..self:get_key().."] in mct_mod ["..self:get_mod_key().."], but the x/y coordinates supplied are not numbers! Returning false")
        return false
    end

    -- set internal pos
    self._pos = {x=x,y=y}

    -- set coords defined in the mod obj
    local mod = self:get_mod()
    local index = tostring(x)..","..tostring(y)
    mod._coords[index] = self._key
end

--- Get the x/y coordinates of the mct_option
--- Returns two vals, comma delimited (ie. local x,y = option:get_position())
--- @return number x x-coord
--- @return number y y-coord
function mct_option:get_position()
    return self._pos.x, self._pos.y
end

function mct_option:is_dropdown()
    return self:get_type() == "MCT.Option.Dropdown"
end

function mct_option:is_checkbox()
    return self:get_type() == "MCT.Option.Checkbox"
end

function mct_option:is_slider()
    return self:get_type() == "MCT.Option.Slider"
end

function mct_option:is_textinput()
    return self:get_type() == "MCT.Option.TextInput"
end

function mct_option:is_radiobutton()
    return self:get_type() == "MCT.Option.RadioButton"
end

--- Internal checker to see if the values passed through mct_option methods are valid.
--- This remains because I renamed the function to "check_validity" but didn't want to ruin backwards compatibility.
---@param val any Value being tested for type.
---@return any valid Returns true if valid; returns a valid default value if the one passed isn't valid.
function mct_option:is_val_valid_for_type(val)
    return self:check_validity(val)
end

--- TODO abstract
--- Internal checker to see if the values passed through mct_option methods are valid.
---@param val any Value being tested for type.
---@return any valid Returns true if valid; returns a valid default value if the one passed isn't valid.
function mct_option:check_validity(val)
    --- TODO abstract this method
end

function mct_option:ui_select_value(val)
    -- mct:get_ui():set_actions_states()
end

--- TODO hook up, cache, campaign-only, etc.
--- Require the game to be reloaded on changing this setting.
---@param callback any
function mct_option:force_reload_on_change(callback)

end

--- Enable a Confirmation Popup for this MCT.Option. When an option is edited in the UI with a confirmation popup, the panel will trigger a popup saying the supplied text and an ok/cancel set of buttons.
---@param confirmation_callback fun(new_val:any):boolean,string #An optional callback - if the boolean returned is "true", then the popup will trigger with the supplied text.
function mct_option:add_confirmation_popup(confirmation_callback)
    if not is_function(confirmation_callback) then
        confirmation_callback = function() return true, "Are you sure you wish to edit this option?" end
    end

    self._confirmation_popup_callback = confirmation_callback
end

function mct_option:test_confirmation_popup(new_val, old_val)
    if not self._confirmation_popup_callback then
        return false
    end

    local trigger,trigger_text = self._confirmation_popup_callback(new_val)

    if trigger == true then
        GLib.TriggerPopup(
            "confirmation_popup", 
            trigger_text, 
            true, 
            function() --- "ok" button
                -- keep the new selected setting, so do nothing I think?
                logf("Pressed OK - keeping the new setting!")
                self:set_selected_setting(new_val, true)
            end,
            function() --- "cancel" button
                -- return to the previously selected setting
                logf("Pressed Cancel - returning to the old setting!")
                self:set_selected_setting(old_val, true)
            end,
            nil,
            mct:get_ui().panel
        )
        return true
    end
end

---- Internal function to set the option UIC as disabled or enabled, for read-only/mp-disabled.
--- Use `mct_option:set_uic_locked()` for the external version of this; this just reads the uic_locked boolean and changes the UI.
--- @see mct_option:set_uic_locked
function mct_option:ui_change_state()
    -- return self:get_wrapped_type():ui_change_state()
end

--- Creates the UI component in the UI. Shouldn't be used externally!
---@param dummy_parent UIC The parent component for the new option.
---@return UIC #
function mct_option:ui_create_option(dummy_parent)
    return dummy_parent
end

--- TODO add in the extra goodies ie. "revert to defaults" button or "info" button
--- Creates the Option in the UI. Pass along the parent UIC and the preferred w/h of the option row.
---@param parent any
---@param w any
---@param h any
function mct_option:ui_create_option_base(parent, w, h)
    local dummy_option = core:get_or_create_component(self:get_key(), "ui/campaign ui/script_dummy", parent)

    dummy_option:SetCanResizeHeight(true) dummy_option:SetCanResizeWidth(true)
    dummy_option:Resize(w, h)
    dummy_option:SetCanResizeHeight(false) dummy_option:SetCanResizeWidth(false)

    dummy_option:SetVisible(true)
    
    -- set to dock center
    dummy_option:SetDockingPoint(5)

    -- give priority over column
    dummy_option:PropagatePriority(parent:Priority() +1)

    dummy_option:SetProperty("mct_option", self:get_key())
    dummy_option:SetProperty("mct_mod", self:get_mod_key())

    --- Create the border if necessary
    local dummy_border = core:get_or_create_component("border", "ui/groovy/image", dummy_option)
    dummy_border:Resize(w, h)

    dummy_border:SetDockingPoint(5)

    local border_path = self:get_border_image_path()
    local border_visible = self:get_border_visibility()

    -- if is_string(border_path) and border_path ~= "" then
    --     dummy_border:SetImagePath(border_path)
    -- else -- some error; default to default
    --     dummy_border:SetImagePath("ui/skins/default/panel_back_border.png")
    -- end
    dummy_border:SetImagePath("ui/skins/default/panel_back_border.png")

    --- TODO enable when it looks good
    dummy_border:SetVisible(false)

    self:set_uic_with_key("border", dummy_border, true)

    -- make some text to display deets about the option
    local option_text = core:get_or_create_component("text", "ui/groovy/text/fe_default", dummy_option)
    option_text:SetVisible(true)
    option_text:SetDockingPoint(4)
    option_text:SetDockOffset(15, 0)

    -- set the tooltip on the "dummy", and remove anything from the option text
    dummy_option:SetInteractive(true)
    option_text:SetInteractive(false)

    -- create the interactive option
    local new_option = self:ui_create_option(dummy_option)

    self:set_uic_with_key("text", option_text, true)

    local n_w = new_option:Width()
    local t_w = dummy_option:Width()
    local oh = dummy_option:Height() * 0.95

    if self._control_dock_point == 6 then
        -- standard

        -- resize the text so it takes up the space of the dummy column that is not used by the option
        local ow = t_w - n_w - 35 -- -25 is for some spacing! -15 for the offset, -10 for spacing between the option to the right
        
        option_text:Resize(ow, oh)
        option_text:SetTextVAlign("centre")
        option_text:SetTextHAlign("left")
        option_text:SetTextXOffset(5, 0)

        option_text:ResizeTextResizingComponentToInitialSize(ow, oh)

        option_text:SetStateText(self:get_text())
    elseif self._control_dock_point == 8 then
        -- radio buttons, for now.

        local ow, oh = t_w * 0.4, oh/2
        option_text:Resize(ow, oh)
        option_text:SetTextVAlign("centre")
        option_text:SetTextHAlign("left")
        option_text:SetTextXOffset(5, 0)

        option_text:ResizeTextResizingComponentToInitialSize(ow, oh)
        option_text:SetStateText(self:get_text())

        option_text:SetDockingPoint(1)
        option_text:SetDockOffset(15, 0)
    end

    new_option:SetDockingPoint(self._control_dock_point)
    new_option:SetDockOffset(self._control_dock_offset[1], self._control_dock_offset[2])

    --- TODO absolutely don't handle this here
    -- read if the option is read-only in campaign (and that we're in campaign)
    if __game_mode == __lib_type_campaign then

        -- if game is MP, and the local faction isn't the host, lock any non-local settings
        if cm:is_multiplayer() and cm:get_local_faction_name(true) ~= cm:get_saved_value("mct_host") then
            log("local faction: "..cm:get_local_faction_name(true))
            log("host faction: ".. tostring(cm:get_saved_value("mct_host")))
            -- if the option isn't local only, disable it
            log("mp and client")
            if not self:is_global() then
                log("option ["..self:get_key().."] is not local only, locking!")
                self:set_locked(true, "mct_lock_reason_mp_client")
            end
        end
    end

    -- if self:get_tooltip_text() ~= "" then
    --     dummy_option:SetTooltipText(self:get_tooltip_text(), true)
    -- end

    --- a horizontal list engine to hold icons
    local icon_holder = core:get_or_create_component("icons_holder", "ui/groovy/layouts/hlist", option_text)
    icon_holder:SetDockingPoint(7)
    icon_holder:SetDockOffset(15, 0)

    local function create_icon_button(key, image, tt, uses_click)
        local template = "ui/groovy/buttons/icon_button"
        if not uses_click then
            template = template .. "_no_click"
        end
        local icon_button = core:get_or_create_component(key, template, icon_holder)

        icon_button:SetProperty("mct_option", self:get_key())
        icon_button:SetProperty("mct_mod", self:get_mod_key())

        icon_button:SetImagePath(image, 0)
        icon_button:SetTooltipText(tt, true)

        return icon_button
    end

    --- if this is a global option, show the global icon
    if self:get_type() ~= "MCT.Option.Action" and self:get_type() ~= "MCT.Option.Dummy" then
        if self:is_global() then
            self:set_uic_with_key(
                "button_global",
                create_icon_button(
                    "button_global", 
                    "ui/skins/default/icon_registry.png",
                    "Global Option||This option is global, meaning its value is shared everywhere - between all campaigns, saves, etc. Changing it once changes it everywhere."
                ),
                true
            )
        else
            local this_tt = "Campaign-Specific Option||This option is campaign-specific."
            if mct:context() == "campaign" then
                this_tt = this_tt .. " Changing this option will only change it for this ongoing campaign."
            else
                this_tt = this_tt .. " Changing this opption will only change it for the next campaign you start, and won't apply to any ongoing campaigns."
            end
            
            self:set_uic_with_key(
                "button_local",
                create_icon_button(
                    "button_local", 
                    "ui/skins/default/icon_floppy_disk.png",
                    this_tt
                ),
                true
            )
        end

    end
    
    --- TODO if we have an info button to show, show it!
    local tt = self:get_tooltip_text()
    local has_info_popup = false

    if is_string(tt) and tt ~= "" then
        -- If we need a full info popup, then set the micro tt on the tt button
        if has_info_popup then

        else -- Otherwise, we just need a tooltip icon
            -- Create the tooltip icon
            self:set_uic_with_key(
                "button_tooltip",
                create_icon_button(
                    "button_tooltip", 
                    "ui/skins/default/icon_question_mark.png",
                    tt
                ),
                true
            )
        end
    end

    --- if we have a default value set, create the revert-to-defaults button!
    if not is_nil(self:get_default_value(true)) then
        -- get the localised text associated with the default value, if it's a dropdown or radio button
        local default_value = self:get_default_value(true)
        local default_value_text = tostring(default_value)

        if self:is_dropdown() then
            ---@cast self MCT.Option.Dropdown
            local value = self:get_option(default_value)
            default_value_text = value.text
        elseif self:is_radiobutton() then
            ---@cast self MCT.Option.RadioButton
            local option = self:get_option(default_value)
            default_value_text = option.text
        end

        local test = common.get_localised_string(default_value_text)
        if test ~= "" then
            default_value_text = test
        end

        self:set_uic_with_key(
            "revert_to_defaults", 
            create_icon_button(
                "mct_revert_to_defaults", 
                "ui/skins/default/icon_reset.png", 
                "Revert this option to its default value.||Default value: " .. default_value_text,
                true
            ),
            true
        )
    end

    -- create the lock icon, and set it if we're currently locked
    self:set_uic_with_key(
        "lock_icon",
        create_icon_button(
            "mct_lock_icon",
            "ui/skins/default/icon_padlock.png",
            "This Control is locked.||[[col:red]]" .. self:get_lock_reason() .. "[[/col]]",
            false
        ),
        true
    )

    
    if self._control_dock_point == 8 then
        icon_holder:SetDockingPoint(1)
        icon_holder:SetDockOffset(option_text:Width() + 10, option_text:Height() / 2 - icon_holder:Height() / 2) -- will prolly look bad for now.
    end

    self:ui_refresh()
end

--- set the state, value, visibility, and actions (ie. revert to defaults)
function mct_option:ui_refresh()
    if not self:get_uic_with_key("option") then return end
    local setting = self:get_selected_setting()
    
    self:ui_select_value(setting)
    self:ui_change_state()
    self:set_uic_visibility(self:get_uic_visibility())

    -- show lock icon and tooltip if we're locked
    local lock = self:get_uic_with_key("lock_icon")
    if lock then
        lock:SetVisible(self:is_locked())
    end

    local revert = self:get_uic_with_key("revert_to_defaults")
    if revert then
        --- only set visible if the selected setting is different than default AND we're not locked
        local vis =  false
        if not self:is_locked() then
            if setting ~= self:get_default_value(true) then
                vis = true
            end
        end

        revert:SetVisible(vis)
    end
end

---- Getter for the "finalized_setting" for this `mct_option`.
--- @return any finalized_setting Finalized setting for this `mct_option` - either the default value set via @{mct_option:set_default_value}, or the latest saved value if in a campaign, or the latest mct_settings.lua - value if in a new campaign or in frontend.
function mct_option:get_finalized_setting(finalized_only)
    if finalized_only then
        return self._finalized_setting
    end
    
    if is_nil(self._finalized_setting) then
        self._finalized_setting = self:get_default_value()
    end
    
    return self._finalized_setting
end


--- Get the finalized setting for this mct_option, but in a format that can be saved to the mct_settings.lua file. This is used internally by MCT, and should not be used by modders.
--- @return string 
function mct_option:get_value_for_save(use_default)
    local t = self:get_type()
    local f = function(txt, ...) return string.format(txt, ...) end

    -- local ret = ""
    local val = self:get_finalized_setting()
    if use_default then val = self:get_default_value() end

    return val

    -- logf("Getting %s value for option [%s] of type [%s] and value [%s]", use_default == true and "default" or "finalized", self:get_key(), t, tostring(val))

    -- -- if we're a dropdown or text_input, we need to wrap the value in quotes
    -- if t == "MCT.Option.Dropdown" or t == "MCT.Option.TextInput" then
    --     ---@cast self MCT.Option.Dropdown | MCT.Option.TextInput
    --     ret = f("%q", val)
    -- -- if we're a checkbox, we need to set the value to "true" or "false"
    -- elseif t == "MCT.Option.Checkbox" then
    --     ---@cast self MCT.Option.Checkbox
    --     ret = tostring(val)
    -- -- if we're a slider, we need to use %f or %d and set the precision based on the slider's precision
    -- elseif t == "MCT.Option.Slider" then
    --     ---@cast self MCT.Option.Slider
    --     ret = self:slider_get_precise_value(val, true)
    -- end

    -- logf("Returned value is [%s]", ret)

    -- return ret
end


---- Internal use only. Sets the finalized setting and triggers the event "MctOptionSettingFinalized".
---@param val any Set the finalized setting as the passed value, tested with @{mct_option:is_val_valid_for_type}
---@param is_first_load boolean? This is set to "true" for the first-load version of this function, when the mct_settings.lua file is loaded.
function mct_option:set_finalized_setting(val, is_first_load)
    local valid, new_value = self:is_val_valid_for_type(val)
    if not valid then
        if new_value ~= nil then
            log("set_finalized_setting() called for option with key ["..self:get_key().."], but the val provided ["..tostring(val).."] is not valid for the type. Replacing with ["..tostring(new_value).."].")
            val = new_value
        else
            err("set_finalized_setting() called for option with key ["..self:get_key().."], but the val supplied ["..tostring(val).."] is not valid for the type!")
            return false
        end
    end

    self._finalized_setting = val

    -- trigger an event to listen for externally (skip if it's first load)
    if not is_first_load then
        core:trigger_custom_event("MctOptionSettingFinalized", {mct = mct, mod = self:get_mod(), option = self, setting = val})
    end
end

--- Set the default setting when the mct_mod is first created and loaded. Also used for the "Revert to Defaults" option.
---@param val any Set the default setting as the passed value, tested with @{mct_option:is_val_valid_for_type}
function mct_option:set_default_value(val)
    if self:is_val_valid_for_type(val) then
        self._default_setting = val
    end

    return self
end

---- Getter for the default setting for this mct_option.
---@param only_set boolean? Set to true if you only want to get a modder-set :set_default_value(); if set to false or nil, you'll get the fallback values. 
---@return any The modder-set default value.
function mct_option:get_default_value(only_set)
    if only_set then
        return self._default_setting
    end

    if not is_nil(self._default_setting) then return self._default_setting end
    return self:get_fallback_value()
end

function mct_option:get_fallback_value()
    -- return self:get_default_value() or self:get_fallback_value()
end

---- Getter for the current selected setting. This is the value set in @{mct_option:set_default_value} if nothing has been selected yet in the UI.
--- Used when finalizing settings.
--- @return any val The value set as the selected_setting for this mct_option.
function mct_option:get_selected_setting()
    return Registry:get_selected_setting_for_option(self)
end

---- Getter for the available values for this mct_option - true/false for checkboxes, different stuff for sliders/dropdowns/etc.
function mct_option:get_values()
    return self._values
end

---- Getter for this mct_option's type; slider, dropdown, checkbox
function mct_option:get_type()
    return self.className
end

---- Getter for this option's UIC template for quick reference.
function mct_option:get_uic_template()
    return self._template
end

---- Getter for this option's key.
--- @return string key mct_option's unique identifier
function mct_option:get_key()
    return self._key
end

function mct_option:revert_to_default()
    self:set_selected_setting(self:get_default_value(true))
end

---- Setter for this option's text, which displays next to the dropdown box/checkbox.
--- MCT will automatically read for text if there's a loc key with the format `mct_[mct_mod_key]_[mct_option_key]_text`.
---@param text string The text string for this option. You can either supply hard text - ie., "My Cool Option" - or a loc key - ie., "`ui_text_replacements_my_cool_option`".
function mct_option:set_text(text)
    if not is_string(text) then
        err("set_text() called for option ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the text supplied is not a string! Returning false.")
        return false
    end

    self._text = text
end

---- Setter for this option's tooltip, which displays when hovering over the option or the text.
--- MCT will automatically read for text if there's a loc key with the format `mct_[mct_mod_key]_[mct_option_key]_tooltip`.
---@param text string The tootlip string for this option. You can either supply hard text - ie., "My Cool Option's Tooltip" - or a loc key - ie., "`ui_text_replacements_my_cool_option_tt`".
function mct_option:set_tooltip_text(text)
    if not is_string(text) then
        err("set_tooltip_text() called for option ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the tooltip_text supplied is not a string! Returning false.")
        return false
    end

    self._tooltip_text = text
end

---- Getter for this option's text. Will read the loc key, `mct_[mct_mod_key]_[mct_option_key]_text`, before seeing if any was supplied through @{mct_option:set_text}.
function mct_option:get_text()
    return GLib.HandleLocalisedText(self._text, "No text assigned", "mct_"..self:get_mod():get_key().."_"..self:get_key().."_text")
end

function mct_option:get_localised_text()
    return self:get_text()
end

---- Getter for this option's text. Will read the loc key, `mct_[mct_mod_key]_[mct_option_key]_tooltip`, before seeing if any was supplied through @{mct_option:set_tooltip_text}.
function mct_option:get_tooltip_text()
    return GLib.HandleLocalisedText(self._tooltip_text, "", "mct_"..self:get_mod_key().."_"..self:get_key().."_tooltip")
end

return mct_option
