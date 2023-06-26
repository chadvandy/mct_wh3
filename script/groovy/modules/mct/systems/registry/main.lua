--- TODO the system for handling global registry values, context-specific registry values, and campaign-saved registry values

--- TODO the flow should be:
--[[
    open the existing mct_registry.lua file, and read all the context-specific saved settings we have here, cached settings, etc.
    if we're in campaign, load up the saved settings from the campaign save (and save those in the registry so we can access them through frontend)
    if we're in campaign battle, we should be using the same saved settings
    if we're in quick battle or frontend, we should be using the global settings
]]

--- TODO view/edit, campaign/global, client/host
--- TODO unique Registry objects loaded for each registry, call/edit them as needed
    -- TODO a "for next campaign" registry
    -- "default values" registry
    -- "global values" registry, for hotkeys and such
    -- "saved values" for each campaign
    -- unsaved changes

local this_path = GLib.ThisPath(...)

local mct = get_mct()
local log,logf,err,errf = get_vlog("[mct_registry]")

local table_print = table_print

---@class MCT.RegistryManager : Class
local defaults = {
    ---@type string The path to the appdata/scripts/ folder
    appdata_path = string.gsub(common.get_appdata_screenshots_path(), "screenshots\\$", "scripts\\"),

    --- TODO
    ---@type table<string, MCT.Profile>
    __saved_profiles = {},

    ---@alias changed_settings {old_value:any,new_value:any}

    -- a better way to read if any settings have been changed
    -- table of mod keys (only added when a setting is changed)
    -- within each mod key table, option keys (only added when that specific option changed)
    -- within each option key table, two field - old_value (for finalized-setting) and new_value (for selected-setting) (option key table removed if new_value is set to old_value)
    ---@type table<string, table<string, changed_settings>> Changed-in-UI settings
    __changed_settings = {},

    __last_used_campaign_index = 0,

    __this_campaign = 0,

    __campaigns = {},

    __registries = {
        Global = {},
        Campaigns = {},
        Cache = {},
        NextCampaign = {},
    },

    --- The Registry for the "next campaign"; created when the player is in a New Campaign menu, for singleplayer and multiplayer. 
    __next_campaign = {},

    __main_file = "mct_registry.lua",
    __profiles_file = "mct_profiles.lua",
}

---@class MCT.RegistryManager : Class
local RegistryManager = GLib.NewClass("MCT.RegistryManager", defaults)

---@type MCT.RegistryInstance
RegistryManager.RegistryInstance = GLib.LoadModule("obj", this_path .. "instance/")

function RegistryManager:get_file_path(append)
    return self.appdata_path .. append
end

function RegistryManager:new_profile(name)
    local Profile = mct:get_profile_class()

    local p = Profile:new(name)

    self.__saved_profiles[name] = p
    return p
end

function RegistryManager:get_profile(name)
    return self.__saved_profiles[name]
end

function RegistryManager:get_profiles()
    return self.__saved_profiles
end


function RegistryManager:port_forward()
    logf("Attempting to port forward.")
    --- read the old Profiles
    local old_file = io.open("mct_save.lua", "r")
    if not old_file then
        logf("Can't find the old file to port forward!")
        --- No old profiles to port - all good!
        return
    end

    old_file:close()

    local content = loadfile("mct_save.lua")

    if not content then
        err("port_forward() called, but there is no valid profiles found in the mct_save file!")
        return false
    end

    content = content()

    if content.__has_been_ported then
        -- We've already done this, stop!!!!
        return 
    end
    
    local old_profiles = content.__profiles

    --- create NuProfiles with their old name/description
    for profile_key, profile_data in pairs(old_profiles) do
        logf("Porting forward profile %s", profile_key)
        local new_profile = self:new_profile(profile_key)
        new_profile:set_description(profile_data.__description)

        logf("Setting description to %q", profile_data.__description)

        local this_mods = profile_data.__mods

        --- go through all their saved settings, compare them against the default value - if different, save it to this profile
        for mod_key, mod_data in pairs(this_mods) do
            local mod_obj = mct:get_mod_by_key(mod_key)
            if mod_obj then
                for option_key, value in pairs(mod_data) do
                    local option_obj = mod_obj:get_option_by_key(option_key)
                    if option_obj then
                        if option_obj:get_default_value() ~= value then
                            new_profile:set_saved_value(mod_key, option_key, value)
                        end
                    end
                end
            end
        end
    end

    --- apply the settings from the last used profile to the current global registry
    local last_used = content.__used_profile
    local this_profile = self:get_profile(last_used)
    self:apply_profile(this_profile)

    content.__has_been_ported = true

    local close_file = io.open("mct_save.lua", "w+")
    if close_file then
        close_file:write("return " .. table_print(content))
        close_file:close()
    end

    self:save()
end

---@param profile MCT.Profile
function RegistryManager:apply_profile(profile)
    local settings = profile:get_overridden_settings()

    for mod_key, mod_data in pairs(settings) do
        local mod_obj = mct:get_mod_by_key(mod_key)
        if mod_obj then
            for option_key, value in pairs(mod_data) do
                local option_obj = mod_obj:get_option_by_key(option_key)
                if option_obj then
                    option_obj:set_finalized_setting(value, true)
                end
            end
        end
    end
end

function RegistryManager:initialize_unsaved_changes_registry()
    local UnsavedChanges = self.RegistryInstance:new()

end

--- TODO discard the "changed settings" system, or at least tweak it so it's just used to inform the script about changed settings or something along those lines.

--- TODO handle held-saved-settings (cached settings) somehow someway

function RegistryManager:clear_changed_settings()
    self.__changed_settings = {}
end

-- this saves the changed-setting, called whenever @{mct_option:set_selected_setting} is called (except for creation).
---@param option_obj MCT.Option
---@param new_value any
---@param is_popup_open any
function RegistryManager:set_changed_setting(option_obj, new_value, is_popup_open)
    if not mct:is_mct_option(option_obj) then
        GLib.Error("set_changed_setting() called, but the option provided ["..tostring(option_obj).."] is not a valid MCT.Option!")
        return false
    end

    local mct_mod = option_obj:get_mod()
    local mod_key = mct_mod:get_key()
    local option_key = option_obj:get_key()

    -- add this as a table if it doesn't exist already
    if not is_table(self.__changed_settings[mod_key]) then
        self.__changed_settings[mod_key] = {}
    end

    -- ditto for the setting
    if not is_table(self.__changed_settings[mod_key][option_key]) then
        self.__changed_settings[mod_key][option_key] = {}
    end

    local old = option_obj:get_finalized_setting()

    GLib.Log("Setting changed setting %s.%s to %s; former is %s", mod_key, option_key, tostring(new_value), tostring(old))

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

        GLib.Log("%s.%s old = %s", mod_key, option_key, tostring(old))
        GLib.Log("%s.%s new = %s", mod_key, option_key, tostring(new_value))
    end
end

function RegistryManager:get_changed_settings(mod_key, option_key)
    if is_string(mod_key) then
        if is_string(option_key) then
            return self.__changed_settings[mod_key] and self.__changed_settings[mod_key][option_key] and self.__changed_settings[mod_key][option_key]["new_value"]
        end
        return self.__changed_settings[mod_key]
    end

    return self.__changed_settings
end

---@param option_obj MCT.Option
---@return any #The selected setting for the option
---@return "Changed"|"Saved"|"Default" #Where this setting was retrieved from.
function RegistryManager:get_selected_setting_for_option(option_obj)
    local value

    -- logf("Getting selected setting for option %s.%s", option_obj:get_mod_key(), option_obj:get_key())

    local mod_key = option_obj:get_mod_key()
    local option_key = option_obj:get_key()

    local pos = "Changed"
    ---@type any
    value = self:get_changed_settings(mod_key, option_key)

    if is_nil(value) then
        pos = "Saved"
        value = option_obj:get_finalized_setting(true)

        if is_nil(value) then
            pos = "Default"
            value = option_obj:get_default_value()
        end
    end

    logf("Selected setting for option %s.%s is %s. Retrieved from %s Settings.", option_obj:get_mod_key(), option_obj:get_key(), tostring(value), pos)

    return value, pos
end

-- ---@param option_obj MCT.Option
-- function Registry:get_finalized_setting_for_option(option_obj)
--     local value = self:query_option(option_obj)
--     return value
-- end

-- function Registry:get_settings_for_mod(mod_obj)
--     local options = mod_obj:get_options()
--     local retval = {}

--     for key, option in pairs(options) do
--         retval[key] = self:get_finalized_setting_for_option(option)
--     end

--     return retval
-- end

function RegistryManager:clear_changed_settings_for_mod(mod_key)
    self.__changed_settings[mod_key] = nil
end

--- Startpoint into creating the "next campaign registry" for a new campaign in the frontend.
--- Creates a blank registry, assigns all campaign-specific settings to it with their current values.
function RegistryManager:initialize_next_campaign_registry()
    local next_campaign_registry = {
        saved_mods = {},
    }


end

---@param mod_obj MCT.Mod
function RegistryManager:apply_changes_for_mod(mod_obj)
    local mod_key = mod_obj:get_key()
    local changed_options = self:get_changed_settings(mod_key)
    if not is_table(changed_options) then
        -- this mod hasn't had any changed settings - skip!
        logf("Finalizing settings for mod [%s], but nothing was changed in this mod! Cool!", mod_key)
        return false
    end

    logf("Applying changed settings for mod [%s]", mod_key)

    for option_key, option_data in pairs(changed_options) do
        local option_obj = mod_obj:get_option_by_key(option_key)

        if not option_obj or not mct:is_mct_option(option_obj) then
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

---@return thread
function RegistryManager:get_save_co()
    if not type(self.__save_co) == "thread" then
        self.__save_co = coroutine.create(
            function(all_mods)
                local old = io.open(self:get_file_path(self.__main_file), "r+")
                ---@cast old file*
                local str = old:read("*a")
                local t = loadstring(str)()
            
                old:close()
            
                if not is_table(t) then
                    t = {
                        ["global"] = {
                            ["saved_mods"] = {},
                        },
                        ["campaigns"] = {},
                        ["last_used_campaign_index"] = self.__last_used_campaign_index,
                    }
                end
            
                t.last_used_campaign_index = self.__last_used_campaign_index
            
                if not t.global then
                    t.global = {saved_mods = {},}
                end
            
                --- TODO make sure we're taking into account things not held in active memory (ie. reading the .campaign field from the registry file so that stays true (should the .campaign field be a foreign file? (yes!)))
                
                --- Loop through all mod objects, add a field in .saved_mods.
                if not t.campaigns then
                    t.campaigns = {}
                end
                if not t.campaigns[self.__this_campaign] and self.__this_campaign > 0 then
                    t.campaigns[self.__this_campaign] = {saved_mods = {}}
                end
            
                logf("Saving the MCT.Registry!")
            
                local all_mods = mct:get_mods()
                for mod_key,mod_obj in pairs(all_mods) do
                    if not t.global.saved_mods[mod_key] then
                        t.global.saved_mods[mod_key] = {
                            options = {},
                            data = {},
                        }
                    end
            
                    logf("\tIn mod [%s]", mod_key)
            
                    local this = t.global.saved_mods[mod_key]
                    local this_campaign
            
                    if mct:in_campaign_registry() then
                        if not t.campaigns[self.__this_campaign].saved_mods[mod_key] then
                            t.campaigns[self.__this_campaign].saved_mods[mod_key] = {
                                options = {},
                            }
                        end
            
                        this_campaign = t.campaigns[self.__this_campaign].saved_mods[mod_key]
                    end
            
                    for option_key, option_obj in pairs(mod_obj:get_options()) do
                        logf("\t\tIn option [%s]", option_key)
            
                        --- Save all the shared data we need to keep in the global reg
                        this.options[option_key] = {
                            name = option_obj:get_text(),
                            description = option_obj:get_tooltip_text(),
                            default_value = option_obj:get_default_value(),
                        }
            
            
                        -- if this option is global, or it's campaign-specific but we're outside a campaign, save its changes in the global registry
                        if option_obj:is_global() or (not option_obj:is_global() and not mct:in_campaign_registry()) then
                            logf("\t\t\tSaving this option as global!")
                            this.options[option_key].setting = option_obj:get_finalized_setting(true)
            
                            logf("\t\t\tFinalized setting is %s", tostring(tostring(option_obj:get_finalized_setting())))
            
                            if option_obj:is_locked() then
                                this.options[option_key].is_locked = true
                                this.options[option_key].lock_reason = option_obj:get_lock_reason()
                            end
                        else
                            -- otherwise, this option is campaign-specific and we're in a campaign
                            -- this.options[option_key].setting = 
                            if mct:in_campaign_registry() and not option_obj:is_global() then
                                this_campaign.options[option_key] = {
                                    setting = option_obj:get_finalized_setting(true),
                                }
            
                                if option_obj:is_locked() then
                                    this_campaign.options[option_key].is_locked = true
                                    this_campaign.options[option_key].lock_reason = option_obj:get_lock_reason()
                                end
                            end
                        end
                    end
            
                    this.data.name = mod_obj:get_title()
                    this.data.description = mod_obj:get_description()
                    this.data.userdata = mod_obj:get_userdata()
                end
            
                local t_str = table_print(t)
            
                local file = io.open(self:get_file_path(self.__main_file), "w+")
                ---@cast file file*
                file:write("return " .. t_str)
                file:close()
            end
        )
    end
    return self.__save_co
end

function RegistryManager:save(is_read)
    -- only force a save if we have changes, AND we're not calling save from the read functions.
    local has_changes = self:has_pending_changes()
    local force_save = has_changes and not is_read

    if cm then
        logf("Saving Registry in campaign.")
        -- delay this call to first tick (so we can guarantee we've got all the details we need and can save the save file propa)
        ---@diagnostic disable-next-line: undefined-field
        if not cm.model_is_created then
            logf("Trying to save Registry in campaign before the model is created! Delaying until first tick.")
            cm:add_first_tick_callback(function() RegistryManager:save(is_read) end)
            return
        end
    end

    local mods = mct:get_mods()

    for key, mod in pairs(mods) do
        self:apply_changes_for_mod(mod)
        logf("Finalized mod [%s]", key)
    end

    local ok, errmsg = pcall(function()
        self:save_registry_file()
        self:save_profiles_file()
    end) if not ok then log(errmsg) end

    -- Automatically save the game whenever the settings are edited
        -- IF the user has already made a save for this game.
        -- AND this isn't the on-read save (ie. when a game is loaded and the Registry is read)
    if force_save and cm and cm.save_counter > 1 then
        cm:save()
    end
end

--- TODO combine with :finalize()!
function RegistryManager:local_only_finalize(...)

end

--- Check whether there are any pending changes.
---@return boolean PendingSettingChanges Whether there's pending changes in the currently selected profile (ie. changing a single setting or more).
function RegistryManager:has_pending_changes()
    logf("Testing if Registry has pending changes: " .. tostring(next(self.__changed_settings) ~= nil))
    return (next(self.__changed_settings) ~= nil)
end

--- TODO get cached setting!
---@param option MCT.Option
function RegistryManager:get_default_setting(option)
    return option:get_default_value()
end

--- Save every option from every mod into this profile with a default (or cached) setting
function RegistryManager:save_all_mods()
    -- if not self.__data then self.__data = {} end
    
    --- TODO don't do this here or at all tbh
    --- TODO make sure EVERY option from EVERY mod is accounted for
    for mod_key,mod in pairs(mct:get_mods()) do
        -- if not self.__data[mod_key] then self.__data[mod_key] = {} end
        for option_key,option in pairs(mod:get_options()) do
            -- logf("checking option %s", option_key)
            -- if not self.__data[mod_key][option_key] then
                
                local value = RegistryManager:get_default_setting(option)
                -- logf("saving [%s].__mods[%s][%s] = %s", self.__data, mod_key, option_key, tostring(value))
                -- self.__data[mod_key][option_key] = value
            -- end
        end
    end
end

function RegistryManager:read_profiles_file()
    local file = io.open(self:get_file_path(self.__profiles_file), "r+")

    if not file then
        return
    end

    local str = file:read("*a")
    file:close()
    
    local t = loadstring(str)()

    self.__saved_profiles = {}

    if not is_table(t) then return end

    local ProfileClass = mct:get_profile_class()
    
    --- instantiate all the profiles!
    for profile_key, profile_data in pairs(t) do
        local new_profile = ProfileClass:instantiate(profile_data)
        self.__saved_profiles[profile_key] = new_profile
    end
end

function RegistryManager:save_profiles_file()
    local file = io.open(self:get_file_path(self.__profiles_file), "w+")
    if not file then return end

    ModLog("Saved profiles table is " .. tostring(self.__saved_profiles))

    for k,v in pairs(self.__saved_profiles) do
        ModLog("Saved profile " .. k)
        -- ModLog("Has details: " .. tostring(v))

        if is_table(v) then
            for ik,iv in pairs(v) do
                ModLog("\t["..tostring(ik).."] = "..tostring(iv))
            end
        end
    end

    local t
    local ok, errmsg = pcall(function()
        t = table_print(self.__saved_profiles, {["class"] = true})
    end) if not ok then err(errmsg) end
    ModLog("Saved profiles string is " .. tostring(t))

    file:write("return " .. t)
    file:close()
end

--- TODO split this up into a few sub functions so it's easier to call externally
function RegistryManager:read_registry_file()
    local file = io.open(self:get_file_path(self.__main_file), "r+")

    if not file then self:save_file_with_defaults() return self:read_registry_file() end

    local str = file:read("*a")
    file:close()

    local t, t_err = loadstring(str)

    if not t then
        --- Don't read - set values to default and save immediately.
        errf("Error while reading MCT.Registry file: " .. tostring(t_err))
        self:save_file_with_defaults()
        return self:read_registry_file()
    end

    t = t()

    if not t or not t.global then
        --- Don't read - set values to default and save immediately.
        self:save_file_with_defaults()
        return self:read_registry_file()
    end

    logf("Loading MCT.Registry file!")

    local all_mods = mct:get_mods()
    for mod_key, mod_obj in pairs(all_mods) do
        local this_mod_data = t.global.saved_mods[mod_key]
        if is_table(this_mod_data) then
            mod_obj:load_data(this_mod_data)
            for option_key, option_obj in pairs(mod_obj:get_options()) do
                logf("Searching for saved settings for %s.%s", mod_key, option_key)

                local this_option_data = this_mod_data.options[option_key]
                option_obj:load_data(this_option_data)
            end
            
            if this_mod_data.data then
                if this_mod_data.data.userdata then
                    mod_obj:set_userdata(this_mod_data.data.userdata)
                end
            end
        else
            logf("Can't find any saved information for mod %s", mod_key)
        end
    end

    self.__last_used_campaign_index = t.last_used_campaign_index
    self.__campaigns = t.campaigns

    self:save(true)
end

--- TODO load new Profiles file
function RegistryManager:load()
    local con = mct:context()
    logf("MCT Load is being called in context %s.", con)

    -- self:save_all_mods()
    if not cm then
        self:read_registry_file()
        self:read_profiles_file()
        self:port_forward()
    end

    if cm then
        local is_mp = cm.game_interface:model():is_multiplayer()

        if is_mp then
            mct:get_sync():init_campaign()
            mct:set_mode("campaign", false) -- host has edit enabled in the init_campaign function.
        else
            mct:set_mode("campaign", true)
        end

        --- read the saved settings for current options!
        cm:add_loading_game_callback(function(context)
            local ok, err = pcall(function()
                self:read_registry_file()
                self:read_profiles_file()

                self:load_game(context)

                logf("Trigger MctInitialized")
                core:trigger_custom_event("MctInitialized", {["mct"] = mct, ["is_multiplayer"] = is_mp})
            end) if not ok then logf(err) end
        end)

        cm:add_saving_game_callback(function(context) self:save_game(context) end)

    elseif con == "campaign_battle" then
        --- We're in a campaign battle - pull the info from the campaign registry!
        self:load_campaign_battle()

        mct:set_mode("campaign", false)

        core:trigger_custom_event("MctInitialized", {["mct"] = mct, ["is_multiplayer"] = false})
    else
        if con == "frontend" then
            self:new_frontend()
            mct:set_mode("global", true)
        elseif con == "battle" then
            mct:set_mode("global", false)
        end

        core:trigger_custom_event("MctInitialized", {["mct"] = mct, ["is_multiplayer"] = false})
    end
end

function RegistryManager:save_file_with_defaults()
    local file = io.open(self:get_file_path(self.__main_file), "w+")
    ---@cast file file*
    
    logf("Saving registry file with defaults.")

    local t = {
        global = {
            saved_mods = {}
        },
        campaigns = {},
        last_used_campaign_index = 0,
    }

    local all_mods = mct:get_mods()
    for mod_key,mod_obj in pairs(all_mods) do
        t.global.saved_mods[mod_key] = {
            options = {},
            data = {},
        }

        local this = t.global.saved_mods[mod_key]

        for option_key, option_obj in pairs(mod_obj:get_options()) do
            this.options[option_key] = {
                name = option_obj:get_text(),
                description = option_obj:get_tooltip_text(),
                setting = option_obj:get_value_for_save(true),
            }

            if option_obj:is_locked() then
                this.options[option_key].is_locked = true
                this.options[option_key].lock_reason = option_obj:get_lock_reason()
            end
        end

        this.data.name = mod_obj:get_title()
        this.data.description = mod_obj:get_description()

        --- TODO save mod_userdata in the global registry!
    end


    local t_str = table_print(t)

    file:write("return " .. t_str)
    file:close()
end

function RegistryManager:save_registry_file()
    local old = io.open(self:get_file_path(self.__main_file), "r+")
    ---@cast old file*
    local str = old:read("*a")
    local t = loadstring(str)()

    old:close()

    local st = os.clock()

    if not is_table(t) then
        t = {
            ["global"] = {
                ["saved_mods"] = {},
            },
            ["campaigns"] = {},
            ["last_used_campaign_index"] = self.__last_used_campaign_index,
        }
    end

    t.last_used_campaign_index = self.__last_used_campaign_index

    if not t.global then
        t.global = {saved_mods = {},}
    end

    --- TODO make sure we're taking into account things not held in active memory (ie. reading the .campaign field from the registry file so that stays true (should the .campaign field be a foreign file? (yes!)))
    
    --- Loop through all mod objects, add a field in .saved_mods.
    if not t.campaigns then
        t.campaigns = {}
    end

    if not t.campaigns[self.__this_campaign] then
        t.campaigns[self.__this_campaign] = {saved_mods = {}}
    end

    logf("Saving the MCT.Registry!")

    local all_mods = mct:get_mods()
    for mod_key,mod_obj in pairs(all_mods) do
        if not t.global.saved_mods[mod_key] then
            t.global.saved_mods[mod_key] = {
                options = {},
                data = {},
            }
        end

        -- logf("\tIn mod [%s]", mod_key)

        local this = t.global.saved_mods[mod_key]
        local this_campaign

        if mct:context() == "campaign" then
            if not t.campaigns[self.__this_campaign].saved_mods[mod_key] then
                t.campaigns[self.__this_campaign].saved_mods[mod_key] = {
                    options = {},
                }
            end

            this_campaign = t.campaigns[self.__this_campaign].saved_mods[mod_key]
        end

        for option_key, option_obj in pairs(mod_obj:get_options()) do
            -- logf("\t\tIn option [%s]", option_key)

            --- Save all the shared data we need to keep in the global reg
            this.options[option_key] = {
                name = option_obj:get_text(),
                description = option_obj:get_tooltip_text(),
                default_value = option_obj:get_value_for_save(true),
            }

            local this_option = this.options[option_key]

            -- Save the setting for this option globally.
            -- this.options[option_key].setting = option_obj:get_value_for_save()

            -- if this option is global, save its changes in the global registry
            if option_obj:is_global() then
                -- logf("\t\t\tSaving this option as global!")
                this_option.setting = option_obj:get_value_for_save()

                -- logf("\t\t\tFinalized setting is %s", tostring(option_obj:get_value_for_save()))

                if option_obj:is_locked() then
                    this_option.is_locked = true
                    this_option.lock_reason = option_obj:get_lock_reason()
                end
            else
                -- otherwise, this option is campaign-specific, and we need to track both sets of changes.
                -- logf("\t\t\tSaving this option as campaign-specific!")

                -- Save the global changes, always.
                
                -- if we're in a campaign, save the campaign-specific changes
                if this_campaign then
                    this_option.global_value = option_obj:get_global_value()

                    this_campaign.options[option_key] = {
                        setting = option_obj:get_value_for_save(),
                    }
    
                    if option_obj:is_locked() then
                        this_campaign.options[option_key].is_locked = true
                        this_campaign.options[option_key].lock_reason = option_obj:get_lock_reason()
                    end
                else
                    -- "Used" setting and global setting should match when not in campaign.
                    this_option.setting = option_obj:get_value_for_save()
                    this_option.global_value = option_obj:get_value_for_save()

                    if option_obj:is_locked() then
                        this_option.is_locked = true
                        this_option.lock_reason = option_obj:get_lock_reason()
                    end
                end
            end
        end

        this.data.name = mod_obj:get_title()
        this.data.description = mod_obj:get_description()
        this.data.userdata = mod_obj:get_userdata()
    end

    -- local et = os.clock() - st

    -- local st2 = os.clock()
    -- local t_str = table_printer:print(t)
    local t_str = table_print(t)
    -- local t_str = GLib.Json.encode(t)
    -- local et2 = os.clock() - st2

    -- local st3 = os.clock()

    local file = io.open(self:get_file_path(self.__main_file), "w+")
    ---@cast file file*
    file:write("return " .. t_str)
    file:close()

    -- local et3 = os.clock() - st3

    -- logf("Time to build table: %dms", et * 1000)
    -- logf("Time to build string: %dms", et2 * 1000)
    -- logf("Time to print string: %dms", et3 * 1000)
end

--- TODO save the info of this campaign into a registry file so we can get the options and settings in the Frontend easily.
function RegistryManager:save_campaign_info()

end

--- TODO read the info of a previously saved campaign savegame
function RegistryManager:read_campaign_info(save_index)

end

function RegistryManager:new_frontend()
    --listener for on sp_grand_campaign or mp_grand_campaign, setup_next_campaign_registry
    core:add_listener(
        "NewCampaign",
        "FrontendScreenTransition",
        function(context)
            return context.string == "sp_grand_campaign" or context.string == "mp_grand_campaign"
        end,
        function(context)
            self:setup_next_campaign_registry()
        end,
        true
    )
end

--- Load up the next campaign registry in the background, and save a pointer to it.
--- We'll then apply all saved values from the Global Registry into this transient registry, and save it to file after any changes.
--- If the user doesn't begin a new campaign before this registry is used, it'll be deleted.
function RegistryManager:setup_next_campaign_registry()
    local ncr = self.RegistryInstance:new()
    self.__registries.NextCampaign = ncr

    local all_mods = mct:get_mods()

    for mod_key, mod_obj in pairs(all_mods) do
        local this_mod_data = ncr:get_saved_mod_data(mod_key)
        if is_table(this_mod_data) then
            ncr:load_data(this_mod_data)
            for option_key, option_obj in pairs(mod_obj:get_options()) do
                logf("Searching for saved settings for %s.%s", mod_key, option_key)

                local this_option_data = this_mod_data.options[option_key]
                option_obj:load_data(this_option_data)
            end
            
            if this_mod_data.data then
                if this_mod_data.data.userdata then
                    mod_obj:set_userdata(this_mod_data.data.userdata)
                end
            end
        else
            logf("Can't find any saved information for mod %s", mod_key)
        end
    end
end

--- if we're in a campaign battle, read the SVR String to get the campaign's index and pull the settings therein.
function RegistryManager:load_campaign_battle()
    local this_campaign_str = core:get_svr():LoadString("mct_registry_campaign_index")
    local this_campaign_index = tonumber(this_campaign_str)
    if not this_campaign_index then
        -- errmsg?
        return false
    end

    local file = io.open(self:get_file_path(self.__main_file), "r+")
    if file then
        local t = loadstring(file:read("*a"))()
        local this_campaign = t.campaigns[this_campaign_index]

        for mod_key, mod_data in pairs(this_campaign.saved_mods) do
            local mod_obj = mct:get_mod_by_key(mod_key)
            if mod_obj then
                for option_key, option_data in pairs(mod_data.options) do
                    local option_obj = mod_obj:get_option_by_key(option_key)
                    if option_obj then
                        if is_nil(option_data.setting) then option_data.setting = option_obj:get_default_value() end

                        option_obj._finalized_setting = option_data.setting
                        option_obj._is_locked = option_data.is_locked
                        option_obj._lock_reason = option_data.lock_reason
                    end
                end
            end
        end
    end
end

--- save the settings info into this campaign's SaveGameHeader
--- for the first time through, this will save the last-used settings in the frontend.
function RegistryManager:save_game(context)
    local t = {
        ["saved_mods"] = {}, 
        ["this_campaign_index"] = self.__this_campaign
    }

    local all_mods = mct:get_mods()
    for mod_key,mod_obj in pairs(all_mods) do
        t.saved_mods[mod_key] = {
            options = {},
        }

        local this = t.saved_mods[mod_key].options

        for option_key, option_obj in pairs(mod_obj:get_options()) do
            if not option_obj:is_global() then
                this[option_key] =  {
                    setting = option_obj:get_value_for_save()
                }
                logf("Saving %s.%s in Campaign Registry as %s", mod_key, option_key, tostring(option_obj:get_value_for_save()))

                if option_obj:is_locked() then
                    this[option_key].is_locked = true
                    this[option_key].lock_reason = option_obj:get_lock_reason()
                end
            end
        end
    end

    cm:save_named_value("mct_registry", t, context)

    core:get_svr():SaveString("mct_registry_campaign_index", tostring(self.__this_campaign))

    -- if this is our first save with this campaign, iterate the counter. This allows us to make a new campaign, use the next index, but choose to abandon that save without holding the settings in Registry. IE., if we're at index 4, we make a new campaign, and abandon it without saving it, we can reuse index 4.
    if self.__last_used_campaign_index + 1 == self.__this_campaign then
        self.__last_used_campaign_index = self.__this_campaign
    end
end

--- load the settings for this campaign into memory
function RegistryManager:load_game(context)
    local registry_data = cm:load_named_value("mct_registry", {}, context)
    ---@cast registry_data table

    if is_nil(next(registry_data)) then
        --- assign this_campaign to the next index, and iterate that counter. (ie. if last index is 0, assign this campaign to 1, and save 1 in MCT so we iterate it next time)
        local index = self.__last_used_campaign_index + 1
        self.__this_campaign = index

        logf("Loading new campaign index %d", self.__this_campaign)

        core:get_svr():SaveString("mct_registry_campaign_index", tostring(self.__this_campaign))
        return
    end

    for mod_key, mod_data in pairs(registry_data.saved_mods) do
        local mod_obj = mct:get_mod_by_key(mod_key)
        if mod_obj then
            for option_key, option_data in pairs(mod_data.options) do
                local option_obj = mod_obj:get_option_by_key(option_key)
                if option_obj then
                    if is_nil(option_data.setting) then
                        option_data.setting = option_obj:get_default_value()
                    end

                    logf("Loading saved setting for %s.%s as %s", mod_key, option_key, tostring(option_data.setting))
                    option_obj:set_finalized_setting(option_data.setting, true)

                    if option_data.is_locked then
                        option_obj._is_locked = true
                        option_obj._lock_reason = option_data.lock_reason
                    end
                end
            end
        end
    end

    self.__this_campaign = registry_data.this_campaign_index
    core:get_svr():SaveString("mct_registry_campaign_index", tostring(self.__this_campaign))
end

return RegistryManager