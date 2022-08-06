--- TODO the system for handling global registry values, context-specific registry values, and campaign-saved registry values

--- TODO the flow should be:
--[[
    open the existing mct_registry.lua file, and read all the context-specific saved settings we have here, cached settings, etc.
    if we're in campaign, load up the saved settings from the campaign save (and save those in the registry so we can access them through frontend)
    if we're in campaign battle, we should be using the same saved settings
    if we're in quick battle or frontend, we should be using the global settings
]]

local mct = get_mct()
local log,logf,err,errf = get_vlog("[mct_registry]")

---@class MCT.Registry : Class
local defaults = {
    --- TODO
    __saved_profiles = {},

    ---@alias changed_settings {old_value:any,new_value:any}

    -- a better way to read if any settings have been changed
    -- table of mod keys (only added when a setting is changed)
    -- within each mod key table, option keys (only added when that specific option changed)
    -- within each option key table, two field - old_value (for finalized-setting) and new_value (for selected-setting) (option key table removed if new_value is set to old_value)
    ---@type table<string, table<string, changed_settings>> Changed-in-UI settings
    __changed_settings = {},

    --- TODO rename this shit.
    ---@type boolean If any settings were changed during this "session", ie. one panel open/close
    __settings_changed = false,

    __last_used_campaign_index = 0,

    __this_campaign = 0,

    __campaigns = {},
}

---@class MCT.Registry : Class
local Registry = VLib.NewClass("MCT.Registry", defaults)

function Registry:init()
    self.appdata_path = string.gsub(common.get_appdata_screenshots_path(), "screenshots\\$", "scripts\\")

    --- TODO read the old file and register everything in active memory
    self:read_file()
end

function Registry:get_file_path()
    local appdata = string.gsub(common.get_appdata_screenshots_path(), "screenshots\\$", "scripts\\")
    return appdata .. "mct_registry.lua"
end

--- TODO discard the "changed settings" system, or at least tweak it so it's just used to inform the script about changed settings or something along those lines.
--- TODO serialize-to-file function
--- TODO hold campaign registry within a file instead of save game? To be read outside of campaign, maybe later? Both?
--- TODO handle held-saved-settings (cached settings) somehow someway
--- TODO print stuff into appdata/scripts/

function Registry:clear_changed_settings(clear_bool)
    self.__changed_settings = {}

    if clear_bool then
        self.__settings_changed = false
    end
end

-- this saves the changed-setting, called whenever @{mct_option:set_selected_setting} is called (except for creation).
---@param option_obj MCT.Option
---@param new_value any
---@param is_popup_open any
---@return boolean
function Registry:set_changed_setting(option_obj, new_value, is_popup_open)
    if not mct:is_mct_option(option_obj) then
        VLib.Error("set_changed_setting() called, but the option provided ["..tostring(option_obj).."] is not a valid MCT.Option!")
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

    VLib.Log("Setting changed setting %s.%s to %s; former is %s", mod_key, option_key, tostring(new_value), tostring(old))

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

        VLib.Log("%s.%s old = %s", mod_key, option_key, tostring(old))
        VLib.Log("%s.%s new = %s", mod_key, option_key, tostring(new_value))
    end
end

function Registry:get_changed_settings(mod_key, option_key)
    if is_string(mod_key) then
        if is_string(option_key) then
            return self.__changed_settings[mod_key] and self.__changed_settings[mod_key][option_key] and self.__changed_settings[mod_key][option_key]["new_value"]
        end
        return self.__changed_settings[mod_key]
    end

    return self.__changed_settings
end

---@param option_obj MCT.Option
function Registry:get_selected_setting_for_option(option_obj)
    local value

    local mod_key = option_obj:get_mod_key()
    local option_key = option_obj:get_key()

    ---@type any
    value = self:get_changed_settings(mod_key, option_key)
    if not is_nil(value) then return value end

    value = option_obj:get_finalized_setting()

    if not is_nil(value) then return value end

    value = option_obj:get_default_value()

    return value
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

function Registry:clear_changed_settings_for_mod(mod_key)
    self.__changed_settings[mod_key] = nil
end

function Registry:finalize_first_time()
    for _, mod in pairs(mct:get_mods()) do
        mod:load_finalized_settings()
    end

    self:save_file()
end

---@param mod_obj MCT.Mod
function Registry:finalize_mod(mod_obj)
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

function Registry:finalize()
    local mods = mct:get_mods()

    for key, mod in pairs(mods) do
        self:finalize_mod(mod)
        logf("Finalized mod [%s]", key)
    end

    self:save_file()

    --- TODO rename this and put it into the UI object
    self.__settings_changed = true
end

--- TODO combine with :finalize()!
function Registry:local_only_finalize()

end

--- Check whether there are any pending changes.
---@return boolean PendingSettingChanges Whether there's pending changes in the currently selected profile (ie. changing a single setting or more).
function Registry:has_pending_changes()
    logf("Testing if Registry has pending changes: " .. tostring(next(self.__changed_settings) ~= nil))
    return (next(self.__changed_settings) ~= nil)
end

--- TODO get cached setting!
---@param option MCT.Option
function Registry:get_default_setting(option)
    return option:get_default_value()
end

--- Save every option from every mod into this profile with a default (or cached) setting
function Registry:save_all_mods()
    -- if not self.__data then self.__data = {} end
    
    --- TODO don't do this here or at all tbh
    --- TODO make sure EVERY option from EVERY mod is accounted for
    for mod_key,mod in pairs(mct:get_mods()) do
        -- if not self.__data[mod_key] then self.__data[mod_key] = {} end
        for option_key,option in pairs(mod:get_options()) do
            -- logf("checking option %s", option_key)
            -- if not self.__data[mod_key][option_key] then
                
                local value = Registry:get_default_setting(option)
                -- logf("saving [%s].__mods[%s][%s] = %s", self.__data, mod_key, option_key, tostring(value))
                -- self.__data[mod_key][option_key] = value
            -- end
        end
    end
end


function Registry:read_file()
    local file = io.open(self:get_file_path(), "r+")

    if not file then self:save_file_with_defaults() return self:read_file() end

    local str = file:read("*a")

    local t = loadstring(str)()

    if not t or not t.global then
        --- Don't read - set values to default and save immediately.
        self:save_file_with_defaults()
        return self:read_file()
    end

    local all_mods = mct:get_mods()
    for mod_key, mod_obj in pairs(all_mods) do
        if t.global.saved_mods[mod_key] then
            for option_key, option_obj in pairs(mod_obj:get_options()) do
                local test = t.global.saved_mods[mod_key].options[option_key]

                -- if we have something saved in the global registry ...
                if test and test.setting then

                    -- if this option is global OR we're outside of a "campaign" context ...
                    if option_obj:is_global() or mct:context() ~= "campaign" then

                        -- assign finalized settings!
                        option_obj._finalized_setting = test.setting or option_obj:get_default_value()
                        option_obj._is_locked = (is_boolean(test.is_locked) and test.is_locked) or false
                        option_obj._lock_reason = (is_string(test.lock_reason) and test.lock_reason) or ""
                    end
                end
            end
        end
    end

    self.__last_used_campaign_index = t.last_used_campaign_index
    self.__campaigns = t.campaigns

    --- Loaded in save_game()
    self.__this_campaign = 0

    file:close()
end

function Registry:load(loading_game_context)
    self:save_all_mods()
    self:read_file()

    if cm and loading_game_context then
        --- TODO read the saved settings for current options!
        self:load_game(loading_game_context)
        cm:add_saving_game_callback(function(context) self:save_game(context) end)
    end
end

function Registry:save_file_with_defaults()
    local file = io.open(self:get_file_path(), "w+")
    ---@cast file file*

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
            }

            -- if option_obj:is_global() or mct:context() ~= "campaign" then
                this.options[option_key].setting = option_obj:get_default_value()
                --- TODO

                if option_obj:is_locked() then
                    this.options[option_key].is_locked = true
                    this.options[option_key].lock_reason = option_obj:get_lock_reason()
                end
            -- end
        end

        this.data.name = mod_obj:get_title()
        this.data.description = mod_obj:get_description()

        --- TODO save mod_userdata in the global registry!
    end

    local t_str = table_printer:print(t)

    file:write("return " .. t_str)
    file:close()
end

function Registry:save_file()
    local file = io.open(self:get_file_path(), "w+")
    ---@cast file file*
    local t = {
        ["global"] = {
            ["saved_mods"] = {},
        },
        ["campaign"] = self.__campaigns,
        ["last_used_campaign_index"] = self.__last_used_campaign_index,
    }

    --- TODO make sure we're taking into account things not held in active memory (ie. reading the .campaign field from the registry file so that stays true (should the .campaign field be a foreign file? (yes!)))

    --- Loop through all mod objects, add a field in .saved_mods.

    local all_mods = mct:get_mods()
    for mod_key,mod_obj in pairs(all_mods) do
        t.global.saved_mods[mod_key] = {
            options = {},
            data = {},
        }

        local this = t.global.saved_mods[mod_key]
        local this_campaign = t.campaign[self.__this_campaign]

        if mct:context() == "campaign" then
            this_campaign[mod_key] = {
                options = {},
            }
        end

        for option_key, option_obj in pairs(mod_obj:get_options()) do
            this.options[option_key] = {
                name = option_obj:get_text(),
                description = option_obj:get_tooltip_text(),
            }

            if option_obj:is_global() then
                this.options[option_key].setting = option_obj:get_finalized_setting()
                --- TODO

                if option_obj:is_locked() then
                    this.options[option_key].is_locked = true
                    this.options[option_key].lock_reason = option_obj:get_lock_reason()
                end
            else

                -- this.options[option_key].setting = 
                if mct:context() == "campaign" then
                    this_campaign[mod_key].options[option_key] = {
                        setting = option_obj:get_finalized_setting(),
                    }

                    if option_obj:is_locked() then
                        this_campaign[mod_key].options.is_locked = true
                        this_campaign[mod_key].options.lock_reason = option_obj:get_lock_reason()
                    end
                end
            end
        end

        this.data.name = mod_obj:get_title()
        this.data.description = mod_obj:get_description()

        --- TODO save mod_userdata in the global registry!
    end

    local t_str = table_printer:print(t)

    file:write("return " .. t_str)
    file:close()
end

--- TODO save the info of this campaign into a registry file so we can get the options and settings in the Frontend easily.
function Registry:save_campaign_info()

end

--- TODO read the info of a previously saved campaign savegame
function Registry:read_campaign_info(save_index)

end

--- save the settings info into this campaign's SaveGameHeader
--- for the first time through, this will save the last-used settings in the frontend.
function Registry:save_game(context)
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
            this[option_key] =  {}
            if not option_obj:is_global() then
                this[option_key].setting = option_obj:get_finalized_setting()
                --- TODO

                if option_obj:is_locked() then
                    this[option_key].is_locked = true
                    this[option_key].lock_reason = option_obj:get_lock_reason()
                end
            end
        end
    end

    cm:save_named_value("mct_registry", t, context)
end

--- TODO load the settings for this campaign into memory
function Registry:load_game(context)
    local registry_data = cm:load_named_value("mct_registry", {}, context)
    ---@cast registry_data table

    if is_nil(next(registry_data)) then
        --- assign this_campaign to the next index, and iterate that counter. (ie. if last index is 0, assign this campaign to 1, and save 1 in MCT so we iterate it next time)
        local index = self.__last_used_campaign_index + 1
        self.__this_campaign = index
        self.__last_used_campaign_index = index
    end

    for mod_key, mod_data in pairs(registry_data.saved_mods) do
        local mod_obj = mct:get_mod_by_key(mod_key)
        if mod_obj then
            for option_key, option_data in pairs(mod_data.options) do
                local option_obj = mod_obj:get_option_by_key(option_key)
                if option_obj then
                    option_obj._finalized_setting = option_data.setting

                    if option_data.is_locked then
                        option_obj._is_locked = true
                        option_obj._lock_reason = option_data.lock_reason
                    end
                end
            end
        end
    end

    self.__this_campaign = registry_data.this_campaign_index
end

--- TODO forward compatibility
function Registry:adapt_old_file()

end


return Registry