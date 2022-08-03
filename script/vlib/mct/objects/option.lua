--- the abstract class for all individual option types (checkbox, dropdown, etc).
--- this holds all global information that's valuable to each option type, and is then extended into the individual versions.


---- MCT Option Object
---@class MCT.Option
---@field _template string

local mct = get_mct()
local Registry = mct.registry

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
    _tooltip_text = "No tooltip assigned.",


    ---@type table Used for Sliders / Dropdowns, internal values to choose betwixt.
    _values = {},

    -- default setting is the mct_mod default and the one to reset to;
    -- selected setting is the current UI state, defaults to default_setting if no finalized_setting;
    -- finalized setting is the saved setting in the file/etc;
    _default_setting = nil,
    _finalized_setting = nil,

    _is_locked = false,
    _lock_reason = "",

    _local_only = false,
    _mp_disabled = false,

    -- the UICs linked to this option (the option + the txt)
    _uics = {},

    -- UIC options for construction
    _uic_visible = true,
    _uic_locked = false,
    _uic_lock_reason = {},
    _uic_in_ui = true,

    -- border deets
    _border_visible = true,
    _border_image_path = "ui/skins/default/panel_back_border.png",

    _pos = {
        x = 0,
        y = 0
    },

    ---@type string
    _assigned_section = nil,

    ---@type boolean Whether this option has its settings stored globally or within independent campaigns.
    _is_global = false,
}

---@class MCT.Option : Class
---@field __new fun():MCT.Option
local mct_option = VLib.NewClass("MCT.Option", mct_option_defaults)

--- Overridden by subtypes!
function mct_option:new(...) end

function mct_option:init(mod_obj, option_key)
    logf("MCT.Option init on %s", option_key)
    self._mod = mod_obj
    self._key = option_key
    self._text = option_key

    -- assigned section, used for UI, defaults to the last created section unless one is specified
    self._assigned_section = mod_obj:get_last_section():get_key()

    -- add the option to the mct_section
    mod_obj:get_section_by_key(self._assigned_section):assign_option(self)
end


---- Read whether this mct_option is edited exclusively for the client, instead of passed between both PC's.
--- @treturn boolean local_only Whether this option is only edited on the local PC, instead of both.
function mct_option:get_local_only()
    return self._local_only
end

---- Set whether this mct_option is edited for just the local PC, or sent to both PC's.
--- For instance, this is useful for settings that don't edit the model, like enabling script logging.
---@param enabled boolean True for local-only, false for passed-in-MP-and-only-editable-by-the-host.
function mct_option:set_local_only(enabled)
    if is_nil(enabled) then
        enabled = true
    end

    if not is_boolean(enabled) then
        err("set_local_only() called for mct_mod ["..self:get_key().."], but the enabled argument passed is not a boolean or nil!")
        return false
    end

    self._local_only = enabled
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
--- @treturn boolean mp_disabled Whether this mct_option is available in multiplayer or completely disabled.
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

    if is_uicomponent(self:get_uic_with_key("option")) then
        self:ui_change_state()
    end
end

function mct_option:is_locked()
    return self._is_locked
end

function mct_option:get_lock_reason()
end

--- TODO make an option context-specific (ie. battle) so 
function mct_option:set_context_specific(context)

end

--- Set this Option as an array-type. That means the option will have a table-type saved setting, useful for options which can 
---@param max_fields number
---@param min_fields number
function mct_option:set_is_array(max_fields, min_fields)
    self._is_array = true

    self._array = {
        max = max_fields,
        min = min_fields,
    }
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
-- @treturn boolean read_only Whether this option is uneditable or not.
function mct_option:get_read_only()
    return self:is_locked()
end

---- Set whether this mct_option can be edited or not at the moment.
---@param b_read_only boolean True for non-editable, false for editable.
---@param reason string
function mct_option:set_read_only(b_read_only, reason)
    -- if is_nil(b_read_only) then
    --     b_read_only = true
    -- end

    -- if is_nil(reason) then
    --     reason = "mct_lock_reason_read_only"
    -- end

    -- if not is_boolean(b_read_only) then
    --     -- issue
    --     return false
    -- end

    -- if not is_string(reason) then return false end

    -- self._read_only = {
    --     b = b_read_only,
    --     reason = reason,
    -- }

    self:set_locked(b_read_only, reason)
end

---- Assigns the section_key that this option is a member of.
--- Calls @{mct_section:assign_option} internally.
---@param section_key string The key for the section this option is being added to.
function mct_option:set_assigned_section(section_key)
    local mod = self:get_mod()
    local section = mod:get_section_by_key(section_key)
    if not mct:is_mct_section(section) then
        log("set_assigned_section() called for option ["..self:get_key().."] in mod ["..mod:get_key().."] but no section with the key ["..section_key.."] was found!")
        return false
    end

    section:assign_option(self) -- this sets the option's self._assigned_section
end

---- Reads the assigned_section for this option.
--- @treturn string section_key The key of the section this option is assigned to.
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
        if is_uicomponent(uic) and key ~= "error_popup" then
            uic:SetVisible(self:get_uic_visibility())
        end
    end
end

---- Get the current visibility for this mct_option.
--- @treturn boolean visibility True for visible, false for invisible.
function mct_option:get_uic_visibility()
    return self._uic_visible
end

---- Getter for the image path for this mct_option's border.
--- @treturn string border_path The image path for the .png for the border.
function mct_option:get_border_image_path()
    return self._border_image_path
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
        border_uic:SetImagePath(border_path, 1)
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
--- @treturn boolean visibility True for visible, false for the opposite of that.
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
function mct_option:set_selected_setting(val)
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
    if self:get_uic_locked() then
        return
    end
    
    -- -- make sure nothing happens if the new val is the current setting
    -- if self:get_selected_setting() == val then
    --     return
    -- end
    
    --- Only valid if the panel is open!
    if not mct.ui:is_open() then
        return
    end
    
    Registry:set_changed_setting(self:get_mod_key(), self:get_key(), val)
    
    -- call ui_select_value if the UI exists
    if is_uicomponent(self:get_uic_with_key("option")) then
        self:ui_select_value(val, true)
    end
    
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
--- @treturn number x x-coord
--- @treturn number y y-coord
function mct_option:get_position()
    return self._pos.x, self._pos.y
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

--- Sets an automatic default for this mct_option, if a modder didn't.
--- Automatic default depends on the type of the mct_option; ie., booleans automatically default to false.
function mct_option:set_default()
    -- return self:get_wrapped_type():set_default()
end

function mct_option:ui_select_value(val, is_new_version)
    if not is_new_version then
        self:set_selected_setting(val)
    end

    mct.ui:set_actions_states()
end


-- function mct_option:ui_select_value(val, is_new_version)
--     local valid, new_value = self:check_validity(val)
--     if not valid then
--         if val ~= nil then
--             err("ui_select_value() called for option with key ["..self:get_key().."], but the val supplied ["..tostring(val).."] is not valid for the type. Replacing with ["..tostring(new_value).."].")
--             val = new_value
--         else
--             err("ui_select_value() called for option with key ["..self:get_key().."], but the val supplied ["..tostring(val).."] is not valid for the type!")
--             return false
--         end
--     end


--     local option_uic = self:get_uic_with_key("option")

--     if not is_uicomponent(option_uic) then
--         err("ui_select_value() called for option with key ["..self:get_key().."], in mct_mod ["..self:get_mod():get_key().."], but this option doesn't currently exist in the UI! Aborting change.")
--         return false
--     end

--     --- TODO, err?

-- end

---- Internal function to set the option UIC as disabled or enabled, for read-only/mp-disabled.
--- Use `mct_option:set_uic_locked()` for the external version of this; this just reads the uic_locked boolean and changes the UI.
--- @see mct_option:set_uic_locked
function mct_option:ui_change_state()
    -- return self:get_wrapped_type():ui_change_state()
end

--- Creates the UI component in the UI. Shouldn't be used externally!
---@param dummy_parent UIC The parent component for the new option.
function mct_option:ui_create_option(dummy_parent)
    -- return self:get_wrapped_type():ui_create_option(dummy_parent)
end

-- type-specifics

---- sliders ----

-- --- Slider-specific function. Calls @{mct_slider:slider_get_precise_value}.
-- function mct_option:slider_get_precise_value(...)
-- ---@diagnostic disable-next-line: redundant-parameter
-- -- return self:get_wrapped_type():slider_get_precise_value(...)
-- end

-- --- Slider-specific function. Calls @{mct_slider:slider_set_step_size}.
-- function mct_option:slider_set_step_size(...)
--     -- ---@diagnostic disable-next-line: redundant-parameter
--     -- return self:get_wrapped_type():slider_set_step_size(...)
-- end

-- --- Slider-specific function. Calls @{mct_slider:slider_set_precision}.
-- function mct_option:slider_set_precision(...)
--     -- ---@diagnostic disable-next-line: redundant-parameter
--     -- return self:get_wrapped_type():slider_set_precision(...)
-- end

-- --- Slider-specific function. Calls @{mct_slider:slider_set_min_max}.
-- function mct_option:slider_set_min_max(...)
--     -- ---@diagnostic disable-next-line: redundant-parameter
--     -- return self:get_wrapped_type():slider_set_min_max(...)
-- end

---- dropdowns ----

-- --- Dropdown-specific function. Calls @{mct_dropdown:add_dropdown_values}
-- function mct_option:add_dropdown_values(...)
--     -- ---@diagnostic disable-next-line: redundant-parameter
--     -- return self:get_wrapped_type():add_dropdown_values(...)
-- end

-- --- Dropdown-specific function. Calls @{mct_dropdown:add_dropdown_value}
-- function mct_option:add_dropdown_value(...)
--     -- ---@diagnostic disable-next-line: redundant-parameter
--     -- return self:get_wrapped_type():add_dropdown_value(...)
-- end

-- --- Dropdown-specific function. Calls @{mct_dropdown:refresh_dropdown_box}
-- function mct_option:refresh_dropdown_box()
--     -- return self:get_wrapped_type():refresh_dropdown_box()
-- end

---- text-input ----


---- Getter for the "finalized_setting" for this `mct_option`.
--- @treturn any finalized_setting Finalized setting for this `mct_option` - either the default value set via @{mct_option:set_default_value}, or the latest saved value if in a campaign, or the latest mct_settings.lua - value if in a new campaign or in frontend.
function mct_option:get_finalized_setting()
    return Registry:get_finalized_setting_for_option(self)
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

    Registry:save_setting(self, val)

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
end

---- Getter for the default setting for this mct_option.
--- @treturn any The modder-set default value.
function mct_option:get_default_value()
    -- if no default value was set, pick one automatically.
    local default_val = self._default_setting

    if is_nil(default_val) then
        self:set_default()
    end

    return self._default_setting
end

---- Getter for whether this UIC is currently locked.
--- @return boolean uic_locked Whether the UIC is set as locked.
function mct_option:get_uic_locked()
    return self._uic_locked
end

---- Set this option as disabled in the UI, so the user can't interact with it.
--- This will result in `mct_option:ui_change_state()` being called later on.
---@param should_lock boolean Lock this UI option, preventing it from being interacted with.
---@param lock_reason string? The text to supply to the tooltip, to show the player why this is locked. This argument is ignored if should_lock is false.
function mct_option:set_uic_locked(should_lock, lock_reason)
    self:set_locked(should_lock, lock_reason)
    -- if is_nil(should_lock) then
    --     should_lock = true
    -- end

    -- if not is_boolean(should_lock) then 
    --     err("set_uic_locked() called for mct_option with key ["..self:get_key().."], but the should_lock argument passed is not a boolean or nil!")
    --     return false 
    -- end

    -- -- only care about localisation if it's being locked!
    -- if should_lock then
    --     if is_nil(lock_reason) then
    --         lock_reason = "Locked."
    --     end

    --     if not is_string(lock_reason) then
    --         err("set_uic_locked() called for mct_option ["..self:get_key().."], but the lock_reason passed is not a string or nil! Returning false.")
    --         return false
    --     end

    --     self._uic_lock_reason = lock_reason
    -- else
    --     self._uic_lock_reason = ""
    -- end

    -- self._uic_locked = should_lock

    -- -- if the option already exists in UI, update its state
    -- if is_uicomponent(self:get_uic_with_key("option")) then
    --     self:ui_change_state()
    -- end
end

---- Getter for the current selected setting. This is the value set in @{mct_option:set_default_value} if nothing has been selected yet in the UI.
--- Used when finalizing settings.
--- @treturn any val The value set as the selected_setting for this mct_option.
function mct_option:get_selected_setting()
    return Registry:get_selected_setting_for_option(self)
end

---- Getter for the available values for this mct_option - true/false for checkboxes, different stuff for sliders/dropdowns/etc.
function mct_option:get_values()
    return self._values
end

---- Getter for this mct_option's type; slider, dropdown, checkbox
function mct_option:get_type()
    return self._type
end

---- Getter for this option's UIC template for quick reference.
function mct_option:get_uic_template()
    return self._template
end

---- Getter for this option's key.
--- @treturn string key mct_option's unique identifier
function mct_option:get_key()
    return self._key
end

---- Setter for this option's text, which displays next to the dropdown box/checkbox.
--- MCT will automatically read for text if there's a loc key with the format `mct_[mct_mod_key]_[mct_option_key]_text`.
---@param text string The text string for this option. You can either supply hard text - ie., "My Cool Option" - or a loc key - ie., "`ui_text_replacements_my_cool_option`".
---@param is_localised boolean?  True if a loc key was supplied for the text parameter.
function mct_option:set_text(text, is_localised)
    if not is_string(text) then
        err("set_text() called for option ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the text supplied is not a string! Returning false.")
        return false
    end

    if is_localised then text = "{{loc:" .. text .. "}}" end

    self._text = text
end

---- Setter for this option's tooltip, which displays when hovering over the option or the text.
--- MCT will automatically read for text if there's a loc key with the format `mct_[mct_mod_key]_[mct_option_key]_tooltip`.
---@param text string The tootlip string for this option. You can either supply hard text - ie., "My Cool Option's Tooltip" - or a loc key - ie., "`ui_text_replacements_my_cool_option_tt`".
---@param is_localised boolean? True if a loc key was supplied for the text parameter.
function mct_option:set_tooltip_text(text, is_localised)
    if not is_string(text) then
        err("set_tooltip_text() called for option ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the tooltip_text supplied is not a string! Returning false.")
        return false
    end

    if is_localised then text = "{{loc:" .. text .. "}}" end

    self._tooltip_text = text
end

---- Getter for this option's text. Will read the loc key, `mct_[mct_mod_key]_[mct_option_key]_text`, before seeing if any was supplied through @{mct_option:set_text}.
function mct_option:get_text()
    -- default to checking the loc files
    local text = common.get_localised_string("mct_"..self:get_mod():get_key().."_"..self:get_key().."_text")
    if text ~= "" then
        return text
    end

    -- nothing found, check for anything supplied by `set_text()`, or send the default "No text assigned"
    text = VLib.FormatText(self._text)

    if not is_string(text) or text == "" then
        text = "No text assigned"
    end
    
    return text
end

function mct_option:get_localised_text()
    return self:get_text()
end

---- Getter for this option's text. Will read the loc key, `mct_[mct_mod_key]_[mct_option_key]_tooltip`, before seeing if any was supplied through @{mct_option:set_tooltip_text}.
function mct_option:get_tooltip_text()
    local text = common.get_localised_string("mct_"..self:get_mod_key().."_"..self:get_key().."_tooltip")
    if text ~= "" then
        return text
    end

    -- nothing found, check for anything supplied by `set_tooltip()`, or send the default "No tooltip assigned"
    text = VLib.FormatText(self._tooltip_text)

    if not is_string(text) then
        text = ""
    end

    return text
end

return mct_option
