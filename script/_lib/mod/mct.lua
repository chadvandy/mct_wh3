---@alias MCT.OptionType 'slider'|'dropdown'|'checkbox'|'text_input'

---@class ModConfigurationTool:Class
local mct_defaults = {
    _mods_path = "/script/mct/settings/",
    _self_path = "/script/vlib/mct/",

    _finalized = false,
    _initialized = false,
    
    _registered_mods = {},
    _selected_mod = nil,

    _version = "0.8",
}

local load_module = VLib.LoadModule
local load_modules = VLib.LoadModules

---@class ModConfigurationTool:Class
local mct = VLib.NewClass("ModConfigurationTool", mct_defaults)

--- Initial creation and loading of MCT, and all the individual MCT Mods.
function mct:init()
    self:load_modules()
    self:load_mods()

    ---@diagnostic disable-next-line : missing-parameter
    core:add_static_object("mod_configuration_tool", self)

    if not core:is_campaign() then
        -- trigger load_and_start after all mod scripts are loaded!
        core:add_listener(
            "MCT_Init",
            "ScriptEventAllModsLoaded",
            true,
            function(context)
                local ok, err = pcall(function()
                mct:load_and_start()
                end) if not ok then vlogf(err) end
            end,
            false
        )
    else
        vlog("LISTENING FOR LOAD GAME")
        
        cm:add_loading_game_callback(function(context)
            vlog("LOADING GAME CALBACK")
            if not cm.game_interface:model():is_multiplayer() then
                mct:load_and_start(context, false)
            else
                mct:load_and_start(context, true)
            end

            vlog("Done the loading game callback!")
        end)
    end
end

--- Load up all the included modules for MCT - UI, Options, Settings, etc.
function mct:load_modules()
    local path = "script/vlib/mct/"
    local core_path = path .. "core/"
    local ui_path = path .. "ui/"
    local obj_path = path .. "objects/"
    local options_path = path .. "option_types/"

    ---@type MCT.Settings
    self.settings = load_module("settings", core_path)

    ---@type MCT.UI
    self.ui = load_module("main", ui_path)

    -- TODO auto-load all types
    ---@type table<string, MCT.Option>
    self._MCT_TYPES = { }

    ---@type MCT.Option
    self._MCT_OPTION = load_module("option", obj_path)
    
    ---@type MCT.Option.Dummy
    self._MCT_TYPES.dummy = load_module("dummy", options_path)

    ---@type MCT.Option.Slider
    self._MCT_TYPES.slider = load_module("slider", options_path)

    ---@type MCT.Option.Dropdown
    self._MCT_TYPES.dropdown = load_module("dropdown", options_path)

    ---@type MCT.Option.Checkbox
    self._MCT_TYPES.checkbox = load_module("checkbox", options_path)

    ---@type MCT.Option.TextInput
    self._MCT_TYPES.text_input = load_module("text_input", options_path)

    ---@type MCT.Mod
    self._MCT_MOD = load_module("mod", obj_path)

    ---@type MCT.Section
    self._MCT_SECTION = load_module("section", obj_path)
end

--- TODO get the option type

---comment
---@overload fun(key:"checkbox"):MCT.Option.Checkbox
---@overload fun(key:"text_input"):MCT.Option.TextInput
---@overload fun(key:"slider"):MCT.Option.Slider
---@overload fun(key:"dropdown"):MCT.Option.Dropdown
---@overload fun(key:"dummy"):MCT.Option.Dummy
---@param key string
---@return MCT.Option
function mct:get_option_type(key)
    if not is_string(key) then
        --- errmsg
    end

    if not self._MCT_TYPES[key] then
        --- errmsg
        return nil
    end

    return self._MCT_TYPES[key]
end

function mct:get_version()
    return self._version
end

--- TODO kill?
function mct:mp_prep()

end

--- TODO clean this the fuck up
function mct:load_and_start(loading_game_context, is_mp)
    self._initialized = true

    vlogf("LOAD AND START - Is this literally ever called?")

    core:add_listener(
        "who_is_the_host_tell_me_now_please",
        "UITrigger",
        function(context)
            return context:trigger():starts_with("mct_host|")
        end,
        function(context)
            out("UITrigger!")
            local str = context:trigger()
            local faction_key = string.gsub(str, "mct_host|", "")

            cm:set_saved_value("mct_host", faction_key)

            self.settings:mp_load()
        end,
        false
    )
    
    local function trigger(is_multi)
        core:trigger_custom_event("MctInitialized", {["mct"] = self, ["is_multiplayer"] = is_multi})
    end

    if __game_mode == __lib_type_campaign then
        if is_mp then
            out("Is MP! Pre-pre-first-tick")
            cm:add_pre_first_tick_callback(function()
                out("Pre first tick callback in mct_mp")
                if not cm:get_saved_value("mct_mp_init") then
                    out("MP INIT not done")
                    local my_faction = cm:get_local_faction_name(true)
                    --[[local their_faction = ""
                    local faction_keys = cm:get_human_factions()
                    if faction_keys[1] == my_faction then
                        their_faction = faction_keys[2]
                    else
                        their_faction = faction_keys[1]
                    end]]
                    
                    local is_host = core:svr_load_bool("local_is_host")
                    if is_host then
                        CampaignUI.TriggerCampaignScriptEvent(0, "mct_host|"..my_faction)
                    end
                    
                    -- if not cm:get_saved_value("mct_mp_init") then
                    cm:set_saved_value("mct_mp_init", true)
                    -- end
                    --self.settings:mp_load()
                    
                    --trigger()
                else
                    out("MP INIT done")
                    -- self.settings:mp_load()
                    --     -- trigger during pre-first-tick-callback to prevent time fuckery
                --     trigger(true)
                end
            end)
            out("Pre load game callback")
            self.settings:load_game_callback(loading_game_context)
            out("Post load game callback")
            --trigger(true)

            self:mp_prep()
            out("Post mp_prep()")


            cm:add_saving_game_callback(function(context) out("save game callback pre") self.settings:save_game_callback(context) end)
        else
            --- if it's a new game, save the currently selected profile into the save file, and load up that profile
            if cm:is_new_game() then
                vlogf("New game - loading!")
                self.settings:load_old()
            else
                self.settings:load_game_callback(loading_game_context)
            end

            cm:add_saving_game_callback(function(context) self.settings:save_game_callback(context) end)

            trigger(false)
        end
    else
        --log("frontend?")
        -- read the settings file
        local ok, msg = pcall(function()
            self.settings:load_old()

            trigger(false)
        end) if not ok then verr(msg) end
    end

    out("End of load_and_start")
end

function mct:load_mods()
    vlog("[mct] Loading Mod Settings!")
    local mods_path = self._mods_path
    load_modules(
        mods_path, 
        "*.lua", 
        function(filepath, module)
            vlogf("Loading mod %s!", filepath)

            -- module()
            --- TODO needed?
            -- local all_mods = self:get_mods_from_file(filepath)

            -- for _,mod in pairs(all_mods) do
            --     mod:finalize()
            -- end
        end
    )
end

function mct:open_panel()
    self.ui:open_frame()
end

function mct:set_selected_mod(mod_name)
    self._selected_mod = mod_name
end

function mct:get_selected_mod_name()
    return self._selected_mod
end

---@return MCT.Mod
function mct:get_selected_mod()
    return is_string(self:get_selected_mod_name()) and self:get_mod_by_key(self:get_selected_mod_name())
end



function mct:has_mod_with_name_been_registered(mod_name)
    return not not self._registered_mods[mod_name]
end

function mct:get_mod_with_name(mod_name)
    return self:get_mod_by_key(mod_name)
end

function mct:finalize_new()
    
end

--- Internal use only. Triggers all the functionality for "Finalize Settings!"
function mct:finalize()
    local ok, msg = pcall(function()
    if __game_mode == __lib_type_campaign then
        -- check if it's MP!
        if cm.game_interface:model():is_multiplayer() then
            -- check if it's the host
            if cm:get_local_faction_name(true) == cm:get_saved_value("mct_host") then
                vlog("Finalizing settings mid-campaign for MP.")
                self.settings:finalize()

                self._finalized = true
                self.ui.locally_edited = false

                -- communicate to both clients that this is happening!
                local mct_data = {}
                local all_mods = self:get_mods()
                for mod_key, mod_obj in pairs(all_mods) do
                    vlog("Looping through mod obj ["..mod_key.."]")
                    mct_data[mod_key] = {}
                    local all_options = mod_obj:get_options()

                    for option_key, option_obj in pairs(all_options) do
                        if not option_obj:get_local_only() then
                            vlog("Looping through option obj ["..option_key.."]")
                            mct_data[mod_key][option_key] = {}

                            vlog("Setting: "..tostring(option_obj:get_finalized_setting()))

                            mct_data[mod_key][option_key]._setting = option_obj:get_finalized_setting()
                        else
                            --?
                        end
                    end
                end
                ClMultiplayerEvents.notifyEvent("MctMpFinalized", 0, mct_data)

                self.settings:local_only_finalize(true)
            else
                self._finalized = true
                self.ui.locally_edited = false
                
                self.settings:local_only_finalize(false)
            end
        else
            -- it's SP, do regular stuff
            self.settings:finalize()

            self._finalized = true
    
            -- remove the "locally_edited" field
            self.ui.locally_edited = false
    
            core:trigger_custom_event("MctFinalized", {["mct"] = self, ["mp_sent"] = false})
        end
    else
        --- TODO if we haven't locally edited, don't do this?
        self.settings:finalize()

        self._finalized = true

        -- remove the "locally_edited" field
        self.ui.locally_edited = false

        core:trigger_custom_event("MctFinalized", {["mct"] = self, ["mp_sent"] = false})
    end
     end) if not ok then verr(msg) end
end

--- Getter for the @{mct_mod} with the supplied key.
---@param mod_name string Unique identifier for the desired mct_mod.
---@return MCT.Mod
function mct:get_mod_by_key(mod_name)
    if not is_string(mod_name) then
        verr("get_mod_by_key() called, but the mod_name provided ["..tostring(mod_name).."] is not a string!")
        return nil
    end
    
    local test = self._registered_mods[mod_name]
    if type(test) == "nil" then
        -- errlog("Trying to get mod with name ["..mod_name.."] but none is found! Returning nil.")
        return nil
    end
        
    return self._registered_mods[mod_name]
end

function mct:get_mods()
    return self._registered_mods
end

function mct:get_mods_from_file(filepath)
    local mod_list = self._registered_mods
    local retval = {}
    for key, mod in pairs(mod_list) do
        local compare_path = mod._FILEPATH

        if compare_path == filepath then
            retval[key] = mod
        end
    end

    return retval
end

--- Primary function to begin adding settings to a "mod".
--- Calls the internal function @{mct_mod.new}.
--- @param mod_name string The identifier for this mod.
--- @see mct_mod.new
---@return MCT.Mod
function mct:register_mod(mod_name)
    vlogf("Registering mod %s", mod_name)


    -- get info about where this function was called from, to save that Lua file as a part of the mod obj
    local info = debug.getinfo(2, "S")
    local filepath = info.source
    if self:has_mod_with_name_been_registered(mod_name) then
        verr("Loading mod with name ["..mod_name.."], but it's already been registered. Only use `mct:register_mod()` once. Returning the previous version.")
        return self:get_mod_by_key(mod_name)
    end

    if mod_name == "mct_cached_settings" then
        verr("mct:register_mod() called with key \"mct_cached_settings\". Why have you tried to do this? Use a different key.")
        return false
    end



    local new_mod = self._MCT_MOD:new(mod_name)
    new_mod._FILEPATH = filepath
    self._registered_mods[mod_name] = new_mod


    vlogf("Registered mod %s", mod_name)

    return new_mod
end

--- Type-checker for @{mct_mod}s
--- @param obj any Tested value.
--- @return boolean Whether it passes.
function mct:is_mct_mod(obj)
    return is_table(obj) and obj.class
    and obj:instanceOf(mct._MCT_MOD)
end

--- Type-checker for @{mct_option}s
--- @param obj any Tested value.
--- @return boolean Whether it passes.
function mct:is_mct_option(obj)
    return is_table(obj) and obj.class
    and obj:instanceOf(mct._MCT_OPTION)
end

--- Type-checker for @{mct_section}s
--- @param obj any Tested value.
--- @return boolean Whether it passes.
function mct:is_mct_section(obj)
    return is_table(obj) and obj.class
    and obj:instanceOf(mct._MCT_SECTION)
end

--- Type-checker for @{mct_option} types.
--- @param val any Tested value.
--- @return boolean Whether it passes.
function mct:is_valid_option_type(val)
    return self._MCT_TYPES[val] ~= nil
end

function mct:get_valid_option_types()
    local retval = {}
    for k,_ in pairs(self._MCT_TYPES) do
        if k ~= "template" then
            retval[#retval+1] = k
        end
    end

    return retval
end

function mct:get_valid_option_types_table()
    local types = self:get_valid_option_types()
    local o = {}

    for i = 1, #types do
        local type = types[i]
        o[type] = {}
    end

    return o
end

function get_mct()
    return mct
end

mct:init()

core:add_ui_created_callback(function()
    mct.ui:ui_created()
end)