---- Settings Object. INTERNAL USE ONLY.
--- @class MCT.Settings

local mct = get_mct()
local log,logf,err,errf = get_vlog "[mct_settings]"

--- TODO localise "Default Profile"
---@class MCT.Profile
local Profile = {
    ---@type string Localised name for this profile.
    __name = "",

    ---@type string Localised description for this profile.
    __description = "",

    ---@type table<string, table<string, any>> Table of settings for this profile; indexed by mod key, which is then a table index by option keys linked to values, ie. __mods[mod_key][option_key] = true
    __mods = {},
}

local __Profile = {
    __index = Profile,
}

function Profile:instantiate(o)
    setmetatable(o or {}, __Profile)

    return o
end

---@class MCT.Settings
local settings_defaults = {
    ---@type string Path to the profile save file. ANTIQUATED.
    profiles_file = "mct_profiles.lua",

    ---@type string Path to the settings save file. ANTIQUATED.
    settings_file = "mct_settings.lua",

    ---@type string Path to the default profile import.
    __import_profiles_file = "mct_profiles_import",

    ---@type string Path to the new save file for MCT.
    __new_settings_file = "mct_save.lua",

    ---@alias changed_settings {old_value:any,new_value:any}

    -- a better way to read if any settings have been changed
    -- table of mod keys (only added when a setting is changed)
    -- within each mod key table, option keys (only added when that specific option changed)
    -- within each option key table, two field - old_value (for finalized-setting) and new_value (for selected-setting) (option key table removed if new_value is set to old_value)
    ---@type table<string, table<string, changed_settings>> Changed-in-UI settings
    __changed_settings = {},

    ---@type table Settings that have not yet been saved by MCT, new ones added by a mod since last load.
    __new_settings = {},
    
    --- TODO don't hold it in memory, keep it in a file on disk and query when necessary?
    --- this is a table of mod keys to tables of options keys to their options.
    --- cached on reading mct_settings.lua. When reading *extant* mct_mods, the cache is cleared for that mod key.
    --- This lets a user/modder disable a mod, finalize settings, and load up that old mod again without losing settings.
    ---@type table<string, table<string, any>>
    __cached_settings = {},
    
    __profiles_mt = {
        __index = function(self, k)
            return rawget(self, k)
        end,
        __newindex = function(self, k, v)
            if k:match("^__") then
                -- you can't make a profile that starts with "__"
                return
            end

            return rawset(self, k, v)
        end,
    },

    ---@type table<string, MCT.Profile>
    __profiles = {

    },

    ---@type string Key of the currently selected profile.
    __selected_profile = "",
    ---@type boolean If any settings were changed during this "session", ie. one panel open/close
    __settings_changed = false,
}

---@class MCT.Settings
local Settings = new_class("MCT.Settings", settings_defaults)

function Profile:get_settings_for_mod(mod_key)

end

function Profile:query_mod(mod_key)
    return self.__mods[mod_key]
end

---comment
---@param mod_key string Mod in question.
---@param option_key string Option in question.
---@return any Val The value of the option's saved value (or nil, if there is no option)
function Profile:query_mod_option(mod_key, option_key)
    logf("Querying %s & %s from %s", tostring(mod_key), tostring(option_key), self.__name)
    return self.__mods[mod_key] and self.__mods[mod_key][option_key]
end

function Profile:new_mod(mod_key)
    if not self.__mods[mod_key] then
        self.__mods[mod_key] = {}
    end
end

function Profile:new_option(mod_key, option_key, value)
    if not self:query_mod(mod_key) then
        self:new_mod(mod_key)
    end

    if not self:query_mod_option(mod_key, option_key) then
        self.__mods[mod_key][option_key] = value
    end 
end

function Profile:save_setting(mod_key, option_key, value)
    if not self.__mods[mod_key] then
        self.__mods[mod_key] = {}
    end

    self.__mods[mod_key][option_key] = value
end

--- Save all of the options for specified mod.
---@param mod_obj MCT.Mod
function Profile:save_mod(mod_obj)
    logf('save mod called')
    local ok, errmsg = pcall(function()
    local mod_key = mod_obj:get_key()

    if not self.__mods[mod_key] then
        logf("%s.%s = {}", self.__name, mod_key)
        self.__mods[mod_key] = {}
    end

    local t = self.__mods[mod_key]

    for option_key, option_obj in pairs(mod_obj:get_options()) do
        logf("Saving %s.%s.%s = %s", self.__name, mod_key, option_key, tostring(option_obj:get_finalized_setting()))
        t[option_key] = option_obj:get_finalized_setting()
    end 
end) if not ok then errf(errmsg) end
end

--- Save every option from every mod into this profile with a default (or cached) setting
function Profile:save_all_mods()
    if not self.__mods then self.__mods = {} end
    
    --- TODO don't do this here or at all tbh
    --- TODO make sure EVERY option from EVERY mod is accounted for
    for mod_key,mod in pairs(mct:get_mods()) do
        logf("checking mod %s", mod_key)
        if not self.__mods[mod_key] then self.__mods[mod_key] = {} end
        for option_key,option in pairs(mod:get_options()) do
            logf("checking option %s", option_key)
            if not self.__mods[mod_key][option_key] then
                
                local value = Settings:get_cached_settings(mod_key, option_key) or option:get_default_value()
                logf("saving [%s].__mods[%s][%s] = %s", self.__name, mod_key, option_key, tostring(value))
                self.__mods[mod_key][option_key] = value
            end
        end
    end
end

function Settings:create_profile_with_key(key, o)
    if not is_string(key) then
        -- errmsg
        return
    end

    if self:get_profile(key) then
        -- errmsg
        return
    end

    local profile = Profile:instantiate(o)
    profile:save_all_mods()
    self.__profiles[key] = profile


    return profile
end

function Settings:get_main_profile()
    return self:get_profile("Default Profile")
end

--- Check if this option is already saved in main with this value
---@return boolean
function Settings:query_main(mod_key, option_key, value)
    local main = self:get_main_profile()
    if is_nil(mod_key) then return false end

    if is_nil(option_key) then
        return main:query_mod(mod_key) ~= nil
    end

    if option_key and is_nil(value) then
        return main:query_mod_option(mod_key, option_key) ~= nil
    end

    return main:query_mod_option(mod_key, option_key) == value
end

function Profile:get_settings()
    return self.__mods
end

setmetatable(Settings.__profiles, Settings.__profiles_mt)

function Settings:create_default_profile()
    logf("Setting up default profile!")
    self:create_profile_with_key("Default Profile",{
        __name = "Default Profile",
        __description = "The default MCT profile. Stores all important information about mods, as well as the current saved settings.",
        __mods = {},
    })

    self:set_selected_profile("Default Profile")
end

function Settings:setup_default_profile()

    local main = self:get_main_profile()

    logf("Reading profiles file")
    self:read_profiles_file()

    -- for _,mod_obj in pairs(mct:get_mods()) do
    --     logf("Saving %s in Main Profile", _)
    --     main:save_mod(mod_obj)
    -- end

    --- clear out the old fielsd in all profiles
    for key,_ in pairs(self.__profiles) do
        if key ~= "Default Profile" then
            local p = self.__profiles[key]

            p.__mods = p.settings
            p.selected = nil
            p.settings = nil
    
            p.__name = key
            p.__description = ""
    
            for mod_key, mod_data in pairs(p.__mods) do
                p.__mods[mod_key] = nil
                --- make sure that unused mods saved in profiles go to "cached settings", delete them from profiles.
                if not mct:get_mod_by_key(mod_key) then
                    if not self:get_cached_settings(mod_key) then
                        self.__cached_settings[mod_key] = mod_data
                    else
                        for option_key, option_value in pairs(mod_data) do
                            local setting = self.__cached_settings[mod_key][option_key]
                            if is_nil(setting) or setting ~= option_value then
                                self.__cached_settings[mod_key][option_key] = option_value
                            end
                        end
                    end
                else
                    p.__mods[mod_key] = {}
                    for option_key, option_value in pairs(mod_data) do
                        p.__mods[mod_key][option_key] = option_value
                    end
                end
            end
            
            self.__profiles[key] = Profile:instantiate(p)
            self.__profiles[key]:save_all_mods()
            -- --- if there's no differences from main, destroy this one.
            -- local any_open = false
            -- for k,v in pairs(p.__mods) do
            --     if next(v) == nil then
            --         p.__mods[k] = nil
            --     else
            --         any_open = true
            --     end
            -- end

            -- -- Kill it!
            -- if not any_open then
            --     self.__profiles[key] = nil
            -- else -- Save it!
            -- end
        end
    end

    -- Fix the "cached settings" table
    local t = self.__cached_settings
    for mod_key, mod_data in pairs(t) do
        if mod_data then
            for option_key, option_data in pairs(mod_data) do
                if is_table(option_data) and not is_nil(option_data._setting) then
                    t[mod_key][option_key] = option_data._setting
                end
            end
        end
    end

    self:save()
end

--- Load the shit from the profiles file.
function Settings:load(selected_profile)
    logf("Loading all settings from the mct_save.lua file!")
    local content = loadfile(self.__new_settings_file)
    if not content then
        -- errmsg!
        return
    end

    content = content()

    self.__selected_profile = selected_profile or content.__used_profile
    self.__cached_settings = content.__cached_settings

    -- instantiate all profiles!
    self.__profiles = content.__profiles
    for _,profile in pairs(self.__profiles) do
        profile = Profile:instantiate(profile)
    end

    local mod_data = content.__mod_data
    
    if is_nil(self:get_main_profile()) then self:create_default_profile() end
    local main = self:get_main_profile()

    -- also load all MCT mods and check for new settings
    logf("Checking all mods for new mods/options!")
    local any_changed = false
    for mod_key,mod_obj in pairs(mct:get_mods()) do
        logf("In %s", mod_key)
        --- if this mod isn't saved in the main profile, save it in all profiles ... 
        if is_nil(main.__mods[mod_key]) then
            logf("%s hasn't been saved - saving in all profiles!", mod_key)
            for _,profile in pairs(self.__profiles) do
                profile:save_mod(mod_obj)
                any_changed = true
            end
        end
        
        if mod_data[mod_key] then
            mod_obj:set_last_viewed_patch(mod_data[mod_key].__patch)
        end
        
        --- if this option isn't saved in the main profile, save it in all profiles ...
        for option_key,option_obj in pairs(mod_obj:get_options()) do
            logf("In %s.%s", mod_key, option_key)
            if is_nil(main.__mods[mod_key][option_key]) then
                logf("%s.%s hasn't been saved - saving in all profiles!", mod_key, option_key)

                local value = option_obj:get_default_value()
                local cached_value = self:get_cached_settings(mod_key, option_key)
                if cached_value and cached_value[1] then
                    value = cached_value[1] 
                    self:remove_cached_setting(mod_key, option_key)
                end
                
                for _,profile in pairs(self.__profiles) do
                    any_changed = true
                    profile:save_setting(mod_key, option_key, value)
                end
            end
        end
    end

    --- TODO prevent saving if we're in the LoadingGame callback!
    if any_changed then
        logf("Is it crashing in save?")
        self:save()
        logf("Post-save")
    end
end

function Settings:get_mod_data()
    local t = {}

    for key,mod in pairs(mct:get_mods()) do
        t[key] = {
            __patch = mod:get_last_viewed_patch(),
            __name = mod:get_title(),
            __description = mod:get_description(),
        }
    end

    return t
end

--- Save the shit into the profiles file.
function Settings:save()
    local ok, errmsg = pcall(function()
    local t = {}
    local warning = {
        "WARNING: This file is automatically edited by the Mod Configuration Tool, is regularly read, and is required for ALL save functionality with the mods.",
        "\n\t========\n\tDO NOT EDIT THIS MANUALLY. DO NOT DELETE THIS.\n\t========\n",
        "This file, that said, is safe to delete if you are no longer using the Mod Configuration Tool and don't plan on resubbing it. I'll miss you!",
    }

    t.__used_profile = self:get_selected_profile_key()
    t.__profiles = self:get_profiles()
    t.__cached_settings = self.__cached_settings
    t.__mod_data = self:get_mod_data()

    local str = string.format("--[[\n\t%s\n--]]\n\nreturn %s",  table.concat(warning, "\n\t"), table_printer:print(t))

    logf("about to print")
    local file = io.open(self.__new_settings_file, "w+")
    if file then
        file:write(str)
        file:close()
        logf("printed")
    end

end) if not ok then errf("Issue with saving! \n%s", errmsg) end

    core:trigger_custom_event(
        "MctSaved",
        {mct = mct,}
    )
end

function Settings:clear_changed_settings(clear_bool)
    self.__changed_settings = {}

    if clear_bool then
        self.__settings_changed = false
    end
end

--- Check whether there are any pending changes.
---@return boolean PendingSettingChanges Whether there's pending changes in the currently selected profile (ie. changing a single setting within Profile A).
---@return boolean PendingProfileChanges Whether there's a pending change in currently selected profile (ie. changing from Profile A -> B)
function Settings:has_pending_changes()
    return (next(self.__changed_settings) ~= nil)
end

function Profile:clear_tracking(mod_key, option_key)
    if is_string(mod_key) then
        if is_string(option_key) then
            self.__mods[mod_key][option_key] = nil
        else
            self.__mods[mod_key] = {}
        end
    end
end

---comment
---@param option_obj MCT.Option
---@param finalized_setting any
function Settings:save_setting(option_obj, finalized_setting)
    local profile = self:get_selected_profile()
    local mod_key = option_obj:get_mod():get_key()
    local opt_key = option_obj:get_key()

    profile:save_setting(mod_key, opt_key, finalized_setting)
end


-- this saves the changed-setting, called whenever @{mct_option:set_selected_setting} is called (except for creation).
function Settings:set_changed_setting(mod_key, option_key, new_value, is_popup_open)
    if not is_string(mod_key) then
        err("set_changed_setting() called, but the mod_key provided ["..tostring(mod_key).."] is not a valid string!")
        return false
    end

    if not is_string(option_key) then
        err("set_changed_setting() called for mod_key ["..mod_key.."], but the option_key provided ["..tostring(option_key).."] is not a valid string!")
        return false
    end

    local mct_mod = mct:get_mod_by_key(mod_key)
    local mct_option = mct_mod:get_option_by_key(option_key)

    -- add this as a table if it doesn't exist already
    if not is_table(self.__changed_settings[mod_key]) then
        self.__changed_settings[mod_key] = {}
    end

    -- ditto for the setting
    if not is_table(self.__changed_settings[mod_key][option_key]) then
        self.__changed_settings[mod_key][option_key] = {}
    end

    local old = mct_option:get_finalized_setting()

    logf("Setting changed setting %s.%s to %s; former is %s", mod_key, option_key, tostring(new_value), tostring(old))

    -- if the new value is the finalized setting, remove it, UNLESS the popup is open
    if old == new_value and not is_popup_open then
        self.__changed_settings[mod_key][option_key] = nil
        -- check to see if the mod_key obj needs to be removed too
        if self.__changed_settings[mod_key] and next(self.__changed_settings[mod_key]) == nil then
            self.__changed_settings[mod_key] = nil
        end
    else
        self.__changed_settings[mod_key][option_key]["old_value"] = old
        self.__changed_settings[mod_key][option_key]["new_value"] = new_value
    end
end

function Settings:get_changed_settings(mod_key, option_key)
    if is_string(mod_key) then
        if is_string(option_key) then
            return self.__changed_settings[mod_key] and self.__changed_settings[mod_key][option_key] and self.__changed_settings[mod_key][option_key]["new_value"]
        end
        return self.__changed_settings[mod_key]
    end

    return self.__changed_settings
end

---@param option_obj MCT.Option
function Settings:get_selected_setting_for_option(option_obj)
    logf("Is this being called?")
    local value

    local mod_key = option_obj:get_mod_key()
    local option_key = option_obj:get_key()
    logf("Getting selected setting for [%s]_[%s]", mod_key, option_key)

    ---@type any
    logf("Querying changed settings")
    value = self:get_changed_settings(mod_key, option_key)
    if not is_nil(value) then logf("Changed found: %s", tostring(value))  return value end

    local current_profile = self:get_selected_profile()
    value = current_profile:query_mod_option(mod_key, option_key)

    if not is_nil(value) then 
        logf("Current profile found: %s", tostring(value))
        return value
    end
end

---@param option_obj MCT.Option
function Settings:get_finalized_setting_for_option(option_obj)
    local mod_key = option_obj:get_mod_key()
    local option_key = option_obj:get_key()
    logf("getting finalized setting for %s", option_key)

    -- local ret

    local profile = self:get_selected_profile()
    local value = profile:query_mod_option(mod_key, option_key)
    if not is_nil(value) then logf("Found! %s", tostring(value)) end

    -- ret = value
    return value
end

function Settings:get_settings_for_mod(mod_obj)
    local options = mod_obj:get_options()
    local retval = {}

    for key, option in pairs(options) do
        retval[key] = option:get_finalized_setting()
    end

    return retval
end

function Settings:get_profiles()
    return self.__profiles
end

function Settings:get_selected_profile()
    return self:get_profile(self:get_selected_profile_key())
end

function Settings:get_selected_profile_key()
    return self.__selected_profile
end

function Settings:get_profile(key)
    if not is_string(key) then return end
    
    return self:get_profiles()[key]
end

--- TODO make a functionality for "import/export profile", for things like MP campaigns and MP battles
--- TODO choose from all files in the game folder that match the pattern?
function Settings:import_profile()
    local content = loadfile(self.__import_profiles_file)
    if not content then
        -- errmsg!
        return
    end

    content = content()

    local n,d,m = content.__name, content.__description, content.__mods

    self:add_profile_with_key(n,d,m)
end

---@param profile MCT.Profile
function Settings:export_profile(profile)
    local t = {}

    t.__name = profile.__name
    t.__description = profile.__description
    t.__mods = profile.__mods

    local str = string.format("return %s", table_printer:print(t))

    --- TODO make sure there's not already a file with this name?
    local file = io.open(self.__import_profiles_file, "w+")
    if file then
        file:write(str)
        file:close()
    end
end

--- TODO keep in mind to make a popup and good UX for "don't fucking delete your profile mid-campaign and don't do it for MP profiles" and stuff
function Settings:delete_profile_with_key(key)
    if not is_string(key) then
        err("delete_profile_with_key() called, but the key provided ["..tostring(key).."] is not a string!")
        return false
    end

    --- err catch; UI shouldn't show main as deletable, but this is still available in API
    if key == "Default Profile" then
        err("delete_profile_with_key() called, but they're trying to delete main! Abort!")
        return false
    end

    if not self:get_profile(key) then
        err("delete_profile_with_key() called, but the profile with key ["..key.."] doesn't exist!")
        return false
    end

    self.__profiles[key] = nil
    self:set_selected_profile("Default Profile")

    -- refresh the dropdown UI
    mct.ui:populate_profiles_dropdown_box()

    self:save()
end

function Settings:set_selected_profile(key)
    if not is_string(key) then
        err("set_selected_profile() called, but the key provided ["..tostring(key).."] is not a string!")
        return false
    end

    if not self:get_profile(key) then
        err("set_selected_profile() called, but there's not profile found with the key ["..key.."]")
        return false
    end

    -- save the new one as saved
    self.__selected_profile = key
end

function Settings:get_all_profile_keys()
    local ret = {}
    for k,_ in pairs(self.__profiles) do
        ret[#ret+1] = _.__name
    end

    return ret
end

--- Antiquated, only used for backwards compat.
function Settings:read_profiles_file()
    local ok, msg = pcall(function()
    local file = io.open(self.profiles_file, "r")
    
    -- if no file exists, skip operation
    if not file then
        return false
    end

    file:close()

    local content = loadfile(self.profiles_file)
    
    if not content then
        err("read_profiles_file() called, but there is no valid profiles found in the profiles_file!")
        return false
    end

    content = content()

    for k,v in pairs(content) do
        if k == "Default Profile" then k = "Old Default" end
        self.__profiles[k] = v
    end

    setmetatable(self.__profiles, self.__profiles_mt)
    self.__selected_profile = "Default Profile"

end) if not ok then err(msg) end end


function Settings:rename_profile(key, new_key, desc)
    local profile = self:get_profile(key)
    if not profile then
        --- errmsg
        return false
    end

    if not is_string(new_key) then
        --- errmsg
        return false
    end

    profile.__name = new_key
    if is_string(desc) then
        profile.__description = desc
    end

    self.__profiles[key] = nil
    self.__profiles[new_key] = profile
end

function Settings:apply_profile_with_key(key)
    if not is_string(key) then
        return "bad_key"
    end

    if not self.__profiles[key] then
        return "none_found"
    end
    
    self:clear_changed_settings()

    self:set_selected_profile(key)

    local profile_settings = self:get_profile(key)


    --- Grab all the changed settings in this profile, and apply them immediately within the UI.
    for mod_key, mod_data in pairs(profile_settings.__mods) do
        local mod_obj = mct:get_mod_by_key(mod_key)

        if mod_obj then
            for option_key, selected_setting in pairs(mod_data) do
                local option_obj = mod_obj:get_option_by_key(option_key)

                --- 
                option_obj:set_selected_setting(selected_setting)
            end
        end
    end

    self.__settings_changed = true
    self:save()
end

function Settings:test_profile_with_key(key)
    if not is_string(key) then
        return common.get_localised_string("mct_profiles_bad_key")
    end

    if key == "" then
        return common.get_localised_string("mct_profiles_blank_key")
    end

    -- test if one exists already
    if self.__profiles[key] ~= nil then
        return common.get_localised_string("mct_profiles_exists")
    end

    return true
end

function Settings:add_profile_with_key(name, desc, mods)
    local test = self:test_profile_with_key(name)

    if test ~= true then
        return test
    end

    local applied_mods = {}
    local main_mods = self:get_main_profile().__mods

    if mods then -- make sure the imported mod has every mod and every option local!
        for mod_key,mod_data in pairs(main_mods) do
            applied_mods[mod_key] = {}

            if not mods[mod_key] then 
                applied_mods[mod_key] = mod_data
            else
                for option_key,option_value in pairs(mod_data) do
                    if mods[mod_key][option_key] then 
                        applied_mods[mod_key][option_key] = mods[mod_key][option_key]
                    else
                        applied_mods[mod_key][option_key] = option_value
                    end
                end
            end
        end
    else
        applied_mods = main_mods
    end

    self:create_profile_with_key(
        name,
        {
            __name = name,
            __description = desc,
            __mods = applied_mods,
        }
    )

    self:set_selected_profile(name)
    self.__settings_changed = true

    mct.ui:populate_profiles_dropdown_box()

    return true
end

--- Add a new cached_settings object for a specific mod key, or adds new option keys if one exists already.
function Settings:add_cached_settings(mod_key, option_data)
    if not is_string(mod_key) then
        -- errmsg
        return nil
    end

    if not is_table(option_data) then
        -- errmsg
        return nil
    end

    local test_mod = self.__cached_settings[mod_key]
    if is_nil(test_mod) then
        self.__cached_settings[mod_key] = {}
    end

    for k,v in pairs(option_data) do
        self.__cached_settings[mod_key][k] = v
    end
end

--- Check the cached_settings object for a specific mod key, and a single (or multiple) option.
--- Will return a table of settings keys in the order the option keys were presented. Nil if none are found.
function Settings:get_cached_settings(mod_key, option_keys)
    if not is_string(mod_key) then
        err("get_cached_settings() called, but the mod_key provided ["..tostring(mod_key).."] is not a string!")
        return nil
    end

    if is_string(option_keys) then
        option_keys = {option_keys}
    end

    if is_nil(option_keys) then
        -- return the entire cached mod
        return self.__cached_settings[mod_key]
    end

    if not is_table(option_keys) then
        err("get_cached_settings() called for mod_key ["..mod_key.."], but the option_keys arg provided wasn't a single option key, a table of option keys, or nil. Returning nil!")
        return nil
    end

    local test_mod = self.__cached_settings[mod_key]

    -- no mod with this key was found in cached settings
    if is_nil(test_mod) then
        return nil
    end

    local retval = {}

    for i = 1, #option_keys do
        local option_key = option_keys[i]
        local test = test_mod[option_key]

        if not is_nil(test) then
            retval[option_key] = test
        end
    end

    return retval
end

--- Remove any cached settings within the mod-key provided with the option keys provided. 
--- If no option keys are provided, the entire mod's cached settings will be axed.
function Settings:remove_cached_setting(mod_key, option_keys)
    if not is_string(mod_key) then
        err("remove_cached_setting() called but the mod_key provided ["..tostring(mod_key).."] is not a string.")
        return false
    end

    if is_string(option_keys) then
        option_keys = {option_keys}
    end

    -- no "option_keys" were passed - just remove the mod from memory!
    if is_nil(option_keys) then
        self.__cached_settings[mod_key] = nil
        return
    end

    if not is_table(option_keys) then
        err("remove_cached_settings() called for mod_key ["..mod_key.."], but the option_keys argument provided is not a single option key, a table of option keys, or nil. Returning false!")
        return false
    end

    -- check if the mod is cached in memory
    local test_mod = self.__cached_settings[mod_key]

    if is_nil(test_mod) then
        -- this mod was already removed from cached settings - cancel!
        return false
    end

    -- loop through all option keys, and remove them from the cached settings
    for i = 1, #option_keys do
        local option_key = option_keys[i]

        -- kill the cached setting for this option key
        test_mod[option_key] = nil
    end
end

--- ANTIQUATED. Here for backwards support.
function Settings:save_mct_settings()
    if io.open(self.__new_settings_file, "r") then
        return self:save()
    end

    local file, load_err  = io.open(self.settings_file, "w+")

    if not file then
        err("Could not load settings file: "..load_err)
        return false
    end

    self.tab = 0

    local str = "return {\n"

    local mods = mct:get_mods()
    for _, mod_obj in pairs(mods) do
        local addendum = mod_obj:save_mct_settings()

        str = str .. addendum
    end

    local t = ""

    -- append a loop for the cached mods
    if self.__cached_settings and not is_nil(next(self.__cached_settings)) then
        t = "\t[\"mct_cached_settings\"] = {\n"
        for mod_key, mod_data in pairs(self.__cached_settings) do
            t = t .. "\t\t[\""..mod_key.."\"] = {\n"

            -- loop through the k/v table of "mod_data", which is `["option_key"] = "setting",`
            for option_key, option_data in pairs(mod_data) do
                if not option_key:starts_with("__") then
                    t = t .. "\t\t\t[\""..option_key.."\"] = {\n"

                    for _,saved_setting in pairs(option_data) do
                        t = t .. "\t\t\t\t[\"_setting\"] = "
                        if is_string(saved_setting) then
                            t = t .. "\"" .. saved_setting .. "\",\n"
                        elseif is_number(saved_setting) then
                            t = t .. tostring(saved_setting) .. ",\n"
                        elseif is_boolean(saved_setting) then
                            t = t .. tostring(saved_setting) .. ",\n"
                        else
                            --log("not a string number or boolean?")
                            --log(tostring(saved_setting))
                            t = t .. "nil" .. ",\n"
                        end

                        --t = t .. "\t\t\t},\n"
                    end

                    t = t .. "\t\t\t},\n"
                end
            end

            t = t .. "\t\t},\n"
        end

        t = t .. "\t},\n"
    end

    str = str .. t

    --log("starting run through table")
    --str = run_through_table(data, str)
    --log("ending run through table")

    str = str .. "}"

    self.tab = 0

    file:write(str)
    file:close()
end

function Settings:local_only_finalize(sent_by_host)
    -- it's the client; only finalize local-only stuff
    log("Finalizing settings mid-campaign for MP, local-only.")
    local all_mods = mct:get_mods()

    for mod_key, mod_obj in pairs(all_mods) do
        local fin = mod_obj:get_settings()

        log("Looping through mct_mod ["..mod_key.."]")
        local all_options = mod_obj:get_options()

        for option_key, option_obj in pairs(all_options) do
            if option_obj:get_local_only() then
                log("Editing mct_option ["..option_key.."]")

                -- only trigger the option-changed event if it's actually changing setting
                local selected = option_obj:get_selected_setting()

                if option_obj:get_finalized_setting() ~= selected then
                    option_obj:set_finalized_setting(selected)
                    fin[option_key] = selected
                end
            end
        end

        mod_obj._finalized_settings = fin
    end

    mct._finalized = true
    
    mct.ui.locally_edited = false

    if not sent_by_host then
        mct.ui.changed_settings = {}
    end

    core:trigger_custom_event("MctFinalized", {["mct"] = mct, ["mp_sent"] = sent_by_host})
end

function Settings:finalize_first_time(force)
    local mods = mct:get_mods()

    for key, mod in pairs(mods) do
        mod:load_finalized_settings()
    end

    self:save()
end

function Settings:clear_changed_settings_for_mod(mod_key)
    self.__changed_settings[mod_key] = nil
end

---@param mod_obj MCT.Mod
function Settings:finalize_mod(mod_obj)
    local mod_key = mod_obj:get_key()
    local changed_options = self:get_changed_settings(mod_key)
    if not is_table(changed_options) then
        -- this mod hasn't had any changed settings - skip!
        logf("Finalizing settings for mod [%s], but nothing was changed in this mod! Cool!", mod_key)
        return false
    end

    logf("Finalizing settings for mod [%s]", mod_key)

    for option_key, option_data in pairs(changed_options) do
        local option_obj = mod_obj:get_option_by_key(option_key)

        if not mct:is_mct_option(option_obj) then
            logf("Trying to finalize settings for mct_mod [%s], but there's no option with the key [%s].", mod_key, option_key)
            --return false
        else
            local new_setting = option_data.new_value
            local old_setting = option_data.old_value
    
            logf("Finalizing setting for option [%s], changing [%s] to [%s].", option_key, tostring(old_setting), tostring(new_setting))
    
            option_obj:set_finalized_setting(new_setting)
        end
    end

    self:clear_changed_settings_for_mod(mod_obj:get_key())
end

function Settings:finalize()
    local mods = mct:get_mods()

    for key, mod in pairs(mods) do
        self:finalize_mod(mod)
        logf("Finalized mod [%s]", key)
    end

    self:save()

    self.__settings_changed = true
end

--- TODO when you're in a MPC lobby about to load in, get a prompt to create a new profile and link it to this save game, or use an existing profile (it'll duplicate an existing one).
--- TODO create a new, custom profile for specifically this campaign. Save the profile name as the two users names(?)
--- TODO send the host, the profile key, and the current settings along to both parties.
--- TODO whenever the game is loaded afterwards, grab the special profile and all the settings. should be saved on both PCs but check either way.
--- TODO fix up
-- only used for new games in MP
function Settings:mp_load(selected_profile)
    out("mp_load() start")
    -- first up: set up the events to respond to the MP stuff
    ClMultiplayerEvents.registerForEvent(
        "MctMpInitialLoad","MctMpInitialLoad",
        function(mct_data)
            -- mct_data = {mod_key = {option_key = {setting = xxx, read_only = true}, option_key_2 = {setting = yyy, read_only = false}}, mod_key2 = {etc}}
            out("MctMpInitialLoad begun!")
            for mod_key, options in pairs(mct_data) do
                local mod_obj = mct:get_mod_by_key(mod_key)
                out("Looping through mod obj ["..mod_key.."].")

                for option_key, option_data in pairs(options) do
                    
                    out("At object ["..option_key.."]")
                    local option_obj = mod_obj:get_option_by_key(option_key)

                    local setting = option_data._setting

                    out("Setting: "..tostring(setting))

                    option_obj:set_finalized_setting(setting, true)
                end
            end

            out("MctMpInitialLoad end!")

            out("Triggering MctInitializedMp, enjoy")
            core:trigger_custom_event("MctInitialized", {["mct"] = mct, ["is_multiplayer"] = true})
        end
    )

    --log("Is this being called too early?")
    local test_faction = cm:get_saved_value("mct_host")
    out("Host faction key is: "..test_faction)

    -- log("Local faction is: "..local_faction)

    --log("Is THIS?")
    --- TODO use the saved faction key
    if cm.game_interface:model():faction_is_local(test_faction) then
    -- if core:svr_load_bool("local_is_host") then
        out("mct_host found!")
        self:load(selected_profile)

        local tab = {}

        local all_mods = mct:get_mods()
        for mod_key, mod_obj in pairs(all_mods) do
            tab[mod_key] = {}

            local options = mod_obj:get_options()

            for option_key, option_obj in pairs(options) do
                -- don't send local-only settings to both
                if option_obj:get_local_only() == false then
                    tab[mod_key][option_key] = {}

                    tab[mod_key][option_key]._setting = option_obj:get_finalized_setting()
                end
            end
        end

        out("Triggering MctMpInitialLoad")

        ClMultiplayerEvents.notifyEvent("MctMpInitialLoad", 0, tab)
    end
end

--- TODO on first time load, set default values
--- TODO check for empty tables in __mods, ie. some reason mixu_mixer is in profiles.__main.__mods as {}
--- This is the function that reads the mct_settings.lua file and loads up all the necessary components from it.
-- If no file is found, or the file has some sort of script break, MCT will make a new one using all defaults.
-- This is also where settings are "cached" for any mct_mods that aren't currently enabled but are in the mct_settings.lua file
function Settings:load_old()
    logf("Load Old!")
    --- use the new path if we've already constructed the new MCT profiles page
    if io.open(self.__new_settings_file, "r") then
        logf("Old -> New Load!")
        return self:load()
    end

    self:create_default_profile()

    --- TODO move elsewhere too
    -- if we're in the campaign, save the "mct_init" value as true
    if __game_mode == __lib_type_campaign then
        cm:set_saved_value("mct_init", true)
    end

    local file, _ = io.open(self.settings_file, "r")
    if not file then
        -- create a file with all the defaults!
        log("First time load - creating settings file! Using defaults for every option.")
        mct._first_load = true
        self:finalize_first_time(true)
        log("Settings file created, all defaults applied!")
    else
        log("Loading settings file!")
        mct._first_load = false
        local content = loadfile(self.settings_file)

        local ok,content = pcall(function() return content() end)

        if not ok then
            err("The mct_settings.lua file had a script error in it and couldn't be loaded. Investigate!")
            err(content)
            self:finalize_first_time(true)
            return
        end 

        if not content then
            errf("No content!")
            self:finalize_first_time(true)
            return
        end

        local ok, errmsg = pcall(function()

        local any_added = false

        --local content = table.load(self.settings_file)
        local all_mods = mct:get_mods()

        local cached_settings = content["mct_cached_settings"]
        content["mct_cached_settings"] = nil

        for mod_key, mod_obj in pairs(all_mods) do
            --log("Loading settings for mod ["..mod_key.."].")

            -- check if there's any saved data for this mod obj
            local data = content[mod_key]
            
            if is_table(data) then
                local last_patch = data.__patch
                if last_patch then
                    mod_obj:set_last_viewed_patch(last_patch)
                    data.__patch = nil
                end
            end

            -- loop through all of the actual options available in the mct_mod, not only ones in the settings file
            local all_options = mod_obj:get_options()

            for option_key, option_obj in pairs(all_options) do
                local setting = nil

                -- grab data attached to this option key in the .lua settings file
                if not is_nil(data) then
                    local saved_data = data[option_key]

                    -- grab the saved data in the .lua file for this option!
                    if not is_nil(saved_data) then
                        setting = saved_data._setting
                    else -- this is a new setting!
                        --log("New setting found! ["..option_key.."]")

                        --log("???")

                        -- save the option key in the new_settings table, so we can look back later and see that it's new!
                        -- skip this process if the option is a dummy!
                        if option_obj:get_type() ~= "dummy" then
                            if is_nil(self.__new_settings[mod_key]) then
                                --log("?")
                                self.__new_settings[mod_key] = {}
                                --log("??")
                            end

                            self.__new_settings[mod_key][#self.__new_settings[mod_key]+1] = option_key
                            any_added = true
                        end
                    end
                end

                -- if no setting was found, default to whatever the default_value is
                if is_nil(setting) then
                    -- this returns the default value
                    setting = option_obj:get_finalized_setting()
                end

                -- if any setting is found in `mct_cached_settings`, check that for this mod key, for this option key, and then apply it over
                if cached_settings then
                    if cached_settings[mod_key] then
                        if cached_settings[mod_key][option_key] then
                            -- apply the new setting, and clear out the index in cached settings
                            setting = cached_settings[mod_key][option_key]["_setting"]
                            cached_settings[mod_key][option_key] = nil

                            -- if that was the last cached setting in this mct_mod, then remove the mod from cached settings
                            if cached_settings[mod_key] and next(cached_settings[mod_key]) == nil then
                                cached_settings[mod_key] = nil

                                -- if that was the last cached setting in any mct_mod, then just delete the table
                                if cached_settings and next(cached_settings) == nil then
                                    cached_settings = nil
                                end
                            end
                        end
                    end
                end
                
                -- set the finalized setting and read only stuffs
                option_obj:set_finalized_setting(setting, true)

                --log("Finalizing option ["..option_key.."] with setting ["..tostring(setting).."]")

                -- remove this from `data`, so non-existent settings will be cached
                if is_table(data) then
                    data[option_key] = nil
                end
            end
            
            mod_obj:load_finalized_settings()

            -- only clear out this mod from content (from an empty table {} to nil) if it's completely empty from the previous operation
            if content[mod_key] and next(content[mod_key]) == nil then
                content[mod_key] = nil
            end
        end

        -- loop through the "mct_cached_settings", if it exists, and add all of the stuff into the cached_settings table
        if cached_settings then
            for mod_key, mod_data in pairs(cached_settings) do
                log("Re-caching settings for mct_mod with key ["..mod_key.."]")

                if not self.__cached_settings[mod_key] then
                    self.__cached_settings[mod_key] = {}
                end

                for k,v in pairs(mod_data) do
                    self.__cached_settings[mod_key][k] = v
                end
            end
        end

        -- loop through the rest of "content", which is either empty entirely or has
        -- any bits of information that need to be cached due to a disabled mct_mod
        for mod_key, mod_data in pairs(content) do
            
            log("Caching settings for mct_mod with key ["..mod_key.."]")

            if not self.__cached_settings[mod_key] then
                self.__cached_settings[mod_key] = {}
            end

            for k,v in pairs(mod_data) do
                self.__cached_settings[mod_key][k] = v
            end
        end

        --self:finalize()

        -- log("Any new settings added?: "..tostring(any_added))
        if any_added then
            --log("does this exist")
            mct.ui:add_ui_created_callback(function()
                local mod_keys = {}
                for k, _ in pairs(self.__new_settings) do
                    mod_keys[#mod_keys+1] = k
                end

                local key = "mct_new_settings"
                local text = common.get_localised_string("mct_new_settings_start") .. "\n\n" .. common.get_localised_string("mct_new_settings_mid")

                for i = 1, #mod_keys do
                    local mod_obj = mct:get_mod_by_key(mod_keys[i])
                    local title = mod_obj:get_title()

                    -- there's only one changed mod
                    if 1 == #mod_keys then
                        text = text .. "\"" .. title .. "\"" .. ". "
                    else
                        if i == #mod_keys then
                            text = text .. "and \"" .. title .. "\"" .. ". "
                        else
                            text = text .. "\"" .. title .. "\"" .. ", "
                        end
                    end
                end

                --text = text .. "\n" .. effect.get_localised_string("mct_new_settings_end")

                mct.ui:create_popup(
                    key,
                    function()
                        if not mct.ui.opened then 
                            return text .. "\n" .. common.get_localised_string("mct_new_settings_created_end")
                        else 
                            return text
                        end
                    end,
                    function()
                        if not mct.ui.opened then
                            return true
                        else
                            return false
                        end
                    end,
                    function()
                        if mct.ui.opened then
                            -- do nothing
                        else
                            mct.ui:open_frame()
                        end
                    end,
                    function()
                        -- do nothing?
                    end
                )
            end)
        end

    end) if not ok then errf(errmsg) end

        self:finalize_first_time()
    end

    --- trigger the create-new-profile "Default Profile" thing here
    -- first time setup, either for a completely new user or a pre-port user.
    self:setup_default_profile()
end



--- TODO handle MP stuff here!
-- load saved details for all mods
function Settings:load_game_callback(context)
    ---@type {selected_profile:string}
    local data = cm:load_named_value("mct", {selected_profile = "Default Profile"}, context)

    --- TODO grab the host's faction key, and run self:load() similarly to how it was run before in mp_load
    out("Load game callback for MCT! Selected profile is " .. data.selected_profile)
    if not cm:is_new_game() and cm:get_saved_value("mct_mp_init") then
        out("Prepping the MP callback for MCT!")
        cm:add_pre_first_tick_callback(function()
            out("Pre first tick callback in mct_settings.lua")
            self:mp_load(data.selected_profile)
        end)

        -- return
    else
        self:load(data.selected_profile)
    end
end

-- called whenever saving
function Settings:save_game_callback(context)
    local selected_profile = self:get_selected_profile_key()

    cm:save_named_value("mct", {
        selected_profile = selected_profile,
        -- mct_host = "FACTION KEY", -- TODO save the host's faction key
        -- TODO anything else?
    }, context)
end

return Settings